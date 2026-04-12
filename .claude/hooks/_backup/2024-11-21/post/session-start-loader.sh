#!/bin/bash
#
# SessionStart Hook - Automatic Context Loading
#
# Purpose: 세션 시작 시 자동 컨텍스트 로딩 및 복원
# Trigger: Claude Code 세션 시작 시
# Effect: PreCompact 마커 복원, 세션 시작 시간 5분 → 10초
#
# Input (stdin JSON):
# {
#   "session_id": "uuid",
#   "trigger": "session_start",
#   "timestamp": "2025-01-05T10:00:00Z"
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
LOG_FILE="/tmp/claude-session-start.log"

# 자동 로드할 중요 메모리 (최대 5개)
PRIORITY_MEMORIES=(
  "current_project_architecture"
  "current_project_tech_stack"
  "database_schema_analysis"
  "agent_optimization_.*"
  "error_context_.*"
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
  log "No input or timeout - proceeding with defaults"
fi

# 빈 입력 처리 (Graceful Degradation)
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - new session without marker"
fi

# JSON 파싱 (jq 실패 시 조용히 기본값 사용)
SESSION_ID=""
TIMESTAMP=""
if command -v jq &> /dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
  TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // ""' 2>/dev/null || echo "")
else
  log "jq not found - using defaults"
  SESSION_ID="unknown"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fi

log "SessionStart: session=$SESSION_ID, timestamp=$TIMESTAMP"

# ============================================
# Marker File Detection
# ============================================

has_marker_file() {
  [[ -f "$MARKER_FILE" ]] && [[ -r "$MARKER_FILE" ]]
}

# ============================================
# Context Restoration
# ============================================

restore_from_marker() {
  log "Restoring context from marker: $MARKER_FILE"

  # Marker 파일 읽기
  if ! command -v jq &> /dev/null; then
    log "jq not found - cannot parse marker"
    return 1
  fi

  local marker_content=$(cat "$MARKER_FILE" 2>/dev/null || echo "{}")

  # 컨텍스트 추출
  local prev_epic=$(echo "$marker_content" | jq -r '.context.epic // "unknown"' 2>/dev/null || echo "unknown")
  local prev_task=$(echo "$marker_content" | jq -r '.context.task // "none"' 2>/dev/null || echo "none")
  local prev_summary=$(echo "$marker_content" | jq -r '.context.summary // ""' 2>/dev/null || echo "")

  # Memories 추출 (배열)
  local memories_json=$(echo "$marker_content" | jq -r '.context.memories[]' 2>/dev/null || echo "")

  log "Previous context: epic=$prev_epic, task=$prev_task"

  # 사용자에게 복원 정보 표시
  echo "═══════════════════════════════════════" >&2
  echo "✅ 세션 컨텍스트 자동 복원 완료" >&2
  echo "═══════════════════════════════════════" >&2
  echo "" >&2
  echo "📋 이전 세션 정보:" >&2
  echo "  Epic: $prev_epic" >&2
  echo "  Task: $prev_task" >&2
  echo "" >&2

  # 요약 표시 (첫 200자)
  if [[ -n "$prev_summary" ]]; then
    echo "💡 작업 요약:" >&2
    echo "  ${prev_summary:0:200}..." >&2
    echo "" >&2
  fi

  # 메모리 목록 표시
  if [[ -n "$memories_json" ]]; then
    echo "🧠 로드된 메모리:" >&2
    echo "$memories_json" | while read -r memory; do
      echo "  - $memory" >&2
    done
    echo "" >&2
  fi

  # 복원 명령어 실행 (중요 파일 표시)
  if [[ -f "CLAUDE.md" ]]; then
    echo "📄 프로젝트 규칙: CLAUDE.md 로드 완료" >&2
  fi

  if [[ "$prev_task" != "none" ]] && [[ -f "$prev_task" ]]; then
    echo "📄 현재 Task: $prev_task 로드 완료" >&2
  fi

  echo "═══════════════════════════════════════" >&2

  # 마커 파일 삭제 (이미 복원했으므로)
  rm -f "$MARKER_FILE" 2>/dev/null || true
  log "Marker file removed after restoration"
}

# ============================================
# New Session Info
# ============================================

display_new_session_info() {
  log "New session without previous context"

  echo "═══════════════════════════════════════" >&2
  echo "🚀 새 세션 시작" >&2
  echo "═══════════════════════════════════════" >&2
  echo "" >&2
  echo "프로젝트: $(basename "$PROJECT_ROOT")" >&2
  echo "세션 ID: $SESSION_ID" >&2
  echo "" >&2

  # CLAUDE.md 확인
  if [[ -f "CLAUDE.md" ]]; then
    echo "✅ CLAUDE.md 로드 완료" >&2
  else
    echo "⚠️ CLAUDE.md 파일을 찾을 수 없습니다" >&2
  fi

  # .claude/CLAUDE.md 확인
  if [[ -f ".claude/CLAUDE.md" ]]; then
    echo "✅ .claude/CLAUDE.md 로드 완료" >&2
  fi

  # PROGRESS.md 확인
  if [[ -f "PROGRESS.md" ]]; then
    echo "✅ PROGRESS.md 로드 완료" >&2

    # 진행 중인 Epic/Task 표시
    local current_epic=$(grep -A 5 "## Epic" PROGRESS.md 2>/dev/null | grep -E "status.*in.progress" | head -1 || echo "")
    if [[ -n "$current_epic" ]]; then
      echo "📋 진행 중인 Epic: $current_epic" >&2
    fi
  fi

  echo "═══════════════════════════════════════" >&2
}

# ============================================
# Phase 3: Agent Chain Restoration (Agent 체인 상태 복원)
# ============================================

restore_agent_chain() {
  log "Checking for Agent chain state (Session: $SESSION_ID)"

  # 세션별 체인 상태 경로 (동시 세션 격리)
  local CHAIN_STATE_DIR="$PROJECT_ROOT/.claude/hooks-cache/${SESSION_ID}"
  local CHAIN_STATE="$CHAIN_STATE_DIR/agent-chain-state.json"

  # 체인 상태 파일 존재 확인
  if [[ ! -f "$CHAIN_STATE" ]]; then
    log "No agent chain state file for session $SESSION_ID"
    return 0
  fi

  # jq 필수
  if ! command -v jq &> /dev/null; then
    log "jq not found - cannot restore agent chain"
    return 0
  fi

  # 상태 로드
  local LAST_AGENT=$(jq -r '.last_completed_agent // "none"' "$CHAIN_STATE" 2>/dev/null || echo "none")
  local LAST_TASK=$(jq -r '.last_task // ""' "$CHAIN_STATE" 2>/dev/null || echo "")
  local LAST_STORY=$(jq -r '.last_story // ""' "$CHAIN_STATE" 2>/dev/null || echo "")
  local LAST_EPIC=$(jq -r '.last_epic // ""' "$CHAIN_STATE" 2>/dev/null || echo "")
  local TIMESTAMP=$(jq -r '.timestamp // 0' "$CHAIN_STATE" 2>/dev/null || echo "0")

  # 24시간 이내 체인만 복원 (86400초)
  local CURRENT_TIME=$(date +%s)
  local TIME_DIFF=$((CURRENT_TIME - TIMESTAMP))

  if [[ $TIME_DIFF -ge 86400 ]]; then
    log "Agent chain state too old (${TIME_DIFF}s > 86400s)"
    return 0
  fi

  if [[ "$LAST_AGENT" == "none" ]] || [[ -z "$LAST_TASK" ]]; then
    log "No valid agent chain state"
    return 0
  fi

  # 사용자에게 복원 정보 표시
  echo "" >&2
  echo "╔═══════════════════════════════════════════════════════════════════════════╗" >&2
  echo "║                  🔄 Agent 체인 상태 복원 (Phase 3)                       ║" >&2
  echo "╚═══════════════════════════════════════════════════════════════════════════╝" >&2
  echo "" >&2
  echo "이전 세션:" >&2
  echo "  - 마지막 Agent: $LAST_AGENT" >&2
  echo "  - 마지막 Task: $LAST_TASK" >&2
  echo "  - 마지막 Story: $LAST_STORY" >&2
  echo "  - 마지막 Epic: $LAST_EPIC" >&2
  echo "  - 경과 시간: $((TIME_DIFF / 60)) 분 전" >&2
  echo "" >&2
  echo "⚠️ REMINDER: Agent 체인을 계속 진행하세요." >&2
  echo "" >&2

  # 다음 Task 찾기
  find_next_task_for_session "$LAST_EPIC" "$LAST_TASK"

  echo "═══════════════════════════════════════════════════════════════════════════" >&2
  echo "" >&2

  log "Agent chain state restored successfully"
}

find_next_task_for_session() {
  local EPIC_ID="$1"
  local TASK_ID="$2"

  if [[ -z "$EPIC_ID" ]] || [[ -z "$TASK_ID" ]]; then
    return 0
  fi

  local TASK_DIR="$PROJECT_ROOT/docs/epics/${EPIC_ID}/tasks"

  # Task 디렉토리 존재 확인
  if [[ ! -d "$TASK_DIR" ]]; then
    log "Task directory not found: $TASK_DIR"
    return 0
  fi

  # 현재 Task 번호 추출 (예: T001-S03 → 001)
  local CURRENT_NUM=$(echo "$TASK_ID" | sed -E 's/T0*([0-9]+)-.*/\1/')

  if [[ -z "$CURRENT_NUM" ]] || [[ ! "$CURRENT_NUM" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  local NEXT_NUM=$((CURRENT_NUM + 1))

  # 다음 Task 파일 찾기
  local NEXT_TASK_FILE=$(find "$TASK_DIR" -name "T$(printf '%03d' $NEXT_NUM)-*.md" 2>/dev/null | head -1)

  if [[ -n "$NEXT_TASK_FILE" ]]; then
    local NEXT_TASK_ID=$(basename "$NEXT_TASK_FILE" .md)
    local NEXT_TASK_TITLE=$(grep -m 1 '^# ' "$NEXT_TASK_FILE" 2>/dev/null | sed 's/^# //' || echo "Unknown")

    echo "다음 Task 확인:" >&2
    echo "  📋 $NEXT_TASK_ID: $NEXT_TASK_TITLE" >&2
    echo "" >&2
    echo "Required Action:" >&2
    echo "  Task(" >&2
    echo "    subagent_type: \"04-implementation/code-writer\"," >&2
    echo "    prompt: \"$NEXT_TASK_ID: $NEXT_TASK_TITLE 구현\"," >&2
    echo "    description: \"$NEXT_TASK_TITLE\"" >&2
    echo "  )" >&2
    echo "" >&2
  else
    echo "💡 Tip: PROGRESS.md에서 미완료 Task 확인" >&2
    echo "" >&2
  fi
}

# ============================================
# Priority Memories Loading
# ============================================

load_priority_memories() {
  log "Loading priority memories"

  if [[ ! -d ".serena/memories" ]]; then
    log "No Serena memories directory"
    return 0
  fi

  local memories_loaded=0

  for pattern in "${PRIORITY_MEMORIES[@]}"; do
    # 패턴과 일치하는 메모리 찾기
    local memory_files=$(find .serena/memories -name "${pattern}.md" -type f 2>/dev/null || echo "")

    if [[ -n "$memory_files" ]]; then
      echo "$memory_files" | while read -r memory_file; do
        local memory_name=$(basename "$memory_file" .md)
        log "Priority memory found: $memory_name"
        memories_loaded=$((memories_loaded + 1))

        # 5개 제한
        if [[ $memories_loaded -le 5 ]]; then
          echo "  🧠 $memory_name" >&2
        fi
      done
    fi
  done

  if [[ $memories_loaded -gt 0 ]]; then
    echo "" >&2
    echo "💡 Tip: mcp__serena__read_memory 도구로 세부 내용 확인 가능" >&2
  fi
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== SessionStart Hook Started ==="

  # 마커 파일이 있으면 복원
  if has_marker_file; then
    restore_from_marker
  else
    # 새 세션
    display_new_session_info
  fi

  # Phase 3: Agent 체인 상태 복원 (24시간 이내)
  restore_agent_chain

  # 우선순위 메모리 로드
  load_priority_memories

  log "=== SessionStart Hook Completed ==="
  exit 0
}

# Graceful error handling
trap 'log "Error occurred, but continuing (Graceful Degradation)"; exit 0' ERR

main
