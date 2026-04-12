#!/bin/bash
#
# Secret Scanner Hook - Security Guardian
#
# Purpose: 소스 코드 내 하드코딩된 시크릿 감지 및 차단
# Trigger: PreToolUse (Write|Edit|MultiEdit, Bash)
# Effect: API 키, 비밀번호 등 실수 커밋 방지
#
# Input (stdin JSON):
# {
#   "tool_name": "Write" | "Edit" | "MultiEdit" | "Bash",
#   "tool_input": {
#     "file_path": "/path/to/file.ts",
#     "content": "...",
#     "command": "git commit ..."
#   }
# }
#
# Exit Codes:
#   0: Safe (통과)
#   2: Secret detected (차단)

# set -eo pipefail (disabled for Graceful Degradation)
set +e

# ============================================
# Configuration
# ============================================

LOG_FILE="/tmp/claude-secret-scanner.log"

# 검사 대상 확장자
SCAN_EXTENSIONS=(
  "ts" "tsx" "js" "jsx"
  "py" "java" "go" "rs"
  "yaml" "yml" "json"
)

# 제외 파일 패턴 (정상적인 시크릿 저장소)
EXCLUDE_PATTERNS=(
  ".env"
  ".env.local"
  ".env.production"
  ".env.development"
  ".env.test"
  "*.key"
  "*.pem"
  "*.cert"
  "*.crt"
  ".gitignore"
  ".npmrc"
  "package-lock.json"
  "pnpm-lock.yaml"
)

# 시크릿 검출 정규식
SECRET_PATTERNS=(
  'sk_test_[A-Za-z0-9]{24,}'                      # Stripe test key
  'sk_live_[A-Za-z0-9]{24,}'                      # Stripe live key
  'AIza[0-9A-Za-z\-_]{35}'                        # Google API key
  'AKIA[0-9A-Z]{16}'                              # AWS access key
  'ghp_[0-9a-zA-Z]{36}'                           # GitHub token
  'github_pat_[0-9a-zA-Z]{22}_[0-9a-zA-Z]{59}'   # GitHub PAT
  'eyJ[A-Za-z0-9\-_=]+\.eyJ[A-Za-z0-9\-_=]+\.'   # JWT token
  'password\s*[:=]\s*["'"'"'][^"'"'"']{8,}["'"'"']'  # Generic password
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

# stdin에서 JSON 읽기 (타임아웃 1초)
INPUT=""
if read -t 1 INPUT; then
  log "Input received: ${#INPUT} bytes"
else
  log "No input - skipping scan"
  exit 0
fi

# 빈 입력 처리 (Graceful Degradation)
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - skipping scan"
  exit 0
fi

# JSON 파싱 (jq 실패 시 조용히 종료)
TOOL_NAME=""
FILE_PATH=""
CONTENT=""

if ! command -v jq &> /dev/null; then
  log "jq not found - skipping scan"
  exit 0
fi

# JSON 파싱
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null) || TOOL_NAME="unknown"
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path' 2>/dev/null) || FILE_PATH=""
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content' 2>/dev/null) || CONTENT=""

# Edit의 경우 new_string도 확인
if [[ -z "$CONTENT" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string' 2>/dev/null) || CONTENT=""
fi

# Bash의 경우 (git commit)
if [[ -z "$FILE_PATH" ]] && [[ "$TOOL_NAME" == "Bash" ]]; then
  BASH_COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command' 2>/dev/null) || BASH_COMMAND=""
  log "Bash command detected: ${BASH_COMMAND:0:50}..."

  # git commit 명령이 아니면 skip
  if [[ "$BASH_COMMAND" != *"git commit"* ]] && [[ "$BASH_COMMAND" != *"git add"* ]]; then
    log "Not a git command - skipping"
    exit 0
  fi

  # staged files 검사 (파일 변경은 Write/Edit에서 이미 검사됨)
  log "Git command - skipping (already checked during Write/Edit)"
  exit 0
fi

log "Secret scan: tool=$TOOL_NAME, file=$FILE_PATH, content_size=${#CONTENT}"

# ============================================
# File Validation
# ============================================

should_scan_file() {
  local file="$1"

  # 파일 경로가 없으면 skip
  [[ -z "$file" ]] && return 1

  # 제외 패턴 확인
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      log "Skipped: matches exclude pattern '$pattern'"
      return 1
    fi
  done

  # 확장자 확인
  local ext="${file##*.}"
  for scan_ext in "${SCAN_EXTENSIONS[@]}"; do
    if [[ "$ext" == "$scan_ext" ]]; then
      return 0
    fi
  done

  log "Skipped: extension '.$ext' not in scan list"
  return 1
}

# ============================================
# Secret Detection
# ============================================

scan_for_secrets() {
  local content="$1"
  local file_path="$2"

  # 내용이 비어있으면 안전
  [[ -z "$content" ]] && return 0

  local found_secrets=()

  # 각 패턴으로 검사
  for pattern in "${SECRET_PATTERNS[@]}"; do
    # 패턴 매칭 (라인 번호 포함)
    local matches=$(echo "$content" | grep -nE "$pattern" 2>/dev/null || true)

    if [[ -n "$matches" ]]; then
      log "Secret pattern matched: $pattern"

      # 첫 번째 매칭만 저장 (너무 많으면 출력 제한)
      local first_match=$(echo "$matches" | head -1)
      local line_num=$(echo "$first_match" | cut -d: -f1)
      local line_content=$(echo "$first_match" | cut -d: -f2-)

      found_secrets+=("Line $line_num: ${line_content:0:80}...")
    fi
  done

  # Secret 발견 시 차단
  if [[ ${#found_secrets[@]} -gt 0 ]]; then
    echo "" >&2
    echo "🚨 SECRET DETECTED - Commit Blocked!" >&2
    echo "═══════════════════════════════════════" >&2
    echo "" >&2
    echo "File: $file_path" >&2
    echo "" >&2
    echo "Found secrets:" >&2
    for secret in "${found_secrets[@]}"; do
      echo "  ❌ $secret" >&2
    done
    echo "" >&2
    echo "💡 Use environment variables instead:" >&2
    echo "   const KEY = process.env.API_KEY;" >&2
    echo "   Add to .env: API_KEY=your_key_here" >&2
    echo "" >&2
    echo "═══════════════════════════════════════" >&2

    log "Secret detected - blocking operation"
    exit 2  # 차단
  fi

  return 0  # 안전
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== Secret Scanner Started ==="

  # 파일 검사 대상 확인
  if ! should_scan_file "$FILE_PATH"; then
    log "File skipped: $FILE_PATH"
    exit 0  # Skip (안전)
  fi

  # Secret 검사
  scan_for_secrets "$CONTENT" "$FILE_PATH"

  log "=== Secret Scanner Completed (Safe) ==="
  exit 0
}

# Graceful error handling
trap 'log "Error occurred, but continuing (Graceful Degradation)"; exit 0' ERR

main
