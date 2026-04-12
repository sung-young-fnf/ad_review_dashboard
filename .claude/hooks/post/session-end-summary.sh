#!/bin/bash
#
# SessionEnd Hook - Smart Session Summary & Handoff (v2.0)
#
# Purpose: 세션 종료 시 작업 요약 + 실패 접근법 + 다음 세션 Handoff 생성
# Trigger: Claude Code 세션 종료 시
# Enhancement v2.0:
#   - historian 기반 "시도했지만 실패한 접근법" 추출
#   - 구체적인 "다음에 무엇부터 해야 하는지" 명세
#   - compact-state.json과 통합
#
# Exit Codes:
#   0: Success (항상 성공, Graceful Degradation)

set -eo pipefail
trap 'exit 0' ERR

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
HANDOFF_DIR="$PROJECT_ROOT/.claude/handoffs"
HANDOFF_FILE="$HANDOFF_DIR/latest-handoff.md"
HANDOFF_JSON="/tmp/claude-session-handoff-${PROJECT_NAME}.json"
COMPACT_STATE="$PROJECT_ROOT/.claude/compact-state.json"
LOG_FILE="/tmp/claude-session-end.log"

mkdir -p "$HANDOFF_DIR" 2>/dev/null || true

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ============================================
# Input Processing
# ============================================

INPUT=""
if read -t 1 INPUT; then
  log "Input received: ${#INPUT} bytes"
fi

SESSION_ID="unknown"
DURATION=0
if command -v jq &>/dev/null && [[ -n "$INPUT" ]]; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
  DURATION=$(echo "$INPUT" | jq -r '.duration_minutes // 0' 2>/dev/null || echo "0")
fi

log "SessionEnd v2: session=$SESSION_ID, duration=${DURATION}min"

# ============================================
# 1. Git Activity Analysis
# ============================================

