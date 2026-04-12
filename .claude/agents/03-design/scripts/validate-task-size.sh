#!/bin/bash
# Task 크기 검증 (> 2일이면 분해 권장)
# 사용법: ./validate-task-size.sh <tasks_dir>

set -euo pipefail

TASKS_DIR="${1:-.}"

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Task 크기 검증..."

if [ ! -d "$TASKS_DIR" ]; then
  echo "❌ Tasks 디렉토리 없음: $TASKS_DIR"
  exit 1
fi

# Task 파일 찾기
TASK_FILES=$(find "$TASKS_DIR" -maxdepth 2 -name "T*.md" -type f 2>/dev/null | sort)

if [ -z "$TASK_FILES" ]; then
  echo "⚠️ Task 파일 없음"
  exit 0
fi

TASK_COUNT=$(echo "$TASK_FILES" | wc -l | tr -d ' ')
echo "  발견: ${TASK_COUNT}개 Task"

WARNINGS=()

while IFS= read -r task_file; do
  [ -f "$task_file" ] || continue

  task_name=$(basename "$task_file")

  # Estimated 추출 (다양한 형식 지원)
  estimated=$(grep -i "Estimated" "$task_file" 2>/dev/null | head -1 || echo "")

  if [ -z "$estimated" ]; then
    # Size 필드 확인
    estimated=$(grep -i "Size" "$task_file" 2>/dev/null | head -1 || echo "")
  fi

  if [ -z "$estimated" ]; then
    continue
  fi

  # 일수 추출 (3일, 3d, 3 days 등)
  days=$(echo "$estimated" | grep -oE '[0-9]+' | head -1 || echo "0")

  # "Large", "XL" 등 키워드 감지
  if echo "$estimated" | grep -qiE "(large|xl|extra.?large)"; then
    days=3  # Large = 3일로 간주
  fi

  # 2일 초과 경고
  if [ "$days" -gt 2 ]; then
    WARNINGS+=("⚠️ P1: $task_name - 예상 ${days}일 (분해 권장)")
  fi

done <<< "$TASK_FILES"

echo ""
echo "═══════════════════════════════════════"

if [ ${#WARNINGS[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ Task 크기 검증 완료 - 모두 적절 (≤ 2일)${NC}"
  exit 0
fi

echo -e "${YELLOW}⚠️ P1 Warnings (${#WARNINGS[@]}개):${NC}"
printf '%s\n' "${WARNINGS[@]}"
echo ""
echo "권장: 큰 Task는 Sub-Task로 분해"
echo "  예: T101 → T101-A, T101-B, T101-C"

exit 1
