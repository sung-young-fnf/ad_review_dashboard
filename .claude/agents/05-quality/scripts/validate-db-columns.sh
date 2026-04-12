#!/bin/bash
# DB 컬럼명 일치 검증 (snake_case vs camelCase)
# 사용법: ./validate-db-columns.sh

set -euo pipefail

WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 DB 컬럼명 일치 검증 시작..."

# 1. 변경된 파일 목록
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || git diff --cached --name-only)

if [ -z "$CHANGED_FILES" ]; then
  echo "⚠️ 변경된 파일 없음"
  exit 0
fi

ISSUES=()

# 2. Entity 파일에서 @Column 컬럼명 추출 (snake_case)
echo "📋 Entity 컬럼명 추출..."

ENTITY_FILES=$(echo "$CHANGED_FILES" | grep -E "backend.*\.entity\.ts$" || true)

if [ -z "$ENTITY_FILES" ]; then
  echo "✅ 변경된 Entity 파일 없음"
  exit 0
fi

declare -A ENTITY_COLUMNS

while IFS= read -r entity_file; do
  if [ -f "$entity_file" ]; then
    echo "  분석: $entity_file"

    # @Column({ name: 'snake_case' }) 패턴 찾기
    while IFS= read -r line; do
      if [[ $line =~ @Column.*name:[[:space:]]*[\'\"]([a-z_]+)[\'\"] ]]; then
        col_name="${BASH_REMATCH[1]}"

        # 다음 줄에서 TypeScript 필드명 찾기
        next_line=$(grep -A 1 "name: '$col_name'" "$entity_file" | tail -1)
        if [[ $next_line =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
          ts_field="${BASH_REMATCH[1]}"
          ENTITY_COLUMNS["$col_name"]="$ts_field"
          echo "    - $col_name → $ts_field"
        fi
      fi
    done < "$entity_file"
  fi
done <<< "$ENTITY_FILES"

# 3. Frontend/API에서 snake_case 직접 사용 여부 확인
echo ""
echo "🔍 Frontend에서 snake_case 사용 검증..."

FRONTEND_FILES=$(echo "$CHANGED_FILES" | grep -E "frontend.*\.(ts|tsx)$" || true)

if [ -n "$FRONTEND_FILES" ]; then
  for col_name in "${!ENTITY_COLUMNS[@]}"; do
    camel_case="${ENTITY_COLUMNS[$col_name]}"

    # Frontend에서 snake_case 직접 사용 검색
    matches=$(grep -n "$col_name" $FRONTEND_FILES 2>/dev/null || true)

    if [ -n "$matches" ]; then
      while IFS= read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        content=$(echo "$match" | cut -d: -f3-)

        # 예외: 타입 정의나 주석 제외
        if [[ ! $content =~ ^[[:space:]]*(//|/\*|\*) ]]; then
          ISSUES+=("🔴 P0: $file:$line - snake_case 직접 사용: '$col_name' (camelCase '$camel_case' 사용 필요)")
        fi
      done <<< "$matches"
    fi
  done
fi

# 4. Backend DTO에서 snake_case 사용 검증
echo ""
echo "🔍 Backend DTO에서 snake_case 검증..."

DTO_FILES=$(echo "$CHANGED_FILES" | grep -E "backend.*\.dto\.ts$" || true)

if [ -n "$DTO_FILES" ]; then
  for col_name in "${!ENTITY_COLUMNS[@]}"; do
    camel_case="${ENTITY_COLUMNS[$col_name]}"

    # DTO에서 snake_case 사용 검색
    matches=$(grep -n "^\s*$col_name:" $DTO_FILES 2>/dev/null || true)

    if [ -n "$matches" ]; then
      while IFS= read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)

        ISSUES+=("🟡 P1: $file:$line - DTO에서 snake_case 사용: '$col_name' (일반적으로 camelCase 권장)")
      done <<< "$matches"
    fi
  done
fi

# 5. 결과 출력
echo ""
echo "═══════════════════════════════════════"
if [ ${#ISSUES[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ DB 컬럼명 검증 완료 - 문제 없음${NC}"
  exit 0
else
  echo -e "${RED}⚠️ 문제 발견 (${#ISSUES[@]}개):${NC}"
  printf '%s\n' "${ISSUES[@]}"
  echo ""
  echo "자동 수정: error-fixer에 위임 권장"
  exit 1
fi
