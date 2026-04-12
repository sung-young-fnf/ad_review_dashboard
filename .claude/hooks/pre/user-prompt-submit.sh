#!/bin/bash
# .claude/hooks/pre/user-prompt-submit-compact.sh
# Compact Pre-Hook: 간소화된 컨텍스트 주입 (3000 chars 제한)
# Version: 3.1

# set -e 제거: Hook에서는 Graceful Degradation 필수
# grep 실패 등으로 인한 에러를 방지

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
# NOTE: 현재 해제 상태 (디버깅 용이성 우선)
# exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================

DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"  # 환경 변수로 제어 (기본: 비활성화)

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# Phase 0: stdin 읽기
# NOTE: 프로젝트 초기화 체크는 unified Hook에서 SERVICE_CONTEXT.md 유무로 처리
# ============================================================================

log_debug "=== HOOK START ==="

if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, INPUT_JSON length: ${#INPUT_JSON}"

  # Graceful JSON parsing
  if command -v jq &> /dev/null; then
    # jq가 존재하면 JSON 파싱 시도
    if echo "$INPUT_JSON" | jq -e . &>/dev/null; then
      log_debug "jq available, parsing JSON"
      USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)

      # jq 파싱 실패 시 fallback
      if [[ -z "$USER_INPUT" ]] || [[ "$USER_INPUT" == "null" ]]; then
        log_debug "jq parsing returned empty/null, using raw INPUT_JSON as fallback"
        USER_INPUT="$INPUT_JSON"
      else
        log_debug "jq parsing result: USER_INPUT='$USER_INPUT' (length: ${#USER_INPUT})"
      fi
    else
      log_debug "Invalid JSON, using raw INPUT_JSON"
      USER_INPUT="$INPUT_JSON"
    fi
  else
    log_debug "jq not available, using raw INPUT_JSON"
    USER_INPUT="$INPUT_JSON"
  fi
else
  log_debug "no stdin, using CLAUDE_USER_PROMPT or arg"
  USER_INPUT="${CLAUDE_USER_PROMPT:-${1:-}}"
fi

log_debug "Final USER_INPUT: '$USER_INPUT' (length: ${#USER_INPUT})"

# 빈 입력이면 조용히 종료
if [[ -z "$USER_INPUT" ]] || [[ "${#USER_INPUT}" -lt 2 ]]; then
  log_debug "Empty or short input detected, exiting silently (length: ${#USER_INPUT})"
  exit 0
fi

# ============================================================================
# Phase 0.7: 일반 대화 감지 (개발 요청이 아닌 경우 스킵)
# ============================================================================
# 인사, 질문, 일반 대화는 MANDATORY WORKFLOW 강제하지 않음
if echo "$USER_INPUT" | grep -qiE '^(안녕|하이|ㅎㅇ|hi|hello|hey|yo|감사|고마워|thanks|네|응|ㅇㅇ|ok|확인|알겠|넵)'; then
  log_debug "Greeting/casual input detected, skipping workflow enforcement"
  exit 0
fi

# 짧은 입력 (5자 이하)이고 개발 키워드가 없으면 스킵
if [[ "${#USER_INPUT}" -le 5 ]]; then
  if ! echo "$USER_INPUT" | grep -qiE '(fix|bug|에러|수정|추가|삭제|변경)'; then
    log_debug "Short non-dev input, skipping workflow enforcement"
    exit 0
  fi
fi

# Agent 내부 실행 감지 (무한 재귀 방지)
# STOP → ANALYZE → ROUTE 패턴이 포함된 경우에만 차단
if echo "$USER_INPUT" | grep -qE "🛑 STOP.*ANALYZE.*ROUTE"; then
  log_debug "Agent pattern detected, exiting to prevent recursion"
  exit 0
fi

log_debug "Input validation passed, continuing to Phase 1"

# ============================================================================
# Phase 0.8: Ralph Loop 자동 감지 (완료 보증 시스템)
# ============================================================================

