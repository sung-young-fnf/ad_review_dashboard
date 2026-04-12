#!/usr/bin/env bash
# fnf-mono-starter: 인터랙티브 앱 스캐폴딩 스크립트
#
# Interactive mode: ./scripts/create-app.sh
# CLI mode:         ./scripts/create-app.sh s3gate fastapi --port 3100 --sso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/templates"

# ─── Colors ───
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# ─── Helper: Check if port is in use ───
check_port() {
  local port="$1"
  if lsof -i ":$port" -sTCP:LISTEN &>/dev/null; then
    return 0  # in use
  fi
  return 1  # available
}

# ─── Helper: Find next available port ───
find_available_port() {
  local base_port="$1"
  local port="$base_port"
  while check_port "$port"; do
    port=$((port + 1))
  done
  echo "$port"
}

# ─── Helper: Prompt with default ───
prompt_with_default() {
  local prompt_text="$1"
  local default_val="$2"
  local result
  printf "${CYAN}${prompt_text}${RESET} ${DIM}[${default_val}]${RESET}: "
  read -r result
  echo "${result:-$default_val}"
}

# ─── Helper: Prompt yes/no ───
prompt_yn() {
  local prompt_text="$1"
  local default_val="${2:-y}"
  local hint="Y/n"
  [[ "$default_val" == "n" ]] && hint="y/N"
  local result
  printf "${CYAN}${prompt_text}${RESET} ${DIM}(${hint})${RESET}: "
  read -r result
  result="${result:-$default_val}"
  [[ "$result" =~ ^[Yy] ]]
}

# ─── Helper: Select from options ───
prompt_select() {
  local prompt_text="$1"
  shift
  local options=("$@")
  echo -e "${CYAN}${prompt_text}${RESET}"
  local i=1
  for opt in "${options[@]}"; do
    echo -e "  ${BOLD}${i})${RESET} ${opt}"
    i=$((i + 1))
  done
  local choice
  printf "${DIM}선택${RESET}: "
  read -r choice
  echo "${options[$((choice - 1))]}"
}

# ─── Replace placeholders ───
replace_placeholders() {
  local file="$1"
  # 루트 package.json에서 프로젝트명 추출
  local project_name
  project_name=$(grep '"name"' "$ROOT_DIR/package.json" | head -1 | sed 's/.*"\(.*\)".*/\1/' | sed 's/.*: *"//' | sed 's/".*//')

  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' \
      -e "s/{{APP_NAME}}/$APP_NAME/g" \
      -e "s/{{APP_NAME_SNAKE}}/$APP_SNAKE/g" \
      -e "s/{{PROJECT_NAME}}/$project_name/g" \
      -e "s/{{BACKEND_PORT}}/8000/g" \
      -e "s/{{FRONTEND_PORT}}/$FRONTEND_PORT/g" \
      -e "s/{{SSO_ENABLED}}/$SSO_ENABLED/g" \
      "$file"
  else
    sed -i \
      -e "s/{{APP_NAME}}/$APP_NAME/g" \
      -e "s/{{APP_NAME_SNAKE}}/$APP_SNAKE/g" \
      -e "s/{{PROJECT_NAME}}/$project_name/g" \
      -e "s/{{BACKEND_PORT}}/8000/g" \
      -e "s/{{FRONTEND_PORT}}/$FRONTEND_PORT/g" \
      -e "s/{{SSO_ENABLED}}/$SSO_ENABLED/g" \
      "$file"
  fi
}

