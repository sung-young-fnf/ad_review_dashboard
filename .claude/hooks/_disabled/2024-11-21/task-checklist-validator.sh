#!/bin/bash
# .claude/hooks/post/task-checklist-validator.sh
# Defense Line 2: Task 파일 패턴 체크리스트 검증

set -e
trap 'exit 0' ERR

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
DOCS_EPICS="$REPO_ROOT/docs/epics"

# Step 0: stdin에서 event_info 받기 (Empty Input Safety)
event_info=$(cat)
if [ -z "$event_info" ]; then
  exit 0  # Silent skip
fi

SESSION_ID=$(echo "$event_info" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")

# Step 1: Agent 정보 수집 (환경 변수)
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-unknown}"
AGENT_TASK="${CLAUDE_TASK_ID:-}"
AGENT_EPIC="${CLAUDE_EPIC_ID:-}"
AGENT_STORY="${CLAUDE_STORY_ID:-}"

# Step 2: task-planner Agent만 검증
if [[ "$AGENT_TYPE" != *"task-planner"* ]]; then
  exit 0  # Skip (다른 Agent)
fi

# Step 3: Task ID 추출 (T001, T042 등)
if [ -z "$AGENT_TASK" ]; then
  echo "⚠️ CLAUDE_TASK_ID 환경 변수 없음. Task 파일 검증 스킵." >&2
  exit 0
fi

# Step 4: Task 파일 경로 결정 (Regular vs Backlog)
TASK_FILE=""
if [ -n "$AGENT_EPIC" ]; then
  # Regular Mode: docs/epics/{epic_id}/tasks/T{XXX}-S{NN}.md
  TASK_FILE=$(find "$DOCS_EPICS/$AGENT_EPIC/tasks" -name "${AGENT_TASK}*.md" 2>/dev/null | head -1)
else
  # Backlog Mode: docs/epics/_backlog/T{XXX}_*.md
  TASK_FILE=$(find "$DOCS_EPICS/_backlog" -name "${AGENT_TASK}_*.md" -o -name "${AGENT_TASK}.md" 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
  echo "⚠️ Task 파일 없음: $AGENT_TASK (검증 스킵)" >&2
  exit 0
fi

echo "🔍 Defense Line 2: Task 패턴 체크리스트 검증 시작"
echo "   Task: $AGENT_TASK"
echo "   File: $(basename "$TASK_FILE")"

# Step 5: 패턴 체크리스트 섹션 존재 확인
if ! grep -q "## 필수 패턴 준수 \[MANDATORY\]" "$TASK_FILE"; then
  echo "❌ DEFENSE LINE 2 FAILURE" >&2
  echo "   Task 파일에 패턴 체크리스트 섹션 없음!" >&2
  echo "   → task-planner Step 4.5 실행 누락" >&2
  echo "   → Story 파일의 패턴 섹션 확인 필요" >&2
  exit 0  # Graceful degradation
fi

# Step 6: 체크리스트 내용 검증 (비어있지 않은지)
CHECKLIST_CONTENT=$(sed -n '/## 필수 패턴 준수 \[MANDATORY\]/,/^## /p' "$TASK_FILE" | grep -E "^\- \[ \]" || echo "")

if [ -z "$CHECKLIST_CONTENT" ]; then
  echo "⚠️ DEFENSE LINE 2 WARNING" >&2
  echo "   패턴 체크리스트가 비어있습니다!" >&2
  echo "   → Story 파일에 패턴 섹션이 없는 경우 정상" >&2
  echo "   → 패턴 적용이 필요하면 Story 재생성 필요" >&2
  exit 0
fi

# Step 7: Story 파일 패턴과 일치 확인 (Regular Mode만)
if [ -n "$AGENT_EPIC" ] && [ -n "$AGENT_STORY" ]; then
  STORY_FILE="$DOCS_EPICS/$AGENT_EPIC/stories/${AGENT_STORY}.md"

  if [ -f "$STORY_FILE" ]; then
    # Story 패턴 섹션 존재 확인
    if grep -q "## 🎯 관련 패턴 \[Story Level\]" "$STORY_FILE"; then
      # 패턴 개수 비교 (간단한 검증)
      STORY_PATTERN_COUNT=$(grep -c "### [0-9]\+\." "$STORY_FILE" || echo "0")
      TASK_CHECKLIST_COUNT=$(echo "$CHECKLIST_CONTENT" | wc -l | tr -d ' ')

      if [ "$TASK_CHECKLIST_COUNT" -lt 3 ]; then
        echo "⚠️ DEFENSE LINE 2 WARNING" >&2
        echo "   체크리스트 항목이 너무 적습니다 ($TASK_CHECKLIST_COUNT개)" >&2
        echo "   → Story 패턴 ($STORY_PATTERN_COUNT개)과 불일치 가능성" >&2
      fi
    fi
  fi
fi

# Step 8: 검증 성공
echo "✅ DEFENSE LINE 2 PASSED"
echo "   패턴 체크리스트 검증 완료"
echo "   체크리스트 항목: $(echo "$CHECKLIST_CONTENT" | wc -l | tr -d ' ')개"

exit 0