REPO_ROOT_RALPH=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
RALPH_JSON="$REPO_ROOT_RALPH/.sisyphus/ralph.json"

# 키워드 정의
COMPLETION_KEYWORDS="수정|고쳐|fix|버그|bug|구현|만들어|추가|add|implement|리팩토링|refactor|개선|업데이트|update|변경|change|삭제|delete|remove|생성|create"
RESEARCH_KEYWORDS="찾아|분석|뭐야|어디|설명|알려|검색|조회|확인해봐|봐봐|what|where|how|why|explain|show|list"

# Ralph Loop 상태 결정
RALPH_ACTIVE=false
RALPH_REASON=""

# 1. --no-guarantee 플래그 체크 (최우선)
if echo "$USER_INPUT" | grep -qiE '\-\-no-guarantee'; then
  RALPH_ACTIVE=false
  RALPH_REASON="--no-guarantee flag detected"
  log_debug "Ralph Loop: OFF (--no-guarantee)"

# 2. 조사/분석 키워드만 있는지 체크
elif echo "$USER_INPUT" | grep -qiE "$RESEARCH_KEYWORDS" && ! echo "$USER_INPUT" | grep -qiE "$COMPLETION_KEYWORDS"; then
  RALPH_ACTIVE=false
  RALPH_REASON="research-only query"
  log_debug "Ralph Loop: OFF (research keywords only)"

# 3. 완료 필요 키워드 체크
elif echo "$USER_INPUT" | grep -qiE "$COMPLETION_KEYWORDS"; then
  RALPH_ACTIVE=true
  RALPH_REASON="completion keyword detected"
  log_debug "Ralph Loop: ON (completion keyword: matched)"

# 4. Task/Story 파일 참조 감지
elif echo "$USER_INPUT" | grep -qiE '(task|story|epic)[-_]?[0-9]+|T[0-9]{3}|S[0-9]{2}|EP[0-9]{3}'; then
  RALPH_ACTIVE=true
  RALPH_REASON="task/story reference detected"
  log_debug "Ralph Loop: ON (task/story reference)"

# 5. 기본: OFF
else
  RALPH_ACTIVE=false
  RALPH_REASON="no trigger detected"
  log_debug "Ralph Loop: OFF (default)"
fi

# Ralph Loop 상태 업데이트 및 리마인더 출력
if [[ "$RALPH_ACTIVE" == "true" ]]; then
  # .sisyphus 디렉토리 확인
  mkdir -p "$REPO_ROOT_RALPH/.sisyphus" 2>/dev/null

  # ralph.json 업데이트
  cat > "$RALPH_JSON" <<RALPHJSON
{
  "active": true,
  "auto_detected": true,
  "reason": "$RALPH_REASON",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "incomplete_count": 0,
  "todos": [],
  "completed_at": null,
  "cancelled_at": null
}
RALPHJSON

  log_debug "Ralph Loop activated: $RALPH_JSON"

  # 리마인더 메시지 출력
  echo ""
  echo "🔄 완료 보증 모드 자동 활성화"
  echo "   └─ 작업 완료까지 중단되지 않습니다"
  echo "   └─ 끄려면: --no-guarantee"
  echo ""
fi

# ============================================================================
# Agent 자동 실행 (Handoff Memory 기반)
# ============================================================================

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "REPO_ROOT: $REPO_ROOT"

# ============================================================================
# VIOLATION 기록 확인 및 경고 (세션 시작 시)
# ============================================================================
VIOLATION_LOG="$REPO_ROOT/.claude/.violations.log"
if [[ -f "$VIOLATION_LOG" ]]; then
  VIOLATION_COUNT=$(wc -l < "$VIOLATION_LOG" | tr -d ' ')
  log_debug "Found $VIOLATION_COUNT violations in log"

  if [[ "$VIOLATION_COUNT" -gt 0 ]]; then
    # Silent Mode: 1줄 경고만
    echo "⚠️ VIOLATION: $VIOLATION_COUNT건 - STOP→ANALYZE→ROUTE 템플릿 사용 필수"
  fi
