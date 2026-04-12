#!/bin/bash
# ============================================================================
# Config Protection Guard Hook (ECC 패턴 적용)
# ============================================================================
# Triggers: PreToolUse (Edit, Write, MultiEdit)
# Purpose: 린터/포매터/빌드 설정 파일 변경 차단
#   → Agent가 코드를 고치는 대신 설정을 약화시키는 안티패턴 방지
# Output: exit 2 = block, exit 0 = allow
# Origin: everything-claude-code config-protection.js 를 Shell로 재구현
# Version: 1.0.0
# ============================================================================

set +e

INPUT=$(cat 2>/dev/null || echo "")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Edit, Write, MultiEdit만 처리
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) echo "$INPUT"; exit 0 ;;
esac

# file_path 없으면 pass
if [[ -z "$FILE_PATH" ]]; then
  echo "$INPUT"
  exit 0
fi

# basename 추출
BASENAME=$(basename "$FILE_PATH")

# ── Protected Files ───────────────────────────────────────────────────────
# ESLint (legacy + flat config)
# Prettier
# Biome
# Ruff (Python)
# StyleLint, ShellCheck, MarkdownLint
# tsconfig (strict 약화 방지)
# ──────────────────────────────────────────────────────────────────────────

BLOCKED=""

case "$BASENAME" in
  # ESLint
  .eslintrc|.eslintrc.js|.eslintrc.cjs|.eslintrc.json|.eslintrc.yml|.eslintrc.yaml)
    BLOCKED="ESLint config"
    ;;
  eslint.config.js|eslint.config.mjs|eslint.config.cjs|eslint.config.ts|eslint.config.mts|eslint.config.cts)
    BLOCKED="ESLint flat config"
    ;;
  # Prettier
  .prettierrc|.prettierrc.js|.prettierrc.cjs|.prettierrc.json|.prettierrc.yml|.prettierrc.yaml)
    BLOCKED="Prettier config"
    ;;
  prettier.config.js|prettier.config.cjs|prettier.config.mjs)
    BLOCKED="Prettier config"
    ;;
  # Biome
  biome.json|biome.jsonc)
    BLOCKED="Biome config"
    ;;
  # Ruff (Python)
  .ruff.toml|ruff.toml)
    BLOCKED="Ruff config"
    ;;
  # StyleLint
  .stylelintrc|.stylelintrc.json|.stylelintrc.yml)
    BLOCKED="StyleLint config"
    ;;
  # ShellCheck
  .shellcheckrc)
    BLOCKED="ShellCheck config"
    ;;
  # MarkdownLint
  .markdownlint.json|.markdownlint.yaml|.markdownlintrc)
    BLOCKED="MarkdownLint config"
    ;;
esac

# tsconfig — 특수 처리: 앱별 tsconfig도 보호
if [[ -z "$BLOCKED" ]]; then
  case "$BASENAME" in
    tsconfig.json|tsconfig.*.json)
      BLOCKED="TypeScript config"
      ;;
  esac
fi

# ── Decision ──────────────────────────────────────────────────────────────

if [[ -n "$BLOCKED" ]]; then
  echo "⛔ BLOCKED: ${BLOCKED} 수정 차단 (${BASENAME}). 설정을 약화시키지 말고 소스 코드를 수정하세요." >&2
  echo "💡 정당한 설정 변경이라면 사용자에게 직접 수정을 요청하세요." >&2
  exit 2
fi

# No match = allow
echo "$INPUT"
exit 0
