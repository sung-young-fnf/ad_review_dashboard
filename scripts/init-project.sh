#!/usr/bin/env bash
# fnf-mono-starter: 프로젝트 초기화 스크립트
# Usage: ./scripts/init-project.sh <project-name> [description]
# Example: ./scripts/init-project.sh prcs-devtool "PRCS Internal Dev Tools"

set -euo pipefail

PROJECT_NAME="${1:?Usage: $0 <project-name> [description]}"
PROJECT_DESC="${2:-$PROJECT_NAME Monorepo}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Initializing project: $PROJECT_NAME"

# Replace placeholders in package.json
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$ROOT_DIR/package.json"
  sed -i '' "s/{{PROJECT_DESCRIPTION}}/$PROJECT_DESC/g" "$ROOT_DIR/package.json"
else
  sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$ROOT_DIR/package.json"
  sed -i "s/{{PROJECT_DESCRIPTION}}/$PROJECT_DESC/g" "$ROOT_DIR/package.json"
fi

# Remove template remote + reinitialize git
cd "$ROOT_DIR"
if [ -d .git ]; then
  git remote remove origin 2>/dev/null || true
  echo "✅ Template remote 제거됨"
else
  git init
  echo "✅ Git initialized"
fi

# Install dependencies
if command -v pnpm &> /dev/null; then
  pnpm install
  echo "✅ Dependencies installed"
else
  echo "⚠️  pnpm not found. Run: npm install -g pnpm && pnpm install"
fi

echo ""
echo "✅ Project '$PROJECT_NAME' initialized!"
echo ""
echo "Next steps:"
echo "  1. Create an app:  ./scripts/create-app.sh <app-name> <fastapi|nestjs>"
echo "  2. Start dev:      pnpm dev"
echo "  3. Build:          pnpm build"
echo ""
echo "Git remote:"
echo "  git remote add origin https://github.com/your-org/$PROJECT_NAME.git"
echo "  git push -u origin main"
