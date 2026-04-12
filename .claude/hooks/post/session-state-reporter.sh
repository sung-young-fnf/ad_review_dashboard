#!/bin/bash
# Session State Reporter - 세션 상태를 로컬 파일에 기록 + HTTP POST로 실시간 전송
# Hook: SessionStart, PreToolUse, PostToolUse, UserPromptSubmit, Stop
# 3-Tier: (1) HTTP POST → Colyseus (~100ms) (2) File → chokidar (~500ms) (3) REST polling (60s)
# 저장 위치: .agent-office/sessions/{session_id}.json (TTL: 10분)

# Graceful Degradation: hook failure should never block the agent
set -eo pipefail
trap 'exit 0' ERR

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SESSIONS_DIR="$REPO_ROOT/.agent-office/sessions"

# stdin에서 Hook 이벤트 JSON 읽기 (없으면 빈 객체)
INPUT=$(cat 2>/dev/null || echo "{}")

# stdin JSON에서 필드 추출 (jq 없으면 grep fallback)
if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
    INPUT_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
    HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event // ""' 2>/dev/null || echo "")
    USER_INPUT=$(echo "$INPUT" | jq -r '.user_input // ""' 2>/dev/null || echo "")
else
    TOOL_NAME=""
    INPUT_SESSION_ID=""
    HOOK_EVENT=""
    USER_INPUT=""
fi

# 세션 ID 결정: stdin > 환경변수 > TTY fallback
if [[ -n "$INPUT_SESSION_ID" && "$INPUT_SESSION_ID" != "null" ]]; then
    SESSION_ID="$INPUT_SESSION_ID"
elif [[ -n "${CLAUDE_SESSION_ID:-}" && "${CLAUDE_SESSION_ID:-}" != "unknown" ]]; then
    SESSION_ID="$CLAUDE_SESSION_ID"
else
    TTY_ID=$(tty 2>/dev/null | sed 's/\//_/g' || echo "notty")
    SESSION_ID="auto-${TTY_ID}-$$"
fi

# 상태 결정: Hook 이벤트 + tool_name 기반
# SessionStart → active, UserPromptSubmit → running, PreToolUse → tool_use
# PostToolUse → running, Stop → stopped
STATUS="active"
CURRENT_TOOL=""
LAST_TOOL=""

case "${HOOK_EVENT}" in
    SessionStart)    STATUS="active" ;;
    UserPromptSubmit) STATUS="running" ;;
    PreToolUse)      STATUS="tool_use"; CURRENT_TOOL="$TOOL_NAME" ;;
    PostToolUse)     STATUS="running"; LAST_TOOL="$TOOL_NAME" ;;
    Stop)            STATUS="stopped" ;;
    *)
        # 환경변수 fallback: PostToolUse matcher에서 호출될 때
        if [[ -n "$TOOL_NAME" ]]; then
            STATUS="running"
            LAST_TOOL="$TOOL_NAME"
        fi
        ;;
esac

# 세션 디렉토리 생성
mkdir -p "$SESSIONS_DIR"

# 현재 작업 중인 파일 (git status에서 추출, 상위 5개만)
WORKING_FILES=$(cd "$REPO_ROOT" && git status --short 2>/dev/null | head -5 | awk '{print $2}' | tr '\n' ',' | sed 's/,$//' || echo "")

# 현재 작업 중인 Epic/Task (PROGRESS.md에서 추출)
CURRENT_TASK=""
if [[ -f "$REPO_ROOT/PROGRESS.md" ]]; then
    CURRENT_TASK=$(grep -A1 "진행 중" "$REPO_ROOT/PROGRESS.md" 2>/dev/null | tail -1 | sed 's/^[- ]*//' | head -c 50 || echo "")
fi

# user_input 처리 (너무 길면 자르기)
LAST_USER_INPUT=""
if [[ -n "$USER_INPUT" && "$USER_INPUT" != "null" ]]; then
    LAST_USER_INPUT=$(echo "$USER_INPUT" | head -c 100)
fi

# JSON 페이로드 생성
JSON_PAYLOAD=$(cat << JSONEOF
{
  "session_id": "${SESSION_ID}",
  "status": "${STATUS}",
  "current_tool": "${CURRENT_TOOL}",
  "last_tool": "${LAST_TOOL}",
  "current_task": "${CURRENT_TASK:-}",
  "working_files": "${WORKING_FILES:-}",
  "last_active": "${TIMESTAMP}",
  "last_user_input": "${LAST_USER_INPUT}"
}
JSONEOF
)

# Tier 2: 파일 저장 (chokidar fallback용 — 항상 성공)
echo "$JSON_PAYLOAD" > "$SESSIONS_DIR/${SESSION_ID}.json"

# Tier 1: HTTP POST fire-and-forget (Colyseus 서버로 직접 전송, ~100ms)
curl -s --max-time 1 -X POST "http://localhost:2567/api/claude/session-event" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" >/dev/null 2>&1 || true

# 10분 이상 오래된 세션 파일 정리 (TTL)
find "$SESSIONS_DIR" -name "*.json" -mmin +10 -delete 2>/dev/null || true

# Hook 응답
echo '{"status": "ok"}'
