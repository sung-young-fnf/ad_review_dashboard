#!/bin/bash
#
# PreToolUse Hook - Monorepo Affected-App Detection
#
# Purpose: git commit 시 staged 파일을 분석하여 크로스앱 영향 경고
# Trigger: PreToolUse (Bash) - git commit 명령어 감지 시
# Output: stderr에 경고 표시 (non-blocking, exit 0 유지)
#
# 감지 항목:
#   1. prisma/schema.prisma 변경 → ai-agent, app-hub 영향
#   2. packages/ 공유 파일 변경 → 모든 앱 영향
#   3. Pydantic DTO 변경 → 크로스서비스 호출 가능성
#   4. OpenAPI spec 변경 → 프론트엔드 재생성 필요
#
# WHY: wrong_approach 95건 중 모노레포 크로스앱 영향 미인지가 주요 원인

set +e
trap 'exit 0' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$PROJECT_DIR" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Bash 도구가 아니면 스킵
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

# git commit 명령어가 아니면 스킵
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit|&&\s*git\s+commit|\|\|\s*git\s+commit'; then
  exit 0
fi

# staged 파일 목록
STAGED=$(cd "$PROJECT_DIR" && git diff --cached --name-only 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

WARNINGS=""
AFFECTED_APPS=""

# === 1. Prisma schema 변경 → ai-agent, app-hub 영향 ===
if echo "$STAGED" | grep -q "prisma/schema.prisma"; then
  AFFECTED_APPS="ai-agent app-hub"
  WARNINGS="${WARNINGS}
  변경: prisma/schema.prisma
  영향 앱: ai-agent, app-hub (Prisma 사용)"
fi

# === 2. packages/ 공유 파일 변경 → 모든 앱 영향 ===
SHARED_CHANGES=$(echo "$STAGED" | grep -E "^packages/" || true)
if [ -n "$SHARED_CHANGES" ]; then
  AFFECTED_APPS="${AFFECTED_APPS} mcp-orbit ai-agent app-hub"
  CHANGED_PKGS=$(echo "$SHARED_CHANGES" | head -3 | tr '\n' ', ' | sed 's/,$//')
  WARNINGS="${WARNINGS}
  변경: ${CHANGED_PKGS}
  영향 앱: mcp-orbit, ai-agent, app-hub (공유 패키지)"
fi

# === 3. Pydantic DTO (mcp-orbit schemas) 변경 → 크로스서비스 호출 가능성 ===
PYDANTIC_CHANGES=$(echo "$STAGED" | grep -E "^apps/mcp-orbit/backend/.*schemas/.*\.py$" || true)
if [ -n "$PYDANTIC_CHANGES" ]; then
  CHANGED_SCHEMAS=$(echo "$PYDANTIC_CHANGES" | head -3 | tr '\n' ', ' | sed 's/,$//')
  WARNINGS="${WARNINGS}
  변경: ${CHANGED_SCHEMAS}
  영향: ai-agent에서 mcp-orbit API를 호출하는 경우 타입 불일치 가능"
fi

# === 4. OpenAPI spec 변경 → 프론트엔드 재생성 필요 ===
OPENAPI_CHANGES=$(echo "$STAGED" | grep -E "openapi\.(json|yaml)$" || true)
if [ -n "$OPENAPI_CHANGES" ]; then
  # OpenAPI가 어느 앱에 속하는지 판별
  OPENAPI_APPS=""
  echo "$OPENAPI_CHANGES" | grep -q "mcp-orbit" && OPENAPI_APPS="${OPENAPI_APPS} mcp-orbit"
  echo "$OPENAPI_CHANGES" | grep -q "ai-agent" && OPENAPI_APPS="${OPENAPI_APPS} ai-agent"
  echo "$OPENAPI_CHANGES" | grep -q "app-hub" && OPENAPI_APPS="${OPENAPI_APPS} app-hub"
  [ -z "$OPENAPI_APPS" ] && OPENAPI_APPS="(앱 미식별)"

  WARNINGS="${WARNINGS}
  변경: $(echo "$OPENAPI_CHANGES" | head -2 | tr '\n' ', ' | sed 's/,$//')
  영향 앱:${OPENAPI_APPS} — 프론트엔드 타입 재생성 필요"
fi

# === 5. 한 앱의 backend DTO 변경 → 같은 앱의 frontend 영향 ===
for APP in mcp-orbit ai-agent app-hub; do
  BE_DTO_CHANGES=$(echo "$STAGED" | grep -E "^apps/${APP}/backend/.*(dto|schemas)/.*\.(ts|py)$" || true)
  FE_CHANGES=$(echo "$STAGED" | grep -E "^apps/${APP}/frontend/" || true)
  if [ -n "$BE_DTO_CHANGES" ] && [ -z "$FE_CHANGES" ]; then
    WARNINGS="${WARNINGS}
  변경: ${APP}/backend DTO
  주의: ${APP}/frontend 변경이 없습니다 — OpenAPI 타입 재생성이 필요할 수 있습니다"
  fi
done

# === 출력 ===
if [ -n "$WARNINGS" ]; then
  # 영향 앱 중복 제거
  UNIQUE_APPS=$(echo "$AFFECTED_APPS" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | xargs)

  {
    echo ""
    echo "=== Cross-App Impact Detection ==="
    echo "$WARNINGS"
    echo ""
    if [ -n "$UNIQUE_APPS" ]; then
      echo "  영향받는 앱에서 타입 체크 권장:"
      for APP in $UNIQUE_APPS; do
        if [ -d "$PROJECT_DIR/apps/${APP}/frontend" ]; then
          echo "    cd apps/${APP}/frontend && pnpm tsc --noEmit"
        fi
      done
      echo ""
    fi
    echo "  NOTE: 경고만 표시 (커밋은 차단하지 않음)"
    echo "=== End Cross-App Detection ==="
    echo ""
  } >&2
fi

exit 0
