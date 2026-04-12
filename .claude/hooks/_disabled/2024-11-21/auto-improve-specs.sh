#!/bin/bash
# .claude/hooks/utils/auto-improve-specs.sh
# Spec 자동 개선 시스템 (주간 배치 또는 수동 실행)

set -euo pipefail

LEARNING_FILE=".claude/memory/pattern-learnings.jsonl"
SPEC_FILE=".claude/CLAUDE.md"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 1. 학습 데이터 존재 확인
if [[ ! -f "$LEARNING_FILE" ]] || [[ ! -s "$LEARNING_FILE" ]]; then
    log "⚠️  학습 데이터 없음: $LEARNING_FILE"
    exit 0
fi

# 2. 최근 10개 학습 데이터 추출
RECENT_LEARNINGS=$(tail -10 "$LEARNING_FILE")
LEARNING_COUNT=$(echo "$RECENT_LEARNINGS" | wc -l)

log "📊 최근 $LEARNING_COUNT개 학습 데이터 분석 중..."

# 3. Claude Headless로 개선안 생성
IMPROVEMENT_PROMPT="Based on these pattern learnings, generate CLAUDE.md improvements:

$RECENT_LEARNINGS

Analyze common mistakes and generate a new section for CLAUDE.md.
Output JSON with:
{
  \"section\": \"section title (e.g., 'YAGNI 위반 방지')\",
  \"content\": \"markdown content with checklist and examples\",
  \"priority\": \"HIGH/MEDIUM/LOW\"
}

Focus on actionable guidelines that prevent repeated mistakes."

if ! timeout 60s claude -p "$IMPROVEMENT_PROMPT" --output-format json > /tmp/spec-improvements.json 2>/dev/null; then
    log "⚠️  Claude Headless 실패, 개선 생략"
    exit 0
fi

# 4. JSON 파싱 (Graceful Degradation)
SECTION=$(jq -r '.section' /tmp/spec-improvements.json 2>/dev/null || echo "")
CONTENT=$(jq -r '.content' /tmp/spec-improvements.json 2>/dev/null || echo "")
PRIORITY=$(jq -r '.priority' /tmp/spec-improvements.json 2>/dev/null || echo "MEDIUM")

if [[ -z "$SECTION" || -z "$CONTENT" ]]; then
    log "⚠️  개선 내용 없음 (JSON 파싱 실패)"
    exit 0
fi

# 5. Spec 문서 패치
DATE=$(date +%Y-%m-%d)

log "📝 CLAUDE.md 개선 중: $SECTION (Priority: $PRIORITY)"

# 백업
cp "$SPEC_FILE" "${SPEC_FILE}.backup-${DATE}"

# 새 섹션 추가
cat >> "$SPEC_FILE" <<EOF

---

### ⚠️ 자동 학습: $SECTION ($DATE)

> **Priority**: $PRIORITY | **Source**: Pattern Learning System

$CONTENT

**적용 시작일**: $DATE

---
EOF

# 6. 결과 표시
echo -e "\n\033[1;32m✅ CLAUDE.md 개선 완료\033[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;33m섹션:\033[0m $SECTION"
echo -e "\033[1;33m우선순위:\033[0m $PRIORITY"
echo -e "\n\033[1;33m📝 변경 내용 (마지막 15줄):\033[0m"
tail -15 "$SPEC_FILE"
echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# 7. Git diff 표시
if command -v git &> /dev/null; then
    echo -e "\n\033[1;33m📊 Git Diff:\033[0m"
    git diff "$SPEC_FILE" | tail -20 || true
fi

log "✅ 완료 (백업: ${SPEC_FILE}.backup-${DATE})"

exit 0
