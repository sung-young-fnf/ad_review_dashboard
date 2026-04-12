#!/bin/bash
# .claude/hooks/stop-task-validator.sh
# Stop Event Hook: task-planner 완료 후 task-validator 자동 실행
# Version: v1.0

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-task-validator.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-validator] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Phase 0: stdin 읽기 (Agent 정보)
# ============================================================================
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, length: ${#event_info}"
else
  event_info=""
  log_debug "No stdin"
fi

# 빈 입력 처리
if [[ -z "$event_info" ]] || [[ "${#event_info}" -lt 10 ]]; then
  log_debug "Skipped: empty input"
  exit 0
fi

# ============================================================================
# Phase 1: Agent 정보 파싱
# ============================================================================
if ! command -v jq &> /dev/null; then
  log_debug "jq not found, skipping"
  exit 0
fi

if ! echo "$event_info" | jq -e . >/dev/null 2>&1; then
  log_debug "Invalid JSON, skipping"
  exit 0
fi

# Agent 타입 추출
agent_type=$(echo "$event_info" | jq -r '.agent_type // .subagent_type // empty' 2>/dev/null || echo "")
agent_status=$(echo "$event_info" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
session_id=$(echo "$event_info" | jq -r '.session_id // empty' 2>/dev/null || echo "")

log_debug "agent_type: $agent_type"
log_debug "agent_status: $agent_status"
log_debug "session_id: $session_id"

# ============================================================================
# Phase 2: task-planner 완료 감지
# ============================================================================
# task-planner가 아니거나 성공이 아니면 스킵
if [[ "$agent_type" != "task-planner" ]] && [[ "$agent_type" != "03-design/task-planner" ]]; then
  log_debug "Not task-planner, skipping"
  exit 0
fi

if [[ "$agent_status" != "success" ]] && [[ "$agent_status" != "completed" ]]; then
  log_debug "task-planner not successful, skipping"
  exit 0
fi

log_debug "✅ task-planner completed successfully! Triggering validation..."

# ============================================================================
# Phase 3: 환경 설정
# ============================================================================
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "PROJECT_ROOT: $PROJECT_ROOT"

# Task 디렉토리 찾기 (최근 수정된 Story의 tasks/ 폴더)
TASKS_DIR=$(find "$PROJECT_ROOT/docs/epics" -type d -name "tasks" -mmin -10 2>/dev/null | head -1 || echo "")

if [[ -z "$TASKS_DIR" ]]; then
  # _backlog에서 찾기
  TASKS_DIR=$(find "$PROJECT_ROOT/docs/epics/_backlog" -type d -name "tasks" -mmin -10 2>/dev/null | head -1 || echo "")
fi

if [[ -z "$TASKS_DIR" ]]; then
  log_debug "No recent tasks directory found, skipping"
  exit 0
fi

log_debug "Found Tasks: $TASKS_DIR"

# Task 개수 확인
TASK_COUNT=$(find "$TASKS_DIR" -name "T*.md" -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0")
log_debug "Task count: $TASK_COUNT"

# Story 이름 추출
STORY_DIR=$(dirname "$TASKS_DIR")
STORY_NAME=$(basename "$STORY_DIR")

# ============================================================================
# Phase 4: Serena Memory에 handoff 저장
# ============================================================================
if command -v mcp-cli &> /dev/null; then
  log_debug "Saving handoff to Serena Memory..."

  # Handoff memory 저장
  mcp-cli call serena/write_memory "{
    \"name\": \"handoff_task_validation\",
    \"content\": \"task-planner completed. Trigger task-validator for $STORY_NAME.\",
    \"metadata\": {
      \"trigger\": \"task-planner\",
      \"session_id\": \"$session_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"tasks_dir\": \"$TASKS_DIR\",
      \"story_name\": \"$STORY_NAME\",
      \"task_count\": $TASK_COUNT
    },
    \"ttl\": 1800
  }" >/dev/null 2>&1 && log_debug "Handoff saved successfully" || log_debug "Failed to save handoff"

  # 사용자에게 알림 출력
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              📋 Task Validation Triggered                                 ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ task-planner 완료 감지
   Story: $STORY_NAME
   Tasks: ${TASK_COUNT}개 생성

💾 Handoff memory 저장 완료
   → 다음 메시지에서 task-validator 자동 실행 예정

🔍 검증 항목 (경량):
   🔴 P0 (치명적):
      - Story AC ↔ Task 매핑 (100% 커버리지)
      - Task 순환 의존성
   🟡 P1 (경고):
      - Task 크기 (> 2일이면 분해 권장)

⚠️ P0 이슈 발견 시 task-planner에게 피드백 전달

───────────────────────────────────────────────────────────────────────────

EOF

else
  log_debug "mcp-cli not found, cannot save handoff"

  # 수동 실행 안내
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              📋 Task Validation Recommended                               ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ task-planner 완료 감지
   Tasks: ${TASK_COUNT}개 생성

💡 검증 실행 권장:

  bash .claude/agents/03-design/task-validator.sh "$STORY_DIR"

───────────────────────────────────────────────────────────────────────────

EOF

fi

log_debug "=== HOOK END ==="
exit 0
