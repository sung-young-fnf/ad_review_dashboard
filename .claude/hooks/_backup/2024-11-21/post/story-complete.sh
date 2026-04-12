#!/bin/bash
# .claude/hooks/post/story-complete.sh
# Story 완료 리포트 자동 생성

set -euo pipefail

STORY_ID="$1"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# 1. 입력 검증
if [[ -z "${STORY_ID:-}" ]]; then
    log "⏭️  Skipped: STORY_ID not provided"
    exit 0
fi

# 2. Story 파일 찾기
STORY_FILE=$(find docs/epics -name "*${STORY_ID}*.md" -type f 2>/dev/null | head -1)

if [[ -z "$STORY_FILE" ]]; then
    log "⚠️  Story 파일 없음: $STORY_ID"
    exit 0
fi

log "📋 Story $STORY_ID 분석 중..."

# 3. Claude Headless로 요약 생성
STORY_PROMPT="Analyze Story completion from: $STORY_FILE

Output JSON with:
{
  \"summary\": \"What was implemented (2-3 sentences)\",
  \"files_changed\": [\"file1.tsx\", \"file2.ts\"],
  \"completion_rate\": 100
}"

TEMP_SUMMARY="/tmp/story-summary-$STORY_ID.json"

if ! timeout 60s claude -p "$STORY_PROMPT" --output-format json > "$TEMP_SUMMARY" 2>/dev/null; then
    log "⚠️  Claude Headless 실패"
    exit 0
fi

# 4. JSON 파싱 (jq 실패 시 Graceful Degradation)
if ! command -v jq &>/dev/null; then
    log "⚠️  jq 미설치, JSON 파싱 생략"
    exit 0
fi

SUMMARY=$(jq -r '.summary' "$TEMP_SUMMARY" 2>/dev/null || echo "요약 없음")
FILES=$(jq -r '.files_changed[]' "$TEMP_SUMMARY" 2>/dev/null || echo "")
COMPLETION=$(jq -r '.completion_rate' "$TEMP_SUMMARY" 2>/dev/null || echo "0")

# 5. Rich UI로 표시
echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m📋 Story $STORY_ID 완료\033[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo -e "\n\033[1;32m📝 요약:\033[0m"
echo "$SUMMARY"

if [[ -n "$FILES" ]]; then
    echo -e "\n\033[1;33m📂 변경된 파일:\033[0m"
    echo "$FILES" | while IFS= read -r file; do
        [[ -n "$file" ]] && echo -e "  • $file"
    done
fi

echo -e "\n\033[1;32m완료율: $COMPLETION%\033[0m"
echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

log "✅ Story 완료 리포트 생성 완료"

# Cleanup
rm -f "$TEMP_SUMMARY"

exit 0
