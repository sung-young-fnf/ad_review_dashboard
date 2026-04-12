#!/bin/bash
#
# PermissionRequest Hook - Auto-Approve Safe Commands (2.0.45)
#
# Purpose: 안전한 Bash 명령어 자동 승인으로 반복 클릭 제거
# Trigger: PermissionRequest 이벤트 (Bash 도구)
# Output: JSON { "decision": "allow" | "deny" | "ask" }
#
# Input (stdin JSON):
# {
#   "tool_name": "Bash",
#   "tool_input": { "command": "ls -la", ... }
# }

set +e

LOG_FILE="/tmp/claude-permission-request.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Read input
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

log "PermissionRequest: command=$COMMAND"

# Safe command patterns (read-only or development tools)
SAFE_PATTERNS=(
  # Git read-only
  "^git status"
  "^git log"
  "^git diff"
  "^git branch"
  "^git show"
  "^git remote"
  "^git fetch"
  "^git rev-parse"

  # File inspection (read-only)
  "^ls "
  "^cat "
  "^head "
  "^tail "
  "^wc "
  "^file "
  "^which "
  "^type "

  # Package manager read-only
  "^pnpm list"
  "^pnpm why"
  "^npm list"
  "^npm why"
  "^uv pip list"
  "^pip list"

  # Development tools
  "^pnpm build"
  "^pnpm lint"
  "^pnpm test"
  "^pnpm dev"
  "^pnpm typecheck"
  "^npm run build"
  "^npm run lint"
  "^npm run test"

  # Safe system commands
  "^pwd$"
  "^whoami$"
  "^date$"
  "^echo "
  "^printenv"
  "^env$"

  # kubectl read-only
  "^kubectl get"
  "^kubectl describe"
  "^kubectl logs"
  "^kubectl config view"

  # Docker read-only
  "^docker ps"
  "^docker images"
  "^docker logs"
  "^docker inspect"
)

# Check if command matches safe patterns
is_safe_command() {
  local cmd="$1"
  for pattern in "${SAFE_PATTERNS[@]}"; do
    if echo "$cmd" | grep -qE "$pattern"; then
      return 0
    fi
  done
  return 1
}

# Dangerous patterns (always ask)
DANGEROUS_PATTERNS=(
  "rm -rf"
  "sudo "
  "> /dev/"
  "mkfs"
  "dd if="
  "chmod 777"
  "curl.*| *sh"
  "wget.*| *sh"
  ":(){:|:&};:"
  # EP121: DB 파괴 명령 (이중 방어)
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE"
  "prisma migrate reset"
  "prisma db push --force-reset"
  "prisma migrate deploy"
  "alembic upgrade"
  "alembic downgrade"
)

is_dangerous_command() {
  local cmd="$1"
  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$cmd" | grep -qF "$pattern"; then
      return 0
    fi
  done
  return 1
}

# Main decision logic
make_decision() {
  local cmd="$1"

  # Empty command - ask
  if [[ -z "$cmd" ]]; then
    echo '{"decision": "ask"}'
    return
  fi

  # Dangerous - always ask
  if is_dangerous_command "$cmd"; then
    log "DANGEROUS: $cmd"
    echo '{"decision": "ask"}'
    return
  fi

  # Safe - auto allow
  if is_safe_command "$cmd"; then
    log "AUTO-ALLOW: $cmd"
    echo '{"decision": "allow"}'
    return
  fi

  # Unknown - ask user
  log "ASK: $cmd"
  echo '{"decision": "ask"}'
}

# Output decision
make_decision "$COMMAND"
