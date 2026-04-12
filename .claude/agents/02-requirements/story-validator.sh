#!/bin/bash
# Story Validator - Main Entry Point
# story-creator 완료 후 자동 실행되어 Story 품질 검증
# 사용법: ./story-validator.sh <epic_dir>

set -euo pipefail

EPIC_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Story Validator v1.0              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Epic 디렉토리 확인
if [ ! -d "$EPIC_DIR" ]; then
  echo -e "${RED}❌ Epic 디렉토리 없음: $EPIC_DIR${NC}"
  exit 1
fi

EPIC_NAME=$(basename "$EPIC_DIR")
echo "📋 Epic: $EPIC_NAME"

# Epic 파일 확인
EPIC_FILE="$EPIC_DIR/epic.md"
if [ -f "$EPIC_FILE" ]; then
  echo "✅ Epic 파일: $(basename "$EPIC_FILE")"
else
  echo "⚠️ Epic 파일 없음 (커버리지 검증 불가)"
fi

# Stories 개수
STORIES_DIR="$EPIC_DIR/stories"
if [ -d "$STORIES_DIR" ]; then
  STORY_COUNT=$(find "$STORIES_DIR" -name "*.md" -type f | wc -l | tr -d ' ')
  echo "📁 Stories: ${STORY_COUNT}개"
else
  echo -e "${RED}❌ Stories 디렉토리 없음${NC}"
  exit 1
fi

echo ""

# 검증 시작
TOTAL_ISSUES=0
P0_ISSUES=0
P1_WARNINGS=0

# P0-1: AC 품질 및 필수 섹션
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-1: AC 품질 및 필수 섹션 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bash "$SCRIPT_DIR/validate-ac-quality.sh" "$EPIC_DIR" 2>&1 | tee /tmp/validate-ac.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p0_count=$(grep -c "🔴 P0:" /tmp/validate-ac.log || echo "0")
  p1_count=$(grep -c "🟡 P1:" /tmp/validate-ac.log || echo "0")
  P0_ISSUES=$((P0_ISSUES + p0_count))
  P1_WARNINGS=$((P1_WARNINGS + p1_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count + p1_count))
fi

echo ""

# P0-2: 의존성 순환
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-2: Story 의존성 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if python3 "$SCRIPT_DIR/validate-dependencies.py" "$EPIC_DIR" 2>&1 | tee /tmp/validate-deps.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p0_count=$(grep -c "❌ P0:" /tmp/validate-deps.log || echo "0")
  P0_ISSUES=$((P0_ISSUES + p0_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count))
fi

echo ""
echo ""

# 결과 리포트
echo "╔═══════════════════════════════════════╗"
echo "║        검증 결과 요약                  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if [ $TOTAL_ISSUES -eq 0 ]; then
  echo -e "${GREEN}✅ 모든 검증 통과!${NC}"
  echo ""

  # 권장 순서 표시
  if grep -q "권장 실행 순서" /tmp/validate-deps.log; then
    echo "💡 권장 순서:"
    grep "권장 실행 순서" -A 1 /tmp/validate-deps.log | tail -1
    echo ""
  fi

  # 병렬 실행 가능
  if grep -q "병렬 실행 가능한 그룹" /tmp/validate-deps.log; then
    echo "🚀 병렬 실행 가능:"
    grep "Phase" /tmp/validate-deps.log
    echo ""
  fi

  echo "다음 단계: task-planner"
  exit 0
fi

echo -e "${RED}⚠️ 문제 발견: ${TOTAL_ISSUES}개${NC}"
echo "  - 🔴 P0 (치명적): $P0_ISSUES개"
echo "  - 🟡 P1 (권장): $P1_WARNINGS개"
echo ""

# P0 이슈 상세
if [ $P0_ISSUES -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔴 P0 Issues (치명적 - 차단):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  grep "🔴 P0:" /tmp/validate-ac.log /tmp/validate-deps.log 2>/dev/null | sed 's/^.*://g' || true
  echo ""
  echo "자동 수정: story-creator에 피드백 전달 권장"
  echo ""
fi

# P1 경고 상세
if [ $P1_WARNINGS -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🟡 P1 Warnings (개선 제안):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  grep "🟡 P1:" /tmp/validate-ac.log 2>/dev/null | sed 's/^.*://g' | head -5 || true
  echo ""
fi

# Exit code
[ $P0_ISSUES -eq 0 ] && exit 0 || exit 1