analyze_git_activity() {
  local commits_count=0
  local files_changed=0
  local commit_messages=""
  local uncommitted_files=""

  if command -v git &>/dev/null && [[ -d ".git" ]]; then
    commits_count=$(git log --since="2 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    commit_messages=$(git log --since="2 hours ago" --oneline 2>/dev/null | head -10)
    files_changed=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    uncommitted_files=$(git status --short 2>/dev/null | head -10)
  fi

  echo "${commits_count}|${files_changed}|${commit_messages}|${uncommitted_files}"
}

# ============================================
# 2. Task Progress Analysis
# ============================================

analyze_task_progress() {
  local epic_id="none"
  local current_task="none"
  local completed=0
  local in_progress=0
  local pending=0
  local progress_file=""

  # 최신 Epic의 PROGRESS.md 찾기
  progress_file=$(find docs/epics -name "PROGRESS.md" -type f 2>/dev/null | sort -r | head -1)

  if [[ -n "$progress_file" ]] && [[ -f "$progress_file" ]]; then
    epic_id=$(echo "$progress_file" | sed 's|.*/epics/\([^/]*\)/.*|\1|')
    completed=$(grep -c '^\- \[✅\]' "$progress_file" 2>/dev/null || echo "0")
    in_progress=$(grep -c '^\- \[🔄\]' "$progress_file" 2>/dev/null || echo "0")
    pending=$(grep -c '^\- \[ \]' "$progress_file" 2>/dev/null || echo "0")
    current_task=$(grep '^\- \[🔄\]' "$progress_file" 2>/dev/null | head -1 | sed 's/.*\] \([^:]*\).*/\1/' || echo "none")
  fi

  echo "${epic_id}|${current_task}|${completed}|${in_progress}|${pending}|${progress_file}"
}

# ============================================
# 3. Failed Approaches Extraction (NEW v2.0)
# ============================================

extract_failed_approaches() {
  local failed_approaches=""
  local error_count=0

  # 3a. 최근 에러 로그에서 실패 패턴 추출
  local error_logs=(/tmp/claude-error-fixer.log /tmp/claude-code-writer.log)
  for logfile in "${error_logs[@]}"; do
    if [[ -f "$logfile" ]]; then
      local recent_errors=$(tail -100 "$logfile" 2>/dev/null | grep -iE "(ERROR|FAIL|reject|❌|실패)" | tail -5)
      if [[ -n "$recent_errors" ]]; then
        failed_approaches+="$recent_errors"$'\n'
        error_count=$((error_count + $(echo "$recent_errors" | wc -l | tr -d ' ')))
      fi
    fi
  done

  # 3b. Git에서 revert/reset 흔적 찾기 (실패 후 되돌린 시도)
  if command -v git &>/dev/null && [[ -d ".git" ]]; then
    local reverts=$(git log --since="2 hours ago" --oneline --all 2>/dev/null | grep -iE "(revert|fix|rollback|undo)" | head -3)
    if [[ -n "$reverts" ]]; then
      failed_approaches+="[Git rollbacks]: $reverts"$'\n'
    fi
  fi

  # 3c. Serena 메모리에서 실패 관련 메모리 검색
  if [[ -d ".serena/memories" ]]; then
    local fail_memories=$(find .serena/memories -name "*.md" -newer /tmp/claude-session-start-marker 2>/dev/null \
      | xargs grep -liE "(실패|error|workaround|rollback|alternative)" 2>/dev/null | head -3)
    if [[ -n "$fail_memories" ]]; then
      for mem in $fail_memories; do
        local mem_name=$(basename "$mem" .md)
        local mem_summary=$(head -3 "$mem" | tr '\n' ' ')
        failed_approaches+="[Memory: $mem_name]: ${mem_summary:0:200}"$'\n'
      done
    fi
  fi

  # 3d. hook-cache에서 에러 패턴 수집
  local cache_dir="$PROJECT_ROOT/.claude/hooks-cache/${SESSION_ID}"
  if [[ -d "$cache_dir" ]]; then
    local error_files=$(find "$cache_dir" -name "*.json" -exec grep -l "error" {} \; 2>/dev/null | head -3)
    if [[ -n "$error_files" ]]; then
      for ef in $error_files; do
        local err_summary=$(jq -r '.error // .message // empty' "$ef" 2>/dev/null | head -1)
        if [[ -n "$err_summary" ]]; then
          failed_approaches+="[Cache]: ${err_summary:0:200}"$'\n'
        fi
      done
    fi
  fi

  if [[ -z "$failed_approaches" ]]; then
    echo "0|없음 (이번 세션에서 실패한 접근법이 감지되지 않음)"
  else
    echo "${error_count}|${failed_approaches}"
  fi
}

# ============================================
# 4. Next Session Instructions (NEW v2.0)
# ============================================

generate_next_instructions() {
  local epic_id="$1"
  local current_task="$2"
  local pending_count="$3"
  local uncommitted_count="$4"

  local instructions=""

  # 4a. 미커밋 파일이 있으면 커밋 우선
  if [[ "$uncommitted_count" -gt 0 ]]; then
    instructions+="1. 미커밋 파일 ${uncommitted_count}개 확인 → git status → 커밋 또는 stash"$'\n'
  fi

  # 4b. 진행 중 Task가 있으면 이어서
  if [[ "$current_task" != "none" ]]; then
    instructions+="2. 진행 중 Task '${current_task}' 이어서 구현"$'\n'
    instructions+="   → Task(subagent_type: 'code-writer', prompt: '${current_task} 구현 계속')"$'\n'
  fi

  # 4c. 남은 Task가 있으면 다음 Task
  if [[ "$pending_count" -gt 0 ]] && [[ "$current_task" == "none" ]]; then
    instructions+="2. 다음 pending Task 시작 (${pending_count}개 남음)"$'\n'
    instructions+="   → PROGRESS.md 확인 후 다음 Task 구현"$'\n'
  fi

  # 4d. 모든 Task 완료면
  if [[ "$pending_count" -eq 0 ]] && [[ "$current_task" == "none" ]]; then
    instructions+="2. 모든 Task 완료 상태 → Epic 완료 절차 진행"$'\n'
    instructions+="   → /epic-completion-manager:complete"$'\n'
  fi

  # 4e. 기본 복구 명령어
  instructions+="3. 컨텍스트 복원: serena/list_memories → 관련 메모리 로드"$'\n'
  instructions+="4. PROGRESS.md 확인: cat docs/epics/${epic_id}/PROGRESS.md"$'\n'

  echo "$instructions"
}

# ============================================
# 5. Generate Handoff Document (Markdown)
# ============================================

generate_handoff_markdown() {
  local session_id="$1"
  local duration="$2"
  local git_info="$3"
  local task_info="$4"
  local failed_info="$5"
  local next_instructions="$6"

  IFS='|' read -r commits_count files_changed commit_messages uncommitted_files <<< "$git_info"
  IFS='|' read -r epic_id current_task completed in_progress pending progress_file <<< "$task_info"
  IFS='|' read -r error_count failed_approaches <<< "$failed_info"

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local total=$((completed + in_progress + pending))
  local pct=0
  if [[ $total -gt 0 ]]; then
    pct=$((completed * 100 / total))
  fi

  cat > "$HANDOFF_FILE" <<EOF
# Session Handoff

> Generated: ${timestamp}
> Session: ${session_id} (${duration}min)
> Project: ${PROJECT_NAME}

## 작업 내역 (What was done)

- Epic: ${epic_id}
- 진행률: ${completed}/${total} Tasks (${pct}%)
- 커밋: ${commits_count}개

### 커밋 내역
\`\`\`
${commit_messages:-없음}
\`\`\`

### 미커밋 파일
\`\`\`
${uncommitted_files:-없음}
\`\`\`

## 현재 상태 (Current state)

- 진행 중 Task: ${current_task}
- 남은 Task: ${pending}개
- 미커밋 파일: ${files_changed}개

## 실패한 접근법 (What was tried but failed)

> 에러/실패 ${error_count}건 감지

\`\`\`
${failed_approaches}
\`\`\`

## 다음 세션 가이드 (What to do next)

${next_instructions}

## 컨텍스트 복원 명령어

\`\`\`bash
# 1. 메모리 확인
mcp-cli call serena/list_memories '{}'

# 2. 진행 상태 확인
cat docs/epics/${epic_id}/PROGRESS.md

# 3. Git 상태 확인
git status && git log --oneline -5

# 4. compact-state 확인
cat .claude/compact-state.json
\`\`\`

---
_Auto-generated by session-end-summary.sh v2.0_
EOF

  log "Handoff markdown generated: $HANDOFF_FILE"
}

# ============================================
# 6. Generate Handoff JSON (for session-start-loader)
# ============================================

generate_handoff_json() {
  local session_id="$1"
  local duration="$2"
  local git_info="$3"
  local task_info="$4"
  local failed_info="$5"
  local next_instructions="$6"

  IFS='|' read -r commits_count files_changed _ _ <<< "$git_info"
  IFS='|' read -r epic_id current_task completed in_progress pending progress_file <<< "$task_info"
  IFS='|' read -r error_count _ <<< "$failed_info"

  # JSON-safe next_instructions
  local safe_instructions=$(echo "$next_instructions" | head -5 | tr '\n' ' ' | sed 's/"/\\"/g')

  cat > "$HANDOFF_JSON" <<EOF
{
  "version": "2.0",
  "trigger": "session_end",
  "session_id": "$session_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_minutes": $duration,
  "context": {
    "epic_id": "$epic_id",
    "current_task": "$current_task",
    "completed_tasks": $completed,
    "pending_tasks": $pending,
    "in_progress_tasks": $in_progress
  },
  "git": {
    "commits_count": $commits_count,
    "uncommitted_files": $files_changed
  },
  "failed_approaches_count": $error_count,
  "next_instructions": "$safe_instructions",
  "handoff_file": "$HANDOFF_FILE",
  "next_session_actions": [
    "Read .claude/handoffs/latest-handoff.md",
    "cat docs/epics/$epic_id/PROGRESS.md",
    "mcp-cli call serena/list_memories '{}'"
  ]
}
EOF

  log "Handoff JSON generated: $HANDOFF_JSON"
}

# ============================================
# 7. User Display
# ============================================

display_summary() {
  local task_info="$1"
  local failed_info="$2"

  IFS='|' read -r epic_id current_task completed in_progress pending _ <<< "$task_info"
  IFS='|' read -r error_count _ <<< "$failed_info"
  local total=$((completed + in_progress + pending))

  echo "" >&2
  echo "=======================================" >&2
  echo "  Session Handoff v2.0" >&2
  echo "=======================================" >&2
  echo "" >&2
  echo "  Epic: $epic_id" >&2
  echo "  Progress: ${completed}/${total} Tasks" >&2
  if [[ "$current_task" != "none" ]]; then
    echo "  Current: $current_task (in progress)" >&2
  fi
  if [[ "$error_count" -gt 0 ]]; then
    echo "  Failed approaches: ${error_count}건 기록됨" >&2
  fi
  echo "" >&2
  echo "  Handoff: .claude/handoffs/latest-handoff.md" >&2
  echo "  (다음 세션 시작 시 자동 로드)" >&2
  echo "=======================================" >&2
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== SessionEnd v2.0 Hook Started ==="

  # Session start marker for failed approaches time filtering
  touch /tmp/claude-session-start-marker 2>/dev/null || true

  # 1. Git 활동 분석
  local git_info=$(analyze_git_activity)

  # 2. Task 진행도 분석
  local task_info=$(analyze_task_progress)

  # 3. 실패 접근법 추출 (NEW v2.0)
  local failed_info=$(extract_failed_approaches)

  # 4. 다음 세션 가이드 생성 (NEW v2.0)
  IFS='|' read -r epic_id current_task completed in_progress pending _ <<< "$task_info"
  IFS='|' read -r _ files_changed _ _ <<< "$git_info"
  local next_instructions=$(generate_next_instructions "$epic_id" "$current_task" "$pending" "$files_changed")

  # 5. Handoff 문서 생성 (Markdown)
  generate_handoff_markdown "$SESSION_ID" "$DURATION" "$git_info" "$task_info" "$failed_info" "$next_instructions"

  # 6. Handoff JSON 생성 (session-start-loader용)
  generate_handoff_json "$SESSION_ID" "$DURATION" "$git_info" "$task_info" "$failed_info" "$next_instructions"

  # 7. 사용자에게 요약 표시
  display_summary "$task_info" "$failed_info"

  log "=== SessionEnd v2.0 Hook Completed ==="
  exit 0
}

main
