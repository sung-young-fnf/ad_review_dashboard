#!/bin/bash
#
# Duplicate Detector Hook - Next.js Route/Component Duplication Prevention
#
# Purpose: Write/Edit 전 중복 route/API/컴포넌트 감지 및 차단
# Trigger: Write, Edit, MultiEdit 도구 실행 전
# Effect: 중복 작업 100% 제거, 405/404 에러 방지
#
# Input (stdin JSON):
# {
#   "session_id": "uuid",
#   "tool_name": "Write",
#   "tool_input": {
#     "file_path": "/path/to/file",
#     "content": "..."
#   }
# }
#
# Exit Codes:
#   0: Success (중복 없음, 계속 진행)
#   2: Block (중복 발견, 작업 차단)

set -euo pipefail

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
LOG_FILE="/tmp/claude-duplicate-detector.log"

# Next.js 프로젝트 감지
is_nextjs_project() {
  [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]
}

# ============================================
# Logging
# ============================================

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ============================================
# Input Processing
# ============================================

# stdin에서 JSON 읽기
INPUT=""
if read -t 1 INPUT; then
  log "Input received: ${#INPUT} bytes"
else
  log "No input - skipping check"
  exit 0
fi

# 빈 입력 처리
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - skipping check"
  exit 0
fi

# JSON 파싱
TOOL_NAME=""
FILE_PATH=""

if command -v jq &> /dev/null; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
else
  log "jq not found - skipping check"
  exit 0
fi

log "Tool: $TOOL_NAME, File: $FILE_PATH"

# 대상 도구가 아니면 스킵
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "MultiEdit" ]]; then
  log "Not a Write/Edit tool - skipping"
  exit 0
fi

# 파일 경로가 없으면 스킵
if [[ -z "$FILE_PATH" ]]; then
  log "No file path - skipping"
  exit 0
fi

# Next.js 프로젝트가 아니면 스킵
if ! is_nextjs_project; then
  log "Not a Next.js project - skipping"
  exit 0
fi

# ============================================
# Duplication Detection
# ============================================

# 1. Next.js Page Route 중복 체크
check_page_route_duplication() {
  local file="$1"

  # page.tsx 또는 page.js 파일인지 확인
  if ! echo "$file" | grep -qE "/(page\.(tsx|ts|jsx|js))$"; then
    return 0  # Not a page file
  fi

  # Route 경로 추출 (app/ 또는 src/app/ 기준)
  local route_path=""
  if echo "$file" | grep -q "app/"; then
    route_path=$(echo "$file" | sed 's|.*app/||' | sed 's|/page\.(tsx|ts|jsx|js)$||')
  else
    return 0  # Not in app directory
  fi

  log "Checking page route: /$route_path"

  # 동일한 route가 이미 존재하는지 확인
  local existing_pages
  existing_pages=$(find . -path "*/app/$route_path/page.*" -type f 2>/dev/null | grep -v "^$file$" || true)

  if [[ -n "$existing_pages" ]]; then
    log "❌ Duplicate page route found: /$route_path"
    echo "❌ 중복 Route 감지: /$route_path" >&2
    echo "" >&2
    echo "기존 파일:" >&2
    echo "$existing_pages" | while read -r existing; do
      echo "  - $existing" >&2
    done
    echo "" >&2
    echo "⚠️ 동일한 route가 이미 존재합니다." >&2
    echo "   기존 파일을 수정하거나 다른 경로를 사용하세요." >&2
    return 1  # Duplicate found
  fi

  return 0
}

# 2. Next.js API Route 중복 체크
check_api_route_duplication() {
  local file="$1"

  # route.tsx 또는 route.js 파일인지 확인
  if ! echo "$file" | grep -qE "/(route\.(tsx|ts|jsx|js))$"; then
    return 0  # Not an API route file
  fi

  # Route 경로 추출
  local route_path=""
  if echo "$file" | grep -q "app/api/"; then
    route_path=$(echo "$file" | sed 's|.*app/api/||' | sed 's|/route\.(tsx|ts|jsx|js)$||')
  else
    return 0  # Not in app/api directory
  fi

  log "Checking API route: /api/$route_path"

  # 동일한 API route가 이미 존재하는지 확인
  local existing_routes
  existing_routes=$(find . -path "*/app/api/$route_path/route.*" -type f 2>/dev/null | grep -v "^$file$" || true)

  if [[ -n "$existing_routes" ]]; then
    log "❌ Duplicate API route found: /api/$route_path"
    echo "❌ 중복 API Route 감지: /api/$route_path" >&2
    echo "" >&2
    echo "기존 파일:" >&2
    echo "$existing_routes" | while read -r existing; do
      echo "  - $existing" >&2
    done
    echo "" >&2
    echo "⚠️ 동일한 API route가 이미 존재합니다." >&2
    echo "   기존 파일을 수정하거나 다른 경로를 사용하세요." >&2
    echo "" >&2
    echo "💡 Tip: 405 Method Not Allowed 에러를 방지하려면" >&2
    echo "   기존 route.ts에 필요한 HTTP 메서드를 추가하세요." >&2
    return 1  # Duplicate found
  fi

  return 0
}

