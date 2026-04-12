#!/bin/bash
# .claude/hooks/post/agent-validation-hook.sh
# Agent 실행 결과 검증 Hook - 실패 감지 및 알림
# Version: 1.0

set -e
trap 'exit 0' ERR

# ============================================================================
# Configuration
# ============================================================================

MIN_EXECUTION_TIME=3  # 최소 실행 시간 (초)
MIN_TOKEN_COUNT=100   # 최소 토큰 사용량
LOG_FILE="/tmp/agent-validation.log"

# ============================================================================
# Input Processing
# ============================================================================

if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "{}")
else
  INPUT_JSON="${1:-{}}"
fi

# Agent 정보 추출
AGENT_NAME=$(echo "$INPUT_JSON" | jq -r '.agent_name // "unknown"' 2>/dev/null || echo "unknown")
EXECUTION_TIME=$(echo "$INPUT_JSON" | jq -r '.execution_time // "0"' 2>/dev/null || echo "0")
TOKEN_COUNT=$(echo "$INPUT_JSON" | jq -r '.token_count // "0"' 2>/dev/null || echo "0")
OUTPUT=$(echo "$INPUT_JSON" | jq -r '.output // ""' 2>/dev/null || echo "")

# ============================================================================
# Validation Logic
# ============================================================================

# 실행 시간 검증
if [[ "$EXECUTION_TIME" -lt "$MIN_EXECUTION_TIME" ]]; then
  cat <<EOF

⚠️ AGENT VALIDATION FAILURE DETECTED
────────────────────────────────────────
Agent: $AGENT_NAME
Execution Time: ${EXECUTION_TIME}s (minimum: ${MIN_EXECUTION_TIME}s)
Status: LIKELY FAILED - Too fast execution

Recommended Actions:
1. Check Agent logs for errors
2. Verify Agent output contains actual work
3. Consider re-running with verbose mode
4. If persistent, run directly without Agent

❌ Agent likely crashed or skipped work
────────────────────────────────────────
EOF

  echo "[$(date +'%Y-%m-%d %H:%M:%S')] VALIDATION FAILED: $AGENT_NAME - ${EXECUTION_TIME}s execution" >> "$LOG_FILE"
  exit 1
fi

# 토큰 사용량 검증
if [[ "$TOKEN_COUNT" -lt "$MIN_TOKEN_COUNT" ]]; then
  cat <<EOF

⚠️ AGENT LOW TOKEN WARNING
────────────────────────────────────────
Agent: $AGENT_NAME
Token Count: $TOKEN_COUNT (minimum: $MIN_TOKEN_COUNT)
Status: SUSPICIOUS - Very low token usage

Possible Issues:
- Agent didn't read files
- Agent skipped analysis
- Agent early exit

Review output carefully
────────────────────────────────────────
EOF
fi

# 출력 내용 검증
if [[ -z "$OUTPUT" ]] || [[ "$OUTPUT" == "Done" ]]; then
  cat <<EOF

⚠️ AGENT EMPTY OUTPUT WARNING
────────────────────────────────────────
Agent: $AGENT_NAME
Output: Empty or generic "Done"
Status: NO MEANINGFUL OUTPUT

Required: Agent should provide:
- Detailed analysis results
- Specific changes made
- Error messages if failed

❌ No actionable output detected
────────────────────────────────────────
EOF
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Validated: $AGENT_NAME - ${EXECUTION_TIME}s, ${TOKEN_COUNT} tokens" >> "$LOG_FILE"
exit 0