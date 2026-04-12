#!/bin/bash
# .claude/hooks/post/post-commit-suggester-trigger.sh
# commit-manager 완료 후 post-commit-suggester 자동 트리거
# Hook 개발 가이드 준수: Bash Only, 100줄 이내

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_FILE="$REPO_ROOT/.claude/hooks/hook.log"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [post-commit-suggester-trigger] $1" >> "$LOG_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Input Validation (MANDATORY)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INPUT=$(cat)
INPUT_LENGTH=${#INPUT}

if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    echo '{"continue": true}'
    exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agent 타입 추출
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AGENT_TYPE=""
if command -v jq &> /dev/null; then
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
fi

# 환경 변수 fallback
AGENT_TYPE="${AGENT_TYPE:-${CLAUDE_AGENT_TYPE:-}}"
AGENT_ID="${CLAUDE_AGENT_ID:-}"

log "Agent detected: type=$AGENT_TYPE, id=$AGENT_ID"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# commit-manager 완료 감지
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# commit-manager 또는 commit-manager-auto 완료 체크
if [[ ! "$AGENT_TYPE" =~ commit-manager ]] && [[ ! "$AGENT_ID" =~ commit-manager ]]; then
    log "Skipped: not commit-manager (type=$AGENT_TYPE)"
    echo '{"continue": true}'
    exit 0
fi

log "commit-manager completion detected!"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 최근 커밋 정보 추출
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "unknown")
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | wc -l | tr -d ' ')

log "Commit: $COMMIT_HASH - $COMMIT_MSG ($CHANGED_FILES files)"

# 변경 파일 3개 미만이면 스킵 (작은 변경은 제안 불필요)
if [[ "$CHANGED_FILES" -lt 3 ]]; then
    log "Skipped: less than 3 files changed ($CHANGED_FILES)"
    echo '{"continue": true}'
    exit 0
fi

# 문서만 변경된 경우 스킵
ONLY_DOCS=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -vE '\.(md|txt|json|yaml|yml)$' | wc -l | tr -d ' ')
if [[ "$ONLY_DOCS" -eq 0 ]]; then
    log "Skipped: only documentation files changed"
    echo '{"continue": true}'
    exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# post-commit-suggester 트리거 메시지 출력
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 도메인 추출 (파일 경로 기반)
DOMAINS=""
git diff --name-only HEAD~1..HEAD 2>/dev/null | while read -r file; do
    case "$file" in
        *campaign*|*Campaign*) DOMAINS="$DOMAINS campaign" ;;
        *components/ui*|*styles*) DOMAINS="$DOMAINS ux" ;;
        *api/*|*endpoints*) DOMAINS="$DOMAINS api" ;;
        *schema.prisma*|*migrations*) DOMAINS="$DOMAINS db" ;;
    esac
done
DOMAINS=$(echo "$DOMAINS" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
DOMAINS="${DOMAINS:-general}"

# Silent Mode: 콘솔 출력 제거, 로그 파일에만 기록
log "Post-commit analysis available for $COMMIT_HASH ($CHANGED_FILES files, domains: $DOMAINS)"

# CRITICAL: JSON 응답 반환 (Claude Hook 시스템 요구사항)
# 2.0.64 기능: systemMessage로 백그라운드 에이전트 실행 제안
cat << EOF
{
  "continue": true,
  "systemMessage": "✅ commit-manager 완료 ($COMMIT_HASH, ${CHANGED_FILES}개 파일)\n\n💡 백그라운드 분석 권장:\nTask(subagent_type: 'post-commit-suggester', run_in_background: true, model: 'haiku', prompt: 'Analyze commit $COMMIT_HASH')"
}
EOF
exit 0
