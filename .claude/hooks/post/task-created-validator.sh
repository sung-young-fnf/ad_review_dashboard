#!/usr/bin/env bash
# TaskCreated Hook: Task 생성 시 자동 검증
# - 중복 Task 감지
# - 명명 규칙 체크

set -e
trap 'exit 0' ERR

INPUT=$(cat)

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.tool_input.subject // empty' 2>/dev/null)
TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // empty' 2>/dev/null)

WARNINGS=""

# 1. Task 제목 비어있으면 경고
if [ -z "$TASK_SUBJECT" ]; then
  WARNINGS="⚠️ Task subject가 비어있습니다"
fi

# 2. Task 제목이 너무 짧으면 경고 (5자 미만)
if [ -n "$TASK_SUBJECT" ] && [ ${#TASK_SUBJECT} -lt 5 ]; then
  WARNINGS="${WARNINGS:+$WARNINGS\n}⚠️ Task subject가 너무 짧습니다 (${#TASK_SUBJECT}자): '$TASK_SUBJECT'"
fi

if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS" >&2
fi

exit 0
