#!/bin/bash
# .claude/hooks/stop-epic-lifecycle.sh
# Stop Event Hook: Epic Lifecycle Manager Auto-Execution
# 세션 종료 시 Epic/Task 편집 감지 → epic-completion-manager 조건부 실행
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [epic-lifecycle] $*" >> "$DEBUG_LOG"
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
  event_info=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, length: ${#event_info}"
else
  event_info=""
  log_debug "No stdin"
fi

# 빈 입력 처리
if [[ -z "$event_info" ]] || [[ "${#event_info}" -lt 10 ]]; then
  log_debug "Skipped: empty input"
  exit 0
fi

# ============================================================================
# Phase 1: jq로 session_id 추출
# ============================================================================
if ! command -v jq &> /dev/null; then
  log_debug "jq not found, skipping"
  exit 0
fi

if ! echo "$event_info" | jq -e . >/dev/null 2>&1; then
  log_debug "Invalid JSON, skipping"
  exit 0
fi

session_id=$(echo "$event_info" | jq -r '.session_id // empty' 2>/dev/null || echo "")
log_debug "session_id: $session_id"

# ============================================================================
# Phase 2: 환경 설정
# ============================================================================
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
task_sync_log="$PROJECT_ROOT/.claude/hooks/task-sync.log"

log_debug "PROJECT_ROOT: $PROJECT_ROOT"
log_debug "task_sync_log: $task_sync_log"

# Log function
LOG_FILE="$PROJECT_ROOT/.claude/hooks/epic-lifecycle-stop.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log "Stop Event triggered for session: $session_id"

# ============================================================================
# Step 1: Epic/Task 편집 여부 확인
# ============================================================================
if [[ ! -f "$task_sync_log" ]]; then
  log "No task sync log found. Skipping lifecycle check."
  log_debug "task-sync.log not found"
  exit 0
fi

# 이번 세션에서 Epic/Task 편집 여부 확인 (최근 30분 이내)
thirty_minutes_ago=$(date -u -v-30M +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -u -d "30 minutes ago" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")

recent_edits=$(grep -E "Task file edited:|Story file edited:" "$task_sync_log" 2>/dev/null | \
               awk -v cutoff="[$thirty_minutes_ago" '$0 >= cutoff {print}' 2>/dev/null | wc -l | tr -d ' ' || echo "0")

log_debug "recent_edits: $recent_edits"

if [[ "$recent_edits" -eq 0 ]]; then
  log "No recent Epic/Task edits. Skipping lifecycle check."
  log_debug "No recent edits"
  exit 0
fi

log "Detected $recent_edits Epic/Task edits in this session."

# ============================================================================
# Step 2: Epic 완료 후보 추출
# ============================================================================
# task-sync.log에서 최근 편집된 Epic ID 목록
epic_ids=$(grep -E "Epic: [A-Z0-9-]+," "$task_sync_log" 2>/dev/null | \
           tail -10 | \
           sed -E 's/.*Epic: ([A-Z0-9-]+),.*/\1/' | \
           sort -u || echo "")

log_debug "epic_ids candidates: $(echo "$epic_ids" | tr '\n' ' ')"

if [[ -z "$epic_ids" ]]; then
  log "No Epic IDs found in recent edits"
  log_debug "No epic_ids"
  exit 0
fi

# ============================================================================
# Step 3: Epic 완료 여부 체크 및 제안
# ============================================================================
COMPLETED_EPICS=""

for epic_id in $epic_ids; do
  epic_file="$PROJECT_ROOT/docs/epics/$epic_id/epic.md"

  if [[ ! -f "$epic_file" ]]; then
    log_debug "Epic file not found: $epic_file"
    continue
  fi

  # Epic 내 모든 Task 파일 확인
  tasks_dir="$PROJECT_ROOT/docs/epics/$epic_id/tasks"

  if [[ ! -d "$tasks_dir" ]]; then
    log_debug "Tasks dir not found: $tasks_dir"
    continue
  fi

  # 모든 Task 완료 여부 확인
  total_tasks=$(find "$tasks_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$total_tasks" -eq 0 ]]; then
    log_debug "No tasks found for $epic_id"
    continue
  fi

  # 각 Task의 완료율 확인 (80% 이상 = 완료)
  completed_tasks=0

  for task_file in "$tasks_dir"/*.md; do
    [ -f "$task_file" ] || continue

    checked=$(grep -cE '^\s*-\s+\[x\]' "$task_file" 2>/dev/null || echo 0)
    total=$(grep -cE '^\s*-\s+\[[ x]\]' "$task_file" 2>/dev/null || echo 0)

    if [[ $total -gt 0 ]]; then
      completion=$((checked * 100 / total))
      if [[ $completion -ge 80 ]]; then
        completed_tasks=$((completed_tasks + 1))
      fi
    fi
  done

  log_debug "$epic_id: $completed_tasks/$total_tasks tasks completed"

  # 모든 Task 완료 시 추천
  if [[ $completed_tasks -eq $total_tasks ]]; then
    COMPLETED_EPICS="${COMPLETED_EPICS}
  - $epic_id ($completed_tasks/$total_tasks tasks)"
    log "✅ Epic completion candidate: $epic_id"
  fi
done

# ============================================================================
# Step 4: Epic 완료 제안 출력
# ============================================================================
if [[ -n "$COMPLETED_EPICS" ]]; then
  cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

╔═══════════════════════════════════════════════════════════════════════════╗
║              ✅ EPIC COMPLETION DETECTED                                  ║
╚═══════════════════════════════════════════════════════════════════════════╝

🎉 다음 Epic이 완료된 것으로 보입니다:
${COMPLETED_EPICS}

💡 권장 조치:

Epic 완료 프로세스를 실행하세요:

  /epic-completion-manager:complete {epic-id}

또는:

  Task --subagent_type 05-post-implementation/epic-completion-manager --prompt "
  Epic ID: {epic-id}
  Complete Epic: 검증 → 백로그 정리 → 대시보드 생성
  "

이 명령은 다음을 자동 수행합니다:
  1. Epic MVP 완료 상태 검증
  2. 미완료 항목을 _backlog/로 이동
  3. 우선순위 재평가
  4. Epic 완료 대시보드 생성
  5. Git 커밋

───────────────────────────────────────────────────────────────────────────

EOF

  log "Epic completion suggestion displayed"
fi

log_debug "=== HOOK END ==="
exit 0
