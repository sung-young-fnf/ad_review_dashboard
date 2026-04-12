#!/bin/bash
# .claude/hooks/post/code-writer-retry-handler.sh
# code-writer Agent 재시도 메커니즘 (최대 3번)
# Task 미완료 감지 → 자동 재호출
# Version: v3.1

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
# NOTE: 현재 해제 상태 (디버깅 용이성 우선)
# exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [retry-handler] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Phase 0: stdin 읽기
# ============================================================================
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, length: ${#event_info}"
else
  event_info=""
  log_debug "No stdin"
fi

# 빈 입력 처리
if [[ -z "$event_info" ]] || [[ "${#event_info}" -lt 2 ]]; then
  log_debug "Skipped: empty input"
  echo '{"continue": true}'
  exit 0
fi

# ============================================================================
# Phase 1: 환경 변수 추출 + 2.0.42 agent_id/transcript 지원
# ============================================================================
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
TASK_ID="${CLAUDE_TASK_ID:-}"
EPIC_ID="${CLAUDE_EPIC_ID:-}"

# 2.0.42 신규 필드: agent_id, agent_transcript_path
# 2.1.47 신규 필드: last_assistant_message (transcript 파싱 불필요)
AGENT_ID=$(echo "$event_info" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
TRANSCRIPT_PATH=$(echo "$event_info" | jq -r '.agent_transcript_path // empty' 2>/dev/null || echo "")
LAST_ASSISTANT_MSG=$(echo "$event_info" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

log_debug "AGENT_TYPE: $AGENT_TYPE, TASK_ID: $TASK_ID, EPIC_ID: $EPIC_ID"
log_debug "AGENT_ID: $AGENT_ID, TRANSCRIPT_PATH: $TRANSCRIPT_PATH"

# Only run for code-writer Agent
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
  log_debug "Skipped: Not code-writer Agent"
  echo '{"continue": true}'
  exit 0
fi

# Get repo root
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RETRY_STATE="$REPO_ROOT/.claude/.code-writer-retry-state"
log_debug "REPO_ROOT: $REPO_ROOT"

# ============================================================================
# Step 1: Task 파일 찾기
# ============================================================================
TASK_FILE=""
if [ -n "$EPIC_ID" ] && [ -n "$TASK_ID" ]; then
  TASK_FILE=$(find "$REPO_ROOT/docs/epics/$EPIC_ID/tasks" -name "${TASK_ID}*.md" 2>/dev/null | head -1)
elif [ -n "$TASK_ID" ]; then
  TASK_FILE=$(find "$REPO_ROOT/docs/epics/_backlog" -name "${TASK_ID}_*.md" -o -name "${TASK_ID}.md" 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
  log_debug "Task file not found: $TASK_ID"
  echo '{"continue": true}'
  exit 0
fi

log_debug "Task file: $TASK_FILE"

# ============================================================================
# Step 2: Task 완료 여부 확인 (체크박스)
# ============================================================================
UNCHECKED_COUNT=$(grep -c "^- \[ \]" "$TASK_FILE" 2>/dev/null || echo "0")
CHECKED_COUNT=$(grep -c "^- \[x\]" "$TASK_FILE" 2>/dev/null || echo "0")
TOTAL_COUNT=$((UNCHECKED_COUNT + CHECKED_COUNT))

log_debug "Checkboxes: $CHECKED_COUNT/$TOTAL_COUNT completed"

# Task 완료 기준: 80% 이상 체크
if [ $TOTAL_COUNT -eq 0 ]; then
  log_debug "No checkboxes found, skipping"
  echo '{"continue": true}'
  exit 0
fi

COMPLETION_RATE=$((CHECKED_COUNT * 100 / TOTAL_COUNT))
log_debug "Completion rate: ${COMPLETION_RATE}%"

if [ $COMPLETION_RATE -ge 80 ]; then
  log_debug "Task completed (${COMPLETION_RATE}% >= 80%)"
  rm -f "$RETRY_STATE"  # 재시도 상태 초기화
  echo '{"continue": true}'
  exit 0
fi

# ============================================================================
# Step 3: 재시도 횟수 확인
# ============================================================================
RETRY_COUNT=0
if [ -f "$RETRY_STATE" ]; then
  STATE_TASK_ID=$(cat "$RETRY_STATE" | cut -d':' -f1)
  if [ "$STATE_TASK_ID" == "$TASK_ID" ]; then
    RETRY_COUNT=$(cat "$RETRY_STATE" | cut -d':' -f2)
  else
    # 다른 Task → 초기화
    RETRY_COUNT=0
  fi
fi

log_debug "Current retry count: $RETRY_COUNT"

# ============================================================================
# Step 4: 재시도 판단 (최대 3번)
# ============================================================================
MAX_RETRIES=3

if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
  # 3번 실패 → 사용자 개입 필요 (간소화된 출력)
  echo "⚠️ RETRY LIMIT: $TASK_ID (${COMPLETION_RATE}%, ${UNCHECKED_COUNT}개 미완료) → error-fixer 또는 task-planner 사용" >&2
  rm -f "$RETRY_STATE"
  log_debug "=== HOOK END (retry limit) ==="
  echo '{"continue": true}'
  exit 0
fi

# ============================================================================
# Step 5: 재시도 실행 (2.1.77 SendMessage + 2.1.47 last_assistant_message 활용)
# ============================================================================
RETRY_COUNT=$((RETRY_COUNT + 1))
echo "${TASK_ID}:${RETRY_COUNT}:${AGENT_ID}:$(date +%s)" > "$RETRY_STATE"

# 실패 원인 추출 (2.1.47: last_assistant_message 우선, transcript fallback)
FAILURE_REASON=""

# 1순위: last_assistant_message (2.1.47+) — 가장 정확한 최종 응답
if [[ -n "$LAST_ASSISTANT_MSG" ]]; then
  # 에러/실패 패턴 검색 (마지막 500자에서 핵심 추출)
  LAST_ERROR=$(echo "$LAST_ASSISTANT_MSG" | tail -c 500 | \
    grep -iE "(error|fail|exception|cannot|unable|not found|undefined|null)" | \
    tail -2 | tr '\n' ' ' | cut -c1-200)

  if [[ -n "$LAST_ERROR" ]]; then
    FAILURE_REASON=$(echo "$LAST_ERROR" | sed 's/"/\\"/g' | sed "s/'/\\'/g" | tr -d '\n\r')
    log_debug "Failure reason from last_assistant_message: $FAILURE_REASON"
  else
    # 에러 패턴 없으면 last_assistant_message 앞 200자 요약 사용
    FAILURE_REASON=$(echo "$LAST_ASSISTANT_MSG" | cut -c1-200 | sed 's/"/\\"/g' | tr -d '\n\r')
    log_debug "Using last_assistant_message summary as failure context"
  fi

# 2순위: transcript 파일 파싱 (fallback, 2.0.42~2.1.46)
elif [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  LAST_ERROR=$(tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | \
    grep -iE "(error|fail|exception|cannot|unable|not found|undefined|null)" | \
    tail -3 | tr '\n' ' ' | cut -c1-200)

  if [[ -n "$LAST_ERROR" ]]; then
    FAILURE_REASON=$(echo "$LAST_ERROR" | sed 's/"/\\"/g' | sed "s/'/\\'/g" | tr -d '\n\r')
    log_debug "Failure reason from transcript (fallback): $FAILURE_REASON"
  fi
fi

# 2.1.77 SendMessage 방식: agent_id가 있으면 SendMessage로 자동 재개 (stopped agent도 자동 wake)
if [[ -n "$AGENT_ID" ]]; then
  # SendMessage 사용 - 이전 컨텍스트 유지 + 실패 원인 포함
  if [[ -n "$FAILURE_REASON" ]]; then
    RETRY_MSG="🔄 RETRY ${RETRY_COUNT}/${MAX_RETRIES}: $TASK_ID (${COMPLETION_RATE}%)\n\n🔍 이전 실패 원인: ${FAILURE_REASON}\n\n💡 SendMessage로 컨텍스트 유지 재시도:\nSendMessage({to: '$AGENT_ID', content: '미완료 항목 ${UNCHECKED_COUNT}개 완료 필요. 이전 에러: ${FAILURE_REASON}'})"
  else
    RETRY_MSG="🔄 RETRY ${RETRY_COUNT}/${MAX_RETRIES}: $TASK_ID (${COMPLETION_RATE}%)\n\n💡 SendMessage로 컨텍스트 유지 재시도:\nSendMessage({to: '$AGENT_ID', content: '미완료 항목 ${UNCHECKED_COUNT}개 완료 필요'})"
  fi
else
  # 새로운 에이전트 실행 + 실패 원인 포함
  if [[ -n "$FAILURE_REASON" ]]; then
    RETRY_MSG="🔄 RETRY ${RETRY_COUNT}/${MAX_RETRIES}: $TASK_ID (${COMPLETION_RATE}%)\n\n🔍 이전 실패 원인: ${FAILURE_REASON}\n\n→ Task(subagent_type: '04-implementation/code-writer', prompt: '$TASK_ID 미완료 항목 완료. 이전 에러: ${FAILURE_REASON}')"
  else
    RETRY_MSG="🔄 RETRY ${RETRY_COUNT}/${MAX_RETRIES}: $TASK_ID (${COMPLETION_RATE}%)\n\n→ Task(subagent_type: '04-implementation/code-writer', prompt: '$TASK_ID 미완료 항목 완료')"
  fi
fi

log_debug "Retry prompt generated (${RETRY_COUNT}/${MAX_RETRIES}), has_agent_id=${AGENT_ID:+yes}"
log_debug "=== HOOK END (retry scheduled) ==="

# systemMessage로 재시도 안내 (stderr 대신)
cat << EOF
{
  "continue": true,
  "systemMessage": "$RETRY_MSG"
}
EOF
exit 0
