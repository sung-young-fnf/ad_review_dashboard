#!/bin/bash
# Squad Event Logger — SubagentStop/TaskCompleted 시 이벤트를 JSON으로 기록
# ClawTeam Event Sourcing 패턴 참고: 불변 이벤트 로그로 Squad 실행 추적
#
# 이벤트 저장소: .claude/squad-logs/{team-name}/evt-{timestamp}-{uid}.json
# 요약 보고서:   .claude/squad-logs/{team-name}/summary.json

set -eo pipefail
trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOGS_DIR="$REPO_ROOT/.claude/squad-logs"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH_MS=$(date +%s%3N 2>/dev/null || date +%s000)
UID_SHORT=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)

# stdin에서 Hook 이벤트 JSON 읽기
INPUT=$(cat 2>/dev/null || echo "{}")

# jq 필수
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Hook 타입 감지 (SubagentStop vs TaskCompleted)
HOOK_TYPE="${CLAUDE_HOOK_EVENT_NAME:-unknown}"

# 팀 이름 추출 (agent_name에서 또는 환경변수에서)
TEAM_NAME=""
AGENT_NAME=""
AGENT_TYPE=""
EVENT_TYPE=""
EVENT_DATA="{}"

case "$HOOK_TYPE" in
    SubagentStop)
        AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .name // "unknown"' 2>/dev/null)
        AGENT_TYPE=$(echo "$INPUT" | jq -r '.subagent_type // .agent_type // "unknown"' 2>/dev/null)
        AGENT_RESULT=$(echo "$INPUT" | jq -r '.result // ""' 2>/dev/null | head -c 500)

        # team_name 추출: agent_name이 "epic-EP211-20260330:dev-1" 형태면 팀명 추출
        if echo "$AGENT_NAME" | grep -qE '^(epic|story|bug|db|ux|planning|analysis|design|quality)-'; then
            TEAM_NAME=$(echo "$AGENT_NAME" | cut -d: -f1)
        fi

        EVENT_TYPE="agent_stop"
        EVENT_DATA=$(jq -n \
            --arg agent "$AGENT_NAME" \
            --arg type "$AGENT_TYPE" \
            --arg result "$AGENT_RESULT" \
            '{agent_name: $agent, agent_type: $type, result_preview: $result}')
        ;;
    TaskCompleted)
        TASK_ID=$(echo "$INPUT" | jq -r '.task_id // .id // "unknown"' 2>/dev/null)
        TASK_SUBJECT=$(echo "$INPUT" | jq -r '.subject // ""' 2>/dev/null)
        TASK_OWNER=$(echo "$INPUT" | jq -r '.owner // ""' 2>/dev/null)

        EVENT_TYPE="task_completed"
        EVENT_DATA=$(jq -n \
            --arg id "$TASK_ID" \
            --arg subject "$TASK_SUBJECT" \
            --arg owner "$TASK_OWNER" \
            '{task_id: $id, subject: $subject, owner: $owner}')
        ;;
    TaskCreated)
        TASK_ID=$(echo "$INPUT" | jq -r '.task_id // .id // "unknown"' 2>/dev/null)
        TASK_SUBJECT=$(echo "$INPUT" | jq -r '.subject // ""' 2>/dev/null)

        EVENT_TYPE="task_created"
        EVENT_DATA=$(jq -n \
            --arg id "$TASK_ID" \
            --arg subject "$TASK_SUBJECT" \
            '{task_id: $id, subject: $subject}')
        ;;
    SubagentStart)
        AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .name // "unknown"' 2>/dev/null)
        AGENT_TYPE=$(echo "$INPUT" | jq -r '.subagent_type // .agent_type // "unknown"' 2>/dev/null)

        if echo "$AGENT_NAME" | grep -qE '^(epic|story|bug|db|ux|planning|analysis|design|quality)-'; then
            TEAM_NAME=$(echo "$AGENT_NAME" | cut -d: -f1)
        fi

        EVENT_TYPE="agent_start"
        EVENT_DATA=$(jq -n \
            --arg agent "$AGENT_NAME" \
            --arg type "$AGENT_TYPE" \
            '{agent_name: $agent, agent_type: $type}')
        ;;
    *)
        # 알 수 없는 Hook — 무시
        exit 0
        ;;
esac

# 팀 이름이 없으면 "default" 사용
TEAM_NAME="${TEAM_NAME:-default}"

# 이벤트 디렉토리 생성
TEAM_LOG_DIR="$LOGS_DIR/$TEAM_NAME"
mkdir -p "$TEAM_LOG_DIR"

# 이벤트 JSON 생성 (불변 — 한번 쓰면 수정 안 함)
EVENT_FILE="$TEAM_LOG_DIR/evt-${EPOCH_MS}-${UID_SHORT}.json"

jq -n \
    --arg id "evt-${EPOCH_MS}-${UID_SHORT}" \
    --arg type "$EVENT_TYPE" \
    --arg team "$TEAM_NAME" \
    --arg ts "$TIMESTAMP" \
    --arg hook "$HOOK_TYPE" \
    --argjson data "$EVENT_DATA" \
    '{
        id: $id,
        event_type: $type,
        team_name: $team,
        timestamp: $ts,
        hook_source: $hook,
        data: $data
    }' > "$EVENT_FILE" 2>/dev/null

# 요약 업데이트 (증분 — 마지막 집계 이후 새 이벤트만 카운트)
SUMMARY_FILE="$TEAM_LOG_DIR/summary.json"

if [ -f "$SUMMARY_FILE" ]; then
    SUMMARY=$(cat "$SUMMARY_FILE")
else
    SUMMARY='{"team_name":"","total_events":0,"agent_starts":0,"agent_stops":0,"tasks_created":0,"tasks_completed":0,"first_event":"","last_event":"","agents":{}}'
fi

# jq로 증분 업데이트
UPDATED_SUMMARY=$(echo "$SUMMARY" | jq \
    --arg team "$TEAM_NAME" \
    --arg ts "$TIMESTAMP" \
    --arg evt_type "$EVENT_TYPE" \
    --arg agent "${AGENT_NAME:-}" \
    '
    .team_name = $team |
    .total_events += 1 |
    .last_event = $ts |
    (if .first_event == "" then .first_event = $ts else . end) |
    (if $evt_type == "agent_start" then .agent_starts += 1 else . end) |
    (if $evt_type == "agent_stop" then .agent_stops += 1 else . end) |
    (if $evt_type == "task_created" then .tasks_created += 1 else . end) |
    (if $evt_type == "task_completed" then .tasks_completed += 1 else . end) |
    (if $agent != "" then .agents[$agent] = ((.agents[$agent] // 0) + 1) else . end)
    ' 2>/dev/null)

if [ -n "$UPDATED_SUMMARY" ]; then
    echo "$UPDATED_SUMMARY" > "$SUMMARY_FILE"
fi

exit 0
