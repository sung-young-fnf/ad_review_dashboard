#!/bin/bash
# Hook 이름: TodoWrite Quality Gate
# 목적: Task 생성 전 품질 자동 검증 (YAGNI, 실행 가능성, 명확성)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LOG_FILE="$(dirname "$0")/../../logs/todo-write-quality.log"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Input Validation (MANDATORY)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INPUT=$(cat)
INPUT_LENGTH=${#INPUT}
log "=== TodoWrite Quality Gate started ==="
log "Input received: $INPUT_LENGTH bytes"

# SAFETY: Empty Input Handling
if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    exit 0  # Silent success
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSON Parsing with Error Handling
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if ! command -v jq &> /dev/null; then
    log "jq not installed, skipping quality check"
    exit 0
fi

# Parse TodoWrite parameters
TASKS=$(echo "$INPUT" | jq -r '.parameters[]? // empty' 2>/dev/null)
if [[ $? -ne 0 ]] || [[ -z "$TASKS" ]]; then
    log "No tasks found or JSON parsing failed"
    exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Quality Gate Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ISSUES=()

# Iterate through each task
echo "$INPUT" | jq -c '.parameters[]?' 2>/dev/null | while IFS= read -r TASK; do
    CONTENT=$(echo "$TASK" | jq -r '.content' 2>/dev/null)
    STATUS=$(echo "$TASK" | jq -r '.status' 2>/dev/null)

    if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
        continue
    fi

    SCORE=100
    TASK_ISSUES=()

    # 1. YAGNI 위반 감지
    if [[ "$CONTENT" =~ (might|maybe|future|later|eventually|possibly|could) ]]; then
        SCORE=$((SCORE - 30))
        TASK_ISSUES+=("YAGNI 위반: 불확실한 요구사항")
        log "YAGNI violation detected: $CONTENT"
    fi

    # 2. 실행 가능성 체크
    if [[ ! "$CONTENT" =~ (구현|작성|수정|추가|삭제|생성|제거|변경|업데이트) ]]; then
        SCORE=$((SCORE - 20))
        TASK_ISSUES+=("실행 불가능: 명확한 동사 누락")
        log "Non-actionable task: $CONTENT"
    fi

    # 3. 명확성 체크
    if [[ ${#CONTENT} -lt 15 ]]; then
        SCORE=$((SCORE - 15))
        TASK_ISSUES+=("불명확: Task 내용이 너무 짧음 (${#CONTENT}자)")
        log "Too short task: $CONTENT"
    fi

    # 품질 보고서 출력
    if [[ ${#TASK_ISSUES[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️ Task 품질 경고 (점수: ${SCORE}/100)"
        echo "Task: \"$CONTENT\""
        echo ""
        for ISSUE in "${TASK_ISSUES[@]}"; do
            echo "  - $ISSUE"
        done
        echo ""

        # 차단 조건: 60점 미만
        if [[ $SCORE -lt 60 ]]; then
            echo "❌ Task 품질 부족 (${SCORE}점). 더 명확하게 재작성해주세요."
            echo ""
            log "Task blocked due to low quality score: $SCORE"
            exit 1  # Task 생성 차단
        fi
    fi
done

log "TodoWrite Quality Gate passed"
exit 0
