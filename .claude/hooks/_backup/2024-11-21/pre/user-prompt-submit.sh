#!/bin/bash
# .claude/hooks/pre/user-prompt-submit-compact.sh
# Compact Pre-Hook: 간소화된 컨텍스트 주입 (3000 chars 제한)
# Version: 3.0

set -e
trap 'exit 0' ERR

# ============================================================================
# Phase 0: stdin 읽기
# ============================================================================

if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "")
  if command -v jq &> /dev/null && echo "$INPUT_JSON" | jq -e . &>/dev/null; then
    USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null || echo "$INPUT_JSON")
  else
    USER_INPUT="$INPUT_JSON"
  fi
else
  USER_INPUT="${CLAUDE_USER_PROMPT:-${1:-}}"
fi

# 빈 입력이면 조용히 종료
if [[ -z "$USER_INPUT" ]] || [[ "${#USER_INPUT}" -lt 2 ]]; then
  exit 0
fi

# Agent 내부 실행 감지 (무한 재귀 방지)
# STOP → ANALYZE → ROUTE 패턴이 포함된 경우에만 차단
if echo "$USER_INPUT" | grep -qE "🛑 STOP.*ANALYZE.*ROUTE"; then
  exit 0
fi

# ============================================================================
# Agent 자동 실행 (Handoff Memory 기반)
# ============================================================================

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

# Handoff Memory 확인 (code-writer 완료 시)
HANDOFF_PATTERN="handoff_code_writer_*"
HANDOFF_MEMORY=$(ls "$REPO_ROOT/.serena/memories/$HANDOFF_PATTERN.md" 2>/dev/null | head -1)

if [[ -n "$HANDOFF_MEMORY" ]] && [[ -f "$HANDOFF_MEMORY" ]]; then
  # Memory 내용 파싱 (Bash 패턴)
  NEXT_TASK_ID=$(grep -o '"next_task_id":\s*"[^"]*"' "$HANDOFF_MEMORY" | cut -d'"' -f4)
  AUTO_EXECUTE=$(grep -o '"auto_execute":\s*true' "$HANDOFF_MEMORY")

  if [[ -n "$NEXT_TASK_ID" ]] && [[ -n "$AUTO_EXECUTE" ]]; then
    # Memory 삭제 (1회성 실행)
    rm -f "$HANDOFF_MEMORY"

    # 자동 실행 메시지 출력
    cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║                    🤖 AGENT AUTO-EXECUTION                                 ║
╚═══════════════════════════════════════════════════════════════════════════╝

🔄 이전 Task 완료 감지!
   다음 Task를 자동으로 실행합니다: $NEXT_TASK_ID

📋 자동 실행 명령:
   Task --subagent_type "04-implementation/code-writer" \\
        --prompt "$NEXT_TASK_ID 구현"

───────────────────────────────────────────────────────────────────────────
EOF
    # Hook은 자동 실행 불가. 메시지만 출력하고 종료.
    # 사용자가 "진행" 또는 엔터를 누르면 메인 스레드가 실행.
  fi
fi

# ============================================================================
# Phase 1: 키워드 분석 (간소화)
# ============================================================================

analyze_keywords() {
  local input="$1"
  local keywords=""

  # 긴급 키워드
  echo "$input" | grep -qiE '(error|bug|crash|fail|500|404|undefined)' && keywords="$keywords bug"
  echo "$input" | grep -qiE '(hotfix|urgent|asap|critical|production)' && keywords="$keywords urgent"

  # 도메인 키워드
  echo "$input" | grep -qiE '(database|db|schema|migration|prisma)' && keywords="$keywords db"
  echo "$input" | grep -qiE '(api|endpoint|route|backend|server)' && keywords="$keywords api"
  echo "$input" | grep -qiE '(ui|frontend|component|react|next)' && keywords="$keywords frontend"

  # 작업 크기
  echo "$input" | grep -qiE '(epic|대형|시스템|전체)' && keywords="$keywords epic"
  echo "$input" | grep -qiE '(story|기능|추가|중형)' && keywords="$keywords story"
  echo "$input" | grep -qiE '(task|수정|소형|간단)' && keywords="$keywords task"

  echo "${keywords:-general}"
}

# ============================================================================
# Phase 2: 컴팩트 출력 (3000 chars 이하)
# ============================================================================

KEYWORDS=$(analyze_keywords "$USER_INPUT")

cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║                    🎯 WORKFLOW ENFORCEMENT (v3.0)                          ║
╚═══════════════════════════════════════════════════════════════════════════╝

🔍 ANALYSIS:
  Keywords: [$KEYWORDS]

📋 MANDATORY WORKFLOW:
  1. STOP  - Do NOT read code immediately
  2. CHECK - Verify Agent existence in .claude/agents/
  3. ROUTE - Use Task tool with appropriate Agent

⚡ AGENT ROUTING:
EOF

# Agent 추천 (컴팩트)
if echo "$KEYWORDS" | grep -qE 'bug|urgent|error'; then
  echo "  → 99-utils/error-fixer (3x faster parallel mode)"
elif echo "$KEYWORDS" | grep -qE 'db'; then
  echo "  → 04-implementation/db-code-writer (YAGNI + safety first)"
elif echo "$KEYWORDS" | grep -qE 'epic'; then
  echo "  → 02-requirements/epic-creator"
elif echo "$KEYWORDS" | grep -qE 'story'; then
  echo "  → 02-requirements/story-creator"
else
  echo "  → 03-design/task-planner (default)"
fi

cat <<EOF

⚠️ VIOLATIONS:
  ❌ Direct Read/Write/Edit without Agent
  ❌ Skipping STOP → CHECK → ROUTE workflow
  ✅ Always use: Task --subagent_type {agent} --prompt "{request}"

───────────────────────────────────────────────────────────────────────────
EOF

# 스크린샷 감지 (간소화)
if echo "$USER_INPUT" | grep -qiE 'screenshot|스크린샷|화면|UI|버튼'; then
  echo "📸 Screenshot Protocol: Phase 1 (analyze image) → Phase 2 (map to files)"
fi

# Next.js 16 useSearchParams 패턴 경고
if echo "$USER_INPUT" | grep -qiE 'useSearchParams|searchParams\.get|Suspense.*boundary|prerender.*error'; then
  cat <<'PATTERN_WARNING'
⚠️ Next.js 16 Pattern Alert:
  → NEVER use useSearchParams() directly
  → ALWAYS use Server Component + searchParams props
  → See: @docs/patterns/nextjs-16-searchparams-pattern.md
PATTERN_WARNING
fi

exit 0