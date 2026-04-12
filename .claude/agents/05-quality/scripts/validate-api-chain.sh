#!/bin/bash
# Frontend → Backend API 파라미터 체인 검증
# 사용법: ./validate-api-chain.sh [task_file]

set -euo pipefail

TASK_FILE="${1:-}"
WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Frontend → Backend API 체인 검증 시작..."

# 1. 최근 변경된 파일 목록
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || git diff --cached --name-only)

if [ -z "$CHANGED_FILES" ]; then
  echo "⚠️ 변경된 파일 없음"
  exit 0
fi

echo "변경된 파일:"
echo "$CHANGED_FILES" | sed 's/^/  - /'

# 2. Frontend DTO/Types에서 새로 추가된 필드 찾기
echo ""
echo "📋 Frontend에 추가된 필드 검색..."

FRONTEND_NEW_FIELDS=$(git diff HEAD~1 -- '**/frontend/**/*.ts' | \
  grep "^+.*:" | \
  grep -v "^+++" | \
  grep -v "^+import" | \
  grep -v "^+export" | \
  grep -v "^+//" | \
  sed 's/^+[[:space:]]*//' | \
  sed 's/:.*$//' | \
  grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\??" || true)

if [ -z "$FRONTEND_NEW_FIELDS" ]; then
  echo "✅ Frontend에 새 필드 없음"
  exit 0
fi

echo "새로 추가된 필드:"
echo "$FRONTEND_NEW_FIELDS" | sed 's/^/  - /'

# 3. Backend DTO에서 같은 필드 확인
echo ""
echo "🔍 Backend DTO 확인..."

ISSUES=()

while IFS= read -r field; do
  # ? 제거 (optional field)
  clean_field=$(echo "$field" | sed 's/?$//')

  # snake_case 변환 시도
  snake_case=$(echo "$clean_field" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')

  # Backend DTO에서 검색 (camelCase 또는 snake_case)
  backend_match=$(grep -r "^\s*$clean_field:" apps/*/backend/src/**/*.dto.ts 2>/dev/null || \
                  grep -r "^\s*@ApiProperty.*\s*$clean_field" apps/*/backend/src/**/*.dto.ts 2>/dev/null || \
                  grep -r "@Column.*'$snake_case'" apps/*/backend/src/**/*.entity.ts 2>/dev/null || true)

  if [ -z "$backend_match" ]; then
    ISSUES+=("🔴 P0: Frontend 필드 '$clean_field'가 Backend DTO에 없음")

    # 과거 유사 사례 검색
    past_case=$(git log --all --oneline --grep="$clean_field\|missing.*parameter\|파라미터.*누락" -5 | head -1 || true)
    if [ -n "$past_case" ]; then
      ISSUES+=("   과거 사례: $past_case")
    fi
  else
    echo "  ✅ $clean_field: Backend에 존재"
  fi
done <<< "$FRONTEND_NEW_FIELDS"

# 4. API 호출 체인 확인
echo ""
echo "🔗 API 호출 체인 검증..."

# Frontend API 파일에서 fetch/axios 호출 찾기
API_FILES=$(echo "$CHANGED_FILES" | grep -E "frontend.*api.*\.ts$" || true)

if [ -n "$API_FILES" ]; then
  while IFS= read -r api_file; do
    if [ -f "$api_file" ]; then
      # fetch body에 전달되는 필드 추출
      body_fields=$(grep -A 10 "body.*JSON.stringify" "$api_file" | \
                    grep -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*:" | \
                    sed 's/:.*$//' | \
                    sed 's/^[[:space:]]*//' || true)

      if [ -n "$body_fields" ]; then
        # FormData와 비교
        while IFS= read -r field; do
          clean_field=$(echo "$field" | sed 's/?$//')

          if ! echo "$body_fields" | grep -q "^$clean_field$"; then
            # Frontend에는 있지만 API 호출에서 누락
            if echo "$FRONTEND_NEW_FIELDS" | grep -q "^$clean_field"; then
              ISSUES+=("🔴 P0: API 체인 끊김: $api_file에서 '$clean_field' 전달 안함")
            fi
          fi
        done <<< "$FRONTEND_NEW_FIELDS"
      fi
    fi
  done <<< "$API_FILES"
fi

# 5. 결과 출력
echo ""
echo "═══════════════════════════════════════"
if [ ${#ISSUES[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ API 체인 검증 완료 - 문제 없음${NC}"
  exit 0
else
  echo -e "${RED}⚠️ 문제 발견 (${#ISSUES[@]}개):${NC}"
  printf '%s\n' "${ISSUES[@]}"
  echo ""
  echo "자동 수정: error-fixer에 위임 권장"
  exit 1
fi