# ═══════════════════════════════════════════════
# Interactive Mode (no args)
# ═══════════════════════════════════════════════
if [[ $# -eq 0 ]]; then
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║   fnf-mono-starter: New App Setup     ║${RESET}"
  echo -e "${BOLD}╚═══════════════════════════════════════╝${RESET}"
  echo ""

  # 1. App name
  APP_NAME=$(prompt_with_default "1. 앱 이름 (kebab-case)" "my-app")

  # 2. Backend type
  echo ""
  BACKEND_TYPE=$(prompt_select "2. 백엔드 프레임워크" "fastapi  — Python 3.11+ (SQLAlchemy + Alembic)" "nestjs   — TypeScript (Prisma)")
  BACKEND_TYPE=$(echo "$BACKEND_TYPE" | awk '{print $1}')

  # 3. Frontend port
  echo ""
  DEFAULT_PORT=$(find_available_port 3100)
  echo -e "${DIM}   포트 스캔: 3100부터 검색 중...${RESET}"
  if [[ "$DEFAULT_PORT" != "3100" ]]; then
    echo -e "${YELLOW}   ⚠️  3100 사용 중 → ${DEFAULT_PORT} 추천${RESET}"
  else
    echo -e "${GREEN}   ✅ 3100 사용 가능${RESET}"
  fi
  FRONTEND_PORT=$(prompt_with_default "3. 프론트엔드 포트" "$DEFAULT_PORT")

  # Validate chosen port
  if check_port "$FRONTEND_PORT"; then
    ALT_PORT=$(find_available_port "$FRONTEND_PORT")
    echo -e "${YELLOW}   ⚠️  포트 $FRONTEND_PORT 사용 중!${RESET}"
    if prompt_yn "   → $ALT_PORT 로 변경할까요?" "y"; then
      FRONTEND_PORT="$ALT_PORT"
    fi
  fi

  # 4. MS SSO
  echo ""
  SSO_ENABLED="false"
  if prompt_yn "4. Microsoft Entra ID SSO 인증 포함?" "y"; then
    SSO_ENABLED="true"
  fi

  # 5. DESIGN.md
  echo ""
  INCLUDE_DESIGN="false"
  if prompt_yn "5. DESIGN.md (AI 디자인 시스템) 포함?" "y"; then
    INCLUDE_DESIGN="true"
  fi

  # Summary
  echo ""
  echo -e "${BOLD}─── 설정 확인 ────────────────────────${RESET}"
  echo -e "  앱 이름:       ${GREEN}${APP_NAME}${RESET}"
  echo -e "  백엔드:        ${GREEN}${BACKEND_TYPE}${RESET}"
  echo -e "  프론트 포트:   ${GREEN}${FRONTEND_PORT}${RESET}"
  echo -e "  MS SSO:        ${GREEN}${SSO_ENABLED}${RESET}"
  echo -e "  DESIGN.md:     ${GREEN}${INCLUDE_DESIGN}${RESET}"
  echo -e "${BOLD}─────────────────────────────────────${RESET}"
  echo ""

  if ! prompt_yn "이대로 생성할까요?" "y"; then
    echo "취소됨."
    exit 0
  fi

# ═══════════════════════════════════════════════
# CLI Mode (with args)
# ═══════════════════════════════════════════════
else
  APP_NAME="${1:?Usage: $0 <app-name> <fastapi|nestjs> [--port N] [--sso] [--design]}"
  BACKEND_TYPE="${2:?Specify: fastapi or nestjs}"
  FRONTEND_PORT="3100"
  SSO_ENABLED="false"
  INCLUDE_DESIGN="false"

  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) FRONTEND_PORT="$2"; shift 2 ;;
      --sso) SSO_ENABLED="true"; shift ;;
      --design) INCLUDE_DESIGN="true"; shift ;;
      *) echo "❌ Unknown option: $1"; exit 1 ;;
    esac
  done
fi

# ─── Derived values ───
APP_SNAKE="${APP_NAME//-/_}"
APP_DIR="$ROOT_DIR/apps/$APP_NAME"

# ─── Validation ───
if [[ "$BACKEND_TYPE" != "fastapi" && "$BACKEND_TYPE" != "nestjs" ]]; then
  echo "❌ Backend type must be 'fastapi' or 'nestjs'. Got: $BACKEND_TYPE"
  exit 1
fi

if [ -d "$APP_DIR" ]; then
  echo "❌ App '$APP_NAME' already exists at $APP_DIR"
  exit 1
fi

echo ""
echo -e "${BOLD}🏗️  Creating app: $APP_NAME${RESET}"
echo ""

# ─── 1. Backend ───
echo "📦 Backend ($BACKEND_TYPE)..."
mkdir -p "$APP_DIR/backend"
cp -r "$TEMPLATE_DIR/$BACKEND_TYPE/"* "$APP_DIR/backend/"

if [[ "$BACKEND_TYPE" == "fastapi" ]]; then
  if [ -d "$APP_DIR/backend/src/{app_name}" ]; then
    mv "$APP_DIR/backend/src/{app_name}" "$APP_DIR/backend/src/$APP_SNAKE"
  fi
fi

find "$APP_DIR/backend" -type f \( -name "*.py" -o -name "*.toml" -o -name "*.ini" -o -name "*.json" -o -name "*.ts" -o -name "*.env*" -o -name "*.yaml" -o -name "*.yml" -o -name "*.mako" -o -name "*.sql" -o -name "*.prisma" -o -name "*.sh" -o -name "Dockerfile" \) | while read -r f; do
  replace_placeholders "$f"
done

# ─── 2. Frontend (Next.js 16) ───
echo "🎨 Frontend (Next.js 16)..."
mkdir -p "$APP_DIR/frontend"
cp -r "$TEMPLATE_DIR/nextjs/"* "$APP_DIR/frontend/"

