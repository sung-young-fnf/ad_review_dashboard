#!/bin/bash
# ============================================================================
# Sensitive File Guard Hook
# ============================================================================
# Triggers: PreToolUse (Edit, Write)
# Purpose: DB migration, auth, 암호화 관련 파일 변경 시 사용자 확인 강제
# Output: {"decision": "block", "reason": "..."} 또는 빈 출력 (allow)
# Version: 1.0.0
# ============================================================================

set +e

INPUT=$(cat 2>/dev/null || echo "")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Only process Write and Edit tools
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Skip if no file_path
[[ -z "$FILE_PATH" ]] && exit 0

# ── Sensitive File Pattern Matching ─────────────────────────────────────────

REASON=""

# DB Migration files
case "$FILE_PATH" in
  */alembic/versions/*.py)
    REASON="DB Migration 파일 변경 감지. DB 스키마에 영향을 줍니다."
    ;;
  */prisma/schema.prisma|*/prisma/schema/*.prisma)
    REASON="Prisma Schema 변경 감지. DB 스키마에 영향을 줍니다."
    ;;
esac

# Auth/Guard files (if not already matched)
if [[ -z "$REASON" ]]; then
  case "$FILE_PATH" in
    */auth/*.ts|*/auth/*.py|*/guards/*.ts|*/guards/*.py)
      REASON="인증/권한 디렉토리 파일 변경 감지. 보안에 영향을 줍니다."
      ;;
    *guard*.ts|*guard*.py)
      REASON="Guard 파일 변경 감지. 인증/권한에 영향을 줍니다."
      ;;
    *auth*.module.ts)
      REASON="Auth 모듈 변경 감지. 인증 체계에 영향을 줍니다."
      ;;
  esac
fi

# Encryption files (if not already matched)
if [[ -z "$REASON" ]]; then
  case "$FILE_PATH" in
    *encrypt*|*decrypt*|*crypto*)
      REASON="암호화 관련 파일 변경 감지. 데이터 보안에 영향을 줍니다."
      ;;
  esac
fi

# Settings files (non-blocking warning only)
if [[ -z "$REASON" ]]; then
  case "$FILE_PATH" in
    */.claude/settings.json|*/.claude/settings.local.json)
      # WARN only, non-blocking
      echo "Claude 설정 파일 변경 감지 (non-blocking)" >&2
      exit 0
      ;;
  esac
fi

# ── Decision Output ─────────────────────────────────────────────────────────

if [[ -n "$REASON" ]]; then
  echo "$REASON" >&2
  # Block: 사용자 확인 필요
  cat <<EOF
{"decision":"ask","reason":"$REASON 변경을 승인하시겠습니까?"}
EOF
fi

# No match = allow (빈 출력)
