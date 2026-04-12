#!/bin/bash
set -e

# PostToolUse Hook: Tech Spec Read Tracker
# Read 도구로 tech-spec 파일 읽으면 → session state 업데이트

# Read tool information from stdin
tool_info=$(cat)

# Extract relevant data
tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty')
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty')
session_id=$(echo "$tool_info" | jq -r '.session_id // empty')

# Skip if not Read tool
if [[ "$tool_name" != "Read" ]] || [[ -z "$file_path" ]]; then
    exit 0
fi

# Project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SESSION_STATE_DIR="$PROJECT_ROOT/.claude/hooks/state"
SESSION_STATE_FILE="$SESSION_STATE_DIR/tech-spec-used-${session_id}.json"

# Log file
LOG_FILE="$PROJECT_ROOT/.claude/hooks/tech-spec-guard.log"

log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE"
}

# Check if file is a Tech Spec: docs/epics/**/tech-specs/*.md
if [[ "$file_path" =~ docs/epics/.*/tech-specs/.*\.md ]]; then
    log "Tech Spec READ detected: $file_path"

    # Update session state: mark as verified
    mkdir -p "$SESSION_STATE_DIR"
    echo '{"tech_spec_verified": true, "last_read": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'", "file": "'"$file_path"'"}' > "$SESSION_STATE_FILE"

    log "✅ Session $session_id: Tech Spec verified"
fi

# Exit cleanly
exit 0
