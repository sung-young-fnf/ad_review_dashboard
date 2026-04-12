#!/bin/bash
set -e

# PostToolUse Hook: Task 파일 편집 감지 → PROJECT_STATE.json 자동 업데이트
# Showcase 패턴 기반: post-tool-use-tracker.sh 참조

# Read tool information from stdin
tool_info=$(cat)

# Extract relevant data
tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty')
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty')
session_id=$(echo "$tool_info" | jq -r '.session_id // empty')

# Skip if not an edit tool or no file path
if [[ ! "$tool_name" =~ ^(Edit|MultiEdit|Write)$ ]] || [[ -z "$file_path" ]]; then
    exit 0
fi

# Project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_ROOT/docs/.state/PROJECT_STATE.json"
PROGRESS_SCRIPT="$PROJECT_ROOT/.claude/scripts/generate-progress.sh"

# Log file
LOG_FILE="$PROJECT_ROOT/.claude/hooks/task-sync.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE"
}

# Function: Extract Epic ID from file path
extract_epic_id() {
    local path="$1"
    # docs/epics/EP001/tasks/T001.md → EP001
    echo "$path" | sed -E 's|.*epics/([^/]+)/.*|\1|'
}

# Function: Extract Task ID from file path
extract_task_id() {
    local path="$1"
    # docs/epics/EP001/tasks/T001.md → T001
    basename "$path" .md
}

# Function: Count checkboxes in Task file
count_checkboxes() {
    local file="$1"
    local total=0
    local checked=0

    if [[ -f "$file" ]]; then
        total=$(grep -cE '^\s*-\s+\[[ x]\]' "$file" 2>/dev/null || echo 0)
        checked=$(grep -cE '^\s*-\s+\[x\]' "$file" 2>/dev/null || echo 0)
    fi

    echo "$checked $total"
}

# Check if file matches Task pattern: docs/epics/**/tasks/*.md
if [[ "$file_path" =~ docs/epics/.*/tasks/.*\.md ]]; then
    log "Task file edited: $file_path"

    # Extract IDs
    epic_id=$(extract_epic_id "$file_path")
    task_id=$(extract_task_id "$file_path")

    if [[ -z "$epic_id" ]] || [[ -z "$task_id" ]]; then
        log "ERROR: Failed to extract Epic/Task ID from $file_path"
        exit 0
    fi

    # Count checkboxes
    read -r checked total <<< "$(count_checkboxes "$file_path")"

    log "Epic: $epic_id, Task: $task_id, Progress: $checked/$total"

    # Update PROJECT_STATE.json
    if [[ -f "$STATE_FILE" ]]; then
        # Backup
        cp "$STATE_FILE" "${STATE_FILE}.backup"

        # Update task progress
        jq --arg epic "$epic_id" \
           --arg task "$task_id" \
           --argjson checked "$checked" \
           --argjson total "$total" \
           --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '
           if .epics[$epic].tasks[$task] then
               .epics[$epic].tasks[$task].checkedItems = $checked |
               .epics[$epic].tasks[$task].totalItems = $total |
               .epics[$epic].lastUpdated = $timestamp
           else
               .
           end
           ' "$STATE_FILE" > "${STATE_FILE}.tmp"

        if [[ $? -eq 0 ]]; then
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            log "✅ STATE updated: $epic_id/$task_id ($checked/$total)"

            # Regenerate PROGRESS.md
            if [[ -x "$PROGRESS_SCRIPT" ]]; then
                "$PROGRESS_SCRIPT" >> "$LOG_FILE" 2>&1
                log "✅ PROGRESS.md regenerated"
            fi
        else
            log "ERROR: Failed to update STATE"
            mv "${STATE_FILE}.backup" "$STATE_FILE"
        fi
    else
        log "WARNING: STATE file not found: $STATE_FILE"
    fi
fi

# Check if file matches Story pattern: docs/epics/**/stories/*.md
if [[ "$file_path" =~ docs/epics/.*/stories/.*\.md ]]; then
    log "Story file edited: $file_path"

    epic_id=$(extract_epic_id "$file_path")
    story_id=$(extract_task_id "$file_path")  # Same logic

    # Update lastUpdated for Epic
    if [[ -f "$STATE_FILE" ]] && [[ -n "$epic_id" ]]; then
        jq --arg epic "$epic_id" \
           --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '
           if .epics[$epic] then
               .epics[$epic].lastUpdated = $timestamp
           else
               .
           end
           ' "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        log "✅ Epic lastUpdated: $epic_id"

        # Regenerate PROGRESS.md
        if [[ -x "$PROGRESS_SCRIPT" ]]; then
            "$PROGRESS_SCRIPT" >> "$LOG_FILE" 2>&1
        fi
    fi
fi

# Exit cleanly
exit 0
