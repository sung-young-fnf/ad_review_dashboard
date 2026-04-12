#!/bin/bash
# TeammateIdle hook - Squad lifecycle 자동화 (v2.1.33+)
# 유휴 teammate 감지 시 구체적인 다음 행동 안내
#
# 개선 (v2.1.41+):
# - 남은 task 수 표시
# - 전체 완료 시 해산 권고
# - praetorian compact 안내
#
# 개선 (v2.1.76+):
# - Stall 감지: in_progress만 남고 pending 없으면 stall 경고
# - 반복 idle 감지: 동일 agent가 3회+ idle이면 자동 종료
# - continue:false + stopReason 지원

trap 'exit 0' ERR

INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null)

# Squad 모드가 아니면 무시
TEAM_DIR="$HOME/.claude/teams"
if [ ! -d "$TEAM_DIR" ] || [ -z "$(ls -A "$TEAM_DIR" 2>/dev/null)" ]; then
  exit 0
fi

# 반복 idle 카운터 (동일 agent의 idle 횟수 추적)
IDLE_COUNTER_DIR="/tmp/claude-teammate-idle"
mkdir -p "$IDLE_COUNTER_DIR" 2>/dev/null || true
IDLE_COUNTER_FILE="$IDLE_COUNTER_DIR/${AGENT_NAME}.count"

IDLE_COUNT=0
if [ -f "$IDLE_COUNTER_FILE" ]; then
  IDLE_COUNT=$(cat "$IDLE_COUNTER_FILE" 2>/dev/null || echo 0)
fi
IDLE_COUNT=$((IDLE_COUNT + 1))
echo "$IDLE_COUNT" > "$IDLE_COUNTER_FILE" 2>/dev/null || true

# 현재 team 디렉토리에서 task 현황 파악 시도
TASK_DIR="$HOME/.claude/tasks"
PENDING_COUNT=0
IN_PROGRESS_COUNT=0
COMPLETED_COUNT=0

if [ -d "$TASK_DIR" ]; then
  LATEST_TEAM=$(ls -t "$TASK_DIR" 2>/dev/null | head -1)
  if [ -n "$LATEST_TEAM" ] && [ -d "$TASK_DIR/$LATEST_TEAM" ]; then
    TASK_FILE="$TASK_DIR/$LATEST_TEAM/tasks.json"
    if [ -f "$TASK_FILE" ]; then
      PENDING_COUNT=$(jq '[.[] | select(.status == "pending")] | length' "$TASK_FILE" 2>/dev/null || echo 0)
      IN_PROGRESS_COUNT=$(jq '[.[] | select(.status == "in_progress")] | length' "$TASK_FILE" 2>/dev/null || echo 0)
      COMPLETED_COUNT=$(jq '[.[] | select(.status == "completed")] | length' "$TASK_FILE" 2>/dev/null || echo 0)
    fi
  fi
fi

TOTAL=$((PENDING_COUNT + IN_PROGRESS_COUNT + COMPLETED_COUNT))
REMAINING=$((PENDING_COUNT + IN_PROGRESS_COUNT))

# Case 1: 모든 task 완료 → 자동 종료
if [ "$TOTAL" -gt 0 ] && [ "$REMAINING" -eq 0 ]; then
  rm -f "$IDLE_COUNTER_FILE" 2>/dev/null || true
  MSG="🏁 ${AGENT_NAME} idle — 모든 Task 완료 (${COMPLETED_COUNT}/${TOTAL}). 자동 종료합니다."
  echo "{\"continue\": false, \"stopReason\": \"all_tasks_completed\", \"systemMessage\": \"${MSG}\"}"

# Case 2: 3회+ 반복 idle → stall로 판단, 자동 종료
elif [ "$IDLE_COUNT" -ge 3 ]; then
  rm -f "$IDLE_COUNTER_FILE" 2>/dev/null || true
  MSG="⚠️ ${AGENT_NAME} stalled — ${IDLE_COUNT}회 연속 idle. 진행 불가로 판단하여 자동 종료합니다. (pending: ${PENDING_COUNT}, in_progress: ${IN_PROGRESS_COUNT})"
  echo "{\"continue\": false, \"stopReason\": \"stall_detected_${IDLE_COUNT}_idles\", \"systemMessage\": \"${MSG}\"}"

# Case 3: in_progress만 남고 pending 없음 → stall 경고 (blocked 가능성)
elif [ "$IN_PROGRESS_COUNT" -gt 0 ] && [ "$PENDING_COUNT" -eq 0 ]; then
  MSG="⏳ ${AGENT_NAME} idle — in_progress ${IN_PROGRESS_COUNT}개만 남음 (pending 0). 의존성 블록 또는 stall 가능성. Lead가 TaskList로 상태 확인 필요. (idle ${IDLE_COUNT}회/${AGENT_NAME})"
  echo "{\"systemMessage\": \"${MSG}\"}"

# Case 4: pending 있음 → 할당 안내
elif [ "$PENDING_COUNT" -gt 0 ]; then
  MSG="💤 ${AGENT_NAME} idle — 잔여 Task: pending ${PENDING_COUNT}개, in_progress ${IN_PROGRESS_COUNT}개. TaskList 확인 후 unblocked task를 ${AGENT_NAME}에 할당. (idle ${IDLE_COUNT}회)"
  echo "{\"systemMessage\": \"${MSG}\"}"

# Case 5: 기타
else
  MSG="💤 ${AGENT_NAME} idle — TaskList 확인하여 unblocked task 할당 권장. (idle ${IDLE_COUNT}회)"
  echo "{\"systemMessage\": \"${MSG}\"}"
fi
