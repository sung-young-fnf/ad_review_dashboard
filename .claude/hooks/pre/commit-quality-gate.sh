#!/bin/bash
#
# PreToolUse Hook - Commit Quality Gate
#
# Purpose: git commit 실행 전 staged 파일 기반으로 품질 검증 수행
# Trigger: PreToolUse (Bash) - git commit 명령어 감지 시
# Output: stderr에 경고 표시 (non-blocking, exit 0 유지)
#
# 검증 항목:
#   1. Prisma schema 변경 -> prisma validate 실행
#   2. Migration SQL 파일 -> 테이블명 기본 검증
#   3. package.json 변경 -> pnpm-lock.yaml 동기화 확인
#   4. TypeScript 파일 변경 -> 해당 앱만 tsc --noEmit 실행
#
# WHY: buggy_code 60건/월의 주요 원인 (마이그레이션 오타, lockfile 미동기화, 타입 에러)
#      커밋 전 자동 감지로 프로덕션 사고 방지

set +e
trap 'exit 0' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$PROJECT_DIR" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Bash 도구가 아니면 스킵
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# git commit 명령어가 아니면 스킵
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit|&&\s*git\s+commit|\|\|\s*git\s+commit'; then
  exit 0
fi

# staged 파일 목록
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

WARNINGS=""
GATE_START=$(date +%s)

# === 1. Prisma schema 변경 감지 -> prisma validate ===
PRISMA_CHANGED=""
echo "$STAGED" | grep -q "prisma/schema.prisma" && PRISMA_CHANGED="true"

if [ -n "$PRISMA_CHANGED" ]; then
  PRISMA_DIR="$PROJECT_DIR/apps/ai-agent/backend"
  if [ -f "$PRISMA_DIR/prisma/schema.prisma" ]; then
    VALIDATE_OUTPUT=$(cd "$PRISMA_DIR" && npx prisma validate 2>&1) || true
    VALIDATE_EXIT=$?
    if [ $VALIDATE_EXIT -ne 0 ]; then
      WARNINGS="${WARNINGS}
[FAIL] Prisma schema 검증 실패
${VALIDATE_OUTPUT}
   -> prisma/schema.prisma 수정 후 다시 커밋하세요
   -> cd apps/ai-agent/backend && npx prisma validate"
    else
      WARNINGS="${WARNINGS}
[PASS] Prisma schema 검증 통과"
    fi
  fi
fi

# === 2. Migration SQL 파일 -> 테이블명 기본 검증 ===
MIGRATION_FILES=$(echo "$STAGED" | grep -E "prisma/migrations/.*\.sql$" || true)
ALEMBIC_FILES=$(echo "$STAGED" | grep -E "alembic/versions/.*\.py$" || true)

if [ -n "$MIGRATION_FILES" ]; then
  PRISMA_SCHEMA="$PROJECT_DIR/apps/ai-agent/backend/prisma/schema.prisma"
  if [ -f "$PRISMA_SCHEMA" ]; then
    # Prisma schema에서 @@map으로 정의된 실제 테이블명 추출
    SCHEMA_TABLES=$(grep -E '@@map\(' "$PRISMA_SCHEMA" | sed 's/.*@@map("\(.*\)").*/\1/' 2>/dev/null || true)
    # model 이름도 테이블명 후보로 추가 (@@map 없는 경우)
    MODEL_NAMES=$(grep -E '^\s*model\s+' "$PRISMA_SCHEMA" | awk '{print $2}' 2>/dev/null || true)

    TABLE_WARNINGS=""
    while IFS= read -r mfile; do
      [ -z "$mfile" ] && continue
      FULL_PATH="$PROJECT_DIR/$mfile"
      [ ! -f "$FULL_PATH" ] && continue

      # SQL에서 참조하는 테이블명 추출 (CREATE TABLE, ALTER TABLE, INSERT INTO 등)
      SQL_TABLES=$(grep -oiE '(CREATE|ALTER|DROP|INSERT INTO|UPDATE|DELETE FROM|REFERENCES)\s+"?([a-zA-Z_][a-zA-Z0-9_]*)"?' "$FULL_PATH" 2>/dev/null \
        | sed 's/.*\s\+"\?\([a-zA-Z_][a-zA-Z0-9_]*\)"\?.*/\1/i' \
        | sort -u || true)

      while IFS= read -r tbl; do
        [ -z "$tbl" ] && continue
        # _prisma_migrations는 Prisma 내부 테이블 -> 스킵
        [[ "$tbl" == "_prisma_migrations" ]] && continue
        # SQL 예약어 스킵
        [[ "$tbl" =~ ^(TABLE|INDEX|CONSTRAINT|UNIQUE|PRIMARY|FOREIGN|KEY|CASCADE|SET|DEFAULT|NOT|NULL|IF|EXISTS|ADD|COLUMN|DROP)$ ]] && continue

        # schema 테이블 목록에 있는지 확인
        FOUND=""
        echo "$SCHEMA_TABLES" | grep -qw "$tbl" 2>/dev/null && FOUND="true"
        echo "$MODEL_NAMES" | grep -qiw "$tbl" 2>/dev/null && FOUND="true"

        if [ -z "$FOUND" ]; then
          TABLE_WARNINGS="${TABLE_WARNINGS}
  - ${mfile}: 테이블 \"${tbl}\"이 Prisma schema에 없음 (오타?)"
        fi
      done <<< "$SQL_TABLES"
    done <<< "$MIGRATION_FILES"

    if [ -n "$TABLE_WARNINGS" ]; then
      WARNINGS="${WARNINGS}
