#!/bin/bash
# .claude/hooks/pre/approach-checkpoint.sh
# PreToolUse — frontend .tsx 파일 Edit/Write 전 렌더링 검증 여부 확인
# Route→Page→Component 하향식 추적 없이 컴포넌트를 수정하는 wrong_approach 방지
#
# 트리거: PreToolUse (Edit|Write)
# Version: 1.0

trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_DIR="$REPO_ROOT/.claude/hooks/cache"
READS_LOG="$CACHE_DIR/recent-reads.log"

# stdin에서 Hook 이벤트 JSON 읽기 (기존 Hook 패턴과 통일)
INPUT=$(cat 2>/dev/null || echo "")

if [ -z "$INPUT" ]; then
  exit 0
fi

# jq 필수
if ! command -v jq &>/dev/null; then
  exit 0
fi

# tool_name 확인 — Edit 또는 Write만 처리
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

# file_path 추출
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# frontend .tsx 파일인지 확인 — apps/*/frontend/**/*.tsx 패턴
if [[ ! "$FILE_PATH" =~ apps/[^/]+/frontend/.*\.tsx$ ]]; then
  exit 0
fi

# page.tsx, layout.tsx, route.ts 등 라우트 파일 자체는 스킵 (이미 라우트 추적의 일부)
BASENAME=$(basename "$FILE_PATH")
if [[ "$BASENAME" =~ ^(page|layout|loading|error|not-found|route)\.(tsx|ts)$ ]]; then
  exit 0
fi

# recent-reads.log에서 해당 파일이 Read/Grep된 적 있는지 확인
if [ -f "$READS_LOG" ]; then
  # 파일 경로의 일부(컴포넌트 파일명 또는 디렉토리)로 검색
  COMPONENT_NAME=$(basename "$FILE_PATH" .tsx)
  COMPONENT_DIR=$(dirname "$FILE_PATH")

  # 정확한 경로 매칭 또는 컴포넌트명이 Grep/Read에 나온 적 있는지 확인
  if grep -q "$FILE_PATH" "$READS_LOG" 2>/dev/null; then
    exit 0
  fi
  if grep -q "$COMPONENT_NAME" "$READS_LOG" 2>/dev/null; then
    exit 0
  fi
  # 같은 디렉토리 내 page.tsx가 Read된 적 있으면 렌더링 경로 추적으로 간주
  if grep -q "$(dirname "$COMPONENT_DIR")/page.tsx" "$READS_LOG" 2>/dev/null; then
    exit 0
  fi
fi

# 경고 출력 (비블로킹 — stderr)
echo "" >&2
echo "======================================================" >&2
echo "  [Approach Check] 렌더링 검증 미확인" >&2
echo "======================================================" >&2
echo "  이 컴포넌트가 실제 렌더링되는지 확인되지 않았습니다." >&2
echo "  Route -> Page -> Component 추적을 먼저 수행하세요." >&2
echo "" >&2
echo "  파일: $FILE_PATH" >&2
echo "  컴포넌트: $COMPONENT_NAME" >&2
echo "" >&2
echo "  Grep \"$COMPONENT_NAME\" 으로 import 경로를 확인하세요." >&2
echo "======================================================" >&2
echo "" >&2

exit 0
