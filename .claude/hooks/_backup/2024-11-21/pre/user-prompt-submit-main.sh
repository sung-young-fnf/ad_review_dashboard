#!/bin/bash
# .claude/hooks/pre/user-prompt-submit-main.sh
# Pre-Hook Main Logic: 사용자 입력 전처리 및 컨텍스트 주입
# Phase 1: 키워드/도메인 기반 하드코딩 매핑 (Main Context Injection)

set -e
trap 'exit 0' ERR

# 디렉토리 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"

# 유틸리티 스크립트 로드
if [[ ! -f "$UTILS_DIR/extract-context.sh" ]]; then
  echo "⚠️ Warning: extract-context.sh not found at $UTILS_DIR, skipping context injection" >&2
  exit 0  # Graceful degradation
fi

source "$UTILS_DIR/extract-context.sh"

# 성능 추적 유틸리티 로드
if [[ -f "$UTILS_DIR/hook-performance-tracker.sh" ]]; then
  source "$UTILS_DIR/hook-performance-tracker.sh"
  PERFORMANCE_TRACKING_ENABLED=true
else
  PERFORMANCE_TRACKING_ENABLED=false
fi

# ============================================================================
# Helper Functions
# ============================================================================

get_request_classification() {
  local keywords="$1"

  case "$keywords" in
    "epic")
      echo "대형 (Epic Chain)"
      ;;
    "story")
      echo "중형 (Story Chain)"
      ;;
    "task")
      echo "소형 (Task Chain)"
      ;;
    "hotfix"|"bug")
      echo "긴급 (Hotfix Chain)"
      ;;
    *)
      echo "중형 (Story Chain - 기본값)"
      ;;
  esac
}

# ============================================================================
# Component Reuse Pattern Detection [NEW - 2025-11-10]
# ============================================================================

detect_component_reuse() {
  local input="$1"

  # 컴포넌트 재사용 키워드 감지
  if echo "$input" | grep -qiE '(재사용|reuse|동일하게|처럼|같은 레이아웃|identical|동일한)'; then
    cat <<'EOF'

  🔄 컴포넌트 재사용 패턴 감지:

     ⚠️ 필수 확인 사항:
     1. 원본 컴포넌트의 페이지별 동작 확인
        - onClick 핸들러 분석 (router.push, URL 변경)
        - 하드코딩된 경로 존재 여부

     2. 상태 관리 방식 확인
        - 로컬 상태 (useState) vs 전역 상태 (Zustand/URL)
        - 페이지 간 상태 공유 필요 여부

     3. Side Effect 예측
        - 다른 페이지에서 사용 시 발생 가능한 문제
        - 원하지 않는 페이지 이동, 상태 동기화 이슈

     4. 조건부 동작 설계
        - disableRouting 같은 prop 필요 여부
        - URL 기반 상태 관리로 전환 필요 여부

     📋 권장 Task:
     - [ ] 원본 컴포넌트 Deep Code Analysis
     - [ ] 페이지별 동작 분기 설계
     - [ ] 조건부 prop 추가 (필요 시)
     - [ ] 양쪽 페이지 모두 테스트

EOF
  fi
}

# ============================================================================
# Side Effect Impact Analysis [NEW - 2025-11-10]
# ============================================================================

detect_side_effect_impact() {
  local input="$1"

  # 함수/핸들러/상태 관련 키워드 감지 (포괄적)
  if echo "$input" | grep -qiE '(함수|핸들러|handler|추가|수정|변경|생성|onSubmit|onClick|onChange|useState|useEffect|컴포넌트)'; then
    cat <<'EOF'

  🔍 Side Effect 영향도 분석 필수:

     ⚠️ 코드 수정 전 체크리스트:
     1. 함수 호출 체인 전체 추적
        - handleXxx → onXxx → 최종 핸들러
        - 각 단계별 Side Effect 확인

     2. Toast 메시지 중복 방지
        - 동일 액션에 여러 toast 표시 금지
        - 최상위 호출자만 Toast 표시 (하위는 제거)

     3. Console.log/상태 업데이트 중복 확인
        - 동일 이벤트에 중복 로깅 방지
        - 경쟁 조건(Race Condition) 확인

     4. 최종 사용자 경험 예측
        - 사용자가 보는 메시지 개수
        - 메시지 일관성 (액션 vs 피드백)

     📋 Phase 2.5 실행 권장:
     error-fixer Agent Phase 2.5 자동 실행됨

EOF
  fi
}

# ============================================================================
# Dynamic Form Data Mapping Pattern [NEW - 2025-11-18]
# ============================================================================

