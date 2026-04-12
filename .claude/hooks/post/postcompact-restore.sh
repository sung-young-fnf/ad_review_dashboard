#!/bin/bash
# .claude/hooks/post/postcompact-restore.sh
# PostCompact Hook - Context Restoration Guide + Compact Counter (EP199-S06)
# 컨텍스트 압축 후 보존된 정보를 기반으로 복구 안내
# + 2회 이상 compact 시 handoff 제안
# Pairs with: precompact-preserve.sh (PreCompact)
# Version: v1.1 (2026-03-18)

# Graceful Degradation
trap 'exit 0' ERR

# Configuration
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
MARKER_FILE="/tmp/claude-compaction-marker-${PROJECT_NAME}.json"
LOG_FILE="/tmp/claude-postcompact.log"
COMPACT_COUNT_FILE="${PROJECT_ROOT}/.claude/session-compact-count"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Read stdin (PostCompact hook input)
INPUT=""
if read -t 1 INPUT 2>/dev/null; then
  log "Input received: ${#INPUT} bytes"
fi

log "PostCompact triggered for project: $PROJECT_NAME"

# --- EP199-S06: Compact Counter ---
COMPACT_COUNT=0
if [ -f "$COMPACT_COUNT_FILE" ]; then
  COMPACT_COUNT=$(cat "$COMPACT_COUNT_FILE" 2>/dev/null || echo "0")
  # Validate: must be a number
  case "$COMPACT_COUNT" in
    ''|*[!0-9]*) COMPACT_COUNT=0 ;;
  esac
fi
COMPACT_COUNT=$((COMPACT_COUNT + 1))
echo "$COMPACT_COUNT" > "$COMPACT_COUNT_FILE" 2>/dev/null || true
log "Compact count: $COMPACT_COUNT"

if [ "$COMPACT_COUNT" -ge 2 ]; then
  echo "[Context-Warning] ${COMPACT_COUNT}회 compact 감지. 컨텍스트 품질 저하 가능. /handoff 실행 후 새 세션 시작을 권장합니다." >&2
fi
# --- End EP199-S06 ---

# Check if marker file exists from PreCompact
if [[ ! -f "$MARKER_FILE" ]]; then
  log "No marker file found, skipping restore guidance"
  echo '{"systemMessage": "✅ Compaction 완료. (PreCompact marker 없음 — 새 세션 시작 가능)"}'
  exit 0
fi

# Parse marker file
EPIC="unknown"
TASK="none"
MEMORY_COUNT=0
FILE_COUNT=0

if command -v jq &>/dev/null; then
  EPIC=$(jq -r '.context.epic // "unknown"' "$MARKER_FILE" 2>/dev/null || echo "unknown")
  TASK=$(jq -r '.context.task // "none"' "$MARKER_FILE" 2>/dev/null || echo "none")
  MEMORY_COUNT=$(jq -r '.context.memories | length' "$MARKER_FILE" 2>/dev/null || echo "0")
  FILE_COUNT=$(jq -r '.context.critical_files | length' "$MARKER_FILE" 2>/dev/null || echo "0")
fi

log "Restored context: epic=$EPIC, task=$TASK, memories=$MEMORY_COUNT, files=$FILE_COUNT"

# Build restore guidance message
RESTORE_MSG="✅ Compaction 완료 — 컨텍스트 복구 가이드:"
RESTORE_MSG+="\n  📋 Epic: ${EPIC}"

if [[ "$TASK" != "none" ]]; then
  RESTORE_MSG+="\n  🔧 진행 중 Task: ${TASK}"
fi

RESTORE_MSG+="\n  🧠 Serena 메모리: ${MEMORY_COUNT}개 보존됨"
RESTORE_MSG+="\n  📁 핵심 파일: ${FILE_COUNT}개 기록됨"
RESTORE_MSG+="\n  💡 복구: serena/list_memories + PROGRESS.md 확인 권장"

# Clean up marker file (one-time use)
rm -f "$MARKER_FILE" 2>/dev/null || true
log "Marker file consumed and removed"

# Output as systemMessage for Claude context
echo "{\"systemMessage\": \"$(echo -e "$RESTORE_MSG" | tr '\n' ' ')\"}"

log "PostCompact restore guidance delivered"
exit 0
