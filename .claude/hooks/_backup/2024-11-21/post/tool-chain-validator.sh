#!/bin/bash
# .claude/hooks/post/tool-chain-validator.sh
# PostToolUse Hook: Tool 실행 패턴 검증 및 Agent Chain 보호
# Version: 1.0 (Phase 3)

set -e
trap 'exit 0' ERR

# ============================================================================
# Phase 0: 환경 변수 및 디버깅
# ============================================================================

log_debug() {
    echo "[DEBUG $(date +%H:%M:%S)] $1" >&2
}

log_debug "PostToolUse hook started"

# PostToolUse Hook 환경 변수 (Claude Code 제공)
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_ID="${CLAUDE_TOOL_USE_ID:-unknown}"
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"

log_debug "TOOL_NAME: $TOOL_NAME"
log_debug "TOOL_ID: $TOOL_ID"
log_debug "AGENT_TYPE: $AGENT_TYPE"

# 빈 Tool 이름이면 조용히 종료
if [[ -z "$TOOL_NAME" ]]; then
  log_debug "Empty TOOL_NAME, exiting"
  exit 0
fi

# ============================================================================
# Phase 1: 디렉토리 및 파일 초기화
# ============================================================================

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PATTERN_LOG="$REPO_ROOT/.claude/.tool-execution-pattern"
STATE_FILE="$REPO_ROOT/.claude/.agent-chain-state"

# 디렉토리 생성
mkdir -p "$REPO_ROOT/.claude"

# 패턴 로그 파일 생성 (없으면)
touch "$PATTERN_LOG"

log_debug "REPO_ROOT: $REPO_ROOT"
log_debug "PATTERN_LOG: $PATTERN_LOG"

# ============================================================================
# Phase 2: Tool 실행 패턴 로깅
# ============================================================================

# 로그 포맷: timestamp tool_name tool_id agent_type
TIMESTAMP=$(date +%s)
echo "$TIMESTAMP $TOOL_NAME $TOOL_ID $AGENT_TYPE" >> "$PATTERN_LOG"

log_debug "Pattern logged: $TIMESTAMP $TOOL_NAME $TOOL_ID $AGENT_TYPE"

# 로그 파일 크기 제한 (최근 100줄만 유지)
if [[ $(wc -l < "$PATTERN_LOG") -gt 100 ]]; then
  tail -100 "$PATTERN_LOG" > "$PATTERN_LOG.tmp"
  mv "$PATTERN_LOG.tmp" "$PATTERN_LOG"
  log_debug "Pattern log truncated to 100 lines"
fi

# ============================================================================
# Phase 3: Agent Chain 상태 자동 업데이트
# ============================================================================

if [[ "$TOOL_NAME" == "Task" ]]; then
  # Task tool 실행 → Agent Chain 활성화
  if [[ -n "$AGENT_TYPE" ]]; then
    echo "$AGENT_TYPE" > "$STATE_FILE"
    log_debug "Agent chain state updated: $AGENT_TYPE"

    cat >&2 <<EOF

[agent-chain-validator] ✅ Agent Chain 시작
  - Agent: $AGENT_TYPE
  - Tool ID: $TOOL_ID
  - Time: $(date +%H:%M:%S)

EOF
  fi
fi

# ============================================================================
# Phase 4: 연속 실행 검증 (Agent Chain 보호)
# ============================================================================

if [[ "$TOOL_NAME" =~ ^(Write|Edit|MultiEdit)$ ]]; then
  log_debug "File operation detected: $TOOL_NAME"

  # 최근 30초 이내에 Task tool 호출이 있었는지 확인
  NOW=$(date +%s)
  RECENT_TASK=""

  while IFS= read -r line; do
    # 로그 파싱: timestamp tool_name tool_id agent_type
    LOG_TIME=$(echo "$line" | awk '{print $1}')
    LOG_TOOL=$(echo "$line" | awk '{print $2}')
    LOG_AGENT=$(echo "$line" | awk '{print $4}')

    # 30초 이내 Task tool 확인
    if [[ "$LOG_TOOL" == "Task" ]] && [[ $((NOW - LOG_TIME)) -lt 30 ]]; then
      RECENT_TASK="$LOG_AGENT"
      break
    fi
  done < <(tail -20 "$PATTERN_LOG")

  if [[ -z "$RECENT_TASK" ]]; then
    # 최근 Task tool 없음 → 경고
    log_debug "No recent Task tool found (30s window)"

    cat >&2 <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              ⚠️  AGENT CHAIN PATTERN WARNING                              ║
╚═══════════════════════════════════════════════════════════════════════════╝

Tool: $TOOL_NAME (직접 호출)
Agent: $AGENT_TYPE
Time: $(date +%H:%M:%S)

📊 패턴 분석:
  - 최근 30초 이내 Task tool 호출 없음
  - Agent Chain이 중단되었을 가능성 있음

💡 권장 액션:
  ✅ Task --subagent_type 04-implementation/code-writer
     --prompt "..."

  ❌ Write/Edit 직접 호출 (현재 패턴)

📋 참조: @.claude/guides/AGENT_CHAIN_RULES.md

───────────────────────────────────────────────────────────────────────────

EOF
  else
    log_debug "Recent Task tool found: $RECENT_TASK (within 30s)"
  fi
fi

# ============================================================================
# Phase 5: Agent Chain 완료 감지
# ============================================================================

# 특정 Tool이 Agent Chain 종료를 의미하는 경우
if [[ "$TOOL_NAME" == "TodoWrite" ]]; then
  # TodoWrite에서 모든 Task가 completed인지 확인 (간접 감지)
  log_debug "TodoWrite detected, checking completion status"

  # TODO: TodoWrite 내용 파싱 (향후 구현)
  # 모든 Task가 completed면 Agent Chain 완료
fi

log_debug "PostToolUse hook completed successfully"
exit 0
