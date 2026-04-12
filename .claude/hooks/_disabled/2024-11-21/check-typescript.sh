#!/bin/bash
# .claude/hooks/utils/check-typescript.sh
# TypeScript strict 모드 위반 검증 (any 타입 남용)

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Git 저장소가 아닌 경우 Skip
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "PASS"
  exit 0
fi

# 수정된 TypeScript 파일 확인
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx)$' || true)

# 수정된 파일 없으면 PASS
if [ -z "$MODIFIED_FILES" ]; then
  echo "PASS"
  exit 0
fi

VIOLATIONS=()

# any 타입 허용 임계값 (파일당 최대 3개)
MAX_ANY_COUNT=3

for file in $MODIFIED_FILES; do
  # 파일이 존재하는지 확인
  if [ ! -f "$file" ]; then
    continue
  fi

  # any 타입 사용 카운트 (주석 제외)
  ANY_COUNT=$(grep -vE '^\s*//' "$file" | grep -oE ':\s*any\b' | wc -l | tr -d ' ')

  if [ "$ANY_COUNT" -gt "$MAX_ANY_COUNT" ]; then
    VIOLATIONS+=("$file: any 타입 과다 사용 ($ANY_COUNT개, 최대 $MAX_ANY_COUNT개 권장)")
  fi

  # @ts-ignore 사용 체크 (경고만)
  TS_IGNORE_COUNT=$(grep -cE '@ts-ignore|@ts-nocheck' "$file" 2>/dev/null || echo "0")
  if [ "$TS_IGNORE_COUNT" -gt 0 ]; then
    echo "  💡 Tip: $file - @ts-ignore 사용 ($TS_IGNORE_COUNT개, 타입 개선 권장)" >&2
  fi

  # unused imports 체크 (간단한 휴리스틱)
  IMPORTS=$(grep -oE "import\s+\{[^}]+\}" "$file" 2>/dev/null | grep -oE '\b[A-Z][a-zA-Z]+\b' || true)
  for import_name in $IMPORTS; do
    # import 이름이 파일에서 한 번만 나오면 unused 가능성
    USAGE_COUNT=$(grep -c "\b$import_name\b" "$file" 2>/dev/null || echo "0")
    if [ "$USAGE_COUNT" -eq 1 ]; then
      echo "  💡 Tip: $file - 사용되지 않는 import 가능성: $import_name" >&2
    fi
  done
done

# 위반 사항 발견 시
if [ ${#VIOLATIONS[@]} -gt 0 ]; then
  echo "FAIL"
  for violation in "${VIOLATIONS[@]}"; do
    echo "  ⚠️ $violation" >&2
  done
  exit 0  # Graceful degradation (Hook으로 실행될 때)
fi

echo "PASS"
exit 0
