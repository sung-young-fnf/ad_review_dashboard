#!/bin/bash
#
# PreCompact Hook - Context Preservation
#
# Purpose: 컨텍스트 압축 전 중요 프로젝트 정보 보존
# Trigger: Claude Code가 컨텍스트 윈도우 초과로 Compaction 실행 전
# Effect: 핵심 파일/메모리를 요약하여 복원용 Marker 생성
#
# Input (stdin JSON):
# {
#   "session_id": "uuid",
#   "transcript_path": "/path/to/transcript.json",
#   "trigger": "manual" | "auto",
#   "custom_instructions": "..."
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
LOG_FILE="/tmp/claude-precompact.log"

# 중요 파일 패턴
CRITICAL_FILES=(
  "CLAUDE.md"
  ".claude/CLAUDE.md"
  "docs/epics/**/epic.md"
  "docs/epics/**/stories/*.md"
  "docs/epics/**/tasks/*.md"
  "PROGRESS.md"
  ".claude/AGENT_CATALOG.md"
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
  log "Empty input - skipping PreCompact hook"
  exit 0
fi

# JSON 파싱 (jq 실패 시 조용히 종료)
SESSION_ID=""
TRIGGER=""
if command -v jq &> /dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
  TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "auto"' 2>/dev/null || echo "auto")
else
  log "jq not found - using defaults"
  SESSION_ID="unknown"
  TRIGGER="auto"
fi

log "PreCompact triggered: session=$SESSION_ID, trigger=$TRIGGER"

# ============================================
# Critical Files Collection
# ============================================

collect_critical_files() {
  # 명시적 파일 경로로 검색 (macOS bash 3.x 호환)
  {
    # 단일 파일들
    [[ -f "CLAUDE.md" ]] && echo "CLAUDE.md"
    [[ -f ".claude/CLAUDE.md" ]] && echo ".claude/CLAUDE.md"
    [[ -f "PROGRESS.md" ]] && echo "PROGRESS.md"
    [[ -f ".claude/AGENT_CATALOG.md" ]] && echo ".claude/AGENT_CATALOG.md"

    # Epic/Story/Task 파일들 (재귀 검색)
    [[ -d "docs/epics" ]] && {
      find docs/epics -type f -name "epic.md" 2>/dev/null
      find docs/epics -type f -path "*/stories/*.md" 2>/dev/null
      find docs/epics -type f -path "*/tasks/*.md" 2>/dev/null
    }
  } | sort -u
}

# ============================================
# Context Extraction
# ============================================

extract_current_epic() {
  # 진행 중인 Epic 찾기
  if [[ -f "PROGRESS.md" ]]; then
    grep -A 5 "## Epic" PROGRESS.md 2>/dev/null | grep -E "status.*in.progress" | head -1 || echo "unknown"
  else
    echo "unknown"
  fi
}

extract_current_task() {
  # 진행 중인 Task 찾기 (체크박스 [ ])
  find docs/epics -name "*.md" -type f -exec grep -l "\- \[ \]" {} \; 2>/dev/null | head -1 || echo "none"
}

extract_serena_memories() {
  # Serena MCP 메모리 목록 (최대 10개)
  if [[ -d ".serena/memories" ]]; then
    find .serena/memories -name "*.md" -type f 2>/dev/null | head -10 | while read -r file; do
      basename "$file" .md
    done
  fi
}

# ============================================
# Summary Generation
# ============================================

generate_summary() {
  local critical_files=("$@")
  local summary=""

  # 파일별 미리보기 (첫 3줄)
  for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]]; then
      local preview=$(head -3 "$file" 2>/dev/null | tr '\n' ' ')
      summary+="$file: ${preview:0:100}... "
    fi
  done

  echo "${summary:0:500}"  # 500자 제한
}

# ============================================
# Marker Creation
# ============================================

create_marker() {
  local current_epic="$1"
  local current_task="$2"
  local summary="$3"
  shift 3
  local memories=("$@")

  # JSON 생성
  cat > "$MARKER_FILE" <<EOF
{
  "trigger": "precompact",
  "session_id": "$SESSION_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_root": "$PROJECT_ROOT",
  "context": {
    "epic": "$current_epic",
    "task": "$current_task",
    "summary": "$summary",
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
}

# ============================================
# Main Execution
# ============================================

main() {
  log "=== PreCompact Hook Started ==="

  # 1. 중요 파일 수집
  critical_files=()
  while IFS= read -r line; do
    critical_files+=("$line")
  done < <(collect_critical_files)
  log "Critical files collected: ${#critical_files[@]}"

  # 2. 현재 컨텍스트 추출
  local current_epic=$(extract_current_epic)
  local current_task=$(extract_current_task)
  log "Current context: epic=$current_epic, task=$current_task"

  # 3. Serena 메모리 수집
  memories=()
  while IFS= read -r line; do
    memories+=("$line")
  done < <(extract_serena_memories)
  log "Serena memories: ${#memories[@]}"

  # 4. 요약 생성
  local summary=$(generate_summary "${critical_files[@]}")
  log "Summary generated: ${#summary} chars"

  # 5. Marker 생성
  create_marker "$current_epic" "$current_task" "$summary" "${memories[@]}"

  # 6. 성공 메시지 (stderr로 출력하여 Claude에게 표시)
  echo "✅ PreCompact: 핵심 컨텍스트 보존 완료 (${#critical_files[@]}개 파일, ${#memories[@]}개 메모리)" >&2

  log "=== PreCompact Hook Completed ==="
  exit 0
}

# Graceful error handling
trap 'log "Error occurred, but continuing (Graceful Degradation)"; exit 0' ERR

main