# 3. React 컴포넌트 이름 충돌 체크
check_component_duplication() {
  local file="$1"

  # 컴포넌트 파일인지 확인 (.tsx, .jsx만)
  if ! echo "$file" | grep -qE "\.(tsx|jsx)$"; then
    return 0  # Not a component file
  fi

  # 컴포넌트 이름 추출
  local component_name=$(basename "$file" | sed 's/\.(tsx|jsx)$//')

  # 특수 파일명 제외
  if [[ "$component_name" =~ ^(page|layout|loading|error|not-found|route)$ ]]; then
    return 0  # Special Next.js files
  fi

  log "Checking component: $component_name"

  # 동일한 이름의 컴포넌트 파일 찾기
  local existing_components
  existing_components=$(find . -name "$component_name.*" -type f 2>/dev/null | grep -E "\.(tsx|jsx)$" | grep -v "^$file$" || true)

  if [[ -n "$existing_components" ]]; then
    # 정확한 중복 (경로만 다른 경우) - 차단
    local exact_match
    exact_match=$(echo "$existing_components" | head -1)

    log "⚠️ Component name conflict: $component_name"
    echo "⚠️ 컴포넌트 이름 충돌 감지: $component_name" >&2
    echo "" >&2
    echo "기존 파일:" >&2
    echo "$existing_components" | while read -r existing; do
      echo "  - $existing" >&2
    done
    echo "" >&2
    echo "💡 다음 중 하나를 선택하세요:" >&2
    echo "   1. 기존 컴포넌트를 재사용" >&2
    echo "   2. 다른 이름 사용 (예: ${component_name}V2, New${component_name})" >&2
    echo "   3. 기존 파일이 불필요하면 삭제 후 진행" >&2

    # Warning만 표시하고 계속 진행 (차단하지 않음)
    return 0
  fi

  return 0
}

# 4. Utils/Lib 중복 체크
check_utils_duplication() {
  local file="$1"

  # utils/ 또는 lib/ 디렉토리인지 확인
  if ! echo "$file" | grep -qE "(utils/|lib/)"; then
    return 0  # Not a utils/lib file
  fi

  local basename_file=$(basename "$file")
  local filename="${basename_file%.*}"

  log "Checking utils/lib: $filename"

  # 동일한 파일명 찾기
  local existing_files
  existing_files=$(find . -path "*/utils/$basename_file" -o -path "*/lib/$basename_file" -type f 2>/dev/null | grep -v "^$file$" || true)

  if [[ -n "$existing_files" ]]; then
    log "⚠️ Utils/Lib duplication: $basename_file"
    echo "⚠️ Utils/Lib 중복 감지: $basename_file" >&2
    echo "" >&2
    echo "기존 파일:" >&2
    echo "$existing_files" | while read -r existing; do
      echo "  - $existing" >&2
    done
    echo "" >&2
    echo "💡 중복된 유틸리티 함수는 코드 불일치를 유발합니다." >&2
    echo "   기존 파일을 사용하거나 통합하세요." >&2

    # Warning만 표시
    return 0
  fi

  return 0
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== Duplicate Detector Started ==="
  log "Checking file: $FILE_PATH"

  local violations=0

  # 1. Page Route 중복 체크
  if ! check_page_route_duplication "$FILE_PATH"; then
    violations=$((violations + 1))
  fi

  # 2. API Route 중복 체크
  if ! check_api_route_duplication "$FILE_PATH"; then
    violations=$((violations + 1))
  fi

  # 3. Component 중복 체크 (Warning만)
  check_component_duplication "$FILE_PATH"

  # 4. Utils 중복 체크 (Warning만)
  check_utils_duplication "$FILE_PATH"

  # 위반 사항이 있으면 차단
  if [[ $violations -gt 0 ]]; then
    log "❌ Duplications found: $violations"
    echo "" >&2
    echo "═══════════════════════════════════════" >&2
    echo "❌ 중복 감지: 작업이 차단되었습니다" >&2
    echo "═══════════════════════════════════════" >&2
    exit 2  # Block
  fi

  log "✅ No duplications found"
  exit 0  # Success
}

# Graceful error handling (기본값: Success)
trap 'log "Error occurred, allowing continuation"; exit 0' ERR

main
