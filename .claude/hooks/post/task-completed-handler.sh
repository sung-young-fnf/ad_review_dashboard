#!/bin/bash
# TaskCompleted hook - Task 완료 시 자동 후속 처리 (v2.1.33+)
# 의존 task unblock 및 진행률 안내
#
# 개선 (v2.1.41+):
# - 진행률 표시 (완료/전체)
# - 전체 완료 시 해산 + praetorian 안내
# - Inter-Story Test Gate 리마인드

trap 'exit 0' ERR

INPUT=$(cat)
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"' 2>/dev/null)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null)

# Squad 모드가 아니면 무시
TEAM_DIR="$HOME/.claude/teams"
if [ ! -d "$TEAM_DIR" ] || [ -z "$(ls -A "$TEAM_DIR" 2>/dev/null)" ]; then
  exit 0
fi

# Task 현황 파악
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

# 진행률 계산
if [ "$TOTAL" -gt 0 ]; then
  PROGRESS=$(( (COMPLETED_COUNT * 100) / TOTAL ))
else
  PROGRESS=0
fi

# 메시지 생성 (v2.1.64 continue:false 지원)
if [ "$TOTAL" -gt 0 ] && [ "$REMAINING" -eq 0 ]; then
  # 전체 완료 — 이 teammate 자동 종료
  MSG="🏁 Task #${TASK_ID} 완료 (${TASK_SUBJECT}). 전체 진행률: ${COMPLETED_COUNT}/${TOTAL} (100%). 모든 Task 완료! 자동 종료합니다."
  echo "{\"continue\": false, \"stopReason\": \"all_tasks_completed\", \"systemMessage\": \"${MSG}\"}"
elif [ "$REMAINING" -le 2 ]; then
  # 거의 완료
  MSG="✅ Task #${TASK_ID} 완료 (${TASK_SUBJECT}). 진행률: ${COMPLETED_COUNT}/${TOTAL} (${PROGRESS}%). 잔여 ${REMAINING}개. Inter-Story Test Gate: pnpm build && pnpm tsc --noEmit 통과 필수."
  echo "{\"systemMessage\": \"${MSG}\"}"
else
  MSG="✅ Task #${TASK_ID} 완료 (${TASK_SUBJECT}). 진행률: ${COMPLETED_COUNT}/${TOTAL} (${PROGRESS}%). idle teammate에 unblocked task 할당 권장."
  echo "{\"systemMessage\": \"${MSG}\"}"
fi
