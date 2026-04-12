#!/bin/bash

################################################################################
# WebSearch Year Injector Hook
#
# Purpose: Automatically adds current year to WebSearch queries when no year
#          is specified, ensuring search results are current and relevant.
#
# Logic:
#   1. Parse WebSearch query from tool_input
#   2. Check if query already contains year (20XX pattern)
#   3. Check if query has temporal keywords (latest, recent, etc.)
#   4. If neither, append current year to query
#
# Follows: HOOK_DEVELOPMENT_GUIDE.md (Bash only, Graceful Degradation)
################################################################################

set -euo pipefail

# Read stdin
INPUT=$(cat)
INPUT_LENGTH=${#INPUT}

# Logging function (to stderr)
log() {
    echo "[WebSearch Year Injector] $*" >&2
}

# Empty input handling (mandatory per HOOK_DEVELOPMENT_GUIDE.md)
if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse"}}'
    exit 0
fi

# Parse query with jq (graceful degradation)
QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null)
if [[ -z "$QUERY" ]]; then
    log "Skipped: no query found in tool_input"
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse"}}'
    exit 0
fi

log "Original query: '$QUERY'"

# Get current year
CURRENT_YEAR=$(date +%Y)

# Check if query already has year (20XX pattern)
if echo "$QUERY" | grep -qE '\b20[0-9]{2}\b'; then
    log "Skipped: query already contains year"
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse"}}'
    exit 0
fi

# Check for temporal keywords (case-insensitive)
TEMPORAL_KEYWORDS="latest|recent|current|new|now|today"
if echo "$QUERY" | grep -qiE "$TEMPORAL_KEYWORDS"; then
    log "Skipped: query has temporal keyword"
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse"}}'
    exit 0
fi

# Add year to query
MODIFIED_QUERY="$QUERY $CURRENT_YEAR"
log "Modified query: '$MODIFIED_QUERY'"

# Output JSON with jq
jq -n \
  --arg query "$MODIFIED_QUERY" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      modifiedToolInput: {
        query: $query
      }
    }
  }'

log "Successfully injected year: $CURRENT_YEAR"
exit 0
