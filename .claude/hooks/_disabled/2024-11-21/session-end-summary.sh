#!/bin/bash
#
# SessionEnd Hook - Smart Session Summary & Handoff
#
# Purpose: 세션 종료 시 작업 요약 및 다음 세션을 위한 Handoff 생성
# Trigger: Claude Code 세션 종료 시
# Effect: 완료 작업 요약, 미해결 이슈 추출, 패턴 학습 데이터 수집
#
# Input (stdin JSON):
# {
#   "session_id": "uuid",
#   "trigger": "session_end",
#   "timestamp": "2025-01-05T12:00:00Z",
#   "duration_minutes": 45
# }
#
# Exit Codes:
#   0: Success (항상 성공, Graceful Degradation)

set -euo pipefail

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
MARKER_FILE="/tmp/claude-compaction-marker-$(basename "$PROJECT_ROOT").json"
HANDOFF_FILE="/tmp/claude-session-handoff-$(basename "$PROJECT_ROOT").json"
LOG_FILE="/tmp/claude-session-end.log"

# 성능 추적 유틸리티 로드
UTILS_DIR="$PROJECT_ROOT/.claude/hooks/utils"
if [[ -f "$UTILS_DIR/hook-performance-tracker.sh" ]]; then
  source "$UTILS_DIR/hook-performance-tracker.sh"
  start_timer
  PERFORMANCE_TRACKING_ENABLED=true
else
  PERFORMANCE_TRACKING_ENABLED=false
fi

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
  log "No input or timeout - proceeding with defaults"
fi

# 빈 입력 처리 (Graceful Degradation)
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - creating default handoff"
fi

# JSON 파싱 (jq 실패 시 조용히 기본값 사용)
SESSION_ID=""
DURATION=0
if command -v jq &> /dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
  DURATION=$(echo "$INPUT" | jq -r '.duration_minutes // 0' 2>/dev/null || echo "0")
else
  log "jq not found - using defaults"
  SESSION_ID="unknown"
  DURATION=0
fi

log "SessionEnd: session=$SESSION_ID, duration=${DURATION}min"

# ============================================
# Git Activity Analysis
# ============================================

analyze_git_activity() {
  log "Analyzing git activity"

  # 최근 커밋 분석 (세션 시작 이후)
  local commits_count=0
  local files_changed=0

  if command -v git &> /dev/null && [[ -d ".git" ]]; then
    # 최근 1시간 이내 커밋 (세션 기간 추정)
    commits_count=$(git log --since="1 hour ago" --oneline 2>/dev/null | wc -l || echo "0")

    # 변경된 파일 수 (unstaged + staged)
    files_changed=$(git status --short 2>/dev/null | wc -l || echo "0")

    log "Git activity: $commits_count commits, $files_changed files changed"
  fi

  echo "$commits_count|$files_changed"
}

# ============================================
# Task Progress Analysis
# ============================================

analyze_task_progress() {
  log "Analyzing task progress"

  local completed_tasks=0
  local pending_tasks=0
  local in_progress_tasks=0

  # PROGRESS.md 파싱
  if [[ -f "PROGRESS.md" ]]; then
    completed_tasks=$(grep -E "\- \[x\]" PROGRESS.md 2>/dev/null | wc -l || echo "0")
    pending_tasks=$(grep -E "\- \[ \]" PROGRESS.md 2>/dev/null | wc -l || echo "0")
    in_progress_tasks=$(grep -E "in.progress" PROGRESS.md 2>/dev/null | wc -l || echo "0")

    log "Task progress: $completed_tasks completed, $in_progress_tasks in progress, $pending_tasks pending"
  fi

  echo "$completed_tasks|$in_progress_tasks|$pending_tasks"
}

# ============================================
# Unresolved Issues Detection
# ============================================