fi

# 세션 시작 시 first-tool-done 파일 초기화
rm -f "$REPO_ROOT/.claude/.first-tool-done"
log_debug "Cleared first-tool-done state"

# Handoff Memory 확인 (code-writer 완료 시)
HANDOFF_PATTERN="handoff_code_writer_*"
HANDOFF_MEMORY=$(ls "$REPO_ROOT/.serena/memories/$HANDOFF_PATTERN.md" 2>/dev/null | head -1)
log_debug "HANDOFF_MEMORY: $HANDOFF_MEMORY"

if [[ -n "$HANDOFF_MEMORY" ]] && [[ -f "$HANDOFF_MEMORY" ]]; then
  log_debug "Handoff memory found, parsing..."
  # Memory 내용 파싱 (Bash 패턴)
  NEXT_TASK_ID=$(grep -o '"next_task_id":\s*"[^"]*"' "$HANDOFF_MEMORY" | cut -d'"' -f4)
  AUTO_EXECUTE=$(grep -o '"auto_execute":\s*true' "$HANDOFF_MEMORY")
  log_debug "NEXT_TASK_ID: $NEXT_TASK_ID, AUTO_EXECUTE: $AUTO_EXECUTE"

  if [[ -n "$NEXT_TASK_ID" ]] && [[ -n "$AUTO_EXECUTE" ]]; then
    log_debug "Auto-execute conditions met, deleting memory and showing message"
    # Memory 삭제 (1회성 실행)
    rm -f "$HANDOFF_MEMORY"

    # 간소화된 자동 실행 메시지
    echo "🔄 AUTO: $NEXT_TASK_ID → Task(code-writer, \"$NEXT_TASK_ID 구현\")"
  fi
fi

# ============================================================================
# Phase 1: 키워드 분석 (간소화)
# ============================================================================

analyze_keywords() {
  # Fix: 전체 입력 대신 첫 5줄만 분석 (붙여넣은 로그의 False Positive 방지)
  local input=$(echo "$1" | head -5)
  local keywords=""
  log_debug "analyze_keywords called with input (first 5 lines): '$input'"

  # 긴급 키워드 (영어 + 한국어)
  if echo "$input" | grep -qiE '(error|bug|crash|fail|500|404|undefined|에러|버그|오류|문제|안됨|안돼|실패|깨짐)'; then
    keywords="$keywords bug"
    log_debug "Matched: bug"
  fi
  if echo "$input" | grep -qiE '(hotfix|urgent|asap|critical|production|긴급|급함|지속|계속|여전히|아직)'; then
    keywords="$keywords urgent"
    log_debug "Matched: urgent"
  fi

  # 도메인 키워드 (영어 + 한국어)
  if echo "$input" | grep -qiE '(database|db|schema|migration|prisma|데이터베이스|스키마|마이그레이션)'; then
    keywords="$keywords db"
    log_debug "Matched: db"
  fi
  if echo "$input" | grep -qiE '(api|endpoint|route|backend|server|백엔드|서버|엔드포인트)'; then
    keywords="$keywords api"
    log_debug "Matched: api"
  fi
  if echo "$input" | grep -qiE '(ui|frontend|component|react|next|프론트|컴포넌트|화면|페이지|UI)'; then
    keywords="$keywords frontend"
    log_debug "Matched: frontend"
  fi

  # UX 키워드 (UI점검, UX 분석, 레이아웃 등)
  if echo "$input" | grep -qiE '(ux|ui점검|ui/ux|레이아웃|사용성|접근성|인터랙션|탭.*분리|전체화면|모달|패널)'; then
    keywords="$keywords ux"
    log_debug "Matched: ux"
  fi

  # 작업 크기 (영어 + 한국어)
  if echo "$input" | grep -qiE '(epic|대형|시스템|전체|새로운)'; then
    keywords="$keywords epic"
    log_debug "Matched: epic"
  fi
  # Fix: 매칭 범위 축소 (흔한 한국어 단어 제외)
  if echo "$input" | grep -qiE '(story|스토리|기능.*추가|기능.*구현|중형.*작업)'; then
    keywords="$keywords story"
    log_debug "Matched: story"
  fi
  if echo "$input" | grep -qiE '(task|태스크|소형.*작업|간단.*수정)'; then
    keywords="$keywords task"
    log_debug "Matched: task"
  fi

  local result="${keywords:-general}"
  log_debug "analyze_keywords result: '$result'"
  echo "$result"
}

