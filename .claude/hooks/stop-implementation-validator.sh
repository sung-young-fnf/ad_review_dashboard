#!/bin/bash
# .claude/hooks/stop-implementation-validator.sh
# Stop Event Hook: code-writer 완료 후 implementation-validator 자동 실행
# Version: v1.0

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-implementation-validator.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [implementation-validator] $*" >> "$DEBUG_LOG"
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
# Phase 2: code-writer 완료 감지
# ============================================================================
# code-writer가 아니거나 성공이 아니면 스킵
if [[ "$agent_type" != "code-writer" ]] && [[ "$agent_type" != "04-implementation/code-writer" ]]; then
  log_debug "Not code-writer, skipping"
  exit 0
fi

if [[ "$agent_status" != "success" ]] && [[ "$agent_status" != "completed" ]]; then
  log_debug "code-writer not successful, skipping"
  exit 0
fi

log_debug "✅ code-writer completed successfully! Triggering validation..."

# ============================================================================
# Phase 3: 환경 설정
# ============================================================================
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "PROJECT_ROOT: $PROJECT_ROOT"

# ============================================================================
# Phase 4: Serena Memory에 handoff 저장
# ============================================================================
if command -v mcp-cli &> /dev/null; then
  log_debug "Saving handoff to Serena Memory..."

  # Git diff로 변경된 파일 목록
  changed_files=$(git diff --name-only HEAD~1 2>/dev/null || git diff --cached --name-only 2>/dev/null || echo "")

  # JSON 이스케이프
  changed_files_json=$(echo "$changed_files" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')

  # Handoff memory 저장
  mcp-cli call serena/write_memory "{
    \"name\": \"handoff_validation\",
    \"content\": \"code-writer completed. Trigger implementation-validator.\",
    \"metadata\": {
      \"trigger\": \"code-writer\",
      \"session_id\": \"$session_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"changed_files\": $changed_files_json
    },
    \"ttl\": 1800
  }" >/dev/null 2>&1 && log_debug "Handoff saved successfully" || log_debug "Failed to save handoff"

  # 사용자에게 알림 출력
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║           🔍 Implementation Validation Triggered                          ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ code-writer 완료 감지

💾 Handoff memory 저장 완료
   → 다음 메시지에서 implementation-validator 자동 실행 예정

🔍 검증 항목:
   - Task AC 완료 여부
   - Frontend → Backend API 체인
   - DB 컬럼명 일치 (snake_case vs camelCase)
   - Next.js proxy 패턴

⚠️ P0 이슈 발견 시 error-fixer 자동 위임

───────────────────────────────────────────────────────────────────────────

EOF

else
  log_debug "mcp-cli not found, cannot save handoff"

  # 수동 실행 안내
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║           🔍 Implementation Validation Recommended                        ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ code-writer 완료 감지

💡 검증 실행 권장:

  bash .claude/agents/05-quality/implementation-validator.sh --auto-fix

또는 Agent 호출:

  Task --subagent_type implementation-validator --prompt "Validate implementation"

───────────────────────────────────────────────────────────────────────────

EOF

fi

log_debug "=== HOOK END ==="
exit 0
