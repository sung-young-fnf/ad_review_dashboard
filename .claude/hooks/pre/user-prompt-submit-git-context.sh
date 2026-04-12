#!/bin/bash
# .claude/hooks/pre/user-prompt-submit-git-context.sh
# Git Context Injector Hook (v2.0 - Graceful Degradation Pattern)
# Purpose: 사용자 메시지에서 키워드 추출 → Git 히스토리 검색 → 관련 리팩토링 컨텍스트 주입
# Execution: < 500ms (캐시 활용 시 < 100ms)

# ============================================================================
# CRITICAL: set -e 제거 (Graceful Degradation 필수)
# grep 실패 등으로 인한 에러를 방지
# ============================================================================

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================

DEBUG_LOG="/tmp/hook-git-context-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [git-context] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# Configuration
# ============================================================================

CACHE_TTL=3600  # 1시간 캐시 유지
MAX_COMMITS=10  # 최대 검색 커밋 수
SERENA_MEMORY_PREFIX="git-refactor-cache"

# ============================================================================
# Phase 0: stdin 읽기 (메인 Hook 패턴 동일)
# ============================================================================

log_debug "=== GIT CONTEXT HOOK START ==="

# NOTE: 프로젝트 초기화 체크는 unified Hook에서 SERVICE_CONTEXT.md 유무로 처리

if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, INPUT_JSON length: ${#INPUT_JSON}"

  # Graceful JSON parsing
  if command -v jq &> /dev/null; then
    if echo "$INPUT_JSON" | jq -e . &>/dev/null; then
      log_debug "jq available, parsing JSON"
      USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)

      if [[ -z "$USER_INPUT" ]] || [[ "$USER_INPUT" == "null" ]]; then
        log_debug "jq parsing returned empty/null, using raw INPUT_JSON as fallback"
        USER_INPUT="$INPUT_JSON"
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

log_debug "Final USER_INPUT length: ${#USER_INPUT}"

# 빈 입력이면 조용히 종료
if [[ -z "$USER_INPUT" ]] || [[ "${#USER_INPUT}" -lt 2 ]]; then
  log_debug "Empty or short input, exiting silently"
  exit 0
fi

# ============================================================================
# Project Root 확인
# ============================================================================

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "PROJECT_ROOT: $PROJECT_ROOT"

# Git 저장소가 아니면 종료
if ! git rev-parse --git-dir &>/dev/null; then
  log_debug "Not a git repository, exiting"
  exit 0
fi

# ============================================================================
# Helper Functions
# ============================================================================

# 만료된 캐시 정리 (60분 이상된 파일 삭제)
cleanup_expired_cache() {
  local cache_dir="$PROJECT_ROOT/.serena/memories"
  if [[ -d "$cache_dir" ]]; then
    find "$cache_dir" \
      -name "${SERENA_MEMORY_PREFIX}_*.md" \
      -type f \
      -mmin +60 \
      -delete 2>/dev/null || true
    log_debug "Expired cache cleanup completed"
  fi
}

# 키워드 추출 (간단한 패턴 매칭)
extract_keywords() {
  local message="$1"
  local keywords=""

  # 1. 기술 용어 추출 (|| true로 grep 실패 방지)
  local tech_keywords
  tech_keywords=$(echo "$message" | grep -oiE '(weekly-okr|캠페인|campaign|리팩토링|refactor|삭제|delete|이름변경|rename|컴포넌트|component|모듈|module|spark-note|team|admin)' 2>/dev/null || true)

  # 2. URL 패턴 추출 (/admin/teams, /spark-note 등)
  local url_keywords
  url_keywords=$(echo "$message" | grep -oE '/[a-z-]+(/[a-z-]+)*' 2>/dev/null | sed 's|^/||' || true)

  # 결과 병합 (중복 제거)
  keywords=$(echo -e "$tech_keywords\n$url_keywords" | grep -v '^$' | sort -u | head -5)

  log_debug "Extracted keywords: $keywords"
  echo "$keywords"
}

