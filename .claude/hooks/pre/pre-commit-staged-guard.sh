#!/bin/bash
#
# PreToolUse Hook - Pre-Commit Staged File Guard
#
# Purpose: git commit 실행 전 staged 파일 목록을 표시하여 잘못된 staging 방지
# Trigger: PreToolUse (Bash) — git commit 명령어 감지 시에만 동작
# Output: stderr에 정보 표시 (non-blocking)
#
# WHY: Insights 분석에서 잘못된 파일 staging으로 인한 마찰 5+ 세션 발견
#      commit-manager 스킬 사용 시에는 이미 검증하지만, 직접 git commit 시 가드 없음

set +e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Bash 도구가 아니면 스킵
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# git commit 명령어가 아니면 스킵
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit|&&\s*git\s+commit|\|\|\s*git\s+commit'; then
  exit 0
fi

# git amend는 별도 경고
IS_AMEND=""
if echo "$COMMAND" | grep -q -- '--amend'; then
  IS_AMEND=" (--amend)"
fi

# staged 파일 목록
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  STAGED_COUNT=0
else
  STAGED_COUNT=$(echo "$STAGED" | wc -l | tr -d ' ')
fi

# unstaged 변경 파일
UNSTAGED=$(git diff --name-only 2>/dev/null || true)
if [[ -z "$UNSTAGED" ]]; then
  UNSTAGED_COUNT=0
else
  UNSTAGED_COUNT=$(echo "$UNSTAGED" | wc -l | tr -d ' ')
fi

# staged 파일이 없으면 경고
if [[ "$STAGED_COUNT" -eq 0 ]]; then
  echo "⚠️ git commit 감지 — staged 파일 없음 (빈 커밋)" >&2
  exit 0
fi

# 정보 표시 (non-blocking)
{
  echo "📋 Pre-Commit Guard${IS_AMEND}: staged ${STAGED_COUNT}개 파일"
  if [[ "$STAGED_COUNT" -le 15 ]]; then
    echo "$STAGED" | sed 's/^/  · /'
  else
    echo "$STAGED" | head -10 | sed 's/^/  · /'
    echo "  ... 외 $((STAGED_COUNT - 10))개"
  fi
  if [[ "$UNSTAGED_COUNT" -gt 0 ]]; then
    echo "⚠️ unstaged 변경 ${UNSTAGED_COUNT}개 — 커밋에 미포함"
  fi
} >&2

exit 0
