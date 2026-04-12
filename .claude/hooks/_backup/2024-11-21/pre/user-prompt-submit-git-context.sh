#!/usr/bin/env bash
# Git Context Injector Hook (Bash Implementation)
# Purpose: 사용자 메시지에서 키워드 추출 → Git 히스토리 검색 → 관련 리팩토링 컨텍스트 주입
# Execution: < 500ms (캐시 활용 시 < 100ms)

set -e
trap 'exit 0' ERR

# ==================== Configuration ====================
HOOK_NAME="git-context-injector"
CACHE_TTL=3600  # 1시간 캐시 유지
MAX_COMMITS=10  # 최대 검색 커밋 수
SERENA_MEMORY_PREFIX="git-refactor-cache"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# ==================== Helper Functions ====================

# 키워드 추출 (간단한 패턴 매칭)
extract_keywords() {
  local message="$1"

  # 1. 기술 용어 추출
  local tech_keywords
  tech_keywords=$(echo "$message" | grep -oE '(weekly-okr|캠페인|campaign|리팩토링|refactor|삭제|delete|이름변경|rename|API|컴포넌트|component|모듈|module)' || echo "")

  # 2. URL 패턴 추출 (/admin/teams, /spark-note 등)
  local url_keywords
  url_keywords=$(echo "$message" | grep -oE '/[a-z-]+(/[a-z-]+)*' | sed 's|^/||' || echo "")

  # 3. 컴포넌트명 추출 (대문자 시작, CamelCase)
  local component_keywords
  component_keywords=$(echo "$message" | grep -oE '\b[A-Z][a-zA-Z]+\b' | grep -E '^(Dashboard|Team|Spark|Campaign|Filter|Table)' || echo "")

  # 결과 병합 (중복 제거)
  echo -e "$tech_keywords\n$url_keywords\n$component_keywords" | grep -v '^$' | sort -u
}

# Git 히스토리 검색
search_git_refactorings() {
  local keywords=("$@")
  local results=""

  for keyword in "${keywords[@]}"; do
    # 1. 정확한 키워드 매칭 (해당 키워드만)
    local exact_search
    exact_search=$(git log --all --grep="$keyword" --oneline -"$MAX_COMMITS" 2>/dev/null || echo "")

    # 2. 파일 이름 변경 감지 (--diff-filter=R)
    local rename_search
    rename_search=$(git log --all --diff-filter=R --name-status --oneline -"$MAX_COMMITS" | grep -i "$keyword" 2>/dev/null || echo "")

    # 3. 파일 경로 검색 (변경된 파일에 키워드 포함)
    local file_search
    file_search=$(git log --all --name-only --oneline -"$MAX_COMMITS" | grep -B1 -i "$keyword" | grep "^[a-f0-9]" 2>/dev/null || echo "")

    # 결과 병합 (검색 기준 명시)
    if [[ -n "$exact_search" ]]; then
      results+="🔍 Keyword: '$keyword' (Commit Messages - 정확한 매칭)\n"
      results+="   검색: git log --grep=\"$keyword\"\n"
      results+="$exact_search\n\n"
    fi

    if [[ -n "$rename_search" ]]; then
      results+="🔍 Keyword: '$keyword' (File Renames - 파일명 변경)\n"
      results+="   검색: git log --diff-filter=R | grep \"$keyword\"\n"
      results+="$rename_search\n\n"
    fi

    if [[ -n "$file_search" ]]; then
      results+="🔍 Keyword: '$keyword' (File Paths - 변경 파일 경로)\n"
      results+="   검색: git log --name-only | grep \"$keyword\"\n"
      results+="$file_search\n\n"
    fi
  done

  echo -e "$results"
}

# Serena MCP 캐시 체크
check_cache() {
  local cache_key="$1"
  local cache_file="$PROJECT_ROOT/.serena/memories/${SERENA_MEMORY_PREFIX}_${cache_key}.md"

  if [[ -f "$cache_file" ]]; then
    # 캐시 파일 수정 시간 체크
    local file_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file")))

    if [[ $file_age -lt $CACHE_TTL ]]; then
      cat "$cache_file"
      return 0
    fi
  fi

  return 1
}

# Serena MCP 캐시 저장
save_cache() {
  local cache_key="$1"
  local content="$2"
  local cache_file="$PROJECT_ROOT/.serena/memories/${SERENA_MEMORY_PREFIX}_${cache_key}.md"

  mkdir -p "$(dirname "$cache_file")"
  echo "$content" > "$cache_file"
}

# Context Injection 메시지 생성
generate_context_message() {
  local git_findings="$1"

  if [[ -z "$git_findings" ]]; then
    return  # 발견된 리팩토링 없음 → 메시지 주입 안 함
  fi

  cat <<EOF
📚 GIT REFACTORING CONTEXT (Auto-Injected by Hook System)

관련 리팩토링 히스토리가 발견되었습니다:

$git_findings

⚠️ 주의사항:
- 위 커밋에서 모듈/API 이름이 변경되었을 수 있습니다
- 현재 코드베이스의 실제 구현을 확인하세요 (git log의 기록과 다를 수 있음)
- 백엔드 Controller의 @Controller() 데코레이터가 실제 API 엔드포인트입니다

EOF
}

# ==================== Main Logic ====================

main() {
  local user_message="${1:-}"

  # 사용자 메시지 없으면 종료
  if [[ -z "$user_message" ]]; then
    exit 0
  fi

  # 1. 키워드 추출
  local keywords
  keywords=$(extract_keywords "$user_message")

  if [[ -z "$keywords" ]]; then
    # 기술 키워드 없음 → 컨텍스트 주입 불필요
    exit 0
  fi

  # 2. 캐시 체크 (키워드 조합을 해시로 사용)
  local cache_key
  cache_key=$(echo "$keywords" | md5sum | cut -d' ' -f1 2>/dev/null || echo "$keywords" | md5 | cut -d' ' -f1)

  local cached_result
  if cached_result=$(check_cache "$cache_key"); then
    echo "$cached_result"
    exit 0
  fi

  # 3. Git 히스토리 검색
  local git_findings
  git_findings=$(search_git_refactorings $keywords)

  # 4. Context Injection 메시지 생성
  local context_message
  context_message=$(generate_context_message "$git_findings")

  # 5. 캐시 저장
  if [[ -n "$context_message" ]]; then
    save_cache "$cache_key" "$context_message"
    echo "$context_message"
  fi
}

# ==================== Execution ====================

# Hook 입력: stdin (user message) 또는 $1
if [ ! -t 0 ]; then
  # stdin에서 읽기
  USER_MESSAGE=$(cat)
else
  # 인자에서 읽기
  USER_MESSAGE="${1:-}"
fi

main "$USER_MESSAGE"
