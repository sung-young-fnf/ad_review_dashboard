#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enhanced Bash Hook v2 - PROJECT_STATE.json Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Configuration
PROJECT_ROOT="/Users/yun/work/workspace/breeze_sample/okr2"
LOG_FILE="$(dirname "$0")/hook.log"
STATE_FILE="$PROJECT_ROOT/docs/.state/PROJECT_STATE.json"
DEBUG_MODE="${DEBUG_HOOK:-0}"

# Colors (disabled for Claude Code)
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logging Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG_FILE"
}

debug() {
    if [[ "$DEBUG_MODE" == "1" ]]; then
        log "DEBUG: $1"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROJECT_STATE.json Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

read_state_field() {
    local field="$1"
    if [[ -f "$STATE_FILE" ]]; then
        if command -v jq &> /dev/null; then
            jq -r "$field" "$STATE_FILE" 2>/dev/null
        else
            # Fallback: grep + sed (limited)
            grep -o "\"$field\":[^,}]*" "$STATE_FILE" | cut -d':' -f2 | tr -d ' "'
        fi
    else
        echo "0"
    fi
}

get_active_epics() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return
    fi

    if command -v jq &> /dev/null; then
        # jq로 IN_PROGRESS Epic 추출
        jq -r '.epics | to_entries[] | select(.value.status == "IN_PROGRESS") | "\(.key):\(.value.title):\(.value.progress.percentage)"' "$STATE_FILE" 2>/dev/null
    else
        # Fallback: grep (정확도 낮음)
        grep -o '"EP[^"]*":{[^}]*"status":"IN_PROGRESS"[^}]*}' "$STATE_FILE" 2>/dev/null | cut -d'"' -f2
    fi
}

get_stale_epics() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return
    fi

    # 30일 이전 타임스탬프
    thirty_days_ago=$(date -u -v-30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

    if command -v jq &> /dev/null; then
        jq -r ".epics | to_entries[] | select(.value.status == \"IN_PROGRESS\" and .value.lastUpdated < \"$thirty_days_ago\") | .key" "$STATE_FILE" 2>/dev/null
    else
        echo ""
    fi
}

get_blockers() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return
    fi

    if command -v jq &> /dev/null; then
        jq -r '.epics | to_entries[] | select(.value.blockers and (.value.blockers | length > 0)) | "\(.key):\(.value.blockers | join(", "))"' "$STATE_FILE" 2>/dev/null
    else
        echo ""
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Keyword Detection & Agent Recommendation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_keywords() {
    local prompt="$1"
    local keywords=""

    # Domain Detection
    [[ "$prompt" =~ (댓글|comment) ]] && keywords+="COMMENT "
    [[ "$prompt" =~ (드래그|dnd|드랍|순서) ]] && keywords+="DND "
    [[ "$prompt" =~ (인증|auth|로그인|사용자) ]] && keywords+="AUTH "
    [[ "$prompt" =~ (API|api|엔드포인트) ]] && keywords+="API "
    [[ "$prompt" =~ (DB|db|스키마|테이블) ]] && keywords+="DB "
    [[ "$prompt" =~ (UI|ui|화면|컴포넌트) ]] && keywords+="UI "

    # Intent Detection
    [[ "$prompt" =~ (추가|생성|create) ]] && keywords+="CREATE "
    [[ "$prompt" =~ (수정|개선|update) ]] && keywords+="MODIFY "
    [[ "$prompt" =~ (삭제|제거|delete) ]] && keywords+="DELETE "
    [[ "$prompt" =~ (버그|에러|오류|고치) ]] && keywords+="FIX "

    echo "$keywords"
}

recommend_agent() {
    local prompt="$1"
    local keywords="$2"
    local active_epics="$3"
    local blockers="$4"

    # 1. 긴급 상황 우선
    if [[ "$prompt" =~ (긴급|P0|장애|다운|핫픽스) ]] || [[ -n "$blockers" ]]; then
        echo "error-fixer"
        return
    fi

    # 2. DB 작업
    if [[ "$keywords" =~ DB ]] || [[ "$prompt" =~ (마이그레이션|스키마|DDL) ]]; then
        echo "db-code-writer"
        return
    fi

    # 3. 진행 중인 Epic 있으면 Story/Task 우선
    if [[ -n "$active_epics" ]]; then
        local epic_count=$(echo "$active_epics" | wc -l | tr -d ' ')
        if [[ "$epic_count" -gt 0 ]]; then
            # CRUD + UI 결합 → story-creator
            if [[ "$keywords" =~ (CREATE.*UI|API.*UI) ]]; then
                echo "story-creator"
                return
            fi
            # 단순 수정/개선 → task-planner
            if [[ "$keywords" =~ (MODIFY|FIX) ]]; then
                echo "task-planner"
                return
            fi
        fi
    fi

    # 4. 새 시스템/플랫폼 → epic-creator
    if [[ "$prompt" =~ (새로운|신규|시스템|플랫폼|아키텍처) ]]; then
        echo "epic-creator"
        return
    fi

    # 5. CRUD + UI → story-creator
    if [[ "$keywords" =~ (CREATE.*UI|API.*UI|COMMENT|AUTH) ]]; then
        echo "story-creator"
        return
    fi

    # 6. Default
    echo "task-planner"
}