determine_squad_scale() {
  local input="$1"
  local keywords="$2"
  local input_len=${#input}

  # Priority: EPIC > PLANNING > ANALYSIS > DESIGN > QUALITY > BUG_CRITICAL > DB > UX > STORY > SOLO

  # EPIC
  if echo "$keywords" | grep -q 'epic'; then
    echo "EPIC"; return
  fi
  if echo "$input" | grep -qiE '(시스템|플랫폼|아키텍처|architecture|platform|대형|전체.*재설계)'; then
    echo "EPIC"; return
  fi

  # PLANNING (Epic/Story 기획 시 Planning Squad 트리거)
  if echo "$input" | grep -qiE '(기획.*스쿼드|planning.*squad|에픽.*생성.*스쿼드|스토리.*생성.*스쿼드)'; then
    echo "PLANNING"; return
  fi

  # ANALYSIS (사전분석 Squad 트리거)
  if echo "$input" | grep -qiE '(사전분석|전수분석|코드분석.*스쿼드|analysis.*squad|구조.*분석.*스쿼드)'; then
    echo "ANALYSIS"; return
  fi

  # DESIGN (설계 Squad 트리거)
  if echo "$input" | grep -qiE '(설계.*스쿼드|design.*squad|task.*분해.*스쿼드|태스크.*설계)'; then
    echo "DESIGN"; return
  fi

  # QUALITY (품질 검증 Squad 트리거)
  if echo "$input" | grep -qiE '(품질.*검증|quality.*squad|릴리즈.*검증|전수.*검증|코드.*리뷰.*스쿼드)'; then
    echo "QUALITY"; return
  fi

  # BUG_CRITICAL
  if echo "$keywords" | grep -q 'urgent' && echo "$keywords" | grep -q 'bug'; then
    echo "BUG_CRITICAL"; return
  fi

  # DB
  if echo "$keywords" | grep -q 'db' && echo "$input" | grep -qiE '(스키마|마이그레이션|DDL|테이블|migration|schema)'; then
    echo "DB"; return
  fi

  # UX
  if echo "$keywords" | grep -q 'ux' && echo "$input" | grep -qiE '(개선|감사|분석|audit|improve|review)'; then
    echo "UX"; return
  fi

  # STORY
  if echo "$keywords" | grep -q 'story'; then
    echo "STORY"; return
  fi
  if [[ $input_len -ge 200 ]] && echo "$input" | grep -qiE '(기능|추가|통합|API|컴포넌트|feature|integrate)'; then
    echo "STORY"; return
  fi

  # Default
  echo "SOLO"
}

# ============================================================================
# Phase 2: 컴팩트 출력 (3000 chars 이하)
# ============================================================================

log_debug "Phase 2: Generating output"
KEYWORDS=$(analyze_keywords "$USER_INPUT")
log_debug "KEYWORDS extracted: '$KEYWORDS'"

# Squad 규모 판단
SQUAD_SCALE=$(determine_squad_scale "$USER_INPUT" "$KEYWORDS")
log_debug "SQUAD_SCALE: $SQUAD_SCALE"

# 마커 파일 작성 (SOLO가 아닐 때만)
SQUAD_MARKER="$REPO_ROOT/.claude/.squad-recommended"
if [[ "$SQUAD_SCALE" != "SOLO" ]]; then
  cat > "$SQUAD_MARKER" <<SQEOF
scale=$SQUAD_SCALE
keywords=$KEYWORDS
timestamp=$(date +%s)
SQEOF
  log_debug "Squad marker created: $SQUAD_MARKER (scale=$SQUAD_SCALE)"
else
  rm -f "$SQUAD_MARKER"
  log_debug "Solo mode, squad marker removed"
fi

# ============================================================================
# Phase 2.5: 개발 요청 감지 시 상태 파일 생성 (PreToolUse Hook 연동)
# ============================================================================

# ============================================================================
# Phase 2.6: Pre-Review Impact Analysis (사전 영향도 분석)
# ============================================================================
FRONTEND_SRC="$REPO_ROOT/apps/frontend/src"
IMPACT_OUTPUT=""

# 컴포넌트명 추출 (PascalCase: CampaignCard, SparkNoteSidebar 등)
# 2글자 이상의 PascalCase 단어만 추출
COMPONENT_NAMES=$(echo "$USER_INPUT" | grep -oE '\b[A-Z][a-zA-Z]{2,}[a-zA-Z]*\b' 2>/dev/null | sort -u | head -5)
log_debug "Detected component names: $COMPONENT_NAMES"

for COMPONENT in $COMPONENT_NAMES; do
  # 너무 일반적인 단어 스킵
  if echo "$COMPONENT" | grep -qE '^(The|This|That|What|How|Why|When|Where|Which|Task|Agent|Hook|Edit|Write|Read)$'; then
    continue
  fi

  # 컴포넌트 파일 존재 여부 확인
  COMPONENT_FILE=$(find "$FRONTEND_SRC" -type f \( -name "${COMPONENT}.tsx" -o -name "${COMPONENT}.ts" -o -name "${COMPONENT}/index.tsx" \) 2>/dev/null | head -1)

  if [[ -n "$COMPONENT_FILE" ]]; then
    log_debug "Found component file: $COMPONENT_FILE"

    # 사용처 검색
    USAGES=$(grep -rn --include="*.tsx" --include="*.ts" \
         -E "(import.*['\"].*${COMPONENT}['\"]|import.*${COMPONENT}|from.*${COMPONENT}|<${COMPONENT})" \
         "$FRONTEND_SRC" 2>/dev/null | \
         grep -v "node_modules" | \
         grep -v "$COMPONENT_FILE" | \
         head -15 || true)

    if [[ -n "$USAGES" ]]; then
      USAGE_COUNT=$(echo "$USAGES" | wc -l | tr -d ' ')
      log_debug "Component $COMPONENT has $USAGE_COUNT usages"

      # 임계값 판단 (3개 이상만 표시)
      if [[ $USAGE_COUNT -ge 10 ]]; then
        ICON="🔴"
        RISK="CRITICAL"
      elif [[ $USAGE_COUNT -ge 5 ]]; then
        ICON="🟠"
        RISK="HIGH"
      elif [[ $USAGE_COUNT -ge 3 ]]; then
        ICON="🟡"
        RISK="MEDIUM"
      else
        log_debug "Low impact ($USAGE_COUNT), skipping display"
        continue
      fi

      # 영향받는 파일 목록 생성
      AFFECTED_FILES=$(echo "$USAGES" | cut -d':' -f1 | sort -u | head -5 | while read -r f; do
        echo "   - $(echo "$f" | sed "s|$FRONTEND_SRC/||")"
      done)

      TOTAL_UNIQUE=$(echo "$USAGES" | cut -d':' -f1 | sort -u | wc -l | tr -d ' ')

      # 출력 누적
      IMPACT_OUTPUT="${IMPACT_OUTPUT}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 PRE-REVIEW IMPACT ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ICON $COMPONENT (${USAGE_COUNT}곳에서 사용, $RISK)
   영향받는 파일:
$AFFECTED_FILES"

      if [[ $TOTAL_UNIQUE -gt 5 ]]; then
        IMPACT_OUTPUT="${IMPACT_OUTPUT}
   ... 외 $((TOTAL_UNIQUE - 5))개 파일"
      fi

      IMPACT_OUTPUT="${IMPACT_OUTPUT}
💡 이 컴포넌트 수정 시 위 파일들에 영향이 있습니다.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
  fi
done

# 영향도 분석 결과 출력 (있을 경우에만)
if [[ -n "$IMPACT_OUTPUT" ]]; then
  echo "$IMPACT_OUTPUT"
  echo ""
fi
DEV_REQUEST_FILE="$REPO_ROOT/.claude/.dev-request-pending"
UX_GATEWAY_FILE="$REPO_ROOT/.claude/.ux-gateway-required"

# 이전 세션 마커 정리 (새 요청마다 초기화)
rm -f "$UX_GATEWAY_FILE"
log_debug "Cleared previous UX gateway marker"

# 개발 관련 키워드가 있으면 상태 파일 생성
if echo "$KEYWORDS" | grep -qE 'bug|urgent|db|api|frontend|ux|epic|story|task'; then
  echo "keywords=$KEYWORDS" > "$DEV_REQUEST_FILE"
  echo "timestamp=$(date +%s)" >> "$DEV_REQUEST_FILE"
  log_debug "Created dev-request-pending file: $DEV_REQUEST_FILE"

  # ────────────────────────────────────────────────────────────
  # UX Gateway 마커 생성 (Quick-Pass 조건 아니면 생성)
  # UX-First 철학: "사용자가 직접 경험하는가?" 먼저 자문
  # Quick-Pass: 순수 인프라만 (User Impact 없음)
  # API, DB, 에러는 User Impact 있으므로 Quick-Pass 아님
  # ────────────────────────────────────────────────────────────
  IS_QUICK_PASS=false

  # Quick-Pass 조건 1: CI/CD 파이프라인 (순수 인프라)
  if echo "$USER_INPUT" | grep -qiE '(CI/CD|cicd|github.actions|argocd|파이프라인|pipeline|workflow\.yml)'; then
    IS_QUICK_PASS=true
    log_debug "Quick-Pass: CI/CD pipeline (no user impact)"
  fi

  # Quick-Pass 조건 2: 컨테이너/오케스트레이션 (순수 인프라)
  if echo "$USER_INPUT" | grep -qiE '(Docker|docker|Dockerfile|K8s|k8s|Kubernetes|kubernetes|Helm|helm|컨테이너)'; then
    IS_QUICK_PASS=true
    log_debug "Quick-Pass: container/orchestration (no user impact)"
  fi

  # Quick-Pass 조건 3: 린터/포매터 설정 (순수 인프라)
  if echo "$USER_INPUT" | grep -qiE '(ESLint|eslint|Prettier|prettier|린터|linter|포매터|formatter|\.eslintrc|\.prettierrc)'; then
    IS_QUICK_PASS=true
    log_debug "Quick-Pass: linter/formatter (no user impact)"
  fi

  # Quick-Pass 조건 4: 빌드 설정 (순수 인프라)
  if echo "$USER_INPUT" | grep -qiE '(webpack|vite\.config|tsconfig|빌드설정|build\.config|next\.config|rollup)'; then
    IS_QUICK_PASS=true
    log_debug "Quick-Pass: build config (no user impact)"
  fi

  # Quick-Pass 조건 5: 순수 리팩토링 (동작 변경 없음, UI 무관)
  if echo "$USER_INPUT" | grep -qiE '(리팩토링|refactor|코드정리|cleanup)' && ! echo "$USER_INPUT" | grep -qiE '(화면|페이지|UI|UX|버튼|모달|컴포넌트|레이아웃|디자인|API|응답|에러|메시지)'; then
    IS_QUICK_PASS=true
    log_debug "Quick-Pass: pure refactor (no behavior change)"
  fi

  # NOTE: API, DB, 에러 처리는 User Impact 있음 → Quick-Pass 아님
  # - API 응답 → 사용자가 받는 데이터
  # - DB 스키마 → 표현 가능한 정보
  # - 에러 처리 → 사용자 피드백

  # Fix: frontend/ux 키워드가 있을 때만 UX Gateway 활성화
  # 이전: 모든 non-quick-pass → UX Gateway (bug, api, db도 전부 트리거)
  # 이후: frontend/ux 직접 관련만 → UX Gateway (오탐 90% 감소)
  if [[ "$IS_QUICK_PASS" == "false" ]] && echo "$KEYWORDS" | grep -qE 'frontend|ux'; then
    echo "$KEYWORDS" > "$UX_GATEWAY_FILE"
    log_debug "UX Gateway marker created (keywords: $KEYWORDS)"
  else
    log_debug "Quick-Pass: UX Gateway skipped"
  fi
else
  # 개발 요청이 아니면 상태 파일 삭제 (일반 질문)
  rm -f "$DEV_REQUEST_FILE"
  log_debug "No dev keywords, removed pending file"
fi

# ============================================================================
# Compact Output (v3.3) - 컨텍스트 절약형
# ============================================================================

# Agent 추천 결정
RECOMMENDED_AGENT="task-planner"
MCP_REMINDER=""
UX_REMINDER=""
# UX-First: frontend/ux 키워드가 bug보다 우선 (화면+오류 → UX agent 먼저)
if echo "$KEYWORDS" | grep -qE 'frontend|ux'; then
  RECOMMENDED_AGENT="ux-heuristic-auditor"
  UX_REMINDER="🎨 UX MANDATORY: UX agent 분석 후 code-writer 구현 (Main Thread 직접 UX 판단 금지)"
  # frontend + bug 동시 매칭 시 historian도 안내
  if echo "$KEYWORDS" | grep -qE 'bug|urgent|error'; then
    MCP_REMINDER="🔍 ALSO: historian/get_error_solutions 호출 권장 (에러 키워드 동시 감지)"
  fi
elif echo "$KEYWORDS" | grep -qE 'bug|urgent|error'; then
  RECOMMENDED_AGENT="error-fixer"
  MCP_REMINDER="🔍 MANDATORY: historian/get_error_solutions 먼저 호출!"
elif echo "$KEYWORDS" | grep -qE 'db'; then
  RECOMMENDED_AGENT="db-code-writer"
elif echo "$KEYWORDS" | grep -qE 'epic'; then
  RECOMMENDED_AGENT="epic-creator"
elif echo "$KEYWORDS" | grep -qE 'story'; then
  RECOMMENDED_AGENT="story-creator"
fi

# 간소화된 출력 (SOLO vs Squad 분기)
if [[ "$SQUAD_SCALE" != "SOLO" ]]; then
  # Squad 추천 출력
  SQUAD_TEMPLATE=""
  case "$SQUAD_SCALE" in
    EPIC) SQUAD_TEMPLATE="epic-squad" ;;
    PLANNING) SQUAD_TEMPLATE="planning-squad" ;;
    ANALYSIS) SQUAD_TEMPLATE="analysis-squad" ;;
    DESIGN) SQUAD_TEMPLATE="design-squad" ;;
    QUALITY) SQUAD_TEMPLATE="quality-squad" ;;
    STORY) SQUAD_TEMPLATE="story-squad" ;;
    BUG_CRITICAL) SQUAD_TEMPLATE="bug-squad" ;;
    DB) SQUAD_TEMPLATE="db-squad" ;;
    UX) SQUAD_TEMPLATE="ux-squad" ;;
  esac

  cat <<SQOUT
