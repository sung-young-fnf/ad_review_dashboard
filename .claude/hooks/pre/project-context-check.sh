#!/bin/bash
# .claude/hooks/pre/project-context-check.sh
# Project Context Initialization Check
# Version: 1.0
#
# 새 프로젝트 감지 시 SERVICE_CONTEXT.md 및 루트 CLAUDE.md 생성 안내
# 범용 .claude/ 폴더를 복사해서 사용하는 워크플로우 지원

# ============================================================================
# CONFIGURATION
# ============================================================================

DEBUG_LOG="/tmp/hook-project-context-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [project-context] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# INITIALIZATION CHECK
# ============================================================================

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_debug "REPO_ROOT: $REPO_ROOT"

# 체크할 파일들 - 양쪽 경로 지원
ROOT_CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
BUSINESS_DOMAIN="$REPO_ROOT/docs/analysis/business-domain.md"

# SERVICE_CONTEXT 경로 확인 (docs/context/ 우선)
if [[ -f "$REPO_ROOT/docs/context/SERVICE_CONTEXT.md" ]]; then
  SERVICE_CONTEXT="$REPO_ROOT/docs/context/SERVICE_CONTEXT.md"
elif [[ -f "$REPO_ROOT/docs/SERVICE_CONTEXT.md" ]]; then
  SERVICE_CONTEXT="$REPO_ROOT/docs/SERVICE_CONTEXT.md"
else
  SERVICE_CONTEXT=""
fi

# NOTE: unified Hook이 SERVICE_CONTEXT.md 유무로 먼저 체크함
# 이 Hook이 실행된다는 것은 SERVICE_CONTEXT.md가 없다는 의미 (새 프로젝트)
# 또는 스킵 요청, 초기화 요청을 처리하기 위해 실행됨

# 하지만 혹시 직접 실행되는 경우를 위해 SERVICE_CONTEXT.md 체크 유지
if [[ -n "$SERVICE_CONTEXT" ]]; then
  log_debug "SERVICE_CONTEXT.md exists at: $SERVICE_CONTEXT, skipping"
  exit 0
fi

# ============================================================================
# NEW PROJECT DETECTION
# ============================================================================

MISSING_FILES=""
MISSING_COUNT=0

if [[ ! -f "$ROOT_CLAUDE_MD" ]]; then
  MISSING_FILES="$MISSING_FILES\n   - ./CLAUDE.md (프로젝트 페르소나)"
  ((MISSING_COUNT++))
fi

if [[ -z "$SERVICE_CONTEXT" ]]; then
  MISSING_FILES="$MISSING_FILES\n   - docs/context/SERVICE_CONTEXT.md 또는 docs/SERVICE_CONTEXT.md (서비스 비전)"
  ((MISSING_COUNT++))
fi

if [[ ! -f "$BUSINESS_DOMAIN" ]]; then
  MISSING_FILES="$MISSING_FILES\n   - docs/analysis/business-domain.md (비즈니스 분석)"
  ((MISSING_COUNT++))
fi

# 파일이 없는 경우에만 메시지 출력
if [[ "$MISSING_COUNT" -gt 0 ]]; then
  PROJECT_NAME=$(basename "$REPO_ROOT")

  # 초기화 스킵 요청인지 확인
  USER_INPUT="${CLAUDE_USER_PROMPT:-}"
  if echo "$USER_INPUT" | grep -qiE '초기화\s*스킵|skip\s*init|범용|general'; then
    log_debug "User requested skip initialization"
    # 스킵 마커 생성 (향후 세션에서 안내 표시 안함)
    echo "# Skipped at $(date)" > "$REPO_ROOT/.claude/.project-init-skipped"
    cat <<EOF
✅ 프로젝트 초기화를 스킵합니다.
   범용 코딩 도구 모드로 동작합니다.
   나중에 초기화하려면: "프로젝트 초기화" 입력
EOF
    exit 0
  fi

  # 스킵 마커가 있으면 안내 표시 안함
  if [[ -f "$REPO_ROOT/.claude/.project-init-skipped" ]]; then
    log_debug "Project init was skipped, not showing prompt"
    exit 0
  fi

  # 초기화 요청인지 확인 (자동 진행)
  if echo "$USER_INPUT" | grep -qiE '프로젝트\s*초기화|project\s*init|initialize'; then
    log_debug "User requested project initialization - allowing to proceed"
    # 초기화 요청이면 메시지 출력하고 정상 진행 (Agent가 처리)
    cat <<EOF
╔═══════════════════════════════════════════════════════════════════════════╗
║              🚀 PROJECT INITIALIZATION STARTING                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

📁 프로젝트: $PROJECT_NAME
🤖 project-initializer Agent를 호출합니다...

EOF
    exit 0
  fi

  # 첫 방문: 자동 초기화 안내
  cat <<EOF
🆕 NEW PROJECT: $PROJECT_NAME
→ SERVICE_CONTEXT.md 없음 (docs/context/ 또는 docs/)
→ CLAUDE.md 지침에 따라 project-context-loader 실행 필요
EOF

  # NOTE: pending 파일 불필요 - unified Hook이 SERVICE_CONTEXT.md 유무로 판단
  exit 0
fi

exit 0
