#!/bin/bash
# .claude/hooks/post/epic-complete.sh
# Epic 완료 리포트 자동 생성

set -euo pipefail

EPIC_ID="$1"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# 1. 입력 검증
if [[ -z "${EPIC_ID:-}" ]]; then
    log "⏭️  Skipped: EPIC_ID not provided"
    exit 0
fi

EPIC_DIR="docs/epics/$EPIC_ID"

if [[ ! -d "$EPIC_DIR" ]]; then
    log "⚠️  Epic 디렉토리 없음: $EPIC_DIR"
    exit 0
fi

# 2. Epic 파일 수집
log "📊 Epic $EPIC_ID 분석 중..."
EPIC_FILES=$(find "$EPIC_DIR" -name "*.md" -type f 2>/dev/null | tr '\n' ',' | sed 's/,$//')

if [[ -z "$EPIC_FILES" ]]; then
    log "⚠️  Epic 파일 없음"
    exit 0
fi

# 3. Claude Headless로 요약 생성
SUMMARY_PROMPT="Analyze Epic $EPIC_ID completion from these files: $EPIC_FILES

Output JSON with:
{
  \"summary\": \"High-level summary (3-5 sentences)\",
  \"stories\": [\"S01: Story title\", \"S02: Story title\"],
  \"total_tasks\": 10,
  \"completed_tasks\": 10,
  \"learnings\": [\"Key learning 1\", \"Key learning 2\"],
  \"next_steps\": [\"Recommended action 1\"]
}"

if ! timeout 60s claude -p "$SUMMARY_PROMPT" --output-format json > "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null; then
    log "⚠️  Claude Headless 실패, 기본 요약 생성 생략"
    exit 0
fi

# 4. JSON 파싱 (jq 실패 시 Graceful Degradation)
if ! command -v jq &>/dev/null; then
    log "⚠️  jq 미설치, JSON 파싱 생략"
    exit 0
fi

SUMMARY=$(jq -r '.summary' "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null || echo "요약 생성 실패")
STORIES=$(jq -r '.stories[]' "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null || echo "")
TOTAL_TASKS=$(jq -r '.total_tasks' "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null || echo "0")
COMPLETED_TASKS=$(jq -r '.completed_tasks' "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null || echo "0")
LEARNINGS=$(jq -r '.learnings[]' "$EPIC_DIR/COMPLETION_SUMMARY.json" 2>/dev/null || echo "")

# 5. Rich UI로 표시
echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m📊 Epic $EPIC_ID 완료 요약\033[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo -e "\n\033[1;32m📝 요약:\033[0m"
echo "$SUMMARY"

if [[ -n "$STORIES" ]]; then
    echo -e "\n\033[1;33m✅ 완료된 Story:\033[0m"
    echo "$STORIES" | while IFS= read -r story; do
        [[ -n "$story" ]] && echo -e "  \033[32m✓\033[0m $story"
    done
fi

echo -e "\n\033[1;33m📊 Task 완료율:\033[0m $COMPLETED_TASKS / $TOTAL_TASKS"

if [[ -n "$LEARNINGS" ]]; then
    echo -e "\n\033[1;35m💡 주요 학습:\033[0m"
    echo "$LEARNINGS" | while IFS= read -r learning; do
        [[ -n "$learning" ]] && echo -e "  • $learning"
    done
fi

# 6. 사용자 승인
echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "📝 Epic을 완료 상태로 표시할까요? (y/N): " confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # epic.md에 완료 상태 추가
    if [[ -f "$EPIC_DIR/epic.md" ]]; then
        echo -e "\nstatus: completed\ncompletion_date: $(date +%Y-%m-%d)" >> "$EPIC_DIR/epic.md"
        echo -e "\n\033[1;32m✅ Epic $EPIC_ID 완료 처리됨\033[0m"
    else
        log "⚠️  epic.md 파일 없음"
    fi
else
    echo -e "\033[1;33m⚠️  취소됨\033[0m"
fi

log "✅ Epic 완료 리포트 저장: $EPIC_DIR/COMPLETION_SUMMARY.json"

exit 0
