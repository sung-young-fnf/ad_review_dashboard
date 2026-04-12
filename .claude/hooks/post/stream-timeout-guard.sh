#!/bin/bash
# .claude/hooks/post/stream-timeout-guard.sh
# Stream idle timeout 감지 → 자동 재시도 마커 생성
# SubagentStop hook에서 실행
# Version: v1.0

set -e
trap 'exit 0' ERR

# ─── stdin 읽기 ─────────────────────────────
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
else
  event_info=""
fi

if [[ -z "$event_info" ]] || [[ "${#event_info}" -lt 2 ]]; then
  echo '{"continue": true}'
  exit 0
fi

# ─── Agent 정보 추출 ────────────────────────
AGENT_ID=$(echo "$event_info" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
AGENT_NAME=$(echo "$event_info" | jq -r '.agent_name // empty' 2>/dev/null || echo "")
LAST_MSG=$(echo "$event_info" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
TRANSCRIPT=$(echo "$event_info" | jq -r '.agent_transcript_path // empty' 2>/dev/null || echo "")

# ─── Stream idle timeout 감지 ───────────────
# 패턴: "Stream idle timeout", "partial response received", API timeout 계열
TIMEOUT_DETECTED=false

if echo "$LAST_MSG" | grep -qi "stream idle timeout\|partial response received"; then
  TIMEOUT_DETECTED=true
fi

# Transcript에서도 확인 (last_msg가 비어있을 수 있음)
if [[ "$TIMEOUT_DETECTED" == "false" ]] && [[ -n "$TRANSCRIPT" ]] && [[ -f "$TRANSCRIPT" ]]; then
  if tail -c 500 "$TRANSCRIPT" 2>/dev/null | grep -qi "stream idle timeout\|idle timeout.*partial"; then
    TIMEOUT_DETECTED=true
  fi
fi

if [[ "$TIMEOUT_DETECTED" == "false" ]]; then
  echo '{"continue": true}'
  exit 0
fi

# ─── 타임아웃 감지됨! 마커 생성 ──────────────
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MARKER_DIR="$REPO_ROOT/.claude/.stream-timeout-retry"
mkdir -p "$MARKER_DIR" 2>/dev/null

MARKER_FILE="$MARKER_DIR/retry-$(date +%s).json"
cat > "$MARKER_FILE" <<EOF
{
  "detected_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "agent_id": "$AGENT_ID",
  "agent_name": "$AGENT_NAME",
  "transcript_path": "$TRANSCRIPT",
  "error": "Stream idle timeout - partial response received",
  "action": "retry_recommended"
}
EOF

# ─── Main thread에 경고 ─────────────────────
>&2 echo ""
>&2 echo "⚠️ [Stream Timeout Guard] API Stream idle timeout 감지!"
>&2 echo "   Agent: ${AGENT_NAME:-$AGENT_ID}"
>&2 echo "   원인: Anthropic API 응답 생성 중 스트림 끊김"
>&2 echo "   권장: SendMessage로 재개하거나 작업을 더 작은 단위로 분할"
>&2 echo "   마커: $MARKER_FILE"
>&2 echo ""

echo '{"continue": true}'
exit 0