detect_unresolved_issues() {
  log "Detecting unresolved issues"

  local issues=()

  # 1. Git unstaged changes (potential WIP)
  if command -v git &> /dev/null && [[ -d ".git" ]]; then
    local unstaged=$(git diff --name-only 2>/dev/null | head -3)
    if [[ -n "$unstaged" ]]; then
      issues+=("Unstaged changes: $(echo "$unstaged" | tr '\n' ', ')")
    fi
  fi

  # 2. In-progress tasks in docs/epics
  local wip_tasks=$(find docs/epics -name "*.md" -type f -exec grep -l "\- \[ \]" {} \; 2>/dev/null | head -3)
  if [[ -n "$wip_tasks" ]]; then
    issues+=("WIP tasks: $(echo "$wip_tasks" | tr '\n' ', ')")
  fi

  # 3. Error logs (recent errors)
  if [[ -f "/tmp/claude-error-fixer.log" ]]; then
    local recent_errors=$(tail -20 /tmp/claude-error-fixer.log 2>/dev/null | grep -i "error" | head -1)
    if [[ -n "$recent_errors" ]]; then
      issues+=("Recent error: ${recent_errors:0:100}...")
    fi
  fi

  # JSON 배열 생성
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '%s\n' "${issues[@]}" | jq -R -s 'split("\n") | .[:-1]' 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

# ============================================
# Session Summary Generation
# ============================================

generate_session_summary() {
  local git_activity="$1"
  local task_progress="$2"

  IFS='|' read -r commits files <<< "$git_activity"
  IFS='|' read -r completed in_progress pending <<< "$task_progress"

  local summary=""

  # 작업 완료 요약
  if [[ $completed -gt 0 ]]; then
    summary+="✅ $completed 개 Task 완료. "
  fi

  if [[ $in_progress -gt 0 ]]; then
    summary+="🔄 $in_progress 개 Task 진행 중. "
  fi

  # Git 활동 요약
  if [[ $commits -gt 0 ]]; then
    summary+="📝 $commits 개 커밋 생성. "
  fi

  if [[ $files -gt 0 ]]; then
    summary+="⚠️ $files 개 파일 미커밋. "
  fi

  # 기본 메시지
  if [[ -z "$summary" ]]; then
    summary="세션 활동 없음 (탐색 또는 문서 읽기)"
  fi

  echo "$summary"
}

# ============================================
# Next Session Handoff
# ============================================

create_handoff_message() {
  local in_progress_task=""

  # 진행 중인 Task 찾기
  if [[ -f "PROGRESS.md" ]]; then
    in_progress_task=$(grep -A 2 "in.progress" PROGRESS.md 2>/dev/null | grep -E "^\- " | head -1 || echo "")
  fi

  # WIP 파일 찾기
  local wip_files=""
  if command -v git &> /dev/null && [[ -d ".git" ]]; then
    wip_files=$(git diff --name-only 2>/dev/null | head -3 | tr '\n' ', ' || echo "")
  fi

  local handoff_msg=""

  if [[ -n "$in_progress_task" ]]; then
    handoff_msg+="🔄 진행 중: $in_progress_task\n"
  fi

  if [[ -n "$wip_files" ]]; then
    handoff_msg+="📝 WIP 파일: $wip_files\n"
  fi

  if [[ -z "$handoff_msg" ]]; then
    handoff_msg="✅ 세션 정리 완료. 새 작업 시작 가능."
  fi

  echo -e "$handoff_msg"
}

# ============================================
# Handoff File Creation
# ============================================

create_handoff_file() {
  local session_id="$1"
  local duration="$2"
  local summary="$3"
  local handoff_msg="$4"
  local unresolved_issues="$5"

  # JSON 생성
  cat > "$HANDOFF_FILE" <<EOF
{
  "trigger": "session_end",
  "session_id": "$session_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_minutes": $duration,
  "summary": "$summary",
  "handoff": "$handoff_msg",
  "unresolved_issues": $unresolved_issues,
  "next_session_actions": [
    "cat PROGRESS.md",
    "mcp__serena__list_memories",
    "git status"
  ]
}
EOF

  log "Handoff file created: $HANDOFF_FILE"
}

# ============================================
# User Display
# ============================================

display_session_summary() {
  local summary="$1"
  local handoff_msg="$2"

  echo "═══════════════════════════════════════" >&2
  echo "🎯 세션 종료 요약" >&2
  echo "═══════════════════════════════════════" >&2
  echo "" >&2
  echo "📋 작업 내역:" >&2
  echo "  $summary" >&2
  echo "" >&2
  echo "🔄 다음 세션 Handoff:" >&2
  echo -e "$handoff_msg" | sed 's/^/  /' >&2
  echo "" >&2
  echo "💡 Handoff 정보는 다음 세션 시작 시 자동 로드됩니다." >&2
  echo "═══════════════════════════════════════" >&2
}

# ============================================
# Marker Cleanup
# ============================================

cleanup_old_markers() {
  log "Cleaning up old marker files"

  # PreCompact 마커 삭제 (세션이 정상 종료되었으므로 불필요)
  if [[ -f "$MARKER_FILE" ]]; then
    rm -f "$MARKER_FILE" 2>/dev/null || true
    log "Removed PreCompact marker: $MARKER_FILE"
  fi

  # 오래된 Handoff 파일 정리 (7일 이상)
  find /tmp -name "claude-session-handoff-*.json" -mtime +7 -delete 2>/dev/null || true
  log "Cleaned up old handoff files"
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== SessionEnd Hook Started ==="

  # 1. Git 활동 분석
  local git_activity=$(analyze_git_activity)

  # 2. Task 진행도 분석
  local task_progress=$(analyze_task_progress)

  # 3. 미해결 이슈 감지
  local unresolved_issues=$(detect_unresolved_issues)

  # 4. 세션 요약 생성
  local summary=$(generate_session_summary "$git_activity" "$task_progress")
  log "Session summary: $summary"

  # 5. Handoff 메시지 생성
  local handoff_msg=$(create_handoff_message)
  log "Handoff message generated"

  # 6. Handoff 파일 생성
  create_handoff_file "$SESSION_ID" "$DURATION" "$summary" "$handoff_msg" "$unresolved_issues"

  # 7. 사용자에게 요약 표시
  display_session_summary "$summary" "$handoff_msg"

  # 8. 오래된 마커 정리
  cleanup_old_markers

  # 성능 로그 업데이트
  if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
    end_timer "session-end-summary"
  fi

  log "=== SessionEnd Hook Completed ==="
  exit 0
}

# Graceful error handling
trap 'log "Error occurred, but continuing (Graceful Degradation)"; exit 0' ERR

main