get_domain_context() {
    local keywords="$1"
    local context=""

    # Comment System
    if [[ "$keywords" =~ COMMENT ]]; then
        context+="
📋 Comment System Context:
   - API: /api/v1/campaign-submissions/[id]/comments
   - Backend: comments.controller.ts + comments.service.ts
   - Frontend: commentApi.ts (TanStack Query)
   - Schema: sparknote.comments (userId, content, createdAt)
   - Pattern: Nested API Routes (별도 디렉토리 필수)
"
    fi

    # Drag & Drop
    if [[ "$keywords" =~ DND ]]; then
        context+="
🎨 Drag & Drop Context:
   - Library: @dnd-kit/core, @dnd-kit/sortable
   - Pattern: Optimistic UI (useReorderMenu.ts)
   - Validation: parentKey 검증 (같은 레벨만)
   - Backend: PATCH /api/v1/menus/[id]/reorder
"
    fi

    # Authentication
    if [[ "$keywords" =~ AUTH ]]; then
        context+="
🔐 Authentication Context:
   - NextAuth.js + JWT
   - session.backendToken (NOT accessToken)
   - Admin Impersonation: X-Impersonate-User header
   - Pattern: JwtAuthGuard + AdminGuard (NestJS)
"
    fi

    # Database
    if [[ "$keywords" =~ DB ]]; then
        context+="
🗄️ Database Context:
   - Schema: sparknote.table_name (MANDATORY)
   - NO PostgreSQL ENUM (use VARCHAR + TS literal)
   - Prisma: @@schema(\"sparknote\") in every model
   - Migration: npx prisma migrate dev
"
    fi

    echo "$context"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Hook Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "=== Enhanced Hook v2 started ==="

# Read JSON from stdin
INPUT=$(cat)
log "Input received: ${#INPUT} bytes"
debug "Input: $INPUT"

# Extract prompt
if command -v jq &> /dev/null; then
    PROMPT=$(echo "$INPUT" | jq -r '.prompt')
    log "Parsed prompt (jq): $PROMPT"
else
    # Fallback: grep/sed
    PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | sed 's/"prompt":"\(.*\)"/\1/')
    log "Parsed prompt (grep): $PROMPT"
fi

# Check if development request
if [[ ! "$PROMPT" =~ (추가|생성|수정|개선|삭제|구현|개발|시스템|api|ui|db|컴포넌트|기능|comment|댓글) ]]; then
    log "Skipped: non-development prompt"
    exit 0
fi

# Load PROJECT_STATE
TOTAL_EPICS=$(read_state_field '.project.totalEpics')
ACTIVE_EPICS=$(get_active_epics)
STALE_EPICS=$(get_stale_epics)
BLOCKERS=$(get_blockers)
COMPLETED_TODAY=$(read_state_field '.project.completedToday')

log "STATE: Total=$TOTAL_EPICS, Active=$(echo "$ACTIVE_EPICS" | wc -l | tr -d ' '), Blockers=$(echo "$BLOCKERS" | wc -l | tr -d ' ')"

# Detect keywords
KEYWORDS=$(detect_keywords "$PROMPT")
log "Keywords: $KEYWORDS"

# Recommend agent
AGENT=$(recommend_agent "$PROMPT" "$KEYWORDS" "$ACTIVE_EPICS" "$BLOCKERS")
log "Recommended agent: $AGENT"

# Get domain context
DOMAIN_CONTEXT=$(get_domain_context "$KEYWORDS")

# Determine complexity
COMPLEXITY="task"
[[ "$AGENT" == "epic-creator" ]] && COMPLEXITY="epic"
[[ "$AGENT" == "story-creator" ]] && COMPLEXITY="story"
[[ "$AGENT" == "error-fixer" ]] && COMPLEXITY="hotfix"
[[ "$AGENT" == "db-code-writer" ]] && COMPLEXITY="db"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Output Context Injection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 CLAUDE CONTEXT INJECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 $(echo "$KEYWORDS" | tr '[:lower:]' '[:upper:]') DETECTED

📋 Recommended Agent: $AGENT
   Complexity: $COMPLEXITY
   Confidence: 85%

🔧 okr2 Technical Context:
   - Next.js App Router + NestJS Backend
   - PostgreSQL sparknote schema (MANDATORY prefix)
   - Admin Impersonation: X-Impersonate-User header
EOF

# Domain-specific context
if [[ -n "$DOMAIN_CONTEXT" ]]; then
    echo "$DOMAIN_CONTEXT"
fi

# Active Epics
if [[ -n "$ACTIVE_EPICS" ]]; then
    echo ""
    echo "🔄 진행 중인 Epic:"
    echo "$ACTIVE_EPICS" | while IFS=: read -r epic_id title progress; do
        echo "   - $epic_id: $title ($progress%)"
    done
fi

# Blockers Warning
if [[ -n "$BLOCKERS" ]]; then
    echo ""
    echo "⚠️ 블로커 발견:"
    echo "$BLOCKERS" | while IFS=: read -r epic_id blocker; do
        echo "   - $epic_id: $blocker"
    done
fi

# Stale Epics Warning
if [[ -n "$STALE_EPICS" ]]; then
    echo ""
    echo "⏰ 오래된 Epic (30일+ 미변경):"
    echo "$STALE_EPICS" | while read -r epic_id; do
        echo "   - $epic_id"
    done
fi

# Critical Warnings (always show)
cat << 'EOF'

⚠️ Critical Warnings:
   - NO PostgreSQL ENUM types (use VARCHAR + TypeScript literal)
   - DB Schema Prefix: sparknote.table_name
   - React Hook Dependencies: primitive values only
   - Next.js API Routes: 중첩 엔드포인트는 별도 디렉토리

🎯 AUTO-WORKFLOW ROUTING:
   Enhanced 4-Step: STOP → ANALYZE → INJECT → ROUTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

echo "📨 Original User Message: \"$PROMPT\""
echo ""

log "Hook completed successfully"
exit 0
