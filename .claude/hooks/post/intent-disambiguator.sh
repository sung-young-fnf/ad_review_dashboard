#!/bin/bash
#
# PostToolUse Hook - Intent Disambiguation Gate
#
# Purpose: 모호한 사용자 입력을 감지하여 명확화 경고
# Trigger: UserPromptSubmit 이벤트
# Output: stderr에 경고 표시 (non-blocking, exit 0 유지)
#
# 감지 규칙:
#   1. UI 요소 키워드가 3개+ 파일과 매칭 → 어떤 컴포넌트인지 명시 요청
#   2. 넓은 동사 + 구체적 대상 없음 → 파일/컴포넌트명 요청
#   3. False positive 방지 (파일 경로, PascalCase, API 경로 등)
#
# WHY: wrong_approach 95건 중 모호한 요청 → 잘못된 접근이 주요 원인

set +e
trap 'exit 0' ERR

# stdin에서 Hook 이벤트 JSON 읽기
INPUT=$(cat 2>/dev/null || echo "{}")

# hook_event 확인 — UserPromptSubmit만 처리
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event // ""' 2>/dev/null || echo "")
if [[ "$HOOK_EVENT" != "UserPromptSubmit" ]]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$PROJECT_DIR" ] && exit 0

# 사용자 입력 추출 (첫 줄만 분석 — false positive 방지)
USER_INPUT=$(echo "$INPUT" | jq -r '.user_input // ""' 2>/dev/null || echo "")
[ -z "$USER_INPUT" ] && exit 0

FIRST_LINE=$(echo "$USER_INPUT" | head -1)
[ -z "$FIRST_LINE" ] && exit 0

# === False Positive 방지 (우선 체크) ===
# 파일 경로 명시됨
echo "$FIRST_LINE" | grep -qE '(apps/|src/|\.claude/|\.ts|\.tsx|\.py|\.sh|\.md)' && exit 0
# PascalCase 컴포넌트명 명시됨 (2단어+ 대문자 시작)
echo "$FIRST_LINE" | grep -qE '\b[A-Z][a-z]+[A-Z][a-zA-Z]*\b' && exit 0
# API 경로 명시됨
echo "$FIRST_LINE" | grep -qiE '(/api/|POST|GET|PUT|DELETE|PATCH)' && exit 0
# 인프라 명령 (커밋, 푸시, 빌드, 테스트)
echo "$FIRST_LINE" | grep -qiE '(커밋|푸시|빌드|테스트|commit|push|build|test|deploy|lint)' && exit 0
# minor 수정 힌트
echo "$FIRST_LINE" | grep -qE '(만$|만 |줄$|줄 |only)' && exit 0

WARNINGS=""

# === 규칙 1: UI 요소 다중 매칭 ===
UI_KEYWORDS="패널 모달 사이드바 탭 카드 버튼 폼 리스트 테이블 다이얼로그 panel modal sidebar tab card button form list table dialog"

for KEYWORD in $UI_KEYWORDS; do
  # 사용자 입력에 이 키워드가 있는지 확인 (대소문자 무시)
  if echo "$FIRST_LINE" | grep -qiw "$KEYWORD"; then
    # 매칭되는 컴포넌트 파일 수 확인 (2초 타임아웃)
    MATCH_COUNT=$(timeout 2 grep -rl --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist "$KEYWORD" "$PROJECT_DIR"/apps/*/frontend/ --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ' || echo "0")

    if [ "$MATCH_COUNT" -ge 3 ]; then
      # 상위 3개 파일만 표시
      MATCH_FILES=$(timeout 2 grep -rl --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist "$KEYWORD" "$PROJECT_DIR"/apps/*/frontend/ --include="*.tsx" 2>/dev/null | head -3 | sed "s|$PROJECT_DIR/||g" || true)
      WARNINGS="${WARNINGS}
  '${KEYWORD}'가 ${MATCH_COUNT}개 컴포넌트와 매칭됩니다:
$(echo "$MATCH_FILES" | sed 's/^/    - /')
  어떤 컴포넌트인지 명시해주세요."
      break  # 첫 번째 모호한 키워드에서 1개 경고만
    fi
  fi
done

# === 규칙 2: 넓은 동사 + 구체적 대상 없음 ===
BROAD_VERBS="개선 수정 변경 고쳐 바꿔 업데이트 리팩토링 정리 최적화 improve fix change update refactor optimize"
HAS_BROAD_VERB=""

for VERB in $BROAD_VERBS; do
  if echo "$FIRST_LINE" | grep -qiw "$VERB"; then
    HAS_BROAD_VERB="$VERB"
    break
  fi
done

if [ -n "$HAS_BROAD_VERB" ] && [ -z "$WARNINGS" ]; then
  # 구체적 대상이 없는지 확인
  # 구체적 대상: 영문 식별자(snake_case, camelCase, kebab-case), 한글 컴포넌트명 + "컴포넌트/페이지/모듈"
  HAS_SPECIFIC=""
  echo "$FIRST_LINE" | grep -qE '[a-zA-Z_-]{3,}\.(ts|tsx|py|sh|md)' && HAS_SPECIFIC="true"
  echo "$FIRST_LINE" | grep -qE '\b[a-z]+[A-Z][a-zA-Z]+\b' && HAS_SPECIFIC="true"  # camelCase
  echo "$FIRST_LINE" | grep -qE '\b[a-z]+(_[a-z]+){2,}\b' && HAS_SPECIFIC="true"  # snake_case 3단어+
  echo "$FIRST_LINE" | grep -qE '(컴포넌트|페이지|모듈|서비스|컨트롤러|훅|hook)' && HAS_SPECIFIC="true"

  if [ -z "$HAS_SPECIFIC" ]; then
    WARNINGS="${WARNINGS}
  대상이 불명확합니다. (감지된 동사: '${HAS_BROAD_VERB}')
  구체적 파일명, 컴포넌트명, 또는 API 경로를 포함해주세요."
  fi
fi

# === 출력 ===
if [ -n "$WARNINGS" ]; then
  {
    echo ""
    echo "=== Intent Disambiguation ==="
    echo "$WARNINGS"
    echo ""
    echo "  NOTE: 경고만 표시 (작업은 차단하지 않음)"
    echo "=== End Disambiguation ==="
    echo ""
  } >&2
fi

exit 0
