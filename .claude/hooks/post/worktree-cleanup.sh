#!/bin/bash
# WorktreeRemove hook - Squad worktree 정리 (v2.1.50+)
# worktree 제거 시 정리 작업 수행

trap 'exit 0' ERR

INPUT=$(cat)
WORKTREE_NAME=$(echo "$INPUT" | jq -r '.worktree.name // ""' 2>/dev/null)
WORKTREE_BRANCH=$(echo "$INPUT" | jq -r '.worktree.branch // ""' 2>/dev/null)

if [ -z "$WORKTREE_NAME" ]; then
  exit 0
fi

MSG="Worktree '${WORKTREE_NAME}' 제거됨 (branch: ${WORKTREE_BRANCH})"
echo "{\"systemMessage\": \"${MSG}\"}"