find "$APP_DIR/frontend" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.js" -o -name "*.css" -o -name "Dockerfile" -o -name "*.env*" \) | while read -r f; do
  replace_placeholders "$f"
done

# ─── 3. Auth mode (SSO vs No-Auth) ───
if [[ "$SSO_ENABLED" == "true" ]]; then
  echo "🔐 Auth: MS Entra ID SSO..."
  # SSO auth.ts 사용 (이미 템플릿에서 복사됨 — auth-sso.ts가 원본)
  cp "$APP_DIR/frontend/src/lib/auth-modes/auth-sso.ts" "$APP_DIR/frontend/src/lib/auth.ts"
else
  echo "🔓 Auth: No-Auth (개발 모드)..."
  # 더미 auth.ts 사용 — 로그인 없이 바로 진입
  cp "$APP_DIR/frontend/src/lib/auth-modes/auth-none.ts" "$APP_DIR/frontend/src/lib/auth.ts"
  # middleware.ts 제거 (라우트 보호 불필요)
  rm -f "$APP_DIR/frontend/src/middleware.ts"
  # 로그인 페이지 → 홈으로 redirect
  mkdir -p "$APP_DIR/frontend/src/app/(public)/login"
  cat > "$APP_DIR/frontend/src/app/(public)/login/page.tsx" << 'NOLOGINEOF'
import { redirect } from 'next/navigation';
export default function LoginPage() { redirect('/admin/users'); }
NOLOGINEOF
fi

if [[ "$SSO_ENABLED" == "true" ]]; then
  echo "  SSO .env 추가..."

  # Backend SSO config
  if [[ "$BACKEND_TYPE" == "fastapi" ]]; then
    cat >> "$APP_DIR/backend/.env.example" << EOF

# Microsoft Entra ID SSO
$(echo "${APP_SNAKE}" | tr '[:lower:]' '[:upper:]')_ENTRA_CLIENT_ID=your-client-id
$(echo "${APP_SNAKE}" | tr '[:lower:]' '[:upper:]')_ENTRA_CLIENT_SECRET=your-client-secret
$(echo "${APP_SNAKE}" | tr '[:lower:]' '[:upper:]')_ENTRA_TENANT_ID=your-tenant-id
$(echo "${APP_SNAKE}" | tr '[:lower:]' '[:upper:]')_ENTRA_REDIRECT_URI=http://localhost:${FRONTEND_PORT}/api/auth/callback
EOF
  else
    cat >> "$APP_DIR/backend/.env.example" << EOF

# Microsoft Entra ID SSO
ENTRA_CLIENT_ID=your-client-id
ENTRA_CLIENT_SECRET=your-client-secret
ENTRA_TENANT_ID=your-tenant-id
ENTRA_REDIRECT_URI=http://localhost:${FRONTEND_PORT}/api/auth/callback
EOF
  fi

  # Frontend auth API route placeholder
  mkdir -p "$APP_DIR/frontend/src/app/api/auth"
  cat > "$APP_DIR/frontend/src/app/api/auth/route.ts" << 'EOF'
// MS Entra ID SSO — BFF Auth Route
// next-auth 또는 authlib 기반 구현 필요
// Browser → /api/auth/login → Entra ID → /api/auth/callback → JWT 세션

export async function GET() {
  return Response.json({ message: 'Auth route placeholder — implement SSO here' });
}
EOF

  # Login page (next-auth signIn)
  mkdir -p "$APP_DIR/frontend/src/app/(public)/login"
  cat > "$APP_DIR/frontend/src/app/(public)/login/page.tsx" << 'LOGINEOF'
'use client';

import { signIn } from 'next-auth/react';

export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-sm space-y-6 text-center">
        <h1 className="text-3xl font-bold">APP_NAME_PLACEHOLDER</h1>
        <p className="text-gray-500">Microsoft 계정으로 로그인하세요</p>
        <button
          onClick={() => signIn('azure-ad', { callbackUrl: '/' })}
          className="w-full rounded-lg bg-blue-600 px-6 py-3 text-white font-medium hover:bg-blue-700"
        >
          Microsoft 계정으로 로그인
        </button>
      </div>
    </div>
  );
}
LOGINEOF
  # heredoc 내부에서 변수 치환이 안 되므로 sed로 별도 치환
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" "$APP_DIR/frontend/src/app/(public)/login/page.tsx"
  else
    sed -i "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" "$APP_DIR/frontend/src/app/(public)/login/page.tsx"
  fi
fi

# ─── 4. DESIGN.md (optional) ───
if [[ "$INCLUDE_DESIGN" == "true" ]]; then
  echo "🎨 DESIGN.md 추가..."
  cp "$TEMPLATE_DIR/DESIGN.md" "$APP_DIR/DESIGN.md"
  replace_placeholders "$APP_DIR/DESIGN.md"
