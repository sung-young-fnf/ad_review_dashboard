#!/bin/bash
# .claude/hooks/pre/pre-tool-use-agent-chain-guard-enhanced.sh
# Enhanced Agent Chain Interruption Prevention
# CRITICAL: Block direct Write/Edit when code-writer Agent exists
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [agent-chain-guard] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Phase 0: stdin 읽기 (안정화된 방식)
# ============================================================================
# NOTE: Image 데이터 등 대용량 stdin 안전 처리
if [ ! -t 0 ]; then
  # timeout으로 안전하게 읽기 (macOS 호환)
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

# 빈 입력 처리 (단, 환경 변수는 있을 수 있으므로 계속 진행)
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log_debug "Empty stdin (will check environment variables)"
fi

# ============================================================================
# Phase 1: 환경 변수 추출
# ============================================================================
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

log_debug "TOOL_NAME: $TOOL_NAME"
log_debug "AGENT_TYPE: $AGENT_TYPE"
log_debug "FILE_PATH: $FILE_PATH"
log_debug "REPO_ROOT: $REPO_ROOT"

# State file to track Agent chain execution
STATE_FILE="$REPO_ROOT/.claude/.agent-chain-state"

# ============================================================================
# Helper Functions
# ============================================================================
get_current_agent_chain() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo "none"
  fi
}

update_agent_chain() {
  local agent_type="$1"
  echo "$agent_type" > "$STATE_FILE"
}

clear_agent_chain() {
  rm -f "$STATE_FILE"
}

# ============================================================================
# Main Logic
# ============================================================================

# Step 1: Track Agent chain state
if [[ "$TOOL_NAME" == "Task" ]]; then
  # Task tool called → Update chain state
  if [[ -n "$AGENT_TYPE" ]]; then
    update_agent_chain "$AGENT_TYPE"
    log_debug "✅ Agent chain started: $AGENT_TYPE"
  fi
  log_debug "Exiting after Task tool"
  exit 0
fi

# Step 2: Detect Agent chain interruption and role violations
if [[ "$TOOL_NAME" =~ ^(Write|Edit|Read|Grep|Search|Glob)$ ]]; then
  log_debug "File operation tool detected: $TOOL_NAME"

  # Step 2.1: Check Agent-specific file restrictions
  CURRENT_CHAIN=$(get_current_agent_chain)
  log_debug "Current chain state: $CURRENT_CHAIN"

  # story-creator는 문서만 수정 가능
  if [[ "$CURRENT_CHAIN" == *"story-creator"* ]] && [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
    # 코드 파일 수정 시도 감지
    if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|java|go|rs)$ ]] && [[ ! "$FILE_PATH" =~ /docs/ ]]; then
      cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

❌ ROLE VIOLATION: story-creator

Violation: story-creator는 코드 파일을 수정할 수 없습니다
Agent: story-creator (02-requirements)
File: $FILE_PATH
Allowed: docs/epics/**/*.md만 수정 가능

Required Action:
  1. Story 문서만 생성하세요 (docs/epics/.../stories/)
  2. 코드 구현은 code-writer에게 위임하세요
     Task --subagent_type 04-implementation/code-writer

EOF
      log_debug "Blocking story-creator code file edit: $FILE_PATH"
      exit 2  # Blocking error
    fi
  fi

  # Step 2.2: Check if code-writer Agent exists
  CODE_WRITER_AGENT="$REPO_ROOT/.claude/agents/04-implementation/code-writer.md"
  log_debug "Checking code-writer Agent: $CODE_WRITER_AGENT"

  if [[ ! -f "$CODE_WRITER_AGENT" ]]; then
    # No code-writer Agent → Direct use allowed
    log_debug "No code-writer Agent found, allowing direct use"
    exit 0
  fi

  if [[ "$CURRENT_CHAIN" != "none" && "$CURRENT_CHAIN" != "code-writer" ]]; then
    # Agent chain active but not code-writer → VIOLATION
    cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

❌ AGENT CHAIN INTERRUPTION DETECTED

Violation: Direct $TOOL_NAME without Agent call
Current chain: $CURRENT_CHAIN
Expected: Task(code-writer) 호출
Actual: $TOOL_NAME 직접 사용

Impact:
  - Agent 워크플로우 중단
  - 자동 검증/상태 업데이트 누락
  - CLAUDE.md 규칙 위반

Required Action:
  Task --subagent_type 04-implementation/code-writer --prompt '...'

EOF

    # 🔧 ENFORCEMENT MODE (차단 활성화)
    # NOTE: 환경 변수로 강제 모드 제어
    if [[ "${ENFORCE_AGENT_CHAIN:-1}" == "1" ]]; then
      log_debug "Blocking direct tool use (ENFORCE_AGENT_CHAIN=1)"
      exit 2  # Blocking error
    else
      log_debug "Warning only (ENFORCE_AGENT_CHAIN=0)"
      exit 0  # 경고만
    fi
  fi
fi

# Step 3: Clear chain state on stop event
if [[ "$TOOL_NAME" == "stop" ]]; then
  clear_agent_chain
  log_debug "✅ Agent chain completed"
fi

log_debug "=== HOOK END ==="
exit 0