🚨 WORKFLOW [$KEYWORDS] → $RECOMMENDED_AGENT
🏋️ SQUAD [$SQUAD_SCALE] → $SQUAD_TEMPLATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 STOP→ANALYZE→ROUTE 필수 (CLAUDE.md 참조)
🏋️ Squad 편성: .claude/squads/templates/$SQUAD_TEMPLATE.yaml 참조
⚡ Teammate.spawnTeam → Lead 미션 브리핑 → TaskList 기반 병렬 실행
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SQOUT
else
  # 기존 Solo 출력 유지
  cat <<EOF
🚨 WORKFLOW [$KEYWORDS] → $RECOMMENDED_AGENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 STOP→ANALYZE→ROUTE 필수 (CLAUDE.md 참조)
⚡ Task(subagent_type: "$RECOMMENDED_AGENT", prompt: "...")
⚠️ Direct Read/Grep → Agent 우선 (file-analyzer, Explore)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
fi

# 에러 키워드 감지 시 historian MCP 리마인더
if [[ -n "$MCP_REMINDER" ]]; then
  echo "$MCP_REMINDER"
fi

# UX 키워드 감지 시 UX agent 강제 지시
if [[ -n "$UX_REMINDER" ]]; then
  echo "$UX_REMINDER"
  echo "   └─ 필수: Task(subagent_type='05-quality/ux-heuristic-auditor', prompt='...')"
