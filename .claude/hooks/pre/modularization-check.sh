#!/bin/bash
# .claude/hooks/pre/modularization-check.sh
# Modularization Rules Injection Hook
# Version: 1.0 (Reddit Hook System v3.2)
# Purpose: Inject modularization checklist to prevent code duplication and enforce file naming conventions

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================

DEBUG_LOG="/tmp/hook-modularization-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# Phase 0: stdin 읽기 및 JSON 파싱
# ============================================================================

log_debug "=== MODULARIZATION HOOK START ==="

# NOTE: 프로젝트 초기화 체크는 unified Hook에서 SERVICE_CONTEXT.md 유무로 처리

if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, INPUT_JSON length: ${#INPUT_JSON}"

  # Graceful JSON parsing
  if command -v jq &> /dev/null; then
    if echo "$INPUT_JSON" | jq -e . &>/dev/null; then
      log_debug "jq available, parsing JSON"
      USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)

      if [[ -z "$USER_INPUT" ]] || [[ "$USER_INPUT" == "null" ]]; then
        log_debug "jq parsing returned empty/null, using raw INPUT_JSON as fallback"
        USER_INPUT="$INPUT_JSON"
      else
        log_debug "jq parsing result: USER_INPUT='$USER_INPUT' (length: ${#USER_INPUT})"
      fi
    else
      log_debug "Invalid JSON, using raw INPUT_JSON"
      USER_INPUT="$INPUT_JSON"
    fi
  else
    log_debug "jq not available, using raw INPUT_JSON"
    USER_INPUT="$INPUT_JSON"
  fi
else
  log_debug "no stdin, using CLAUDE_USER_PROMPT or arg"
  USER_INPUT="${CLAUDE_USER_PROMPT:-${1:-}}"
fi

log_debug "Final USER_INPUT: '$USER_INPUT' (length: ${#USER_INPUT})"

# ============================================================================
# Phase 1: 빈 입력 처리 (MANDATORY)
# ============================================================================

if [[ -z "$USER_INPUT" ]] || [[ "${#USER_INPUT}" -lt 2 ]]; then
  log_debug "Empty or short input detected, exiting silently (length: ${#USER_INPUT})"
  exit 0
fi

# Agent 내부 실행 감지 (무한 재귀 방지)
if echo "$USER_INPUT" | grep -qE "MODULARIZATION RULES"; then
  log_debug "Modularization pattern detected, exiting to prevent recursion"
  exit 0
fi

log_debug "Input validation passed, continuing to Phase 2"

# ============================================================================
# Phase 2: Modularization 체크리스트 출력
# ============================================================================

# 코드 작성 키워드 감지
CODE_KEYWORDS="(구현|작성|추가|생성|create|implement|add|write|code|function|class|component)"

if echo "$USER_INPUT" | grep -qiE "$CODE_KEYWORDS"; then
  log_debug "Code writing keywords detected, injecting modularization rules"

  cat <<'EOF'

╔═══════════════════════════════════════════════════════════════════════════╗
║                    📦 MODULARIZATION RULES (v3.2)                          ║
╚═══════════════════════════════════════════════════════════════════════════╝

⚠️ BEFORE WRITING CODE - MANDATORY CHECKS:

1. 🔍 SEARCH FIRST (No Duplication)
   ✅ Use: Glob, Grep, mcp__serena__find_file
   ✅ Check: @docs/analysis/code-structure.md
   ✅ Look: /shared/, /lib/, /utils/, /components/
   ❌ NEVER create without searching

2. 📝 FILE NAMING (Descriptive Kebab-Case)
   ✅ GOOD: "user-authentication-service.ts"
   ✅ GOOD: "spark-note-feedback-form-validator.ts"
   ❌ BAD: "auth.ts", "utils.ts", "helper.ts"
   💡 WHY: Longer names = Better Glob/Grep (no Read needed)
   💡 TOKEN SAVE: "grep user-auth" finds it instantly

3. 🧩 LOGICAL SEPARATION (Single Responsibility)
   ✅ Functions: One clear purpose
   ✅ Classes: Cohesive concerns only
   ✅ Files: Domain-specific (not generic "utils")
   ❌ NEVER: Mixed concerns in one file

4. 📐 SIZE LIMITS (YAGNI Principle)
   ✅ Functions: < 50 lines (prefer 20-30)
   ✅ Files: < 200 lines (prefer 100-150)
   ❌ Over-engineering: Don't add unused features

5. 🎯 REUSE PATTERNS (Check Existing)
   ✅ Server Actions: @app/(authenticated)/actions/
   ✅ API Clients: @lib/api-client.ts
   ✅ Shared Types: @types/
   ✅ UI Components: @components/ui/ (shadcn/ui)

⚡ DELEGATE TO AGENTS:
   → code-writer MUST follow these rules
   → task-planner MUST check modularization
   → Sub-agents inherit these constraints

───────────────────────────────────────────────────────────────────────────
EOF

else
  log_debug "No code writing keywords detected, skipping modularization rules"
fi

log_debug "=== MODULARIZATION HOOK END (exit 0) ==="
exit 0