# Git 히스토리 검색 (Graceful - 에러 시 빈 결과)
search_git_refactorings() {
  local keyword="$1"
  local results=""

  # 키워드가 너무 짧으면 스킵 (노이즈 방지)
  if [[ ${#keyword} -lt 3 ]]; then
    return
  fi

  # 1. Commit 메시지 검색
  local exact_search
  exact_search=$(git log --all --grep="$keyword" --oneline -"$MAX_COMMITS" 2>/dev/null || true)

  if [[ -n "$exact_search" ]]; then
    results+="🔍 Keyword: '$keyword' (Commit Messages)\n"
    results+="$exact_search\n\n"
  fi

  # 2. 파일 이름 변경 감지 (--diff-filter=R)
  local rename_search
  rename_search=$(git log --all --diff-filter=R --name-status --oneline -"$MAX_COMMITS" 2>/dev/null | grep -i "$keyword" 2>/dev/null | head -5 || true)

  if [[ -n "$rename_search" ]]; then
    results+="🔍 Keyword: '$keyword' (File Renames)\n"
    results+="$rename_search\n\n"
  fi

  echo -e "$results"
}

# 캐시 체크
check_cache() {
  local cache_key="$1"
  local cache_file="$PROJECT_ROOT/.serena/memories/${SERENA_MEMORY_PREFIX}_${cache_key}.md"

  if [[ -f "$cache_file" ]]; then
    # macOS/Linux 호환 파일 수정 시간
    local file_age
    if [[ "$(uname)" == "Darwin" ]]; then
      file_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
    else
      file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    fi

    if [[ $file_age -lt $CACHE_TTL ]]; then
      log_debug "Cache hit: $cache_file (age: ${file_age}s)"
      cat "$cache_file"
      return 0
    else
      log_debug "Cache expired: $cache_file (age: ${file_age}s)"
    fi
  fi

  return 1
}

# 캐시 저장
save_cache() {
  local cache_key="$1"
  local content="$2"
  local cache_file="$PROJECT_ROOT/.serena/memories/${SERENA_MEMORY_PREFIX}_${cache_key}.md"

  mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true
  echo "$content" > "$cache_file" 2>/dev/null || true
  log_debug "Cache saved: $cache_file"
}

# ============================================================================
# Main Logic
# ============================================================================

# 0. 만료된 캐시 정리
cleanup_expired_cache

# 1. 키워드 추출
keywords=$(extract_keywords "$USER_INPUT")

if [[ -z "$keywords" ]]; then
  log_debug "No keywords found, exiting"
  exit 0
fi

# 2. 캐시 키 생성 (MD5 해시)
cache_key=$(echo "$keywords" | md5 2>/dev/null | cut -d' ' -f1 || echo "$keywords" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "nocache")
log_debug "Cache key: $cache_key"

# 3. 캐시 체크
if cached_result=$(check_cache "$cache_key" 2>/dev/null); then
  echo "$cached_result"
  log_debug "=== GIT CONTEXT HOOK END (cache hit) ==="
  exit 0
fi

# 4. Git 히스토리 검색 (각 키워드별)
all_findings=""
while IFS= read -r keyword; do
  if [[ -n "$keyword" ]]; then
    findings=$(search_git_refactorings "$keyword")
    all_findings+="$findings"
  fi
done <<< "$keywords"

# 5. 결과가 있으면 컨텍스트 주입
if [[ -n "$all_findings" ]]; then
  context_message=$(cat <<EOF
───────────────────────────────────────────────────────────────────────────
📚 GIT REFACTORING CONTEXT (Auto-Injected)

관련 리팩토링 히스토리가 발견되었습니다:

$all_findings
⚠️ 주의사항:
- 위 커밋에서 모듈/API 이름이 변경되었을 수 있습니다
- 현재 코드베이스의 실제 구현을 확인하세요
- 백엔드 @Controller() 데코레이터가 실제 API 엔드포인트입니다
───────────────────────────────────────────────────────────────────────────
EOF
)

  # 캐시 저장
  save_cache "$cache_key" "$context_message"

  # 컨텍스트 출력
  echo "$context_message"
  log_debug "Context injected (${#context_message} chars)"
else
  log_debug "No git findings for keywords"
fi

log_debug "=== GIT CONTEXT HOOK END ==="
exit 0