fi

# ─── 5. Helm Chart ───
echo "⎈  Helm chart..."
CHART_DIR="$ROOT_DIR/charts/$APP_NAME"
mkdir -p "$CHART_DIR/templates"
cp -r "$ROOT_DIR/charts/{app_name}/"* "$CHART_DIR/" 2>/dev/null || true

find "$CHART_DIR" -type f | while read -r f; do
  replace_placeholders "$f"
done

# ─── 6. .mcp.json (DB MCP Server) ───
echo "🗄️  .mcp.json DB MCP 추가..."
MCP_JSON="$ROOT_DIR/.mcp.json"
MCP_LOCAL_KEY="postgres-${APP_NAME}-local"
MCP_LOCAL_URL="postgresql://${APP_SNAKE}_svc:changeme@localhost:5432/${APP_SNAKE}_db"

if [ -f "$MCP_JSON" ]; then
  if command -v jq &>/dev/null; then
    TMP_MCP=$(mktemp)
    jq --arg lk "$MCP_LOCAL_KEY" --arg lu "$MCP_LOCAL_URL" \
       '.mcpServers[$lk] = {
          "type": "stdio",
          "command": "npx",
          "args": ["-y", "enhanced-postgres-mcp-server", $lu]
        }' "$MCP_JSON" > "$TMP_MCP"
    mv "$TMP_MCP" "$MCP_JSON"
    echo -e "  ${GREEN}✅ .mcp.json에 ${MCP_LOCAL_KEY} 추가됨${RESET}"
  else
    echo -e "  ${YELLOW}⚠️  jq 미설치 — .mcp.json 수동 편집 필요${RESET}"
  fi
else
  cat > "$MCP_JSON" << MCPEOF
{
  "mcpServers": {
    "${MCP_LOCAL_KEY}": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "enhanced-postgres-mcp-server",
        "${MCP_LOCAL_URL}"
      ]
    }
  }
}
MCPEOF
  echo -e "  ${GREEN}✅ .mcp.json 생성됨 (${MCP_LOCAL_KEY})${RESET}"
fi

# ─── 7. App CLAUDE.md ───
echo "🤖 CLAUDE.md..."
cat > "$APP_DIR/CLAUDE.md" << EOF
# ${APP_NAME}

## Tech Stack
| Layer | Tech |
|-------|------|
| Backend | $([ "$BACKEND_TYPE" == "fastapi" ] && echo "Python 3.11+ FastAPI + SQLAlchemy + Alembic" || echo "TypeScript NestJS + Prisma") |
| Frontend | Next.js 16 React 19 TypeScript |
| DB Schema | \`${APP_SNAKE}.*\` (PostgreSQL, DBUSER 정책) |
| Auth | $([ "$SSO_ENABLED" == "true" ] && echo "Microsoft Entra ID SSO (OIDC)" || echo "JWT (자체 인증)") |

## DB 작업 시 필수
- public 스키마 금지 → \`${APP_SNAKE}\` 스키마만 사용
- 앱 런타임: \`${APP_SNAKE}_svc\` 계정 (DML 전용)
- 마이그레이션: \`${APP_SNAKE}_$([ "$BACKEND_TYPE" == "fastapi" ] && echo "alembic" || echo "prisma")_ops\` 계정

## BFF 패턴 (필수)
\`\`\`
Browser → Next.js API Route → ${BACKEND_TYPE} Backend
\`\`\`
EOF

echo ""
echo -e "${GREEN}✅ App '${APP_NAME}' 생성 완료!${RESET}"
echo ""
echo "  apps/$APP_NAME/"
echo "  ├── backend/      ($BACKEND_TYPE)"
echo "  ├── frontend/     (Next.js 16)"
[[ "$INCLUDE_DESIGN" == "true" ]] && echo "  ├── DESIGN.md     (AI 디자인 시스템)"
[[ "$SSO_ENABLED" == "true" ]] && echo "  ├── (SSO 포함)    Microsoft Entra ID"
echo "  └── CLAUDE.md"
echo "  charts/$APP_NAME/  (Helm)"
echo "  .mcp.json          (DB MCP: local)"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
if [[ "$BACKEND_TYPE" == "fastapi" ]]; then
  echo "  1. cd apps/$APP_NAME/backend && uv sync"
else
  echo "  1. cd apps/$APP_NAME/backend && pnpm install"
fi
echo "  2. cp .env.example .env && vi .env"
echo "  3. DB init: psql -U postgres -f apps/$APP_NAME/backend/scripts/init-db.sql"
echo "  4. cd apps/$APP_NAME/frontend && pnpm install"
echo "  5. pnpm dev (from root)"
