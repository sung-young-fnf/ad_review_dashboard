#!/bin/bash
# .claude/hooks/post/commit-changelog-recorder.sh
# PostToolUse(Bash) — git commit 감지 시 CHANGELOG.md 자동 업데이트
# Version: 1.0

trap 'exit 0' ERR

# stdin 읽기 (tool_input에서 command 추출)
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
else
  exit 0
fi

# git commit 명령인지 확인
TOOL_INPUT=$(echo "$event_info" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
if [[ ! "$TOOL_INPUT" =~ git\ commit ]]; then
  exit 0
fi

# tool 결과에서 성공 확인
TOOL_OUTPUT=$(echo "$event_info" | jq -r '.tool_result.stdout // empty' 2>/dev/null || echo "")
if [[ -z "$TOOL_OUTPUT" ]] || [[ "$TOOL_OUTPUT" =~ "nothing to commit" ]]; then
  exit 0
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CHANGELOG_FILE="$REPO_ROOT/.claude/learnings/CHANGELOG.md"

if [[ ! -f "$CHANGELOG_FILE" ]]; then
  exit 0
fi

# 최신 커밋 정보 추출
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
COMMIT_MSG=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "unknown")
COMMIT_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -10 | tr '\n' ', ')
FILE_COUNT=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | wc -l | tr -d ' ')
NOW=$(date +"%Y-%m-%d %H:%M")

# 에이전트 정보 (환경변수에서)
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-main-thread}"

# 중복 방지
if grep -q "$COMMIT_HASH" "$CHANGELOG_FILE" 2>/dev/null; then
  exit 0
fi

# CHANGELOG.md 업데이트 (최신이 위로)
temp_file=$(mktemp)
{
  head -n 10 "$CHANGELOG_FILE"
  echo ""
  echo "## [$NOW] $COMMIT_HASH"
  echo "- **Agent**: $AGENT_TYPE"
  echo "- **Scope**: ${FILE_COUNT} files — $COMMIT_FILES"
  echo "- **Summary**: $COMMIT_MSG"
  echo ""
  tail -n +11 "$CHANGELOG_FILE"
} > "$temp_file"
mv "$temp_file" "$CHANGELOG_FILE"

echo "Self-Improve: Commit $COMMIT_HASH recorded in CHANGELOG.md" >&2

exit 0
