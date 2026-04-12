#!/bin/bash
set -e

# Stop Event Hook: Epic Lifecycle Manager Auto-Execution
# Showcase 패턴: stop-build-check-enhanced.sh 참조
# 세션 종료 시 Epic/Task 편집 감지 → lifecycle-manager.sh 조건부 실행

# Read event information from stdin
event_info=$(cat)

# Extract session ID
session_id=$(echo "$event_info" | jq -r '.session_id // empty')

# Project root (with fallback)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_DIR="$PROJECT_ROOT/.claude/agent-cache/${session_id}"
LIFECYCLE_SCRIPT="$PROJECT_ROOT/.claude/scripts/lifecycle-manager.sh"

# Log file
LOG_FILE="$PROJECT_ROOT/.claude/hooks/epic-lifecycle-stop.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE"
}

log "Stop Event triggered for session: $session_id"

# Check if Epic/Task files were edited (PostToolUse cache)
# task-sync.sh가 기록한 로그 확인
task_sync_log="$PROJECT_ROOT/.claude/hooks/task-sync.log"

if [[ ! -f "$task_sync_log" ]]; then
    log "No task sync log found. Skipping lifecycle check."
    exit 0
fi

# 이번 세션에서 Epic/Task 편집 여부 확인 (최근 30분 이내)
thirty_minutes_ago=$(date -u -v-30M +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -u -d "30 minutes ago" +"%Y-%m-%d %H:%M:%S")

recent_edits=$(grep -E "Task file edited:|Story file edited:" "$task_sync_log" 2>/dev/null | \
               awk -v cutoff="$thirty_minutes_ago" '$0 >= "["cutoff {print}' | wc -l | tr -d ' ')

if [[ "$recent_edits" -eq 0 ]]; then
    log "No recent Epic/Task edits. Skipping lifecycle check."
    exit 0
fi

log "Detected $recent_edits Epic/Task edits in this session. Running lifecycle manager..."

# Run lifecycle-manager.sh
if [[ -x "$LIFECYCLE_SCRIPT" ]]; then
    lifecycle_output=$("$LIFECYCLE_SCRIPT" 2>&1)
    lifecycle_exit_code=$?

    log "Lifecycle manager exit code: $lifecycle_exit_code"
    log "Output: $lifecycle_output"

    # Parse lifecycle results
    archived_count=$(echo "$lifecycle_output" | grep -c "Archiving directory:" 2>/dev/null | tail -1 || echo 0)
    stale_count=$(echo "$lifecycle_output" | grep -c "Stale Epic detected:" 2>/dev/null | tail -1 || echo 0)
    orphaned_count=$(echo "$lifecycle_output" | grep -c "Cleaning orphaned tasks:" 2>/dev/null | tail -1 || echo 0)

    # Output to stdout (visible to user)
    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Epic Lifecycle Check Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Checked: $recent_edits Epic/Task edits
Archived: $archived_count Epics
Stale: $stale_count Epics
Orphaned: $orphaned_count Task directories

EOF

    if [[ $stale_count -gt 0 ]]; then
        echo "⚠️  Stale Epics detected (30+ days without update)"
        echo "    Review: PROGRESS.md or docs/epics/_archive/"
        echo ""
    fi

    if [[ $archived_count -gt 0 ]] || [[ $stale_count -gt 0 ]] || [[ $orphaned_count -gt 0 ]]; then
        echo "💡 Full log: .claude/hooks/lifecycle.log"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo "✅ No maintenance needed"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

else
    log "ERROR: Lifecycle script not found or not executable: $LIFECYCLE_SCRIPT"
fi

# Exit cleanly (Exit code 0 = allow, stdout visible to user)
exit 0
