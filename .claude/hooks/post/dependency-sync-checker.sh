#!/bin/bash
# dependency-sync-checker.sh — PostToolUse (Edit/Write) Hook
# 1. package.json 변경 시 동기화 누락 경고 표시
# 2. 새로운 누락 패턴 발견 시 CLAUDE.md에 자동 추가
# WHY: Git 히스토리 분석 결과 SDK 42%, lockfile 15건, openapi 17건 누락
set -o pipefail
trap 'exit 0' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# tool_input에서 파일 경로 추출 (stdin으로 JSON 수신)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)

[ -z "$FILE_PATH" ] && exit 0

WARNINGS=""
CLAUDE_MD="$PROJECT_DIR/apps/ai-agent/CLAUDE.md"

# === 1. SDK 동기화 체크 ===
if [[ "$FILE_PATH" == *"ai-agent/backend/package.json"* ]] || [[ "$FILE_PATH" == *"ai-agent/sandbox/package.json"* ]]; then
  BE_PKG="$PROJECT_DIR/apps/ai-agent/backend/package.json"
  SB_PKG="$PROJECT_DIR/apps/ai-agent/sandbox/package.json"

  if [ -f "$BE_PKG" ] && [ -f "$SB_PKG" ]; then
    # 공통 의존성 버전 비교
    MISMATCHES=$(python3 -c "
import json
be = json.load(open('$BE_PKG')).get('dependencies',{})
sb = json.load(open('$SB_PKG')).get('dependencies',{})
common = set(be.keys()) & set(sb.keys())
for k in sorted(common):
    if be[k] != sb[k]:
        print(f'  {k}: backend={be[k]} ≠ sandbox={sb[k]}')
" 2>/dev/null || true)

    if [ -n "$MISMATCHES" ]; then
      WARNINGS="${WARNINGS}
⚠️ backend ↔ sandbox 공통 의존성 버전 불일치:
${MISMATCHES}
   → 양쪽 package.json을 동일 버전으로 맞춰주세요"
    fi
  fi
fi

# === 2. lockfile 리마인더 ===
if [[ "$FILE_PATH" == *"package.json"* ]]; then
  WARNINGS="${WARNINGS}
📦 package.json 변경 → 커밋 전 pnpm install + pnpm-lock.yaml 포함 필수"
fi

# === 3. DTO/Controller → openapi 리마인더 ===
if [[ "$FILE_PATH" == *"ai-agent/backend/src"* ]] && [[ "$FILE_PATH" == *".dto.ts"* || "$FILE_PATH" == *".controller.ts"* ]]; then
  WARNINGS="${WARNINGS}
📋 DTO/Controller 변경 → 커밋 전 openapi.json 재생성 필요
   cd apps/ai-agent/backend && ./scripts/export-openapi.sh"
fi

# === 4. 새로운 동기화 대상 자동 감지 + CLAUDE.md 업데이트 ===
# backend에 새 의존성 추가됐는데 sandbox에도 있어야 하는 패턴 감지
if [[ "$FILE_PATH" == *"ai-agent/backend/package.json"* ]] && [ -f "$CLAUDE_MD" ]; then
  # claude-agent-sdk 외에 새로운 공통 의존성이 불일치하면 CLAUDE.md에 기록
  NEW_SYNC_NEEDED=$(python3 -c "
import json
be = json.load(open('$BE_PKG')).get('dependencies',{})
sb = json.load(open('$SB_PKG')).get('dependencies',{})
common = set(be.keys()) & set(sb.keys())
mismatched = [k for k in common if be[k] != sb[k] and k != '@anthropic-ai/claude-agent-sdk']
if mismatched:
    print(', '.join(mismatched))
" 2>/dev/null || true)

  if [ -n "$NEW_SYNC_NEEDED" ]; then
    # CLAUDE.md에 이 의존성이 이미 기록되어 있는지 확인
    for dep in $NEW_SYNC_NEEDED; do
      if ! grep -q "$dep" "$CLAUDE_MD" 2>/dev/null; then
        WARNINGS="${WARNINGS}
🔄 새로운 동기화 필요 의존성 발견: $dep
   → CLAUDE.md 체크리스트에 자동 추가됨"
        # CLAUDE.md의 SDK 업그레이드 섹션 아래에 추가
        sed -i '' "/❌ backend만 올리고 sandbox 깜빡/a\\
- \`$dep\` 버전 변경 시에도 backend + sandbox 동시 업데이트 필요" "$CLAUDE_MD" 2>/dev/null || true
      fi
    done
  fi
fi

# === 출력 ===
if [ -n "$WARNINGS" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "🔍 Dependency Sync Checker" >&2
  echo "$WARNINGS" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
fi

exit 0
