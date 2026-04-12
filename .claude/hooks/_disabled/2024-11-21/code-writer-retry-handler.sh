#!/bin/bash
# .claude/hooks/post/code-writer-retry-handler.sh
# code-writer Agent 재시도 메커니즘 (최대 3번)
# Task 미완료 감지 → 자동 재호출

set -e
trap 'exit 0' ERR

# Debug logging
log_debug() {
    echo "[retry-handler $(date +%H:%M:%S)] $1" >&2
}

log_debug "Hook started"

# Read stdin (event_info)
if [ ! -t 0 ]; then
    event_info=$(cat 2>/dev/null || echo "")
else
    event_info=""
fi

# Extract agent type
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
TASK_ID="${CLAUDE_TASK_ID:-}"
EPIC_ID="${CLAUDE_EPIC_ID:-}"

log_debug "AGENT_TYPE: $AGENT_TYPE, TASK_ID: $TASK_ID"

# Only run for code-writer Agent
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
    log_debug "Skipped: Not code-writer Agent"
    exit 0
fi

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
RETRY_STATE="$REPO_ROOT/.claude/.code-writer-retry-state"

# ============================================================================
# Step 1: Task 파일 찾기
# ============================================================================

TASK_FILE=""
if [ -n "$EPIC_ID" ] && [ -n "$TASK_ID" ]; then
    TASK_FILE=$(find "$REPO_ROOT/docs/epics/$EPIC_ID/tasks" -name "${TASK_ID}*.md" 2>/dev/null | head -1)
elif [ -n "$TASK_ID" ]; then
    TASK_FILE=$(find "$REPO_ROOT/docs/epics/_backlog" -name "${TASK_ID}_*.md" -o -name "${TASK_ID}.md" 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
    log_debug "Task file not found: $TASK_ID"
    exit 0
fi

log_debug "Task file: $TASK_FILE"

# ============================================================================
# Step 2: Task 완료 여부 확인 (체크박스)
# ============================================================================

# 미완료 체크박스 개수
UNCHECKED_COUNT=$(grep -c "^- \[ \]" "$TASK_FILE" 2>/dev/null || echo "0")
CHECKED_COUNT=$(grep -c "^- \[x\]" "$TASK_FILE" 2>/dev/null || echo "0")
TOTAL_COUNT=$((UNCHECKED_COUNT + CHECKED_COUNT))

log_debug "Checkboxes: $CHECKED_COUNT/$TOTAL_COUNT completed"

# Task 완료 기준: 80% 이상 체크
if [ $TOTAL_COUNT -eq 0 ]; then
    log_debug "No checkboxes found, skipping"
    exit 0
fi

COMPLETION_RATE=$((CHECKED_COUNT * 100 / TOTAL_COUNT))
log_debug "Completion rate: ${COMPLETION_RATE}%"

if [ $COMPLETION_RATE -ge 80 ]; then
    log_debug "Task completed (${COMPLETION_RATE}% >= 80%)"
    rm -f "$RETRY_STATE"  # 재시도 상태 초기화
    exit 0
fi

# ============================================================================
# Step 3: 재시도 횟수 확인
# ============================================================================

# 재시도 상태 파일 형식: TASK_ID:retry_count:timestamp
RETRY_COUNT=0
if [ -f "$RETRY_STATE" ]; then
    STATE_TASK_ID=$(cat "$RETRY_STATE" | cut -d':' -f1)
    if [ "$STATE_TASK_ID" == "$TASK_ID" ]; then
        RETRY_COUNT=$(cat "$RETRY_STATE" | cut -d':' -f2)
    else
        # 다른 Task → 초기화
        RETRY_COUNT=0
    fi
fi

log_debug "Current retry count: $RETRY_COUNT"

# ============================================================================
# Step 4: 재시도 판단 (최대 3번)
# ============================================================================

MAX_RETRIES=3

if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    # 3번 실패 → 사용자 개입 필요
    cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              ⚠️ CODE-WRITER RETRY LIMIT REACHED                          ║
╚═══════════════════════════════════════════════════════════════════════════╝

❌ code-writer Agent가 ${MAX_RETRIES}번 시도 후에도 Task를 완료하지 못했습니다.

Task: $TASK_ID
완료율: ${COMPLETION_RATE}% (${CHECKED_COUNT}/${TOTAL_COUNT})
미완료 항목: ${UNCHECKED_COUNT}개

📋 미완료 체크박스:
$(grep "^- \[ \]" "$TASK_FILE" | head -10)

💡 권장 조치:

1. **Task 파일 확인**:
   cat "$TASK_FILE"
   → 요구사항이 너무 복잡한지 확인
   → Task 분할 필요 여부 판단

2. **수동 개입**:
   → error-fixer Agent 호출 (복잡한 에러 디버깅)
   → 또는 직접 수정 (ENFORCE_AGENT_CHAIN=0으로 일시 비활성화)

3. **Task 재계획**:
   → task-planner Agent로 Task 재분해
   → 더 작은 단위로 나누기

───────────────────────────────────────────────────────────────────────────

EOF

    # 재시도 상태 초기화
    rm -f "$RETRY_STATE"
    exit 0
fi

# ============================================================================
# Step 5: 재시도 실행
# ============================================================================

RETRY_COUNT=$((RETRY_COUNT + 1))
echo "${TASK_ID}:${RETRY_COUNT}:$(date +%s)" > "$RETRY_STATE"

cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              🔄 CODE-WRITER AUTO-RETRY (Attempt ${RETRY_COUNT}/${MAX_RETRIES})                   ║
╚═══════════════════════════════════════════════════════════════════════════╝

⚠️ code-writer Agent가 Task를 완료하지 못했습니다.

Task: $TASK_ID
완료율: ${COMPLETION_RATE}% (${CHECKED_COUNT}/${TOTAL_COUNT})
미완료 항목: ${UNCHECKED_COUNT}개

🔄 자동 재시도 ${RETRY_COUNT}/${MAX_RETRIES}:

🚀 MANDATORY ACTION (필수 실행):

다음 Agent를 **다시 실행**하세요:

  Task --subagent_type 04-implementation/code-writer --prompt "
  Task ID: $TASK_ID
  Task 파일: $TASK_FILE

  ⚠️ 이전 시도에서 완료하지 못한 항목:
$(grep "^- \[ \]" "$TASK_FILE" | head -10 | sed 's/^/  /')

  위 항목들을 반드시 완료하세요.
  다른 접근 방법을 시도하거나, 더 세밀한 분석이 필요합니다.
  "

💡 재시도 전략:
  - 이전 접근과 다른 방법 시도
  - 더 세밀한 코드 분석
  - mcp__serena__ 도구 활용 (심볼릭 검색)
  - 에러 로그 상세 확인

───────────────────────────────────────────────────────────────────────────

EOF

log_debug "Retry prompt generated (${RETRY_COUNT}/${MAX_RETRIES})"
exit 0