detect_dynamic_form_pattern() {
  local input="$1"

  # Dynamic Form 관련 키워드 감지
  if echo "$input" | grep -qiE '(폼|form|제출|submission|답변|answer|initialData|CampaignSubmission|DynamicForm|Template)'; then
    cat <<'EOF'

  📝 Dynamic Form Data Mapping 패턴 확인:

     ⚠️ 필수 체크리스트:
     1. Backend API 응답 형식 확인
        - questionId (UUID) 키 사용 여부
        - question.order (숫자) 키 사용 여부

     2. DynamicFormContent 사용 시
        - initialData 키가 question.order인지 확인
        - Backend 응답이 questionId면 변환 필수

     3. 템플릿 기반 매핑 (필수)
        - 템플릿 API 호출: /api/v1/question-templates/:id
        - questionId → order 매핑 테이블 생성
        - answers 변환: UUID 키 → order 키

     4. 검증
        - 콘솔 로그: "Setting initialAnswers (questionId→order):"
        - DynamicFormContent: "Received initialData:" (order 키 확인)
        - 폼 필드에 기존 답변 표시 확인

     📋 참조 문서:
     → docs/analysis/coding-patterns.md (섹션 5: Dynamic Form Data Mapping)

     ❌ Anti-pattern:
     - questionId 키 그대로 전달 (키 불일치 → 빈 폼)
     - order 하드코딩 (템플릿 동적 로드 필수)
     - 변환 로직 누락 (증상: 제출 완료인데 답변 표시 안 됨)

EOF
  fi
}

# ============================================================================
# Main Logic
# ============================================================================

# 사용자 입력 읽기
# stdin은 부모 스크립트(user-prompt-submit.sh)에서 이미 읽었으므로
# 환경 변수에서만 가져옴
USER_INPUT="${CLAUDE_USER_PROMPT:-${1:-}}"

# 빈 입력 체크
if [[ -z "$USER_INPUT" ]]; then
  echo "[DEBUG] user-prompt-submit-main: 빈 입력 (CLAUDE_USER_PROMPT not set)" >&2
  exit 0  # Hook은 실패하지 않고 조용히 종료
fi

# 성능 측정 시작
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  start_timer
fi

# 키워드 추출
KEYWORDS=$(extract_keywords "$USER_INPUT")

# 도메인 추출
DOMAIN=$(extract_domain "$USER_INPUT")

# Agent 추천
AGENT_INFO=$(recommend_agent "$KEYWORDS" "$DOMAIN")
RECOMMENDED_AGENT="${AGENT_INFO%%|*}"
AGENT_EXPERTISE="${AGENT_INFO##*|}"

# 기술 컨텍스트 추출
TECH_CONTEXT=$(get_tech_context "$DOMAIN")
WARNINGS=$(get_warnings "$DOMAIN")
EXPECTED_STRUCTURE=$(get_expected_structure "$DOMAIN" "$KEYWORDS")

# Data Fetching 패턴 감지 [NEW - 2025-11-10]
DATA_FETCHING_INFO=$(get_data_fetching_pattern "$USER_INPUT")
DATA_FETCHING_PATTERN="${DATA_FETCHING_INFO%%|*}"
DATA_FETCHING_CHECKLIST="${DATA_FETCHING_INFO##*|}"

# Data Fetching 관련 요청인지 확인
IS_DATA_FETCHING=false
if echo "$USER_INPUT" | grep -qiE '(조회|fetch|get|실시간|폴링|생성|수정|삭제|create|update|delete|api)'; then
  IS_DATA_FETCHING=true
  DATA_FETCHING_WARNINGS=$(get_data_fetching_warnings "$DATA_FETCHING_PATTERN")
fi

# 컴포넌트 재사용 패턴 감지 [NEW - 2025-11-10]
COMPONENT_REUSE_WARNING=$(detect_component_reuse "$USER_INPUT")

# Side Effect 영향도 분석 [NEW - 2025-11-10]
SIDE_EFFECT_WARNING=$(detect_side_effect_impact "$USER_INPUT")

# Dynamic Form 패턴 감지 [NEW - 2025-11-18]
DYNAMIC_FORM_WARNING=$(detect_dynamic_form_pattern "$USER_INPUT")

# 요청 분류
REQUEST_CLASS=$(get_request_classification "$KEYWORDS")

# 대문자 변환 (macOS Bash 3.2 호환)
DOMAIN_UPPER=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')

# 성능 측정 종료 (출력용 시간 계산)
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  # macOS 호환: Python 사용
  if command -v python3 &> /dev/null; then
    end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
  else
    end_time=$(($(date +%s) * 1000))
  fi
  ELAPSED_MS=$((end_time - HOOK_START_TIME))

  # bc가 없으면 awk로 계산
  if command -v bc &> /dev/null; then
    ELAPSED_SEC=$(echo "scale=2; $ELAPSED_MS / 1000" | bc)
  else
    ELAPSED_SEC=$(awk "BEGIN {printf \"%.2f\", $ELAPSED_MS/1000}")
  fi
else
  ELAPSED_SEC="N/A"
