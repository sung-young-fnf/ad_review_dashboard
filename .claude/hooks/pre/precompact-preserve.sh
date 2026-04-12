#!/bin/bash
# .claude/hooks/pre/precompact-preserve.sh
# PreCompact Hook - Context Preservation
# 컨텍스트 압축 전 중요 프로젝트 정보 보존
# Version: v3.1 (Refactored: 228줄 → 180줄)

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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [precompact-preserve] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

log_debug "=== HOOK START ==="

# ============================================================================
# Configuration
# ============================================================================
PROJECT_ROOT="$(pwd)"
MARKER_FILE="/tmp/claude-compaction-marker-$(basename "$PROJECT_ROOT").json"
LOG_FILE="/tmp/claude-precompact.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ============================================================================
# Phase 0: stdin 읽기
# ============================================================================
INPUT=""
if read -t 1 INPUT 2>/dev/null; then
  log_debug "Input received: ${#INPUT} bytes"
else
  log_debug "No input or timeout"
fi

# 빈 입력 처리
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log_debug "Skipped: empty input"
  exit 0
fi

# ============================================================================
# Phase 1: JSON 파싱 (안전하게)
# ============================================================================
SESSION_ID="unknown"
TRIGGER="auto"

if command -v jq &> /dev/null; then
  if echo "$INPUT" | jq -e . >/dev/null 2>&1; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
    TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "auto"' 2>/dev/null || echo "auto")
  fi
fi

log "PreCompact triggered: session=$SESSION_ID, trigger=$TRIGGER"
log_debug "SESSION_ID: $SESSION_ID, TRIGGER: $TRIGGER"

# ============================================================================
# Step 1: 중요 파일 수집 (간소화)
# ============================================================================
collect_critical_files() {
  {
    # 단일 파일들
    [[ -f "CLAUDE.md" ]] && echo "CLAUDE.md"
    [[ -f ".claude/CLAUDE.md" ]] && echo ".claude/CLAUDE.md"
    [[ -f "PROGRESS.md" ]] && echo "PROGRESS.md"
    [[ -f ".claude/AGENT_CATALOG.md" ]] && echo ".claude/AGENT_CATALOG.md"

    # Epic/Story/Task 파일들 (최대 20개)
    [[ -d "docs/epics" ]] && {
      find docs/epics -type f -name "epic.md" 2>/dev/null | head -5
      find docs/epics -type f -path "*/stories/*.md" 2>/dev/null | head -5
      find docs/epics -type f -path "*/tasks/*.md" 2>/dev/null | head -10
    }
  } | sort -u
}

critical_files=()
while IFS= read -r line; do
  critical_files+=("$line")
done < <(collect_critical_files)

log "Critical files collected: ${#critical_files[@]}"
log_debug "Files: ${critical_files[@]}"

# ============================================================================
# Step 2: 현재 컨텍스트 추출 (간소화)
# ============================================================================
extract_current_epic() {
  if [[ -f "PROGRESS.md" ]]; then
    grep -A 5 "## Epic" PROGRESS.md 2>/dev/null | grep -E "status.*in.progress" | head -1 || echo "unknown"
  else
    echo "unknown"
  fi
}

extract_current_task() {
  find docs/epics -name "*.md" -type f -exec grep -l "\- \[ \]" {} \; 2>/dev/null | head -1 || echo "none"
}

current_epic=$(extract_current_epic)
current_task=$(extract_current_task)

log "Current context: epic=$current_epic, task=$current_task"
log_debug "Epic: $current_epic, Task: $current_task"

# ============================================================================
# Step 3: Serena 메모리 수집 (최대 10개)
# ============================================================================
memories=()
if [[ -d ".serena/memories" ]]; then
  while IFS= read -r file; do
    memories+=("$(basename "$file" .md)")
  done < <(find .serena/memories -name "*.md" -type f 2>/dev/null | head -10)
fi

log "Serena memories: ${#memories[@]}"
log_debug "Memories: ${memories[@]}"

# ============================================================================
# Step 4: Marker 파일 생성 (JSON)
# ============================================================================
cat > "$MARKER_FILE" <<EOF
{
  "trigger": "precompact",
  "session_id": "$SESSION_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_root": "$PROJECT_ROOT",
  "context": {
    "epic": "$current_epic",
    "task": "$current_task",
    "memories": [$(printf '"%s",' "${memories[@]}" | sed 's/,$//')],
    "critical_files": [$(printf '"%s",' "${critical_files[@]}" | sed 's/,$//')],
    "restore_commands": [
      "cat CLAUDE.md",
      "cat $current_task",
      "mcp__serena__list_memories"
    ]
  }
}
EOF

log "Marker created: $MARKER_FILE"
log_debug "Marker file: $MARKER_FILE"

# ============================================================================
# Step 5: 성공 메시지 출력 (Plain Text)
# ============================================================================
cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

✅ PreCompact: 핵심 컨텍스트 보존 완료
  - 파일: ${#critical_files[@]}개
  - 메모리: ${#memories[@]}개
  - Epic: $current_epic
  - Task: $current_task

Marker: $MARKER_FILE

EOF

log "=== PreCompact Hook Completed ==="
log_debug "=== HOOK END ==="
exit 0