[WARN] Migration 테이블명 검증 - 불일치 발견${TABLE_WARNINGS}
   -> prisma/schema.prisma의 @@map() 테이블명과 비교하세요"
    fi
  fi
fi

if [ -n "$ALEMBIC_FILES" ]; then
  # Alembic migration에서 op.create_table/op.alter_table 등의 테이블명 추출
  ALEMBIC_MODELS="$PROJECT_DIR/apps/mcp-orbit/backend/app/models"
  if [ -d "$ALEMBIC_MODELS" ]; then
    # models 디렉토리에서 __tablename__ 추출
    MODEL_TABLE_NAMES=$(grep -r "__tablename__" "$ALEMBIC_MODELS" 2>/dev/null \
      | sed 's/.*__tablename__\s*=\s*"\(.*\)"/\1/' | sort -u || true)

    ALEMBIC_WARNINGS=""
    while IFS= read -r afile; do
      [ -z "$afile" ] && continue
      FULL_PATH="$PROJECT_DIR/$afile"
      [ ! -f "$FULL_PATH" ] && continue

      # Alembic op에서 테이블명 추출
      ALEMBIC_TABLES=$(grep -oE "op\.(create_table|alter_table|drop_table|add_column|drop_column)\(['\"]([a-zA-Z_]+)['\"]" "$FULL_PATH" 2>/dev/null \
        | sed "s/.*['\"]\\([a-zA-Z_]*\\)['\"].*/\\1/" | sort -u || true)

      while IFS= read -r tbl; do
        [ -z "$tbl" ] && continue
        [[ "$tbl" == "alembic_version" ]] && continue

        FOUND=""
        echo "$MODEL_TABLE_NAMES" | grep -qw "$tbl" 2>/dev/null && FOUND="true"

        if [ -z "$FOUND" ]; then
          ALEMBIC_WARNINGS="${ALEMBIC_WARNINGS}
  - ${afile}: 테이블 \"${tbl}\"이 models에 없음 (오타?)"
        fi
      done <<< "$ALEMBIC_TABLES"
    done <<< "$ALEMBIC_FILES"

    if [ -n "$ALEMBIC_WARNINGS" ]; then
      WARNINGS="${WARNINGS}
[WARN] Alembic Migration 테이블명 검증 - 불일치 발견${ALEMBIC_WARNINGS}
   -> models/ 디렉토리의 __tablename__과 비교하세요"
    fi
  fi
fi

# === 3. package.json 변경 -> pnpm-lock.yaml 동기화 확인 ===
PKG_CHANGED=$(echo "$STAGED" | grep "package\.json$" || true)

if [ -n "$PKG_CHANGED" ]; then
  LOCKFILE_STAGED=$(echo "$STAGED" | grep "pnpm-lock.yaml" || true)
  if [ -z "$LOCKFILE_STAGED" ]; then
    # lockfile이 staged에 없으면 경고
    # 하지만 git status에서 변경이 있는지도 확인
    LOCKFILE_MODIFIED=$(git diff --name-only 2>/dev/null | grep "pnpm-lock.yaml" || true)
    LOCKFILE_UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | grep "pnpm-lock.yaml" || true)

    if [ -n "$LOCKFILE_MODIFIED" ] || [ -n "$LOCKFILE_UNTRACKED" ]; then
      WARNINGS="${WARNINGS}
[WARN] package.json 변경됨 but pnpm-lock.yaml 미staged
   -> git add pnpm-lock.yaml 후 커밋하세요"
    else
      WARNINGS="${WARNINGS}
[WARN] package.json 변경됨 but pnpm-lock.yaml 미갱신
   -> pnpm install 실행 후 pnpm-lock.yaml을 커밋에 포함하세요"
    fi
  fi
