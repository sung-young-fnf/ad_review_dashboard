#!/bin/bash
# .claude/hooks/post/repeated-file-ref-reminder.sh
# PostToolUse(Bash) — git commit 후 같은 파일 3회+ 수정 감지 → ref 주석 추가 권고
# Version: 1.0

trap 'exit 0' ERR

# stdin 읽기
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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# 오늘 날짜 기준 커밋에서 파일별 수정 횟수 카운트
TODAY=$(date -u +"%Y-%m-%d")
REPEATED_FILES=$(git log --since="$TODAY" --name-only --pretty=format: -- '*.py' '*.ts' '*.tsx' 2>/dev/null \
  | grep -v '^$' \
  | sort \
  | uniq -c \
  | sort -rn \
  | awk '$1 >= 3 {print $1, $2}' \
  | head -5)

if [ -z "$REPEATED_FILES" ]; then
  exit 0
fi

# 경고 출력
echo "" >&2
echo "⚠️ [Ref 주석 권고] 오늘 3회+ 수정된 파일 감지:" >&2
echo "$REPEATED_FILES" | while read COUNT FILE; do
  COMMITS=$(git log --since="$TODAY" --oneline -- "$FILE" 2>/dev/null | head -3 | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
  echo "  📝 ${FILE} (${COUNT}회) — ref: ${COMMITS}" >&2
done
echo "  🔴 MANDATORY: 위 파일들의 핵심 수정 지점에 # ⚠️ + # ref: 주석을 즉시 추가하세요" >&2
echo "  ❌ 주석 미추가 시 = VIOLATION (learning-loop.md 규칙)" >&2
echo "" >&2
