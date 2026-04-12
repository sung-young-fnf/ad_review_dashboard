#!/bin/bash
# .claude/hooks/utils/check-db-schema.sh
# DB 스키마 prefix 검증 (프로젝트별 스키마 명시)

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Git 저장소가 아닌 경우 Skip
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "PASS"
  exit 0
fi

# 프로젝트 스키마명 확인 (docs/analysis/database-schema.md 또는 guides/schema-configuration.md)
SCHEMA_NAME=""
if [ -f "docs/analysis/database-schema.md" ]; then
  SCHEMA_NAME=$(grep -oE 'sparknote|autumn_template|okr2_schema' docs/analysis/database-schema.md 2>/dev/null | head -1 || true)
elif [ -f "docs/analysis/guides/schema-configuration.md" ]; then
  SCHEMA_NAME=$(grep -oE 'sparknote|autumn_template|okr2_schema' docs/analysis/guides/schema-configuration.md 2>/dev/null | head -1 || true)
fi

# 기본값: sparknote (okr2 프로젝트)
if [ -z "$SCHEMA_NAME" ]; then
  SCHEMA_NAME="sparknote"
fi

# 수정된 SQL/TypeScript 파일 확인
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx|sql|prisma)$' || true)

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

  # SQL 쿼리에 테이블명만 있고 스키마 prefix 없는 경우 검증
  # SELECT, INSERT, UPDATE, DELETE, FROM, JOIN 절 확인
  SQL_PATTERNS=(
    'FROM\s+[^.]+\s+(WHERE|LEFT|INNER|ORDER|GROUP|LIMIT|;)'
    'JOIN\s+[^.]+\s+ON'
    'INSERT\s+INTO\s+[^.]+\s+\('
    'UPDATE\s+[^.]+\s+SET'
    'DELETE\s+FROM\s+[^.]+'
  )

  for pattern in "${SQL_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$file" 2>/dev/null; then
      # 스키마 prefix가 없는지 확인
      if ! grep -qE "${SCHEMA_NAME}\." "$file" 2>/dev/null; then
        # 제외 조건: Prisma schema 파일의 @@schema 속성은 허용
        if [[ "$file" == *.prisma ]] && grep -qE "@@schema\(\"${SCHEMA_NAME}\"\)" "$file" 2>/dev/null; then
          continue
        fi
        VIOLATIONS+=("$file: DB 스키마 prefix 누락 (${SCHEMA_NAME}. 명시 필요)")
        break
      fi
    fi
  done

  # Prisma schema 검증: datasource에 schemas 배열 확인
  if [[ "$file" == *.prisma ]]; then
    if grep -q "datasource db" "$file" 2>/dev/null; then
      if ! grep -qE "schemas\s*=\s*\[\"${SCHEMA_NAME}\"\]" "$file" 2>/dev/null; then
        VIOLATIONS+=("$file: Prisma datasource에 schemas = [\"${SCHEMA_NAME}\"] 누락")
      fi
    fi

    # 모델에 @@schema 속성 확인
    if grep -q "^model " "$file" 2>/dev/null; then
      MODELS=$(grep -E "^model " "$file" | awk '{print $2}')
      for model in $MODELS; do
        # 모델 블록 추출 (간단한 휴리스틱)
        MODEL_BLOCK=$(awk "/^model $model/,/^}/" "$file" 2>/dev/null || true)
        if [ -n "$MODEL_BLOCK" ]; then
          if ! echo "$MODEL_BLOCK" | grep -qE "@@schema\(\"${SCHEMA_NAME}\"\)" 2>/dev/null; then
            VIOLATIONS+=("$file: 모델 $model에 @@schema(\"${SCHEMA_NAME}\") 누락")
          fi
        fi
      done
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