fi

# UX Gateway 마커 존재 시 강제 지시 (MANDATORY)
if [[ -f "$UX_GATEWAY_FILE" ]]; then
  GATEWAY_KEYWORDS=$(cat "$UX_GATEWAY_FILE" 2>/dev/null || echo "frontend")
  cat <<UXEOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌐 UX GATEWAY MANDATORY (keywords: $GATEWAY_KEYWORDS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ UI/프론트엔드 요청 감지됨. code-writer 직접 호출 금지!

✅ 필수 선행 단계:
   Task(subagent_type='05-quality/ux-heuristic-auditor',
        prompt='현재 요청 분석 및 UX 관점 개선안 도출')

🚫 다음 행동 차단됨:
   - Task(subagent_type='code-writer', ...) → BLOCKED
   - Main Thread에서 직접 UI 코드 작성 → VIOLATION

📋 UX agent 완료 후:
   - UX-AUDIT-REPORT.md 생성됨
   - code-writer 호출 가능해짐 (.ux-gateway-required 마커 삭제됨)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
UXEOF
fi

# ============================================
# 🛑 STOP→ANALYZE→ROUTE 템플릿 검증
# ============================================
# 키워드 감지 (구현/버그/추가 등)
if echo "$USER_INPUT" | grep -qiE '(구현|수정|추가|변경|버그|에러|오류|문제|fix|feat|refactor|create|delete|update)'; then
  # 템플릿 사용 여부 확인
  if ! echo "$USER_INPUT" | grep -q "STOP.*ANALYZE.*ROUTE"; then
    echo "⚠️ STOP→ANALYZE→ROUTE 템플릿 권장"
    echo "   📝 추천 형식:"
    echo "   🛑 STOP → 🔍 ANALYZE → ✅ ROUTE"
    echo "   Keywords: [keyword1, keyword2]"
    echo "   Domain: [frontend/backend/db/infra]"
    echo "   Code-Change: [none/minor/major]"
  fi
fi

# 스크린샷 감지 (간소화)
if echo "$USER_INPUT" | grep -qiE 'screenshot|스크린샷|화면|UI|버튼'; then
  log_debug "Screenshot keyword detected"
  echo "📸 Screenshot Protocol: Phase 1 (analyze image) → Phase 2 (map to files)"
fi

# Next.js 16 useSearchParams 패턴 경고 (1줄)
if echo "$USER_INPUT" | grep -qiE 'useSearchParams|searchParams\.get|Suspense.*boundary|prerender.*error'; then
  log_debug "Next.js 16 useSearchParams pattern detected"
  echo "⚠️ Next.js 16: useSearchParams() 직접 사용 금지 → Server Component props 사용"
fi

log_debug "=== HOOK END (exit 0) ==="
exit 0