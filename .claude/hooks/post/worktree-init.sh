#!/bin/bash
# WorktreeCreate hook - Squad worktree 자동 초기화 (v2.1.50+)
# worktree 생성 시 필요한 의존성 설치 및 환경 준비
#
# Non-Fatal Initialization 원칙:
# - git worktree 생성 실패 = 치명적 (이미 Claude가 처리)
# - pnpm install 실패 = 경고 (기존 node_modules로 동작 가능)
# - docs/epics 복사 실패 = 경고 (참조 없어도 구현 가능)

trap 'exit 0' ERR

INPUT=$(cat)

# 디버그: 입력 캡처 (문제 진단용)
echo "$INPUT" > /tmp/worktree-hook-input-debug.json 2>/dev/null

# 다양한 입력 형식 대응 (.worktree.path 또는 .path)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree.path // .path // ""' 2>/dev/null)
WORKTREE_NAME=$(echo "$INPUT" | jq -r '.worktree.name // .name // ""' 2>/dev/null)
WORKTREE_BRANCH=$(echo "$INPUT" | jq -r '.worktree.branch // .branch // ""' 2>/dev/null)

# worktree 경로가 없으면 성공 메시지와 함께 종료 (출력 필수)
if [ -z "$WORKTREE_PATH" ]; then
  echo '{"systemMessage": "Worktree hook: path not provided, skipped"}'
  exit 0
fi

WARNINGS=""

# 1. pnpm install (경고 레벨 — 실패해도 계속)
if [ -f "$WORKTREE_PATH/package.json" ]; then
  if ! (cd "$WORKTREE_PATH" && pnpm install --frozen-lockfile 2>/dev/null); then
    WARNINGS="${WARNINGS}pnpm install 실패 (기존 node_modules 사용). "
  fi
fi

# 2. prisma generate (ai-agent 서비스인 경우)
if [ -f "$WORKTREE_PATH/apps/ai-agent/backend/prisma/schema.prisma" ]; then
  if ! (cd "$WORKTREE_PATH/apps/ai-agent/backend" && pnpm prisma generate 2>/dev/null); then
    WARNINGS="${WARNINGS}prisma generate 실패. "
  fi
fi

# 결과 메시지 생성
if [ -z "$WARNINGS" ]; then
  MSG="Worktree '${WORKTREE_NAME}' 초기화 완료 (branch: ${WORKTREE_BRANCH})"
else
  MSG="Worktree '${WORKTREE_NAME}' 초기화 완료 (경고: ${WARNINGS})"
fi

echo "{\"systemMessage\": \"${MSG}\"}"
