#!/bin/bash
# .claude/hooks/post/read-tracker.sh
# PostToolUse — Read/Grep 사용 시 조회된 파일 경로를 로그에 기록
# approach-checkpoint.sh 가 이 로그를 참조하여 렌더링 검증 여부 판단
#
# 트리거: PostToolUse (Read|Grep)
# Version: 1.0

trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_DIR="$REPO_ROOT/.claude/hooks/cache"
LOG_FILE="$CACHE_DIR/recent-reads.log"
MAX_LINES=500

# stdin에서 Hook 이벤트 JSON 읽기 (기존 Hook 패턴과 통일)
INPUT=$(cat 2>/dev/null || echo "")

if [ -z "$INPUT" ]; then
  exit 0
fi

# jq 필수
if ! command -v jq &>/dev/null; then
  exit 0
fi

# tool_name 확인 — Read 또는 Grep만 처리
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Read" ] && [ "$TOOL_NAME" != "Grep" ]; then
  exit 0
fi

# 파일 경로 추출
FILE_PATH=""
if [ "$TOOL_NAME" = "Read" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
elif [ "$TOOL_NAME" = "Grep" ]; then
  # Grep은 pattern과 path를 기록 — path가 있으면 그것을, 없으면 pattern만
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.pattern // ""' 2>/dev/null || echo "")
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 캐시 디렉토리 생성
mkdir -p "$CACHE_DIR" 2>/dev/null

# 타임스탬프와 함께 기록
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $TOOL_NAME $FILE_PATH" >> "$LOG_FILE"

# 최대 줄 수 초과 시 오래된 것부터 truncate
if [ -f "$LOG_FILE" ]; then
  LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
  LINE_COUNT=$(echo "$LINE_COUNT" | tr -d ' ')
  if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
    TAIL_COUNT=$((MAX_LINES / 2))
    tail -n "$TAIL_COUNT" "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null
    mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
  fi
fi

exit 0
