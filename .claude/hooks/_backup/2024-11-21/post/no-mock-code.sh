#!/bin/bash
#
# No Mock Code Hook - Quality Enforcement
#
# Purpose: Mock/Dummy 코드 차단, ABSOLUTE RULES 강제 적용
# Trigger: Write, Edit, MultiEdit 도구 실행 후
# Effect: 불완전한 구현 100% 차단
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
#   0: Success (Mock 코드 없음, 계속 진행)
#   2: Block (Mock 코드 발견, 작업 차단)

set -euo pipefail

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
LOG_FILE="/tmp/claude-no-mock-code.log"

# 금지 패턴
FORBIDDEN_TODO_PATTERNS=(
  "TODO:"
  "FIXME:"
  "HACK:"
  "XXX:"
  "임시"
  "나중에"
  "추후"
  "TODO"
)

FORBIDDEN_MOCK_PATTERNS=(
  "mock.*data"
  "dummy.*data"
  "fake.*data"
  "stub.*implementation"
  "placeholder"
  "임시.*구현"
  "임시.*코드"
)

FORBIDDEN_INCOMPLETE_PATTERNS=(
  "simplified.*for now"
  "temporarily"
  "incomplete.*implementation"
  "not.*implemented"
  "will.*implement.*later"
  "미구현"
  "구현.*예정"
)

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
CONTENT=""

if command -v jq &> /dev/null; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null || echo "")
else
  log "jq not found - skipping check"
  exit 0
fi

log "Tool: $TOOL_NAME, File: $FILE_PATH, Content length: ${#CONTENT}"

# 대상 도구가 아니면 스킵
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "MultiEdit" ]]; then
  log "Not a Write/Edit tool - skipping"
  exit 0
fi

# 파일 경로나 내용이 없으면 스킵
if [[ -z "$FILE_PATH" ]] || [[ -z "$CONTENT" ]]; then
  log "No file path or content - skipping"
  exit 0
fi

# ============================================
# Exception Handling
# ============================================

is_test_file() {
  local file="$1"

  # 테스트 파일은 mock 허용
  if echo "$file" | grep -qE "\.(test|spec)\.(ts|tsx|js|jsx)$"; then
    return 0  # Is test file
  fi

  # __tests__, __mocks__ 디렉토리는 허용
  if echo "$file" | grep -qE "(__tests__|__mocks__|\.test/|\.spec/)"; then
    return 0  # Is test directory
  fi

  return 1  # Not a test file
}

is_mock_library_usage() {
  local content="$1"

  # 명시적인 Mock 라이브러리 사용은 허용
  if echo "$content" | grep -qE "(jest\.mock|vitest\.mock|sinon\.|nock\(|msw\.)"; then
    return 0  # Is legitimate mock library usage
  fi

  return 1  # Not mock library
}

# ============================================
# Pattern Detection
# ============================================

check_forbidden_patterns() {
  local file="$1"
  local content="$2"
  local violations=()

  log "Checking forbidden patterns in: $file"

  # 1. TODO/FIXME 패턴 체크
  for pattern in "${FORBIDDEN_TODO_PATTERNS[@]}"; do
    if echo "$content" | grep -iq "$pattern"; then
      local matches=$(echo "$content" | grep -in "$pattern" | head -3)
      violations+=("TODO/FIXME 패턴 발견: $pattern")
      violations+=("$matches")
      log "❌ TODO pattern found: $pattern"
    fi
  done

  # 2. Mock/Dummy 패턴 체크 (테스트 파일 제외)
  if ! is_test_file "$file" && ! is_mock_library_usage "$content"; then
    for pattern in "${FORBIDDEN_MOCK_PATTERNS[@]}"; do
      if echo "$content" | grep -iq "$pattern"; then
        local matches=$(echo "$content" | grep -in "$pattern" | head -3)
        violations+=("Mock/Dummy 코드 발견: $pattern")
        violations+=("$matches")
        log "❌ Mock pattern found: $pattern"
      fi
    done
  fi

  # 3. Incomplete 패턴 체크
  for pattern in "${FORBIDDEN_INCOMPLETE_PATTERNS[@]}"; do
    if echo "$content" | grep -iq "$pattern"; then
      local matches=$(echo "$content" | grep -in "$pattern" | head -3)
      violations+=("불완전한 구현 발견: $pattern")
      violations+=("$matches")
      log "❌ Incomplete pattern found: $pattern"
    fi
  done

  # 4. 주석으로 "나중에 구현" 패턴 체크
  if echo "$content" | grep -iqE "(//|#|/\*).*구현.*나중|later.*implement|will.*add"; then
    local matches=$(echo "$content" | grep -inE "(//|#|/\*).*구현.*나중|later.*implement|will.*add" | head -3)
    violations+=("'나중에 구현' 주석 발견")
    violations+=("$matches")
    log "❌ 'Later implementation' comment found"
  fi

  # 위반 사항 리턴
  if [[ ${#violations[@]} -gt 0 ]]; then
    printf '%s\n' "${violations[@]}"
    return 1  # Violations found
  fi

  return 0  # No violations
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== No Mock Code Hook Started ==="
  log "Checking file: $FILE_PATH"

  # 테스트 파일 예외 처리 (Warning만)
  if is_test_file "$FILE_PATH"; then
    log "✅ Test file detected - allowing mock usage"
    exit 0
  fi

  # 패턴 체크
  violations_output=$(check_forbidden_patterns "$FILE_PATH" "$CONTENT" 2>&1) || has_violations=1

  if [[ ${has_violations:-0} -eq 1 ]]; then
    log "❌ Forbidden patterns found"

    # 사용자에게 상세 리포트
    echo "═══════════════════════════════════════" >&2
    echo "❌ Mock/Dummy 코드 감지: 작업이 차단되었습니다" >&2
    echo "═══════════════════════════════════════" >&2
    echo "" >&2
    echo "파일: $FILE_PATH" >&2
    echo "" >&2
    echo "발견된 위반 사항:" >&2
    echo "$violations_output" | sed 's/^/  /' >&2
    echo "" >&2
    echo "⚠️ ABSOLUTE RULES 위반:" >&2
    echo "  - NO PARTIAL IMPLEMENTATION" >&2
    echo "  - NO SIMPLIFICATION" >&2
    echo "  - NO MOCK/DUMMY CODE" >&2
    echo "" >&2
    echo "💡 해결 방법:" >&2
    echo "  1. TODO/FIXME 주석 제거 및 즉시 구현" >&2
    echo "  2. Mock/Dummy 데이터 → 실제 구현으로 교체" >&2
    echo "  3. '나중에', '임시' 주석 삭제" >&2
    echo "  4. 완전한 동작하는 코드만 작성" >&2
    echo "" >&2
    echo "ℹ️ 예외:" >&2
    echo "  - 테스트 파일 (*.test.*, *.spec.*)은 mock 허용" >&2
    echo "  - jest.mock(), vitest.mock() 등 명시적 Mock 라이브러리는 허용" >&2
    echo "═══════════════════════════════════════" >&2

    exit 2  # Block
  fi

  log "✅ No forbidden patterns found"
  exit 0  # Success
}

# Graceful error handling (기본값: Success)
trap 'log "Error occurred, allowing continuation"; exit 0' ERR

main
