#!/bin/bash
# ============================================================================
# Organization Invariant Checker Hook
# ============================================================================
# Triggers: PostToolUse (Edit, Write, MultiEdit)
# Purpose: 조직 불변규칙(BFF, 스키마 격리, SSE 금지, OpenAPI 재생성) 위반 자동 감지
# Output: systemMessage (경고만, non-blocking)
# Version: 1.0.0
# ============================================================================

trap 'exit 0' ERR
set +e

INPUT=$(cat 2>/dev/null || echo "")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only process code modification tools
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

# Skip if no file path
[[ -z "$FILE_PATH" ]] && exit 0

# Skip non-code files and internal files
case "$FILE_PATH" in
  *.md|*.log|*.lock|*.css|*.scss) exit 0 ;;
  *node_modules*|*.git*|*dist/*|*build/*) exit 0 ;;
  *.claude/hooks/*|*.claude/settings*) exit 0 ;;
esac

WARNINGS=""

# ── ORG-001: BFF Pattern Violation ──────────────────────────────────────────
# Frontend 파일에서 Backend URL 직접 호출 감지
check_bff_pattern() {
  local file="$1"
  # Frontend 파일만 대상
  case "$file" in
    *apps/*/frontend/src/*.ts|*apps/*/frontend/src/*.tsx) ;;
    *) return ;;
  esac

  # app/api/ 라우트 파일은 BFF 프록시이므로 제외
  case "$file" in
    */app/api/*) return ;;
  esac

  if [[ -f "$file" ]]; then
    # Backend 직접 호출 패턴 감지 (http://localhost, process.env.*_URL 직접 fetch 등)
    if grep -qE "(fetch|axios|got)\s*\(\s*['\"]https?://" "$file" 2>/dev/null ||
       grep -qE "(fetch|axios)\s*\(\s*['\`].*(:8001|:8000|:3001|backend)" "$file" 2>/dev/null; then
      WARNINGS="${WARNINGS}\n[ORG-001] BFF 위반: Browser에서 Backend 직접 호출 금지. app/api/ Route 사용 필요 ($file)"
    fi
  fi
}

# ── ORG-002: Schema Isolation Violation ─────────────────────────────────────
# public. 스키마 사용 감지
check_schema_isolation() {
  local file="$1"
  case "$file" in
    *.py|*.ts|*.sql|*.prisma) ;;
    *) return ;;
  esac

  if [[ -f "$file" ]]; then
    if grep -qE '(public\.\w+|schema.*=.*"public"|@db\..*public)' "$file" 2>/dev/null; then
      WARNINGS="${WARNINGS}\n[ORG-002] 스키마 격리 위반: public 스키마 금지. mcp_orch.* 또는 ai_agent.* 사용 ($file)"
    fi
  fi
}

# ── ORG-003: SSE New Usage ──────────────────────────────────────────────────
# 새 파일에서 SSE 엔드포인트 생성 감지
check_sse_new_usage() {
  local file="$1"
  case "$file" in
    *.py|*.ts) ;;
    *) return ;;
  esac

  if [[ -f "$file" ]]; then
    if grep -qE '(text/event-stream|EventSource|SSE|server-sent)' "$file" 2>/dev/null; then
      # 기존 파일 수정은 허용, 신규 SSE 엔드포인트만 경고
      WARNINGS="${WARNINGS}\n[ORG-003] SSE 신규 금지: Streamable HTTP 사용 필요 ($file)"
    fi
  fi
}

# ── ORG-004: OpenAPI Regeneration Needed ────────────────────────────────────
# DTO/Controller/Schema 파일 수정 시 OpenAPI 재생성 알림
check_openapi_regen() {
  local file="$1"
  case "$file" in
    *.dto.ts|*.controller.ts|*/schemas/*.py)
      WARNINGS="${WARNINGS}\n[ORG-004] OpenAPI 재생성 필요: Backend DTO/Controller 변경 감지. export-openapi + generate:api 실행 필요 ($file)"
      ;;
  esac
}

# Run all checks
check_bff_pattern "$FILE_PATH"
check_schema_isolation "$FILE_PATH"
check_sse_new_usage "$FILE_PATH"
check_openapi_regen "$FILE_PATH"

# Output warnings if any
if [[ -n "$WARNINGS" ]]; then
  # stderr로 경고 출력 (Agent가 인지)
  echo -e "$WARNINGS" >&2
  # JSON 출력 (non-blocking)
  echo '{"continue": true}'
else
  echo '{"continue": true}'
fi
