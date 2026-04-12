#!/bin/bash
# .claude/hooks/post/post-tool-use-task-sync.sh
# PostToolUse Hook: Task 파일 편집 감지 → PROGRESS.md 자동 업데이트
# Version: v3.1

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
# NOTE: 현재 해제 상태 (디버깅 용이성 우선)
# exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-sync] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Phase 0: stdin 읽기
# ============================================================================
if [ ! -t 0 ]; then
  tool_info=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, length: ${#tool_info}"
else
  tool_info=""
  log_debug "No stdin"
fi

# 빈 입력 처리
if [[ -z "$tool_info" ]] || [[ "${#tool_info}" -lt 10 ]]; then
  log_debug "Skipped: empty input"
  exit 0
fi

# ============================================================================
# Phase 1: jq로 데이터 추출 (안전하게)
# ============================================================================
# jq 설치 확인
if ! command -v jq &> /dev/null; then
  log_debug "jq not found, skipping"
  exit 0
fi

# JSON 파싱 (안전하게)
if ! echo "$tool_info" | jq -e . >/dev/null 2>&1; then
  log_debug "Invalid JSON, skipping"
  exit 0
fi

tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
session_id=$(echo "$tool_info" | jq -r '.session_id // empty' 2>/dev/null || echo "")

log_debug "tool_name: $tool_name, file_path: $file_path"

# Skip if not an edit tool or no file path
if [[ ! "$tool_name" =~ ^(Edit|MultiEdit|Write)$ ]] || [[ -z "$file_path" ]]; then
  log_debug "Skipped: Not an edit tool or no file path"
  exit 0
fi

# ============================================================================
# Phase 2: 환경 설정
# ============================================================================
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_ROOT/docs/.state/PROJECT_STATE.json"
PROGRESS_SCRIPT="$PROJECT_ROOT/.claude/scripts/generate-progress.sh"

# Log file
LOG_FILE="$PROJECT_ROOT/.claude/hooks/task-sync.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_debug "PROJECT_ROOT: $PROJECT_ROOT"

# ============================================================================
# Helper Functions
# ============================================================================
extract_epic_id() {
  local path="$1"
  # docs/epics/EP001/tasks/T001.md → EP001
  echo "$path" | sed -E 's|.*epics/([^/]+)/.*|\1|'
}

extract_task_id() {
  local path="$1"
  # docs/epics/EP001/tasks/T001.md → T001
  basename "$path" .md
}

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

# ============================================================================
# Main Logic
# ============================================================================

# NOTE: 이 Hook은 조용히 동작 (출력 없음)
# Task/Story 편집 시 백그라운드에서 PROGRESS.md 업데이트

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

  # Update PROJECT_STATE.json (jq 안전하게)
  if [[ -f "$STATE_FILE" ]]; then
    # Backup
    cp "$STATE_FILE" "${STATE_FILE}.backup" 2>/dev/null || true

    # Update task progress
    if jq --arg epic "$epic_id" \
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
       ' "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null; then

      mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
      log "✅ STATE updated: $epic_id/$task_id ($checked/$total)"

      # Regenerate PROGRESS.md
      if [[ -x "$PROGRESS_SCRIPT" ]]; then
        "$PROGRESS_SCRIPT" >> "$LOG_FILE" 2>&1 || true
        log "✅ PROGRESS.md regenerated"
      fi
    else
      log "ERROR: Failed to update STATE"
      mv "${STATE_FILE}.backup" "$STATE_FILE" 2>/dev/null || true
    fi
  else
    log "WARNING: STATE file not found: $STATE_FILE"
  fi
fi

# Check if file matches Story pattern: docs/epics/**/stories/*.md
if [[ "$file_path" =~ docs/epics/.*/stories/.*\.md ]]; then
  log "Story file edited: $file_path"

  epic_id=$(extract_epic_id "$file_path")
  story_id=$(extract_task_id "$file_path")

  # Update lastUpdated for Epic
  if [[ -f "$STATE_FILE" ]] && [[ -n "$epic_id" ]]; then
    if jq --arg epic "$epic_id" \
       --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '
       if .epics[$epic] then
           .epics[$epic].lastUpdated = $timestamp
       else
           .
       end
       ' "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null; then

      mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
      log "✅ Epic lastUpdated: $epic_id"

      # Regenerate PROGRESS.md
      if [[ -x "$PROGRESS_SCRIPT" ]]; then
        "$PROGRESS_SCRIPT" >> "$LOG_FILE" 2>&1 || true
      fi
    fi
  fi
fi

log_debug "=== HOOK END ==="
exit 0
