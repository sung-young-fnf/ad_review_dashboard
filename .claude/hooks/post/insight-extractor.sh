#!/bin/bash
# .claude/hooks/post/insight-extractor.sh
# 사용자 질의에서 Insight/Best Practice 자동 캡처 → Pattern Documenter 호출

# set -e (disabled for Graceful Degradation)
trap 'exit 0' ERR

# Read stdin (required by Claude Code)
CONVERSATION=$(cat)

# Graceful degradation: 빈 입력 처리
if [[ -z "$CONVERSATION" ]]; then
  exit 0
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_FILE="$REPO_ROOT/.claude/hooks/insight-extractor.log"

# 로그 함수
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Insight Extractor Started ==="

# Step 1: Insight 감지 (키워드 기반)
KEYWORDS="더 좋을|개선|최적화|Best Practice|추천|패턴|효율적|성능|보안|아키텍처"

if ! echo "$CONVERSATION" | grep -qE "$KEYWORDS"; then
  log "No insight keywords detected. Skipped."
  exit 0
fi

log "✅ Insight keywords detected!"

# Step 2: Agent 타입 확인 (code-writer, error-fixer만 대상)
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"

if [[ "$AGENT_TYPE" != "code-writer" ]] && [[ "$AGENT_TYPE" != "error-fixer" ]]; then
  log "Agent type '$AGENT_TYPE' is not applicable. Skipped."
  exit 0
fi

log "✅ Applicable agent type: $AGENT_TYPE"

# Step 3: 대화 내용 길이 체크 (너무 짧으면 스킵)
CONVERSATION_LENGTH=${#CONVERSATION}

if [[ $CONVERSATION_LENGTH -lt 100 ]]; then
  log "Conversation too short ($CONVERSATION_LENGTH chars). Skipped."
  exit 0
fi

log "✅ Conversation length: $CONVERSATION_LENGTH chars"

# Step 4: Serena Memory에 Insight 저장
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MEMORY_KEY="insight_captured_$TIMESTAMP"

# Conversation 샘플링 (첫 500자만 저장)
CONVERSATION_SAMPLE="${CONVERSATION:0:500}"

INSIGHT_DATA=$(cat <<EOF
# Captured Insight ($TIMESTAMP)

## Context
- Agent: $AGENT_TYPE
- Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
- Conversation Length: $CONVERSATION_LENGTH chars

## Sample Conversation
\`\`\`
$CONVERSATION_SAMPLE
...
\`\`\`

## Status
- Captured: ✅
- Pattern Documenter: Pending
- Confidence: TBD

## Next Action
pattern-documenter-v2 Agent로 패턴 추출 및 문서화
EOF
)

# Serena Memory 저장 (실패해도 무시)
if command -v serena &> /dev/null; then
  echo "$INSIGHT_DATA" | serena write-memory "$MEMORY_KEY" || true
  log "✅ Insight saved to Serena Memory: $MEMORY_KEY"
else
  log "⚠️ Serena CLI not found. Skipping memory save."
fi

# Step 5: Pattern Documenter 자동 호출 (Backlog - 사용자 승인 필요)
log "💡 Insight 캡처 완료. Pattern Documenter는 사용자 승인 후 실행."
log "💡 다음 세션에서 /pattern-documenter/analyze-with-confidence 명령어 사용 가능"

# 사용자에게 알림 (너무 시끄럽지 않게)
if [[ -n "${CLAUDE_VERBOSE:-}" ]]; then
  echo "💡 Insight 캡처됨: $MEMORY_KEY (pattern-documenter 승인 대기)"
fi

log "=== Insight Extractor Completed ==="
exit 0
