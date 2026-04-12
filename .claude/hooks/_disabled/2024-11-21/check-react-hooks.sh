#!/bin/bash
# .claude/hooks/utils/check-react-hooks.sh
# React Hook useEffect 의존성 배열 검증

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Git 저장소가 아닌 경우 Skip
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "PASS"
  exit 0
fi

# 수정된 React 컴포넌트 파일 확인
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(tsx|ts|jsx|js)$' || true)

# 수정된 파일 없으면 PASS
if [ -z "$MODIFIED_FILES" ]; then
  echo "PASS"
  exit 0
fi

VIOLATIONS=()

for file in $MODIFIED_FILES; do
  # 파일이 존재하는지 확인
  if [ ! -f "$file" ]; then
    continue
  fi

  # useEffect deps에 위험 패턴 검사
  # 1. api.method 패턴
  if grep -qE 'useEffect\([^,]+,\s*\[[^\]]*\bapi\.' "$file" 2>/dev/null; then
    VIOLATIONS+=("$file: useEffect deps에 api.method 사용 (무한 루프 위험)")
  fi

  # 2. 객체/함수 직접 참조 패턴
  if grep -qE 'useEffect\([^,]+,\s*\[[^\]]*\{' "$file" 2>/dev/null; then
    VIOLATIONS+=("$file: useEffect deps에 객체 리터럴 사용 (무한 루프 위험)")
  fi

  # 3. data 배열/객체 패턴
  if grep -qE 'useEffect\([^,]+,\s*\[[^\]]*\bdata\b[^\]]*\]' "$file" 2>/dev/null; then
    # primitive 타입인지 확인 (간단한 휴리스틱)
    if ! grep -qE 'const\s+data\s*=\s*(string|number|boolean)' "$file" 2>/dev/null; then
      VIOLATIONS+=("$file: useEffect deps에 data 배열/객체 사용 (무한 루프 위험)")
    fi
  fi
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
