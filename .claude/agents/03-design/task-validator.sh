#!/bin/bash
# Task Validator - Main Entry Point
# task-planner 완료 후 자동 실행되어 Task 품질 검증
# 사용법: ./task-validator.sh <story_dir>

set -eo pipefail

STORY_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Task Validator v1.0 (경량)       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Story 디렉토리 확인
if [ ! -d "$STORY_DIR" ]; then
  echo -e "${RED}❌ Story 디렉토리 없음: $STORY_DIR${NC}"
  exit 1
fi

STORY_NAME=$(basename "$STORY_DIR")
echo "📋 Story: $STORY_NAME"

# Story 파일 확인
STORY_FILE=$(find "$STORY_DIR" -maxdepth 1 -name "S*.md" -o -name "story.md" 2>/dev/null | head -1)
if [ -z "$STORY_FILE" ] || [ ! -f "$STORY_FILE" ]; then
  # 상위 디렉토리에서 Story 파일 찾기
  STORY_FILE=$(find "$STORY_DIR/.." -maxdepth 1 -name "S*.md" 2>/dev/null | head -1)
fi

if [ -z "$STORY_FILE" ] || [ ! -f "$STORY_FILE" ]; then
  echo -e "${YELLOW}⚠️ Story 파일 없음 (AC 커버리지 검증 불가)${NC}"
  STORY_FILE=""
fi

if [ -n "$STORY_FILE" ]; then
  echo "✅ Story 파일: $(basename "$STORY_FILE")"
fi

# Tasks 디렉토리 또는 파일 확인
TASKS_DIR="$STORY_DIR/tasks"
if [ -d "$TASKS_DIR" ]; then
  TASK_COUNT=$(find "$TASKS_DIR" -name "T*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "📁 Tasks: ${TASK_COUNT}개"
  TASK_FILES=$(find "$TASKS_DIR" -name "T*.md" -type f 2>/dev/null)
else
  # 현재 디렉토리에서 Task 파일 찾기
  TASK_COUNT=$(find "$STORY_DIR" -maxdepth 1 -name "T*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$TASK_COUNT" -gt 0 ]; then
    echo "📁 Tasks: ${TASK_COUNT}개"
    TASK_FILES=$(find "$STORY_DIR" -maxdepth 1 -name "T*.md" -type f 2>/dev/null)
    TASKS_DIR="$STORY_DIR"
  else
    echo -e "${RED}❌ Task 파일 없음${NC}"
    exit 1
  fi
fi

echo ""

# 검증 시작
TOTAL_ISSUES=0
P0_ISSUES=0
P1_WARNINGS=0

# P0-1: Story AC 커버리지
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-1: Story AC 커버리지 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$STORY_FILE" ]; then
  if python3 "$SCRIPT_DIR/validate-ac-coverage.py" "$STORY_FILE" "$TASKS_DIR" 2>&1 | tee /tmp/validate-ac-coverage.log; then
    echo -e "${GREEN}✅ 통과${NC}"
  else
    p0_count=$(grep -c "🔴 P0:" /tmp/validate-ac-coverage.log 2>/dev/null || echo "0")
    P0_ISSUES=$((P0_ISSUES + p0_count))
    TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count))
  fi
else
  echo -e "${YELLOW}⚠️ Story 파일 없음 - 스킵${NC}"
fi

echo ""

# P0-2: Task 순환 의존성
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-2: Task 의존성 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if python3 "$SCRIPT_DIR/validate-task-deps.py" "$TASKS_DIR" 2>&1 | tee /tmp/validate-task-deps.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p0_count=$(grep -c "❌ P0:" /tmp/validate-task-deps.log 2>/dev/null || echo "0")
  P0_ISSUES=$((P0_ISSUES + p0_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count))
fi

echo ""

# P1: Task 크기 경고
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟡 P1: Task 크기 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bash "$SCRIPT_DIR/validate-task-size.sh" "$TASKS_DIR" 2>&1 | tee /tmp/validate-task-size.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p1_count=$(grep -c "⚠️ P1:" /tmp/validate-task-size.log 2>/dev/null || echo "0")
  P1_WARNINGS=$((P1_WARNINGS + p1_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p1_count))
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
  if grep -q "권장 실행 순서" /tmp/validate-task-deps.log 2>/dev/null; then
    echo "💡 권장 순서:"
    grep "권장 실행 순서" -A 1 /tmp/validate-task-deps.log | tail -1
    echo ""
  fi

  # 병렬 실행 가능
  if grep -q "병렬 실행 가능" /tmp/validate-task-deps.log 2>/dev/null; then
    echo "🚀 병렬 실행 가능:"
    grep "Phase" /tmp/validate-task-deps.log
    echo ""
  fi

  echo "다음 단계: code-writer"
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
  grep "🔴 P0:" /tmp/validate-ac-coverage.log /tmp/validate-task-deps.log 2>/dev/null | sed 's/^.*://g' || true
  echo ""
  echo "자동 수정: task-planner에 피드백 전달 권장"
  echo ""
fi

# P1 경고 상세
if [ $P1_WARNINGS -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🟡 P1 Warnings (개선 제안):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  grep "⚠️ P1:" /tmp/validate-task-size.log 2>/dev/null | head -5 || true
  echo ""
fi

# Exit code
[ $P0_ISSUES -eq 0 ] && exit 0 || exit 1
