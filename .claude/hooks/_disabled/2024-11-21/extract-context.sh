#!/bin/bash
# .claude/hooks/utils/extract-context.sh
# 컨텍스트 추출 유틸리티 함수

# 키워드 추출
extract_keywords() {
  local input="$1"
  local keywords=""

  # 소문자 변환
  local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  # 키워드 패턴 매칭 (우선순위 순)
  if echo "$lower_input" | grep -qE '(새로운 기능|시스템 구축|플랫폼|대규모|아키텍처)'; then
    keywords="epic"
  elif echo "$lower_input" | grep -qE '(긴급|p0|장애|서비스 다운|핫픽스|hotfix|복구)'; then
    keywords="hotfix"
  elif echo "$lower_input" | grep -qE '(버그|bug|fix|에러|error)'; then
    keywords="bug"
  elif echo "$lower_input" | grep -qE '(테스트|test)'; then
    keywords="test"
  elif echo "$lower_input" | grep -qE '(개선|improve|리팩터링|refactor|최적화|optimize)'; then
    keywords="task"
  elif echo "$lower_input" | grep -qE '(api 추가|화면 추가|컴포넌트|기능 확장|통합)'; then
    keywords="story"
  elif echo "$lower_input" | grep -qE '(마이그레이션|migration|스키마|schema)'; then
    # DB 관련은 create로 분류 (db-code-writer 호출)
    keywords="create"
  elif echo "$lower_input" | grep -qE '(create|add|추가|생성)'; then
    keywords="create"
  elif echo "$lower_input" | grep -qE '(modify|update|변경|수정)'; then
    keywords="modify"
  else
    keywords="story"  # 기본값
  fi

  echo "$keywords"
}

# 도메인 추출
extract_domain() {
  local input="$1"
  local domain="general"

  # 소문자 변환
  local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  # 도메인 키워드 우선순위 매칭
  if echo "$lower_input" | grep -qE '(스키마|schema|마이그레이션|migration|ddl|알렘빅|alembic|db|database)'; then
    domain="db"
  elif echo "$lower_input" | grep -qE '(auth|인증|로그인|login|password|비밀번호|session|세션|token|토큰)'; then
    domain="auth"
  elif echo "$lower_input" | grep -qE '(okr|목표|key result|kr)'; then
    domain="okr"
  elif echo "$lower_input" | grep -qE '(campaign|캠페인|피드백|feedback)'; then
    domain="campaign"
  elif echo "$lower_input" | grep -qE '(team|팀|그룹|group)'; then
    domain="team"
  elif echo "$lower_input" | grep -qE '(api|백엔드|backend|서버|server)'; then
    domain="api"
  elif echo "$lower_input" | grep -qE '(ui|화면|컴포넌트|component|frontend|프론트엔드|react)'; then
    domain="ui"
  fi

  echo "$domain"
}

# Agent 추천 로직
recommend_agent() {
  local keywords="$1"
  local domain="$2"
  local agent="02-requirements/02-story-creator"  # 기본값
  local expertise="Story 분해 전문"

  # 키워드 기반 Agent 선택
  case "$keywords" in
    "epic")
      agent="02-requirements/epic-creator"
      expertise="Epic 생성 및 MVP 설계 전문"
      ;;
    "hotfix")
      agent="99-utils/error-fixer"
      expertise="긴급 수정 및 핫픽스 전문"
      ;;
    "bug")
      agent="99-utils/error-fixer"
      expertise="버그 수정 및 디버깅 전문"
      ;;
    "test")
      agent="04-implementation/test-creator"
      expertise="테스트 코드 작성 전문"
      ;;
    "story")
      agent="02-requirements/02-story-creator"
      expertise="Story 분해 및 API/UI 통합 전문"
      ;;
    "task")
      agent="03-design/task-planner"
      expertise="Task 계획 및 구체화 전문"
      ;;
    *)
      # DB 도메인은 항상 db-code-writer
      if [[ "$domain" == "db" ]]; then
        agent="04-implementation/db-code-writer"
        expertise="DB 스키마 및 마이그레이션 전문"
      else
        agent="02-requirements/02-story-creator"
        expertise="Story 분해 전문"
      fi
      ;;
  esac

  echo "$agent|$expertise"
}

# 기술 컨텍스트 매핑
get_tech_context() {
  local domain="$1"
  local context=""

  case "$domain" in
    "auth")
      context="NextAuth.js + JWT + sparknote 스키마"
      ;;
    "okr")
      context="React + Next.js API + Prisma + sparknote.weekly_okrs"
      ;;
    "campaign")
      context="React + Next.js API + Prisma + sparknote.campaigns"
      ;;
    "team")
      context="React + Next.js API + Prisma + sparknote.teams"
      ;;
    "api")
      context="NestJS + Prisma + PostgreSQL + sparknote 스키마"
      ;;
    "ui")
      context="React + TypeScript + FSD 구조 + shadcn/ui"
      ;;
    "db")
      context="Prisma + PostgreSQL + sparknote 스키마 prefix"
      ;;
    *)
      context="React + Next.js + TypeScript + Prisma"
      ;;
  esac

  echo "$context"
}

