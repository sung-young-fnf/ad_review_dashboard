#!/bin/bash
# .claude/hooks/stop-story-validator.sh
# Stop Event Hook: story-creator 완료 후 story-validator 자동 실행
# Version: v1.0

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-story-validator.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [story-validator] $*" >> "$DEBUG_LOG"
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
# Phase 2: story-creator 완료 감지
# ============================================================================
# story-creator가 아니거나 성공이 아니면 스킵
if [[ "$agent_type" != "story-creator" ]] && [[ "$agent_type" != "02-requirements/story-creator" ]]; then
  log_debug "Not story-creator, skipping"
  exit 0
fi

if [[ "$agent_status" != "success" ]] && [[ "$agent_status" != "completed" ]]; then
  log_debug "story-creator not successful, skipping"
  exit 0
fi

log_debug "✅ story-creator completed successfully! Triggering validation..."

# ============================================================================
# Phase 3: 환경 설정
# ============================================================================
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "PROJECT_ROOT: $PROJECT_ROOT"

# Epic 디렉토리 찾기 (최근 생성된 Epic)
EPIC_DIR=$(find "$PROJECT_ROOT/docs/epics" -maxdepth 1 -type d -name "EP*" -not -name "_backlog" 2>/dev/null | sort -r | head -1 || echo "")

if [[ -z "$EPIC_DIR" ]]; then
  log_debug "No Epic directory found, skipping"
  exit 0
fi

log_debug "Found Epic: $EPIC_DIR"

# Story 개수 확인
STORY_COUNT=$(find "$EPIC_DIR/stories" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0")
log_debug "Story count: $STORY_COUNT"

# ============================================================================
# Phase 4: Serena Memory에 handoff 저장
# ============================================================================
if command -v mcp-cli &> /dev/null; then
  log_debug "Saving handoff to Serena Memory..."

  # Epic 이름 추출
  EPIC_NAME=$(basename "$EPIC_DIR")

  # Handoff memory 저장
  mcp-cli call serena/write_memory "{
    \"name\": \"handoff_story_validation\",
    \"content\": \"story-creator completed. Trigger story-validator for $EPIC_NAME.\",
    \"metadata\": {
      \"trigger\": \"story-creator\",
      \"session_id\": \"$session_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"epic_dir\": \"$EPIC_DIR\",
      \"epic_name\": \"$EPIC_NAME\",
      \"story_count\": $STORY_COUNT
    },
    \"ttl\": 1800
  }" >/dev/null 2>&1 && log_debug "Handoff saved successfully" || log_debug "Failed to save handoff"

  # 사용자에게 알림 출력
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              📋 Story Validation Triggered                                ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ story-creator 완료 감지
   Epic: $EPIC_NAME
   Stories: ${STORY_COUNT}개 생성

💾 Handoff memory 저장 완료
   → 다음 메시지에서 story-validator 자동 실행 예정

🔍 검증 항목:
   🔴 P0 (치명적):
      - AC 최소 개수 (3개 이상)
      - 필수 섹션 존재 (Technical Approach, Dependencies)
      - 순환 의존성 검증
   🟡 P1 (경고):
      - AC 품질 (모호한 표현 감지)
      - Epic 커버리지
      - Story 중복/YAGNI 위반

⚠️ P0 이슈 발견 시 story-creator에게 피드백 전달

───────────────────────────────────────────────────────────────────────────

EOF

else
  log_debug "mcp-cli not found, cannot save handoff"

  # 수동 실행 안내
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              📋 Story Validation Recommended                              ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ story-creator 완료 감지
   Stories: ${STORY_COUNT}개 생성

💡 검증 실행 권장:

  bash .claude/agents/02-requirements/story-validator.sh "$EPIC_DIR"

또는 Agent 호출:

  Task --subagent_type story-validator --prompt "Validate stories in $EPIC_DIR"

───────────────────────────────────────────────────────────────────────────

EOF

fi

log_debug "=== HOOK END ==="
exit 0
