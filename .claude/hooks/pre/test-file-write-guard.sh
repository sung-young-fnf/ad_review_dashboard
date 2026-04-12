#!/bin/bash
#
# PreToolUse Hook - Test File Write Guard
#
# Purpose: Agent가 테스트 파일을 Write/Edit할 때 사용자 확인을 강제
# Trigger: PreToolUse (Write, Edit)
# Output: {"decision": "ask"} 또는 빈 출력 (pass-through)
#

set +e

LOG_FILE="/tmp/claude-test-guard.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Read input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Only process Write and Edit tools
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Skip if no file_path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Skip node_modules (vendor files are not our tests)
if [[ "$FILE_PATH" == *"/node_modules/"* ]]; then
  log "SKIP (node_modules): $FILE_PATH"
  exit 0
fi

# Extract basename for pattern matching
BASENAME=$(basename "$FILE_PATH")

# Test file patterns (basename-based matching)
is_test_file() {
  local name="$1"
  case "$name" in
    *.spec.ts)  return 0 ;;
    *.test.ts)  return 0 ;;
    *.spec.tsx) return 0 ;;
    *.test.tsx) return 0 ;;
    test_*.py)  return 0 ;;
    *.spec.py)  return 0 ;;
    *_test.py)  return 0 ;;
  esac
  return 1
}

# Check if file matches test patterns
if is_test_file "$BASENAME"; then
  log "TEST-GUARD ASK: tool=$TOOL_NAME file=$FILE_PATH"
  echo "test file detected: $BASENAME" >&2
  echo "  -> approve test file creation/modification?" >&2
  echo '{"decision": "ask"}'
  exit 0
fi

# Not a test file - pass through to other hooks
log "PASS: tool=$TOOL_NAME file=$FILE_PATH"
