#!/bin/bash
# .claude/hooks/utils/task-navigation.sh
# Task 탐색 공통 유틸리티 (DRY 원칙 적용)
#
# Usage:
#   source "$REPO_ROOT/.claude/hooks/utils/task-navigation.sh"
#   TASK_NUM=$(extract_task_number "T001-S03")
#   NEXT_FILE=$(find_next_task_file "/path/to/tasks" "1")

# Task ID에서 숫자 추출 (예: T001-S03 → 1)
extract_task_number() {
  local TASK_ID="$1"
  echo "$TASK_ID" | sed -E 's/T0*([0-9]+)-.*/\1/'
}

# 다음 Task 파일 찾기
find_next_task_file() {
  local TASK_DIR="$1"
  local CURRENT_NUM="$2"

  # 유효성 검사
  if [[ -z "$TASK_DIR" ]] || [[ ! -d "$TASK_DIR" ]]; then
    return 1
  fi

  if [[ -z "$CURRENT_NUM" ]] || [[ ! "$CURRENT_NUM" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  local NEXT_NUM=$((CURRENT_NUM + 1))
  find "$TASK_DIR" -name "T$(printf '%03d' $NEXT_NUM)-*.md" 2>/dev/null | head -1
}

# Task 파일에서 제목 추출
get_task_title() {
  local TASK_FILE="$1"

  if [[ -f "$TASK_FILE" ]]; then
    grep -m 1 '^# ' "$TASK_FILE" 2>/dev/null | sed 's/^# //'
  else
    echo "Unknown"
  fi
}

# 다음 Task 정보 가져오기 (ID, 제목, 파일경로)
get_next_task_info() {
  local TASK_DIR="$1"
  local CURRENT_TASK_ID="$2"

  local CURRENT_NUM=$(extract_task_number "$CURRENT_TASK_ID")

  if [[ -z "$CURRENT_NUM" ]] || [[ ! "$CURRENT_NUM" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  local NEXT_FILE=$(find_next_task_file "$TASK_DIR" "$CURRENT_NUM")

  if [[ -n "$NEXT_FILE" ]]; then
    local NEXT_ID=$(basename "$NEXT_FILE" .md)
    local NEXT_TITLE=$(get_task_title "$NEXT_FILE")
    echo "$NEXT_ID|$NEXT_TITLE|$NEXT_FILE"
  fi
}
