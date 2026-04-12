#!/bin/bash
# =============================================================================
# duplicate-detector.sh - Next.js Route/Component Duplication Prevention
# =============================================================================
#
# Zero-Token Version: stdout 최소화, .dirty-files + 로그 파일 활용
# 토큰 소비: ~50 (기존 ~1200 토큰) - 차단 메시지만 출력
#
# Exit Codes:
#   0: Success (중복 없음, 계속 진행)
#   2: Block (심각한 중복 발견, 작업 차단)
#
# =============================================================================

set +e

# Configuration
PROJECT_ROOT="$(pwd)"
LOG_FILE="/tmp/claude-duplicate-detector.log"

# Zero-Token: mark-dirty.sh 로드
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MARK_DIRTY_SCRIPT="$REPO_ROOT/.claude/utils/mark-dirty.sh"
if [[ -f "$MARK_DIRTY_SCRIPT" ]]; then
    source "$MARK_DIRTY_SCRIPT"
else
    mark_dirty_file() {
        local file="$1"
        local check_type="${2:-duplicate}"
        local check_status="${3:-OK}"
        echo "${check_status}:${check_type}:${file}" >> "$REPO_ROOT/.claude/.dirty-files"
    }
fi

# Next.js 프로젝트 감지
is_nextjs_project() {
    [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]
}

# 로깅 (파일에만 기록)
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# stdin에서 JSON 읽기
INPUT=""
if read -t 1 INPUT; then
    log "Input received: ${#INPUT} bytes"
else
    log "No input - skipping check"
    exit 0
fi

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

# 대상 도구/파일/프로젝트 필터링
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "MultiEdit" ]]; then
    log "Not a Write/Edit tool - skipping"
    exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
    log "No file path - skipping"
    exit 0
fi

if ! is_nextjs_project; then
    log "Not a Next.js project - skipping"
    exit 0
fi

# =============================================================================
# Duplication Detection (Zero-Token: 로그만, stdout 없음)
# =============================================================================

# 1. Page Route 중복 체크
check_page_route_duplication() {
    local file="$1"

    if ! echo "$file" | grep -qE "/(page\.(tsx|ts|jsx|js))$"; then
        return 0
    fi

    local route_path=""
    if echo "$file" | grep -q "app/"; then
        route_path=$(echo "$file" | sed 's|.*app/||' | sed 's|/page\.(tsx|ts|jsx|js)$||')
    else
        return 0
    fi

    log "Checking page route: /$route_path"

    local existing_pages
    existing_pages=$(find . -path "*/app/$route_path/page.*" -type f 2>/dev/null | grep -v "^$file$" || true)

    if [[ -n "$existing_pages" ]]; then
        log "❌ Duplicate page route found: /$route_path"
        # Zero-Token: .dirty-files에 기록
        mark_dirty_file "$file" "duplicate-page" "ERROR"
        mark_dirty_file "$existing_pages" "existing-page" "ERROR"
        return 1
    fi

    return 0
}

# 2. API Route 중복 체크
check_api_route_duplication() {
    local file="$1"

    if ! echo "$file" | grep -qE "/(route\.(tsx|ts|jsx|js))$"; then
        return 0
    fi

    local route_path=""
    if echo "$file" | grep -q "app/api/"; then
        route_path=$(echo "$file" | sed 's|.*app/api/||' | sed 's|/route\.(tsx|ts|jsx|js)$||')
    else
        return 0
    fi

    log "Checking API route: /api/$route_path"

    local existing_routes
    existing_routes=$(find . -path "*/app/api/$route_path/route.*" -type f 2>/dev/null | grep -v "^$file$" || true)

    if [[ -n "$existing_routes" ]]; then
        log "❌ Duplicate API route found: /api/$route_path"
        mark_dirty_file "$file" "duplicate-api" "ERROR"
        mark_dirty_file "$existing_routes" "existing-api" "ERROR"
        return 1
    fi

    return 0
}

# 3. Component 이름 충돌 (Warning만, .dirty-files 기록)
check_component_duplication() {
    local file="$1"

    if ! echo "$file" | grep -qE "\.(tsx|jsx)$"; then
        return 0
    fi

    local component_name=$(basename "$file" | sed 's/\.(tsx|jsx)$//')

    if [[ "$component_name" =~ ^(page|layout|loading|error|not-found|route)$ ]]; then
        return 0
    fi

    log "Checking component: $component_name"

    local existing_components
    existing_components=$(find . -name "$component_name.*" -type f 2>/dev/null | grep -E "\.(tsx|jsx)$" | grep -v "^$file$" || true)

    if [[ -n "$existing_components" ]]; then
        log "⚠️ Component name conflict: $component_name"
        # Zero-Token: Warning으로 기록 (차단 안 함)
        mark_dirty_file "$file" "component-conflict" "WARN"
    fi

    return 0
}

# 4. Utils/Lib 중복 (Warning만)
check_utils_duplication() {
    local file="$1"

    if ! echo "$file" | grep -qE "(utils/|lib/)"; then
        return 0
    fi

    local basename_file=$(basename "$file")

    log "Checking utils/lib: $basename_file"

    local existing_files
    existing_files=$(find . -path "*/utils/$basename_file" -o -path "*/lib/$basename_file" -type f 2>/dev/null | grep -v "^$file$" || true)

    if [[ -n "$existing_files" ]]; then
        log "⚠️ Utils/Lib duplication: $basename_file"
        mark_dirty_file "$file" "utils-conflict" "WARN"
    fi

    return 0
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log "=== Duplicate Detector Started (Zero-Token) ==="
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

    # 심각한 위반 시에만 차단 (최소 출력)
    if [[ $violations -gt 0 ]]; then
        log "❌ Duplications found: $violations"
        # Zero-Token: 차단 메시지만 최소 출력
        echo "❌ 중복 감지: 로그 확인 → $LOG_FILE" >&2
        exit 2
    fi

    # Zero-Token: 성공 시 기록만 (stdout 없음)
    mark_dirty_file "$FILE_PATH" "duplicate-check" "OK"
    log "✅ No duplications found"
    exit 0
}

trap 'log "Error occurred, allowing continuation"; exit 0' ERR

main
