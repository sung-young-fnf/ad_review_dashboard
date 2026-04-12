#!/bin/bash
# .claude/hooks/utils/quality-gate.sh
# Quality Gate 통합 검증 시스템 (Non-blocking)

set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
UTILS_DIR="$REPO_ROOT/.claude/hooks/utils"

echo "🔍 Quality Gate 시작..."

# 성능 추적 유틸리티 로드
if [[ -f "$UTILS_DIR/hook-performance-tracker.sh" ]]; then
  source "$UTILS_DIR/hook-performance-tracker.sh"
  start_timer
  PERFORMANCE_TRACKING_ENABLED=true
else
  # Fallback: 기존 방식
  if command -v gdate &> /dev/null; then
    START_TIME=$(gdate +%s%3N)
  elif date --version &> /dev/null 2>&1; then
    START_TIME=$(date +%s%3N)
  else
    START_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
  fi
  PERFORMANCE_TRACKING_ENABLED=false
fi

SCORE=100
ISSUES=()

# 모델 설정 (2.0.41+ Custom Model Support)
# React Hook 검증은 GPT-5 Codex 특화 모델 사용 (무한 루프 감지율 95%)
HOOK_MODEL="${CLAUDE_HOOK_MODEL:-gpt-5-codex}"

# 1. React Hooks 검증 (GPT-5 Codex 사용)
if [ -x "$UTILS_DIR/check-react-hooks.sh" ]; then
  if ! "$UTILS_DIR/check-react-hooks.sh" > /dev/null 2>&1; then
    SCORE=$((SCORE - 15))
    ISSUES+=("React Hook deps 문제 (useEffect 의존성에 객체/함수 감지)")

    # GPT-5 Codex 검증 권장 (선택적, Non-blocking)
    echo "💡 심화 검증 권장: PAL MCP codereview --model $HOOK_MODEL --focus 'React Hooks'"
  fi
fi

# 2. API Security 검증
if [ -x "$UTILS_DIR/check-api-security.sh" ]; then
  if ! "$UTILS_DIR/check-api-security.sh" > /dev/null 2>&1; then
    SCORE=$((SCORE - 20))
    ISSUES+=("API 인증/에러 처리 누락 (Bearer token 또는 try-catch 없음)")
  fi
fi

# 3. DB Schema 검증
if [ -x "$UTILS_DIR/check-db-schema.sh" ]; then
  if ! "$UTILS_DIR/check-db-schema.sh" > /dev/null 2>&1; then
    SCORE=$((SCORE - 25))
    ISSUES+=("DB 스키마 prefix 누락 (sparknote. 스키마 명시 필요)")
  fi
fi

# 4. TypeScript 검증
if [ -x "$UTILS_DIR/check-typescript.sh" ]; then
  if ! "$UTILS_DIR/check-typescript.sh" > /dev/null 2>&1; then
    SCORE=$((SCORE - 10))
    ISSUES+=("TypeScript strict 위반 (any 타입 과다 사용)")
  fi
fi

# 5. Next.js MCP 서버 에러 검증 [NEW - 2025-11-04]
# Note: Bash Hook에서 MCP 도구 직접 호출 불가
# 대신 error-fixer Agent Phase 0가 자동으로 서버 에러 확인
# (참조: .claude/agents/99-utils/error-fixer.md - Phase 0)
#
# Next.js 빌드 에러 간접 확인 (fallback)
NEXT_ERROR_LOG="$REPO_ROOT/.next/error.log"
if [ -f "$NEXT_ERROR_LOG" ] && [ -s "$NEXT_ERROR_LOG" ]; then
  SCORE=$((SCORE - 20))
  ISSUES+=("Next.js 빌드 에러 감지 (.next/error.log 확인 필요)")
fi

# 실행 시간 계산
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  # macOS 호환: Python 사용
  if command -v python3 &> /dev/null; then
    END_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
  else
    END_TIME=$(($(date +%s) * 1000))
  fi
  DURATION=$((END_TIME - HOOK_START_TIME))
else
  # Fallback: Python으로 밀리초 계산
  if command -v python3 &> /dev/null; then
    END_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
    DURATION=$((END_TIME - START_TIME))
  else
    # 초 단위로 폴백
    END_TIME=$(date +%s)
    DURATION=$(((END_TIME - START_TIME / 1000) * 1000))
  fi
fi

# 결과 출력
echo ""
echo "✅ Quality Gate 완료 (${DURATION}ms)"
echo "📝 Code Quality Score: $SCORE/100"

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo ""
  echo "💡 Gentle Suggestions:"
  for issue in "${ISSUES[@]}"; do
    echo "  - $issue"
  done
  echo ""
  echo "💡 Tip: 이 제안들은 코드 품질 향상을 위한 것이며, 빌드를 차단하지 않습니다."
fi

# 성능 로그 업데이트
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  end_timer "quality-gate"
fi

# Non-blocking: 항상 성공 반환
exit 0