fi

# === 4. TypeScript 파일 변경 -> 해당 앱만 tsc --noEmit ===
TS_AI_AGENT=$(echo "$STAGED" | grep -E "^apps/ai-agent/.*\.(ts|tsx)$" || true)
TS_MCP_ORBIT_FE=$(echo "$STAGED" | grep -E "^apps/mcp-orbit/frontend/.*\.(ts|tsx)$" || true)
TS_APP_HUB=$(echo "$STAGED" | grep -E "^apps/app-hub/.*\.(ts|tsx)$" || true)

TSC_RESULTS=""

if [ -n "$TS_AI_AGENT" ]; then
  # ai-agent는 backend와 frontend 분리 확인
  AI_AGENT_BE=$(echo "$TS_AI_AGENT" | grep -E "^apps/ai-agent/backend/" || true)
  AI_AGENT_FE=$(echo "$TS_AI_AGENT" | grep -E "^apps/ai-agent/frontend/" || true)

  if [ -n "$AI_AGENT_BE" ] && [ -f "$PROJECT_DIR/apps/ai-agent/backend/tsconfig.json" ]; then
    TSC_OUT=$(cd "$PROJECT_DIR/apps/ai-agent/backend" && npx tsc --noEmit 2>&1 | tail -5) || true
    TSC_EXIT=$?
    if [ $TSC_EXIT -ne 0 ]; then
      ERROR_COUNT=$(cd "$PROJECT_DIR/apps/ai-agent/backend" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
      TSC_RESULTS="${TSC_RESULTS}
  - ai-agent/backend: ${ERROR_COUNT}개 타입 에러
${TSC_OUT}"
    fi
  fi

  if [ -n "$AI_AGENT_FE" ] && [ -f "$PROJECT_DIR/apps/ai-agent/frontend/tsconfig.json" ]; then
    TSC_OUT=$(cd "$PROJECT_DIR/apps/ai-agent/frontend" && npx tsc --noEmit 2>&1 | tail -5) || true
    TSC_EXIT=$?
    if [ $TSC_EXIT -ne 0 ]; then
      ERROR_COUNT=$(cd "$PROJECT_DIR/apps/ai-agent/frontend" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
      TSC_RESULTS="${TSC_RESULTS}
  - ai-agent/frontend: ${ERROR_COUNT}개 타입 에러
${TSC_OUT}"
    fi
  fi
fi

if [ -n "$TS_MCP_ORBIT_FE" ] && [ -f "$PROJECT_DIR/apps/mcp-orbit/frontend/tsconfig.json" ]; then
  TSC_OUT=$(cd "$PROJECT_DIR/apps/mcp-orbit/frontend" && npx tsc --noEmit 2>&1 | tail -5) || true
  TSC_EXIT=$?
  if [ $TSC_EXIT -ne 0 ]; then
    ERROR_COUNT=$(cd "$PROJECT_DIR/apps/mcp-orbit/frontend" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
    TSC_RESULTS="${TSC_RESULTS}
  - mcp-orbit/frontend: ${ERROR_COUNT}개 타입 에러
${TSC_OUT}"
  fi
fi

if [ -n "$TS_APP_HUB" ] && [ -f "$PROJECT_DIR/apps/app-hub/tsconfig.json" ]; then
  TSC_OUT=$(cd "$PROJECT_DIR/apps/app-hub" && npx tsc --noEmit 2>&1 | tail -5) || true
  TSC_EXIT=$?
  if [ $TSC_EXIT -ne 0 ]; then
    ERROR_COUNT=$(cd "$PROJECT_DIR/apps/app-hub" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
    TSC_RESULTS="${TSC_RESULTS}
  - app-hub: ${ERROR_COUNT}개 타입 에러
${TSC_OUT}"
  fi
fi

if [ -n "$TSC_RESULTS" ]; then
  WARNINGS="${WARNINGS}
[FAIL] TypeScript 타입 체크 실패${TSC_RESULTS}
   -> 타입 에러를 수정 후 다시 커밋하세요"
fi

# === 실행 시간 체크 (5초 이내 타겟) ===
GATE_END=$(date +%s)
ELAPSED=$((GATE_END - GATE_START))

# === 출력 ===
if [ -n "$WARNINGS" ]; then
  {
    echo ""
    echo "=== Commit Quality Gate (${ELAPSED}s) ==="
    echo "$WARNINGS"
    echo ""
    echo "NOTE: 경고만 표시 (커밋은 차단하지 않음)"
    echo "=== End Quality Gate ==="
    echo ""
  } >&2
fi

exit 0
