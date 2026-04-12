#!/bin/bash
# .claude/hooks/utils/check-api-security.sh
# Next.js API Routes 인증 및 에러 처리 검증

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Git 저장소가 아닌 경우 Skip
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "PASS"
  exit 0
fi

# 수정된 API route 파일 확인
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E 'app/api/.*route\.ts$' || true)

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

  # 1. Bearer token 인증 체크
  if ! grep -qE 'Authorization.*Bearer|session\.(backendToken|accessToken)' "$file" 2>/dev/null; then
    VIOLATIONS+=("$file: API 인증 누락 (Bearer token 또는 session token 필요)")
  fi

  # 2. try-catch 에러 처리 체크 (GET, POST, PUT, DELETE 메서드)
  for method in GET POST PUT DELETE PATCH; do
    if grep -qE "export\s+async\s+function\s+$method" "$file" 2>/dev/null; then
      # 해당 메서드 블록 추출 (간단한 휴리스틱)
      METHOD_BLOCK=$(awk "/export async function $method/,/^}/" "$file" 2>/dev/null || true)
      if [ -n "$METHOD_BLOCK" ]; then
        if ! echo "$METHOD_BLOCK" | grep -q "try" 2>/dev/null; then
          VIOLATIONS+=("$file: $method 메서드 에러 처리 누락 (try-catch 필요)")
        fi
      fi
    fi
  done

  # 3. Admin Impersonation 헤더 체크 (선택적 - 경고만)
  if grep -qE 'Authorization.*Bearer' "$file" 2>/dev/null; then
    if ! grep -qE 'X-Impersonate-User|impersonatedUserId' "$file" 2>/dev/null; then
      # 경고만 출력 (FAIL로 처리하지 않음)
      echo "  💡 Tip: $file - Admin Impersonation 헤더 미사용 (선택 사항)" >&2
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
