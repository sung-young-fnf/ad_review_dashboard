#!/bin/bash
# AC 품질 및 필수 섹션 검증
# 사용법: ./validate-ac-quality.sh <epic_dir>

set -euo pipefail

EPIC_DIR="${1:-.}"
STORIES_DIR="$EPIC_DIR/stories"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 AC 품질 및 필수 섹션 검증..."

if [ ! -d "$STORIES_DIR" ]; then
  echo "❌ Stories 디렉토리 없음: $STORIES_DIR"
  exit 1
fi

ISSUES=()
WARNINGS=()

# 필수 섹션 목록
REQUIRED_SECTIONS=(
  "## Acceptance Criteria"
  "## Technical Approach"
  "## Dependencies"
)

# 각 Story 파일 검증
for story_file in "$STORIES_DIR"/*.md; do
  [ -f "$story_file" ] || continue

  story_name=$(basename "$story_file")
  echo "  검증: $story_name"

  # 1. AC 개수 확인
  ac_count=$(grep -c "^- \[" "$story_file" 2>/dev/null || echo 0)

  if [ "$ac_count" -lt 3 ]; then
    ISSUES+=("🔴 P0: $story_name - AC ${ac_count}개뿐 (최소 3개 필요)")
  elif [ "$ac_count" -lt 5 ]; then
    WARNINGS+=("🟡 P1: $story_name - AC ${ac_count}개 (5개 이상 권장)")
  fi

  # 2. 필수 섹션 확인
  for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "^$section" "$story_file"; then
      ISSUES+=("🔴 P0: $story_name - 필수 섹션 누락: $section")
    fi
  done

  # 3. AC 품질 (모호한 표현)
  vague_patterns=("기능 추가" "성능 개선" "UI 수정" "코드 변경")

  while IFS= read -r ac_line; do
    for pattern in "${vague_patterns[@]}"; do
      if echo "$ac_line" | grep -qi "$pattern"; then
        WARNINGS+=("🟡 P1: $story_name - 모호한 AC: '$ac_line'")
      fi
    done
  done < <(grep "^- \[" "$story_file" 2>/dev/null || true)
done

# 결과 출력
echo ""
echo "═══════════════════════════════════════"

if [ ${#ISSUES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ AC 품질 검증 완료 - 문제 없음${NC}"
  exit 0
fi

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo -e "${RED}🔴 P0 Issues (${#ISSUES[@]}개 - 차단):${NC}"
  printf '%s\n' "${ISSUES[@]}"
  echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo -e "${YELLOW}🟡 P1 Warnings (${#WARNINGS[@]}개):${NC}"
  printf '%s\n' "${WARNINGS[@]}"
  echo ""
fi

[ ${#ISSUES[@]} -eq 0 ] && exit 0 || exit 1
