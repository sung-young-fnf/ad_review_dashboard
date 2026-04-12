#!/bin/bash
# Implementation Validator - Main Entry Point
# code-writer 완료 후 자동 실행되어 구현 품질 검증
# 사용법: ./implementation-validator.sh [task_file] [--auto-fix] [--strict]

set -euo pipefail

WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$WORKSPACE_ROOT/.claude/agents/05-quality/scripts"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options
TASK_FILE="${1:-}"
AUTO_FIX=false
STRICT_MODE=false
MAX_ATTEMPTS=3

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --auto-fix) AUTO_FIX=true ;;
    --strict) STRICT_MODE=true ;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Implementation Validator v1.0        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# 1. Task 문서 확인
if [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ]; then
  echo "📋 Task 문서: $TASK_FILE"

  # Task AC 추출
  if grep -q "## Acceptance Criteria" "$TASK_FILE"; then
    echo "✅ Acceptance Criteria 발견"
    AC_COUNT=$(grep -A 100 "## Acceptance Criteria" "$TASK_FILE" | grep -c "^- \[" || echo "0")
    echo "  - AC 항목: $AC_COUNT개"
  else
    echo "⚠️ Acceptance Criteria 없음 (AC 검증 불가)"
  fi
else
  echo "⚠️ Task 문서 없음 (AC 검증 건너뛰기)"
fi

echo ""

# 2. 검증 체크리스트 실행
TOTAL_ISSUES=0
P0_ISSUES=0
P1_ISSUES=0

declare -a ALL_ISSUES

echo "🔍 검증 시작..."
echo ""

# P0-1: Frontend → Backend API 체인
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-1: Frontend → Backend API 체인 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bash "$SCRIPT_DIR/validate-api-chain.sh" "$TASK_FILE" 2>&1 | tee /tmp/validate-api-chain.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p0_count=$(grep -c "🔴 P0:" /tmp/validate-api-chain.log || echo "0")
  P0_ISSUES=$((P0_ISSUES + p0_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count))

  mapfile -t issues < <(grep "🔴 P0:" /tmp/validate-api-chain.log || true)
  ALL_ISSUES+=("${issues[@]}")
fi

echo ""

# P0-2: DB 컬럼명 일치
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 P0-2: DB 컬럼명 일치 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bash "$SCRIPT_DIR/validate-db-columns.sh" 2>&1 | tee /tmp/validate-db-columns.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p0_count=$(grep -c "🔴 P0:" /tmp/validate-db-columns.log || echo "0")
  p1_count=$(grep -c "🟡 P1:" /tmp/validate-db-columns.log || echo "0")
  P0_ISSUES=$((P0_ISSUES + p0_count))
  P1_ISSUES=$((P1_ISSUES + p1_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p0_count + p1_count))

  mapfile -t issues < <(grep -E "🔴 P0:|🟡 P1:" /tmp/validate-db-columns.log || true)
  ALL_ISSUES+=("${issues[@]}")
fi

echo ""

# P1: Next.js Proxy 패턴
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟡 P1: Next.js API Proxy 패턴 검증"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bash "$SCRIPT_DIR/validate-nextjs-proxy.sh" 2>&1 | tee /tmp/validate-nextjs-proxy.log; then
  echo -e "${GREEN}✅ 통과${NC}"
else
  p1_count=$(grep -c "🟡 P1:" /tmp/validate-nextjs-proxy.log || echo "0")
  P1_ISSUES=$((P1_ISSUES + p1_count))
  TOTAL_ISSUES=$((TOTAL_ISSUES + p1_count))

  mapfile -t issues < <(grep "🟡 P1:" /tmp/validate-nextjs-proxy.log || true)
  ALL_ISSUES+=("${issues[@]}")
fi

echo ""
echo ""

# 3. 결과 리포트
echo "╔═══════════════════════════════════════╗"
echo "║        검증 결과 요약                  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if [ $TOTAL_ISSUES -eq 0 ]; then
  echo -e "${GREEN}✅ 모든 검증 통과!${NC}"
  echo ""
  echo "다음 단계: commit-manager"
  exit 0
fi

echo -e "${RED}⚠️ 문제 발견: ${TOTAL_ISSUES}개${NC}"
echo "  - 🔴 P0 (치명적): $P0_ISSUES개"
echo "  - 🟡 P1 (권장): $P1_ISSUES개"
echo ""

# P0 이슈 상세 출력
if [ $P0_ISSUES -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔴 P0 Issues (치명적 - 즉시 수정 필요):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  for issue in "${ALL_ISSUES[@]}"; do
    if [[ $issue == *"🔴 P0:"* ]]; then
      echo "  $issue"
    fi
  done
  echo ""
fi

# P1 이슈 상세 출력 (strict 모드에서만)
if [ $STRICT_MODE = true ] && [ $P1_ISSUES -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🟡 P1 Issues (권장):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  for issue in "${ALL_ISSUES[@]}"; do
    if [[ $issue == *"🟡 P1:"* ]]; then
      echo "  $issue"
    fi
  done
  echo ""
fi

# 4. Auto-fix 실행
if [ $AUTO_FIX = true ] && [ $P0_ISSUES -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔧 Auto-fix 모드: error-fixer 자동 위임"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # error-fixer에 전달할 컨텍스트 생성
  cat > /tmp/validation-issues.txt <<EOF
Implementation Validation 결과:

총 ${P0_ISSUES}개의 P0 이슈 발견:

$(for issue in "${ALL_ISSUES[@]}"; do
    if [[ $issue == *"🔴 P0:"* ]]; then
      echo "$issue"
    fi
  done)

과거 유사 사례:
$(git log --all --oneline --grep="API.*parameter\|파라미터.*누락\|proxy.*missing" -5 || true)

수정 후 다시 implementation-validator 실행 필요.
EOF

  echo "📋 Issues 파일 생성: /tmp/validation-issues.txt"
  echo ""
  echo "⚠️ 다음 명령어로 error-fixer 실행:"
  echo "   Task --subagent error-fixer --prompt \"\$(cat /tmp/validation-issues.txt)\""
  echo ""

  # Serena Memory에 handoff 저장
  echo "💾 Handoff Memory 저장..."
  if command -v mcp-cli &> /dev/null; then
    mcp-cli call serena/write_memory "{
      \"name\": \"handoff_error_fixer\",
      \"content\": \"$(cat /tmp/validation-issues.txt | jq -Rs .)\",
      \"ttl\": 3600
    }" || true
  fi
fi

# 5. Exit code
if [ $P0_ISSUES -gt 0 ]; then
  exit 1
elif [ $STRICT_MODE = true ] && [ $P1_ISSUES -gt 0 ]; then
  exit 1
else
  exit 0
fi
