#!/bin/bash
# .claude/hooks/pre/ux-gateway-guard.sh
# UX Gateway 강제: code-writer 호출 전 UX agent 필수
#
# 트리거: PreToolUse (matcher: "Task")
# 로직:
#   1. UX agent 호출 → .ux-gateway-required 마커 삭제 → APPROVE
#   2. code-writer 호출 + 마커 존재 → BLOCK
#   3. 기타 agent → APPROVE
# Version: 1.0

# Graceful Degradation
trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MARKER_FILE="$REPO_ROOT/.claude/.ux-gateway-required"
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ux-gateway-guard] $*" >> "$DEBUG_LOG"
  fi
}

log_debug "=== HOOK START ==="

# stdin 읽기
INPUT=""
if [ ! -t 0 ]; then
  if read -t 1 -r INPUT 2>/dev/null; then
    log_debug "stdin: ${#INPUT} bytes"
  else
    log_debug "stdin read failed"
    INPUT=""
  fi
fi

# 빈 입력이면 통과
if [[ -z "$INPUT" ]]; then
  log_debug "Empty input, allowing"
  exit 0
fi

# tool_input에서 subagent_type 추출
SUBAGENT_TYPE=""
if command -v jq &>/dev/null; then
  SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null || echo "")
fi

log_debug "SUBAGENT_TYPE: $SUBAGENT_TYPE"

# subagent_type이 없으면 통과 (Task가 아닌 tool이 matcher 통과한 경우)
if [[ -z "$SUBAGENT_TYPE" ]]; then
  log_debug "No subagent_type, allowing"
  exit 0
fi

# ─────────────────────────────────────
# Case 1: UX agent 호출 → 마커 삭제 (Gateway 통과)
# ─────────────────────────────────────
if echo "$SUBAGENT_TYPE" | grep -qiE '(ux-master|ux-heuristic|ux-writer|cognitive-load|journey-recorder|persona-journey|ui-tester)'; then
  log_debug "UX agent detected ($SUBAGENT_TYPE), clearing marker"
  rm -f "$MARKER_FILE"
  exit 0
fi

# ─────────────────────────────────────
# Case 2: code-writer 호출 + 마커 존재 → BLOCK
# ─────────────────────────────────────
if echo "$SUBAGENT_TYPE" | grep -qiE '(code-writer|reference-code-writer)'; then
  if [[ -f "$MARKER_FILE" ]]; then
    MARKER_KEYWORDS=$(head -1 "$MARKER_FILE" 2>/dev/null || echo "unknown")
    log_debug "BLOCKING: code-writer without UX agent (keywords: $MARKER_KEYWORDS)"

    # Violation 기록
    VIOLATION_LOG="$REPO_ROOT/.claude/.violations.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] UX-GATEWAY: code-writer blocked (UX agent 미호출, keywords: $MARKER_KEYWORDS)" >> "$VIOLATION_LOG"

    cat <<EOF
{
  "decision": "block",
  "reason": "🌐 UX Gateway 미통과: UI 변경 요청에서 code-writer 전에 UX agent 필수",
  "additionalContext": "🛑 UX GATEWAY VIOLATION: UI/프론트엔드 변경이 감지되었습니다 (keywords: $MARKER_KEYWORDS).\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n✅ 지금 즉시 다음을 실행하세요:\n\nTask(subagent_type='05-quality/ux-heuristic-auditor',\n     prompt='현재 UI 분석 및 UX 관점 개선안 도출. 대상: [사용자 요청 내용]')\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 UX agent 완료 후:\n   1. .ux-gateway-required 마커가 삭제됨\n   2. code-writer 호출 가능해짐\n   3. UX-AUDIT-REPORT.md 참조하여 구현\n\n⚡ Quick-Pass 조건 (UX 불필요):\n   API, DB, 에러, 배포, 인프라 키워드가 있으면 마커가 생성되지 않습니다."
}
EOF
    exit 0
  fi

  log_debug "code-writer allowed (no marker)"
  exit 0
fi

# ─────────────────────────────────────
# Case 2.5: 기타 agent + 마커 존재 → 경고 (차단은 아님)
# WHY: Explore 등 탐색은 허용하되, UX agent 호출을 리마인드
# ─────────────────────────────────────
if [[ -f "$MARKER_FILE" ]]; then
  MARKER_KEYWORDS=$(head -1 "$MARKER_FILE" 2>/dev/null || echo "unknown")
  log_debug "WARNING: non-UX agent with UX marker (agent: $SUBAGENT_TYPE, keywords: $MARKER_KEYWORDS)"
  cat <<EOF
{
  "decision": "approve",
  "reason": "Agent $SUBAGENT_TYPE 허용 (탐색/분석용)",
  "additionalContext": "⚠️ UX Gateway 마커 활성 (keywords: $MARKER_KEYWORDS). 탐색은 허용하지만, 결과를 바탕으로 직접 UX 제안하지 마세요. 반드시 UX agent (ux-heuristic-auditor 또는 ux-master-auditor)를 호출하여 분석을 위임하세요. '제안/설계/기획'도 UX 검토 대상입니다."
}
EOF
  exit 0
fi

# ─────────────────────────────────────
# Case 3: 기타 agent (마커 없음) → 통과
# ─────────────────────────────────────
log_debug "Allowing Task($SUBAGENT_TYPE)"
exit 0
