#!/bin/bash
# InstructionsLoaded hook - CLAUDE.md/rules 로드 시 컨텍스트 주입 (v2.1.64+)
# CLAUDE.md, .claude/rules/*.md 로드 시점에 추가 컨텍스트를 주입
#
# 용도:
# - 현재 활성 Epic/Story 상태 자동 주입
# - 최근 커밋 요약 자동 주입
# - 서비스 감지 컨텍스트 사전 로드

trap 'exit 0' ERR

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

CONTEXT_PARTS=""

# 1. 현재 활성 Epic/Story 감지 (PROGRESS.md 기반)
PROGRESS_FILE="$PROJECT_DIR/docs/PROGRESS.md"
if [ -f "$PROGRESS_FILE" ]; then
  # 현재 진행 중인 Epic/Story 라인 추출
  ACTIVE_EPIC=$(grep -m1 "^## " "$PROGRESS_FILE" 2>/dev/null | head -1)
  if [ -n "$ACTIVE_EPIC" ]; then
    CONTEXT_PARTS="${CONTEXT_PARTS}Active: ${ACTIVE_EPIC}. "
  fi
fi

# 2. 최근 커밋 1줄 요약
LAST_COMMIT=$(cd "$PROJECT_DIR" && git log --oneline -1 2>/dev/null)
if [ -n "$LAST_COMMIT" ]; then
  CONTEXT_PARTS="${CONTEXT_PARTS}Last commit: ${LAST_COMMIT}. "
fi

# 3. 현재 브랜치
CURRENT_BRANCH=$(cd "$PROJECT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$CURRENT_BRANCH" ]; then
  CONTEXT_PARTS="${CONTEXT_PARTS}Branch: ${CURRENT_BRANCH}. "
fi

# 컨텍스트가 있으면 주입
if [ -n "$CONTEXT_PARTS" ]; then
  echo "{\"systemMessage\": \"Project Context: ${CONTEXT_PARTS}\"}"
fi
