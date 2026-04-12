#!/bin/bash
# =============================================================================
# pattern-compliance-checker.sh - Defense Line 4: 패턴 준수 Runtime 검증
# =============================================================================
#
# Zero-Token Version: stdout 출력 없이 .dirty-files에만 기록
# 토큰 소비: 0 (기존 ~500 토큰)
#
# =============================================================================

# Graceful Degradation
trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DOCS_EPICS="$REPO_ROOT/docs/epics"

# Zero-Token: mark-dirty.sh 로드
MARK_DIRTY_SCRIPT="$REPO_ROOT/.claude/utils/mark-dirty.sh"
if [[ -f "$MARK_DIRTY_SCRIPT" ]]; then
    source "$MARK_DIRTY_SCRIPT"
else
    # Fallback: mark_dirty_file 함수 없으면 정의
    mark_dirty_file() {
        local file="$1"
        local check_type="${2:-pattern}"
        local check_status="${3:-OK}"
        echo "${check_status}:${check_type}:${file}" >> "$REPO_ROOT/.claude/.dirty-files"
    }
fi

# stdin에서 event_info 받기
event_info=$(cat)
if [ -z "$event_info" ]; then
    exit 0
fi

SESSION_ID=$(echo "$event_info" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")

# Agent 정보 수집
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-unknown}"
AGENT_TASK="${CLAUDE_TASK_ID:-}"
AGENT_EPIC="${CLAUDE_EPIC_ID:-}"
AGENT_STORY="${CLAUDE_STORY_ID:-}"

# code-writer Agent만 검증
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
    exit 0
fi

# Task 파일 경로 결정
TASK_FILE=""
if [ -n "$AGENT_EPIC" ]; then
    TASK_FILE=$(find "$DOCS_EPICS/$AGENT_EPIC/tasks" -name "${AGENT_TASK}*.md" 2>/dev/null | head -1)
else
    TASK_FILE=$(find "$DOCS_EPICS/_backlog" -name "${AGENT_TASK}_*.md" -o -name "${AGENT_TASK}.md" 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
    exit 0
fi

# Zero-Token: 시작 기록 (stdout 없음)
mark_dirty_file "$TASK_FILE" "pattern-check" "OK"

# 패턴 체크리스트 확인
if ! grep -q "## 필수 패턴 준수 \[MANDATORY\]" "$TASK_FILE"; then
    exit 0
fi

# 미체크 항목 추출
UNCHECKED_ITEMS=$(sed -n '/## 필수 패턴 준수 \[MANDATORY\]/,/^## /p' "$TASK_FILE" | grep -E "^\- \[ \]" || echo "")

if [ -z "$UNCHECKED_ITEMS" ]; then
    # Zero-Token: 성공 기록
    mark_dirty_file "$TASK_FILE" "pattern-complete" "OK"
    exit 0
fi

# Git diff로 수정 파일 추출
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")

if [ -z "$MODIFIED_FILES" ]; then
    exit 0
fi

# 패턴 위반 검증
VIOLATIONS=""
VIOLATION_COUNT=0

# API Routes 패턴
if echo "$UNCHECKED_ITEMS" | grep -q "GET 메서드 구현"; then
    if ! echo "$MODIFIED_FILES" | xargs -I {} grep -l "export async function GET" {} 2>/dev/null | grep -q "route.ts"; then
        VIOLATIONS="${VIOLATIONS}GET_METHOD_MISSING,"
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
    fi
fi

if echo "$UNCHECKED_ITEMS" | grep -q "POST 메서드 구현"; then
    if ! echo "$MODIFIED_FILES" | xargs -I {} grep -l "export async function POST" {} 2>/dev/null | grep -q "route.ts"; then
        VIOLATIONS="${VIOLATIONS}POST_METHOD_MISSING,"
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
    fi
fi

# Admin Impersonation 패턴
if echo "$UNCHECKED_ITEMS" | grep -q "session.backendToken"; then
    if ! echo "$MODIFIED_FILES" | xargs grep -l "session.backendToken" 2>/dev/null >/dev/null; then
        VIOLATIONS="${VIOLATIONS}BACKEND_TOKEN_MISSING,"
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
    fi
fi

# Zero-Token: 위반 결과 기록 (stdout 없음)
if [ -n "$VIOLATIONS" ]; then
    # ERROR 상태로 기록 - 다른 Hook/Agent가 나중에 처리
    mark_dirty_file "$TASK_FILE" "pattern-violation" "ERROR"
    mark_dirty_file "violations:$VIOLATIONS" "pattern-details" "ERROR"
    exit 0  # Graceful degradation - 차단하지 않음
fi

# Zero-Token: 성공 기록
mark_dirty_file "$TASK_FILE" "pattern-verified" "OK"
UNCHECKED_COUNT=$(echo "$UNCHECKED_ITEMS" | wc -l | tr -d ' ')
mark_dirty_file "unchecked:$UNCHECKED_COUNT" "pattern-pending" "WARN"

exit 0
