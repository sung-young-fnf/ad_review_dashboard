#!/bin/bash
# PermissionRequest Hook - DB Destructive Command Guard
# deny: DROP/TRUNCATE/DELETE(no WHERE)/prisma reset/deploy/alembic upgrade/downgrade
# ask: DELETE FROM ... WHERE
# empty output: pass-through

set +e
LOG_FILE="/tmp/claude-db-guard.log"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

deny() {
  log "DENY: $1: $CMD"
  echo "  -> $2" >&2
  echo '{"decision":"deny"}'
}

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
[[ -z "$COMMAND" ]] && exit 0

CMD=$(echo "$COMMAND" | tr '\n' ' ' | sed 's/  */ /g')

make_decision() {
  # SQL DDL/DML (case-insensitive)
  if echo "$CMD" | grep -iqE '\bDROP\s+TABLE\b'; then
    deny "DROP TABLE" "db-code-writer agent에게 위임하거나 수동으로 실행하세요."; return; fi

  if echo "$CMD" | grep -iqE '\bDROP\s+DATABASE\b'; then
    deny "DROP DATABASE" "db-code-writer agent에게 위임하거나 수동으로 실행하세요."; return; fi

  if echo "$CMD" | grep -iqE '\bTRUNCATE\b'; then
    deny "TRUNCATE" "db-code-writer agent에게 위임하거나 수동으로 실행하세요."; return; fi

  # DELETE FROM: deny without WHERE, ask with WHERE
  if echo "$CMD" | grep -iqE '\bDELETE\s+FROM\b'; then
    if echo "$CMD" | grep -iqE '\bDELETE\s+FROM\b.*\bWHERE\b'; then
      log "ASK: DELETE FROM with WHERE: $CMD"
      echo "  -> WHERE 절이 있지만 확인이 필요합니다." >&2
      echo '{"decision":"ask"}'
    else
      deny "DELETE FROM without WHERE" "WHERE 절 없는 DELETE는 차단됩니다. 조건을 추가하세요."
    fi
    return
  fi

  # Prisma
  if echo "$CMD" | grep -iqE 'prisma\s+migrate\s+reset'; then
    deny "prisma migrate reset" "prisma migrate dev --create-only 를 사용하세요."; return; fi

  if echo "$CMD" | grep -iqE 'prisma\s+db\s+push\s+--force-reset'; then
    deny "prisma db push --force-reset" "--force-reset 없이 prisma db push를 사용하세요."; return; fi

  if echo "$CMD" | grep -iqE 'prisma\s+migrate\s+deploy'; then
    deny "prisma migrate deploy" "프로덕션 마이그레이션은 CI/CD 파이프라인에서 실행하세요."; return; fi

  # Alembic
  if echo "$CMD" | grep -iqE 'alembic\s+upgrade\b'; then
    deny "alembic upgrade" "alembic revision으로 파일 생성만 하세요."; return; fi

  if echo "$CMD" | grep -iqE 'alembic\s+downgrade\b'; then
    deny "alembic downgrade" "alembic revision으로 파일 생성만 하세요."; return; fi

  # No match - pass through (empty output)
}

make_decision
