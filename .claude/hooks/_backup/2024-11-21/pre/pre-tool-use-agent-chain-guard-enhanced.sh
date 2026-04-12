#!/bin/bash
# .claude/hooks/pre/pre-tool-use-agent-chain-guard-enhanced.sh
# Enhanced Agent Chain Interruption Prevention
# CRITICAL: Block direct Write/Edit when code-writer Agent exists

# Debug logging function
log_debug() {
    echo "[DEBUG $(date +%H:%M:%S)] $1" >&2
}

log_debug "Hook started"

set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

# Read stdin (required by Claude Code)
# Handle binary data safely by discarding it with timeout
# Image files can send large binary data that causes issues
# macOS compatible: use Bash built-in read -t instead of cat
if read -t 1 -r INPUT 2>/dev/null; then
    log_debug "stdin read successful (${#INPUT} bytes)"
else
    log_debug "stdin read failed or empty"
fi

# Environment variables
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

log_debug "TOOL_NAME: $TOOL_NAME"
log_debug "AGENT_TYPE: $AGENT_TYPE"
log_debug "REPO_ROOT: $REPO_ROOT"

# State file to track Agent chain execution
STATE_FILE="$REPO_ROOT/.claude/.agent-chain-state"

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[agent-chain-guard] $1" >&2
}

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
        log "✅ Agent chain started: $AGENT_TYPE"
        log_debug "Agent chain updated: $AGENT_TYPE"
    fi
    log_debug "Exiting after Task tool"
    exit 0
fi

# Step 2: Detect Agent chain interruption and role violations
if [[ "$TOOL_NAME" =~ ^(Write|Edit|Read|Grep|Search|Glob)$ ]]; then
    log_debug "File operation tool detected: $TOOL_NAME"

    # Get file path from CLAUDE_TOOL_INPUT (JSON)
    FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
    log_debug "Target file: $FILE_PATH"

    # Step 2.1: Check Agent-specific file restrictions
    CURRENT_CHAIN=$(get_current_agent_chain)
    log_debug "Current chain state: $CURRENT_CHAIN"

    # story-creator는 문서만 수정 가능
    if [[ "$CURRENT_CHAIN" == *"story-creator"* ]] && [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
        # 코드 파일 수정 시도 감지
        if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|java|go|rs)$ ]] && [[ ! "$FILE_PATH" =~ /docs/ ]]; then
            log "❌ ROLE VIOLATION: story-creator"
            log ""
            log "Violation: story-creator는 코드 파일을 수정할 수 없습니다"
            log "Agent: story-creator (02-requirements)"
            log "File: $FILE_PATH"
            log "Allowed: docs/epics/**/*.md만 수정 가능"
            log ""
            log "Required Action:"
            log "  1. Story 문서만 생성하세요 (docs/epics/.../stories/)"
            log "  2. 코드 구현은 code-writer에게 위임하세요"
            log "     Task --subagent_type 04-implementation/code-writer"

            log_debug "Blocking story-creator code file edit: $FILE_PATH"
            exit 1  # 차단!
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
        log "❌ AGENT CHAIN INTERRUPTION DETECTED"
        log ""
        log "Violation: Direct $TOOL_NAME without Agent call"
        log "Current chain: $CURRENT_CHAIN"
        log "Expected: Task(code-writer) 호출"
        log "Actual: $TOOL_NAME 직접 사용"
        log ""
        log "Impact:"
        log "  - Agent 워크플로우 중단"
        log "  - 자동 검증/상태 업데이트 누락"
        log "  - CLAUDE.md 규칙 위반"
        log ""
        log "Required Action:"
        log "  Task --subagent_type 04-implementation/code-writer --prompt '...'"

        # 🔧 ENFORCEMENT MODE (차단 활성화)
        # NOTE: 환경 변수로 강제 모드 제어
        if [[ "${ENFORCE_AGENT_CHAIN:-1}" == "1" ]]; then
            log_debug "Blocking direct tool use (ENFORCE_AGENT_CHAIN=1)"
            exit 1  # 차단!
        else
            log_debug "Warning only (ENFORCE_AGENT_CHAIN=0)"
            exit 0  # 경고만
        fi
    fi
fi

# Step 3: Clear chain state on stop event
if [[ "$TOOL_NAME" == "stop" ]]; then
    clear_agent_chain
    log "✅ Agent chain completed"
    log_debug "Agent chain cleared"
fi

log_debug "Hook completed successfully"
exit 0
