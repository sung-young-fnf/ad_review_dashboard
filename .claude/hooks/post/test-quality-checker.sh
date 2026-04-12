#!/bin/bash
#
# Test Quality Checker Hook (PostToolUse - Write)
#
# Purpose: 의미 없는 테스트 패턴 감지 후 경고 (차단하지 않음)
# Trigger: Write 도구로 테스트 파일 저장 시
# EP121-S04: 테스트 품질 강제
#

set +e
trap 'exit 0' ERR

# stdin에서 JSON 수신
HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# 테스트 파일만 체크
case "$FILE_PATH" in
  *.spec.ts|*.test.ts|*.spec.tsx|*.test.tsx) ;;
  test_*.py|*_test.py|*.spec.py) ;;
  *) exit 0 ;;
esac

# 파일 존재 확인
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

WARNINGS=""
FILENAME=$(basename "$FILE_PATH")

# --- 의미 없는 assertion 패턴 감지 ---
MEANINGLESS_PATTERNS=(
  "expect(true).toBe(true)"
  "expect(1).toBe(1)"
  "expect(false).toBe(false)"
  "assert True$"
  "assert 1 == 1"
  "assert False == False"
)

for pattern in "${MEANINGLESS_PATTERNS[@]}"; do
  while IFS=: read -r line_num line_content; do
    if [[ -n "$line_num" ]]; then
      WARNINGS="${WARNINGS}\n  - Line ${line_num}: ${line_content## }"
    fi
  done < <(grep -n "$pattern" "$FILE_PATH" 2>/dev/null || true)
done

# --- 빈 테스트 바디 감지 ---
while IFS=: read -r line_num line_content; do
  if [[ -n "$line_num" ]]; then
    WARNINGS="${WARNINGS}\n  - Line ${line_num}: empty test body"
  fi
done < <(grep -nE 'it\(.*\(\)\s*=>\s*\{\s*\}\s*\)' "$FILE_PATH" 2>/dev/null || true)

# --- mock-only 감지 (expect 없이 toHaveBeenCalled만) ---
HAS_EXPECT=$(grep -c 'expect(' "$FILE_PATH" 2>/dev/null || echo "0")
HAS_EXPECT="${HAS_EXPECT//[^0-9]/}"
HAS_MOCK_ONLY=$(grep -c 'toHaveBeenCalled' "$FILE_PATH" 2>/dev/null || echo "0")
HAS_MOCK_ONLY="${HAS_MOCK_ONLY//[^0-9]/}"

if [[ "$HAS_MOCK_ONLY" -gt 0 ]] && [[ "$HAS_EXPECT" -eq 0 ]]; then
  WARNINGS="${WARNINGS}\n  - mock-only test: expect() assertion 없이 toHaveBeenCalled만 사용"
fi

# --- 경고 출력 (stderr) ---
if [[ -n "$WARNINGS" ]]; then
  {
    echo ""
    echo "[Test Quality] meaningless test pattern detected: ${FILENAME}"
    echo -e "$WARNINGS"
    echo "  -> Replace with assertions that verify actual business logic"
    echo ""
  } >&2
fi

exit 0
