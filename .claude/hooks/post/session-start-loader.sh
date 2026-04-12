#!/bin/bash
#
# SessionStart Hook - Automatic Context Loading & Hook Validation
#
# Purpose: 세션 시작 시 자동 컨텍스트 로딩 및 복원 + Hook 시스템 검증
# Trigger: Claude Code 세션 시작 시
# Effect: PreCompact 마커 복원, 세션 시작 시간 5분 → 10초, Hook 자동 검증
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

# Graceful degradation - 에러 발생 시에도 계속 진행
set +e

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
MARKER_FILE="/tmp/claude-compaction-marker-$(basename "$PROJECT_ROOT").json"
LOG_FILE="/tmp/claude-session-start.log"

# 자동 로드할 중요 메모리 (YAGNI: 실제 사용되는 것만 유지)
# Note: 정규식 패턴(*.*)은 find -name에서 지원되지 않으므로 제거
PRIORITY_MEMORIES=(
  "current_project_architecture"
  "current_project_tech_stack"
  "database_schema_analysis"
)

# ============================================
# Logging
# ============================================

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ============================================
# Hook System Validation
# ============================================

validate_hooks() {
  local HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
  local total_hooks=0
  local failed_hooks=0

  echo "🔍 Validating Hook System..."

  # Pre hooks
  if [[ -d "$HOOKS_DIR/pre" ]]; then
    for hook in "$HOOKS_DIR/pre"/*.sh; do
      [[ -f "$hook" ]] || continue
      total_hooks=$((total_hooks + 1))

      # 실행 권한 확인
      if [[ ! -x "$hook" ]]; then
        echo "  ⚠️  Fixing permission: $(basename "$hook")"
        chmod 755 "$hook" 2>/dev/null && log "Fixed permission: $hook"
        failed_hooks=$((failed_hooks + 1))
      fi
    done
  fi

  # Post hooks
  if [[ -d "$HOOKS_DIR/post" ]]; then
    for hook in "$HOOKS_DIR/post"/*.sh; do
      [[ -f "$hook" ]] || continue
      total_hooks=$((total_hooks + 1))

      if [[ ! -x "$hook" ]]; then
        echo "  ⚠️  Fixing permission: $(basename "$hook")"
        chmod 755 "$hook" 2>/dev/null && log "Fixed permission: $hook"
        failed_hooks=$((failed_hooks + 1))
      fi
    done
  fi

  # Root level hooks
  for hook in "$HOOKS_DIR"/*.sh; do
    [[ -f "$hook" ]] || continue
    total_hooks=$((total_hooks + 1))

    if [[ ! -x "$hook" ]]; then
      echo "  ⚠️  Fixing permission: $(basename "$hook")"
      chmod 755 "$hook" 2>/dev/null && log "Fixed permission: $hook"
      failed_hooks=$((failed_hooks + 1))
    fi
  done

  if [[ $failed_hooks -eq 0 ]]; then
    echo "  ✅ All $total_hooks hooks validated"
  else
    echo "  ⚠️  Fixed $failed_hooks of $total_hooks hooks"
  fi
  echo ""

  log "Hook validation: $total_hooks total, $failed_hooks fixed"
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
AGENT_TYPE=""
if command -v jq &> /dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
  TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // ""' 2>/dev/null || echo "")
  # Claude Code 2.1.2: --agent 옵션으로 시작 시 agent_type 전달됨
  AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null || echo "")
else
  log "jq not found - using defaults"
  SESSION_ID="unknown"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  AGENT_TYPE=""
fi

log "SessionStart: session=$SESSION_ID, timestamp=$TIMESTAMP, agent_type=$AGENT_TYPE"

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
  echo "═══════════════════════════════════════"
  echo "✅ 세션 컨텍스트 자동 복원 완료"
  echo "═══════════════════════════════════════"
  echo ""
  echo "📋 이전 세션 정보:"
  echo "  Epic: $prev_epic"
  echo "  Task: $prev_task"
  echo ""

  # 요약 표시 (첫 200자)
  if [[ -n "$prev_summary" ]]; then
    echo "💡 작업 요약:"
    echo "  ${prev_summary:0:200}..."
    echo ""
  fi

  # 메모리 목록 표시
  if [[ -n "$memories_json" ]]; then
    echo "🧠 로드된 메모리:"
    echo "$memories_json" | while read -r memory; do
      echo "  - $memory"
    done
    echo ""
  fi

  # 복원 명령어 실행 (중요 파일 표시)
  if [[ -f "CLAUDE.md" ]]; then
    echo "📄 프로젝트 규칙: CLAUDE.md 로드 완료"
  fi

  if [[ "$prev_task" != "none" ]] && [[ -f "$prev_task" ]]; then
    echo "📄 현재 Task: $prev_task 로드 완료"
  fi

  echo "═══════════════════════════════════════"

  # 마커 파일 삭제 (이미 복원했으므로)
  rm -f "$MARKER_FILE" 2>/dev/null || true
  log "Marker file removed after restoration"
}

# ============================================
# New Session Info
# ============================================

display_new_session_info() {
  log "New session without previous context"

  # NOTE: stdout으로 출력 → Claude 컨텍스트에 자동 주입됨
  echo "═══════════════════════════════════════"
  echo "🚀 새 세션 시작"
  echo "═══════════════════════════════════════"
  echo ""
  echo "프로젝트: $(basename "$PROJECT_ROOT")"
  echo "세션 ID: $SESSION_ID"

  # Claude Code 2.1.2: agent_type 기반 맞춤 초기화
  if [[ -n "$AGENT_TYPE" ]]; then
    echo "에이전트: $AGENT_TYPE"
    echo ""
    case "$AGENT_TYPE" in
      *"code-writer"*)
        echo "🔧 Code-Writer 모드: Task 파일 위치 확인 필요"
        echo "   → PROGRESS.md에서 현재 Task 확인"
        ;;
      *"error-fixer"*)
        echo "🔍 Error-Fixer 모드: historian 먼저 호출 권장"
        echo "   → mcp-cli call historian/get_error_solutions"
        ;;
      *"db-code-writer"*)
        echo "🗃️ DB-Code-Writer 모드: 스키마 변경 주의"
        echo "   → Alembic migration 필수"
        ;;
      *)
        echo "📋 Agent 모드: $AGENT_TYPE"
        ;;
    esac
  fi
  echo ""

  # ============================================
  # SERVICE_CONTEXT.md 체크 (최우선) - 양쪽 경로 지원
  # ============================================
  local SERVICE_CONTEXT_PATH=""

  if [[ -f "docs/context/SERVICE_CONTEXT.md" ]]; then
    SERVICE_CONTEXT_PATH="docs/context/SERVICE_CONTEXT.md"
  elif [[ -f "docs/SERVICE_CONTEXT.md" ]]; then
    SERVICE_CONTEXT_PATH="docs/SERVICE_CONTEXT.md"
  fi

  if [[ -z "$SERVICE_CONTEXT_PATH" ]]; then
    echo ""
    echo "🆕 NEW PROJECT DETECTED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️ SERVICE_CONTEXT.md를 찾을 수 없습니다"
    echo "   (docs/context/ 또는 docs/ 경로)"
    echo ""
    echo "📋 먼저 프로젝트 초기화를 진행하세요:"
    echo "   → \"프로젝트 초기화\" 입력"
    echo "   또는"
    echo "   → \"프로젝트 초기화 스킵\" (범용 모드)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "═══════════════════════════════════════"
    return 1  # 새 프로젝트 표시 (main에서 조기 종료용)
  fi

  # SERVICE_CONTEXT.md 있으면 정상 진행
  echo "✅ $SERVICE_CONTEXT_PATH 로드 완료"

  # CLAUDE.md 확인
  if [[ -f "CLAUDE.md" ]]; then
    echo "✅ CLAUDE.md 로드 완료"
  else
    echo "⚠️ CLAUDE.md 파일을 찾을 수 없습니다"
  fi

  # .claude/CLAUDE.md 확인
  if [[ -f ".claude/CLAUDE.md" ]]; then
    echo "✅ .claude/CLAUDE.md 로드 완료"
  fi

  # PROGRESS.md 확인
  if [[ -f "PROGRESS.md" ]]; then
    echo "✅ PROGRESS.md 로드 완료"

    # 진행 중인 Epic/Task 표시
    local current_epic=$(grep -A 5 "## Epic" PROGRESS.md 2>/dev/null | grep -E "status.*in.progress" | head -1 || echo "")
    if [[ -n "$current_epic" ]]; then
      echo "📋 진행 중인 Epic: $current_epic"
    fi
  fi

  echo "═══════════════════════════════════════"
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
  echo ""
  echo "╔═══════════════════════════════════════════════════════════════════════════╗"
  echo "║                  🔄 Agent 체인 상태 복원 (Phase 3)                       ║"
  echo "╚═══════════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "이전 세션:"
  echo "  - 마지막 Agent: $LAST_AGENT"
  echo "  - 마지막 Task: $LAST_TASK"
  echo "  - 마지막 Story: $LAST_STORY"
  echo "  - 마지막 Epic: $LAST_EPIC"
  echo "  - 경과 시간: $((TIME_DIFF / 60)) 분 전"
  echo ""
  echo "⚠️ REMINDER: Agent 체인을 계속 진행하세요."
  echo ""

  # 다음 Task 찾기
  find_next_task_for_session "$LAST_EPIC" "$LAST_TASK"

  echo "═══════════════════════════════════════════════════════════════════════════"
  echo ""

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

  # 공통 유틸리티 로드 (DRY 원칙)
  local UTILS_DIR="$PROJECT_ROOT/.claude/hooks/utils"
  if [[ -f "$UTILS_DIR/task-navigation.sh" ]]; then
    source "$UTILS_DIR/task-navigation.sh"
  else
    log "task-navigation.sh not found, using fallback"
    return 0
  fi

  # 공통 함수로 다음 Task 정보 조회
  local NEXT_INFO=$(get_next_task_info "$TASK_DIR" "$TASK_ID")

  if [[ -n "$NEXT_INFO" ]]; then
    local NEXT_TASK_ID=$(echo "$NEXT_INFO" | cut -d'|' -f1)
    local NEXT_TASK_TITLE=$(echo "$NEXT_INFO" | cut -d'|' -f2)

    echo "다음 Task 확인:"
    echo "  📋 $NEXT_TASK_ID: $NEXT_TASK_TITLE"
    echo ""
    echo "Required Action:"
    echo "  Task("
    echo "    subagent_type: \"04-implementation/code-writer\","
    echo "    prompt: \"$NEXT_TASK_ID: $NEXT_TASK_TITLE 구현\","
    echo "    description: \"$NEXT_TASK_TITLE\""
    echo "  )"
    echo ""
  else
    echo "💡 Tip: PROGRESS.md에서 미완료 Task 확인"
    echo ""
  fi
}

# ============================================
# Previous Session Handoff Loading (v2.0)
# ============================================

load_previous_handoff() {
  local HANDOFF_FILE="$PROJECT_ROOT/.claude/handoffs/latest-handoff.md"
  local HANDOFF_JSON="/tmp/claude-session-handoff-$(basename "$PROJECT_ROOT").json"

  # 핸드오프 파일 존재 확인
  if [[ ! -f "$HANDOFF_FILE" ]]; then
    log "No previous handoff file found"
    return 0
  fi

  # 24시간 이내 핸드오프만 표시
  local file_age=0
  if [[ "$(uname)" == "Darwin" ]]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$HANDOFF_FILE" 2>/dev/null || echo "0") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$HANDOFF_FILE" 2>/dev/null || echo "0") ))
  fi

  if [[ $file_age -ge 86400 ]]; then
    log "Handoff file too old (${file_age}s > 86400s)"
    return 0
  fi

  # 핸드오프 요약 표시
  echo ""
  echo "---------------------------------------"
  echo "  Previous Session Handoff"
  echo "---------------------------------------"

  # JSON에서 핵심 정보 추출 (있으면)
  if [[ -f "$HANDOFF_JSON" ]] && command -v jq &>/dev/null; then
    local epic=$(jq -r '.context.epic_id // "unknown"' "$HANDOFF_JSON" 2>/dev/null)
    local task=$(jq -r '.context.current_task // "none"' "$HANDOFF_JSON" 2>/dev/null)
    local pending=$(jq -r '.context.pending_tasks // 0' "$HANDOFF_JSON" 2>/dev/null)
    local failed=$(jq -r '.failed_approaches_count // 0' "$HANDOFF_JSON" 2>/dev/null)
    local elapsed_min=$((file_age / 60))

    echo "  Epic: $epic | Task: $task"
    echo "  Pending: ${pending}개 | Failed: ${failed}건"
    echo "  Age: ${elapsed_min}분 전"
  else
    # Markdown에서 간단 추출
    local first_lines=$(head -10 "$HANDOFF_FILE" 2>/dev/null | grep -E "(Epic|Progress|Task)" | head -3)
    echo "$first_lines" | sed 's/^/  /'
  fi

  echo ""
  echo "  Full: cat .claude/handoffs/latest-handoff.md"
  echo "---------------------------------------"
  echo ""

  log "Previous handoff loaded (age: ${file_age}s)"
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
    # 패턴과 일치하는 메모리 찾기 (프로세스 치환으로 변수 누수 방지)
    while IFS= read -r memory_file; do
      [[ -z "$memory_file" ]] && continue
      local memory_name=$(basename "$memory_file" .md)
      log "Priority memory found: $memory_name"
      memories_loaded=$((memories_loaded + 1))

      # 5개 제한
      if [[ $memories_loaded -le 5 ]]; then
        echo "  🧠 $memory_name"
      fi
    done < <(find .serena/memories -name "${pattern}.md" -type f 2>/dev/null)
  done

  if [[ $memories_loaded -gt 0 ]]; then
    echo ""
    echo "💡 Tip: mcp__serena__read_memory 도구로 세부 내용 확인 가능"
  fi
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== SessionStart Hook Started ==="

  # EP199-S06: 세션 시작 시 compact 카운터 리셋
  local COMPACT_COUNT_FILE="$PROJECT_ROOT/.claude/session-compact-count"
  rm -f "$COMPACT_COUNT_FILE" 2>/dev/null || true
  log "Compact counter reset"

  # Hook 시스템 검증 (최우선 실행)
  validate_hooks

  # 마커 파일이 있으면 복원
  if has_marker_file; then
    restore_from_marker
  else
    # 새 세션 - SERVICE_CONTEXT.md 체크 포함
    if ! display_new_session_info; then
      # 새 프로젝트 (SERVICE_CONTEXT.md 없음) - 조기 종료
      log "New project detected - skipping other initializations"
      log "=== SessionStart Hook Completed (New Project) ==="
      exit 0
    fi
  fi

  # Phase 2.5: 이전 세션 핸드오프 자동 로드 (NEW v2.0)
  load_previous_handoff

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
