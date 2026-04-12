#!/bin/bash
# .claude/hooks/pre/session-title-setter.sh
# Sets session title based on user input context (Claude Code 2.1.94+)
# hookSpecificOutput.sessionTitle — JSON output only, no text
#
# Detection priority:
# 1. Epic reference (EP###)
# 2. Task reference (T###)
# 3. Story reference (S##)
# 4. Keyword-based category
# 5. Active Epic from PROGRESS.md

INPUT=$(cat 2>/dev/null || echo "")

# Extract user prompt
if command -v jq &>/dev/null && echo "$INPUT" | jq -e . &>/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)
  [[ -z "$PROMPT" || "$PROMPT" == "null" ]] && PROMPT="$INPUT"
else
  PROMPT="$INPUT"
fi

# Skip empty/short/greeting input
[[ -z "$PROMPT" || ${#PROMPT} -lt 3 ]] && exit 0
echo "$PROMPT" | grep -qiE '^(안녕|하이|ㅎㅇ|hi|hello|hey|감사|고마워|thanks|네|응|ㅇㅇ|ok)' && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TITLE=""

# --- 1. Epic reference: EP123 ---
EPIC_REF=$(echo "$PROMPT" | grep -oE 'EP[0-9]{3}' | head -1)
if [[ -n "$EPIC_REF" ]]; then
  EPIC_DIR=$(find "$REPO_ROOT/docs/epics" -maxdepth 1 -type d -name "*${EPIC_REF}*" 2>/dev/null | head -1)
  if [[ -n "$EPIC_DIR" ]]; then
    EPIC_NAME=$(basename "$EPIC_DIR" | sed "s/^${EPIC_REF}-//;s/-/ /g" | cut -c1-25)
    TITLE="${EPIC_REF}: ${EPIC_NAME}"
  else
    TITLE="${EPIC_REF}"
  fi
fi

# --- 2. Task reference: T001 ---
if [[ -z "$TITLE" ]]; then
  TASK_REF=$(echo "$PROMPT" | grep -oE 'T[0-9]{3}' | head -1)
  if [[ -n "$TASK_REF" ]]; then
    STORY_CTX=$(echo "$PROMPT" | grep -oE 'S[0-9]{2}' | head -1)
    if [[ -n "$STORY_CTX" ]]; then
      TITLE="${STORY_CTX}-${TASK_REF}"
    else
      TITLE="Task ${TASK_REF}"
    fi
  fi
fi

# --- 3. Story reference: S01 ---
if [[ -z "$TITLE" ]]; then
  STORY_REF=$(echo "$PROMPT" | grep -oE 'S[0-9]{2}' | head -1)
  [[ -n "$STORY_REF" ]] && TITLE="Story ${STORY_REF}"
fi

# --- 4. Keyword-based category ---
if [[ -z "$TITLE" ]]; then
  FIRST_LINE=$(echo "$PROMPT" | head -1)
  if echo "$FIRST_LINE" | grep -qiE '(epic|대형|시스템|플랫폼|아키텍처)'; then
    TITLE="Epic Planning"
  elif echo "$FIRST_LINE" | grep -qiE '(bug|에러|오류|fix|수정|깨짐|안됨|실패)'; then
    TITLE="Bug Fix"
  elif echo "$FIRST_LINE" | grep -qiE '(ux|ui점검|레이아웃|사용성)'; then
    TITLE="UX Audit"
  elif echo "$FIRST_LINE" | grep -qiE '(ui|frontend|프론트|화면|페이지|컴포넌트)'; then
    TITLE="Frontend"
  elif echo "$FIRST_LINE" | grep -qiE '(db|schema|migration|스키마|마이그레이션)'; then
    TITLE="DB Schema"
  elif echo "$FIRST_LINE" | grep -qiE '(deploy|배포|push|release|릴리즈)'; then
    TITLE="Deploy"
  elif echo "$FIRST_LINE" | grep -qiE '(api|endpoint|backend|백엔드|서버)'; then
    TITLE="Backend API"
  elif echo "$FIRST_LINE" | grep -qiE '(test|테스트|검증|QA)'; then
    TITLE="Testing"
  elif echo "$FIRST_LINE" | grep -qiE '(refactor|리팩토링|정리|개선)'; then
    TITLE="Refactoring"
  fi
fi

# --- 5. Active Epic from PROGRESS.md ---
if [[ -z "$TITLE" ]]; then
  PROGRESS="$REPO_ROOT/PROGRESS.md"
  if [[ -f "$PROGRESS" ]]; then
    ACTIVE_EPIC=$(grep -oE 'EP[0-9]{3}' "$PROGRESS" | head -1)
    [[ -n "$ACTIVE_EPIC" ]] && TITLE="${ACTIVE_EPIC} (active)"
  fi
fi

# No context detected
[[ -z "$TITLE" ]] && exit 0

# Output JSON for Claude Code hookSpecificOutput
if command -v jq &>/dev/null; then
  jq -n --arg t "$TITLE" '{
    "hookSpecificOutput": {
      "sessionTitle": $t
    }
  }'
else
  ESCAPED=$(echo "$TITLE" | sed 's/"/\\"/g')
  echo "{\"hookSpecificOutput\":{\"sessionTitle\":\"$ESCAPED\"}}"
fi

exit 0
