#!/bin/bash
# .claude/hooks/pre/pre-tool-use-first-response-guard.sh
# MANDATORY FIRST RESPONSE TEMPLATE 위반 차단
# 개발 요청 시 첫 Tool이 Task가 아니면 차단
# Version: 1.0

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [first-response-guard] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Phase 0: stdin 읽기 (안전하게)
# ============================================================================
if [ ! -t 0 ]; then
  if read -t 1 -r INPUT 2>/dev/null; then
    log_debug "stdin read successful (${#INPUT} bytes)"
  else
    log_debug "stdin read failed or empty"
    INPUT=""
  fi
else
  INPUT=""
  log_debug "No stdin"
fi

# ============================================================================
# Phase 1: 환경 변수 추출
# ============================================================================
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

log_debug "TOOL_NAME: $TOOL_NAME"
log_debug "REPO_ROOT: $REPO_ROOT"

# 상태 파일 경로
DEV_REQUEST_FILE="$REPO_ROOT/.claude/.dev-request-pending"
FIRST_TOOL_DONE_FILE="$REPO_ROOT/.claude/.first-tool-done"

# ============================================================================
# Phase 2: 개발 요청 감지 및 첫 Tool 체크
# ============================================================================

# Step 1: Task tool 호출 시 → 정상 워크플로우
if [[ "$TOOL_NAME" == "Task" ]]; then
  log_debug "Task tool called, clearing dev-request-pending"
  rm -f "$DEV_REQUEST_FILE"
  touch "$FIRST_TOOL_DONE_FILE"
  exit 0
fi

# Step 2: 개발 요청 대기 상태인지 확인
if [[ -f "$DEV_REQUEST_FILE" ]]; then
  log_debug "Dev request pending file exists"

  # Step 3: 첫 Tool이 Read/Grep/Search/Glob면 차단
  if [[ "$TOOL_NAME" =~ ^(Read|Grep|Search|Glob)$ ]]; then
    # 이미 첫 Tool이 완료된 상태인지 확인
    if [[ -f "$FIRST_TOOL_DONE_FILE" ]]; then
      log_debug "First tool already done, allowing $TOOL_NAME"
      exit 0
    fi

    # 차단! (v2.1.0+ additionalContext 포맷)
    VIOLATION_LOG="$REPO_ROOT/.claude/.violations.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VIOLATION: Direct $TOOL_NAME without template (blocked)" >> "$VIOLATION_LOG"

    log_debug "BLOCKING: Direct $TOOL_NAME on dev request"

    cat <<EOF
{
  "decision": "block",
  "reason": "STOP→ANALYZE→ROUTE 템플릿 미사용. 개발 요청에서 바로 $TOOL_NAME 실행 시도됨.",
  "additionalContext": "🛑 MANDATORY FIRST RESPONSE TEMPLATE: 먼저 STOP(키워드분석)→ANALYZE(Domain/Confidence)→ROUTE(Task --subagent_type)로 응답 후 Agent를 호출하세요. 직접 Read/Grep 금지."
}
EOF
    exit 0
  fi

  # Write/Edit는 agent-chain-guard가 처리하므로 여기서는 통과
  log_debug "Tool $TOOL_NAME not in blocking list, allowing"
fi

# Step 4: 일반 요청 또는 이미 처리된 요청
log_debug "No blocking condition, allowing tool use"
exit 0