# 주의사항 매핑
get_warnings() {
  local domain="$1"
  local warnings=""

  case "$domain" in
    "auth")
      warnings="  - session.backendToken 사용 (accessToken 아님)
  - DB ENUM 금지 (VARCHAR + TypeScript Literal Type)
  - useEffect 무한 루프 주의 (primitive deps만)
  - Admin Impersonation 헤더 필수 (X-Impersonate-User)"
      ;;
    "db")
      warnings="  - sparknote 스키마 prefix 필수 (sparknote.table_name)
  - DB ENUM 절대 금지 (VARCHAR 사용)
  - Migration 스크립트 검증 필수
  - @docs/analysis/guides/db-enum-prohibition-policy.md 참조"
      ;;
    "ui")
      warnings="  - FSD 구조 준수 (features/widgets/entities/shared)
  - useEffect deps primitive 값만 (객체/함수 금지)
  - React Hook rules 엄격히 준수
  - ESLint exhaustive-deps 경고 무시 금지"
      ;;
    "api")
      warnings="  - Next.js API Routes: 모든 HTTP 메서드 구현 (405 방지)
  - 중첩 엔드포인트는 별도 디렉토리 (404 방지)
  - Admin Impersonation 헤더 필수
  - @docs/patterns/fullstack/api-routes.md 참조"
      ;;
    *)
      warnings="  - YAGNI 원칙 (필요한 것만 구현)
  - 기존 패턴 재사용 우선 (mcp__serena__ 활용)
  - 테스트 코드 필수
  - sparknote 스키마 prefix 확인"
      ;;
  esac

  echo "$warnings"
}

# 예상 구조 생성
get_expected_structure() {
  local domain="$1"
  local keywords="$2"
  local structure=""

  # Epic인 경우 상세 구조
  if [[ "$keywords" == "epic" ]]; then
    structure="Epic → Story 분해 → Task 계획 → 병렬 구현"
    echo "$structure"
    return 0
  fi

  # 도메인별 구조
  case "$domain" in
    "auth")
      structure="S01 DB+API → S02 UI 로그인 → S03 Session 관리 → S04 테스트"
      ;;
    "okr")
      structure="S01 DB 스키마 → S02 API CRUD → S03 UI 목록 → S04 UI 상세"
      ;;
    "campaign")
      structure="S01 DB 스키마 → S02 API CRUD → S03 UI 목록 → S04 상태 관리"
      ;;
    "api")
      structure="S01 Entity+Repository → S02 Service → S03 Controller → S04 테스트"
      ;;
    "ui")
      structure="S01 컴포넌트 설계 → S02 UI 구현 → S03 상태 관리 → S04 통합"
      ;;
    "db")
      structure="S01 스키마 설계 → S02 Migration 작성 → S03 검증 → S04 적용"
      ;;
    *)
      structure="S01 DB → S02 Backend → S03 Frontend → S04 통합 테스트"
      ;;
  esac

  echo "$structure"
}

# Data Fetching 패턴 자동 판단 [NEW - 2025-11-10]
get_data_fetching_pattern() {
  local input="$1"
  local pattern="server"  # 기본값: Server Component/Action
  local checklist_count=0

  # 소문자 변환
  local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  # React Query 체크리스트 확인 (6가지)
  echo "$lower_input" | grep -qE '(낙관적|optimistic|즉시.*반영)' && ((checklist_count++))
  echo "$lower_input" | grep -qE '(무한.*스크롤|더.*보기|infinite|pagination)' && ((checklist_count++))
  echo "$lower_input" | grep -qE '(실시간|폴링|자동.*갱신|polling|refetch)' && ((checklist_count++))
  echo "$lower_input" | grep -qE '(여러.*컴포넌트|캐시.*공유|shared.*cache)' && ((checklist_count++))
  echo "$lower_input" | grep -qE '(오프라인|네트워크.*복구|offline|resilience)' && ((checklist_count++))
  echo "$lower_input" | grep -qE '(다단계|복잡.*플로우|multi.*step)' && ((checklist_count++))

  # 2개 이상 충족 시 React Query
  if [[ $checklist_count -ge 2 ]]; then
    pattern="react-query"
  fi

  echo "${pattern}|${checklist_count}"
}

# Data Fetching 경고 메시지
get_data_fetching_warnings() {
  local pattern="$1"
  local warnings=""

  if [[ "$pattern" == "react-query" ]]; then
    warnings="  - ✅ React Query 적합 (체크리스트 2개 이상)
  - queryKey 정의 필수
  - staleTime/refetchInterval 설정
  - 에러/로딩 상태 처리
  - 참조: @.claude/guides/DATA_FETCHING_GUIDELINES.md"
  else
    warnings="  - ✅ Server Component/Action 사용 (YAGNI)
  - serverAPI 사용 (자동 인증 + Admin Impersonation)
  - Next.js 캐싱 (revalidate 또는 tags)
  - ❌ React Query 불필요 (체크리스트 2개 미만)
  - 참조: @docs/analysis/data-fetching-patterns.md"
  fi

  echo "$warnings"
}

# 스크립트 직접 실행 시 테스트
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # 테스트 케이스
  echo "=== extract-context.sh 테스트 ==="

  test_input="사용자 인증 시스템 개선"
  echo ""
  echo "입력: $test_input"
  echo "키워드: $(extract_keywords "$test_input")"
  echo "도메인: $(extract_domain "$test_input")"

  domain=$(extract_domain "$test_input")
  keywords=$(extract_keywords "$test_input")
  agent_info=$(recommend_agent "$keywords" "$domain")

  echo "Agent: ${agent_info%%|*}"
  echo "Expertise: ${agent_info##*|}"
  echo "Tech Context: $(get_tech_context "$domain")"
  echo "Expected Structure: $(get_expected_structure "$domain" "$keywords")"
  echo ""
  echo "주의사항:"
  get_warnings "$domain"
fi