fi

# 컨텍스트 주입 메시지 생성
cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║                    🎯 AUTO-CONTEXT INJECTION (Phase 1)                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

ANALYZE:
  키워드: [$KEYWORDS]
  도메인: [$DOMAIN]

INJECT:
  🎯 $DOMAIN_UPPER DETECTED
  📋 Agent 추천: $RECOMMENDED_AGENT
     ($AGENT_EXPERTISE)
  🔧 기술 컨텍스트: $TECH_CONTEXT

  ⚠️ 주의사항:
$WARNINGS

  💡 예상 구조: $EXPECTED_STRUCTURE
EOF

# Data Fetching 패턴 정보 추가 (해당되는 경우만)
if [[ "$IS_DATA_FETCHING" == "true" ]]; then
  cat <<EOF

  📊 Data Fetching Pattern (YAGNI + Server-first):
    - 패턴: $DATA_FETCHING_PATTERN
    - 체크리스트: $DATA_FETCHING_CHECKLIST/6 충족

$DATA_FETCHING_WARNINGS
EOF
fi

# 컴포넌트 재사용 패턴 정보 추가 (해당되는 경우만) [NEW - 2025-11-10]
if [[ -n "$COMPONENT_REUSE_WARNING" ]]; then
  cat <<EOF

$COMPONENT_REUSE_WARNING
EOF
fi

# Side Effect 영향도 분석 정보 추가 (해당되는 경우만) [NEW - 2025-11-10]
if [[ -n "$SIDE_EFFECT_WARNING" ]]; then
  cat <<EOF

$SIDE_EFFECT_WARNING
EOF
fi

# Dynamic Form 패턴 정보 추가 (해당되는 경우만) [NEW - 2025-11-18]
if [[ -n "$DYNAMIC_FORM_WARNING" ]]; then
  cat <<EOF

$DYNAMIC_FORM_WARNING
EOF
fi

cat <<EOF

ROUTE:
  - 요청 분류: $REQUEST_CLASS
  - 자동 실행: $RECOMMENDED_AGENT --hard-think --delegate

───────────────────────────────────────────────────────────────────────────

🚀 MANDATORY ACTION (필수 실행):

다음 Agent를 **즉시 실행**하세요:

  Task --subagent_type $RECOMMENDED_AGENT --prompt "$USER_INPUT"

⚠️ 절대 규칙:
  - ❌ Write/Edit/Read 도구를 직접 사용하지 마세요
  - ❌ 코드를 직접 수정하지 마세요
  - ✅ 반드시 Agent를 통해 실행하세요

───────────────────────────────────────────────────────────────────────────

원본 프롬프트:
$USER_INPUT

───────────────────────────────────────────────────────────────────────────
⏱️ 처리 시간: ${ELAPSED_SEC}s | Phase 1 (하드코딩 매핑)

EOF

# 성능 로그 업데이트
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  end_timer "user-prompt-submit"
fi

# ============================================================================
# Pre-Analysis Document Check (Phase 1.5)
# ============================================================================

check_pre_analysis_docs() {
  local REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local DOCS_ANALYSIS="$REPO_ROOT/docs/analysis"
  local missing=()

  local REQUIRED_DOCS=(
    "tech-stack.md"
    "code-structure.md"
    "database-schema.md"
    "business-domain.md"
  )

  for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ ! -f "$DOCS_ANALYSIS/$doc" ]]; then
      missing+=("$doc")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    cat <<EOF

⚠️  사전분석 문서 누락 (${#missing[@]}/4):
EOF
    for doc in "${missing[@]}"; do
      echo "   - $doc"
    done

    cat <<EOF

💡 다음 Agent를 먼저 실행하세요:
   *parallel [
     '01-pre-analysis/tech-stack-analyzer',
     '01-pre-analysis/code-structure-analyzer',
     '01-pre-analysis/comprehensive-db-analyzer',
     '01-pre-analysis/business-analyzer'
   ]

EOF
    return 1
  fi

  return 0
}

# Epic/Story 생성 요청 시 사전분석 문서 확인
if [[ "$KEYWORDS" == "epic" ]] || [[ "$KEYWORDS" == "story" ]]; then
  check_pre_analysis_docs || {
    echo "⚠️  Warning: Epic/Story 생성 전 사전분석 권장 (선택사항)" >&2
    # exit 0으로 변경하여 hook 실패 방지
  }
fi

# Phase 2 안내 (TODO)
if [[ "$KEYWORDS" == "epic" ]] || [[ "$KEYWORDS" == "story" ]]; then
  cat <<EOF
💡 Phase 2 예고:
   - 유사 패턴 검색 (analyze-similar.sh)
   - 과거 성공 워크플로우 추천
   - 사용자 패턴 학습 기반 개인화

EOF
fi

# 성공 종료
exit 0
