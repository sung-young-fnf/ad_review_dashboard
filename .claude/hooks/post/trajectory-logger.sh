#!/bin/bash
# Trajectory Logger — hermes-traj 패턴 적용
# SubagentStop 시 성공/실패를 분류하여 JSONL로 기록
# 장기적으로 "어떤 유형 작업이 성공/실패하는지" 분석 데이터
#
# 저장소: .claude/trajectories/success.jsonl
#         .claude/trajectories/failure.jsonl
# 영감: hermes-CCC/skills/hermes-traj (NousResearch)

set -eo pipefail
trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TRAJ_DIR="$REPO_ROOT/.claude/trajectories"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SHORT=$(date -u +"%Y-%m-%d")

# stdin에서 Hook 이벤트 JSON 읽기
INPUT=$(cat 2>/dev/null || echo "{}")

# jq 필수
if ! command -v jq &>/dev/null; then
    exit 0
fi

# SubagentStop 이벤트만 처리
HOOK_TYPE="${CLAUDE_HOOK_EVENT_NAME:-}"
if [[ "$HOOK_TYPE" != "SubagentStop" ]]; then
    exit 0
fi

# Agent 메타데이터 추출
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .name // "unknown"' 2>/dev/null)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.subagent_type // .agent_type // "unknown"' 2>/dev/null)
AGENT_RESULT=$(echo "$INPUT" | jq -r '.result // ""' 2>/dev/null | head -c 1000)

# 성공/실패 판정
# 실패 신호: result에 에러/실패 키워드, 또는 빈 결과
COMPLETED=true
FAILURE_REASON=""

if echo "$AGENT_RESULT" | grep -qiE '(error|fail|exception|timeout|VIOLATION|cannot|unable|blocked)'; then
    COMPLETED=false
    # 실패 이유를 첫 매칭 라인에서 추출
    FAILURE_REASON=$(echo "$AGENT_RESULT" | grep -iE '(error|fail|exception|timeout|VIOLATION|cannot|unable|blocked)' | head -1 | head -c 200)
fi

if [[ -z "$AGENT_RESULT" ]] || [[ "$AGENT_RESULT" == "null" ]]; then
    COMPLETED=false
    FAILURE_REASON="empty result (agent may have timed out or crashed)"
fi

# Task 유형 추론 (agent_type에서)
TASK_TYPE="other"
case "$AGENT_TYPE" in
    *code-writer*|*quick-modifier*) TASK_TYPE="coding" ;;
    *error-fixer*) TASK_TYPE="debugging" ;;
    *task-planner*|*story-creator*|*epic-creator*) TASK_TYPE="planning" ;;
    *Explore*|*file-analyzer*) TASK_TYPE="research" ;;
    *implementation-validator*|*test-creator*) TASK_TYPE="verification" ;;
    *ux-*|*design-*) TASK_TYPE="design" ;;
    *db-code-writer*) TASK_TYPE="database" ;;
    *commit-manager*) TASK_TYPE="ops" ;;
    *codex-delegate*|*gemini-delegate*) TASK_TYPE="delegate" ;;
esac

# 태그 자동 추출 (result에서 도메인 키워드)
TAGS="[]"
TAG_LIST=""
echo "$AGENT_RESULT" | grep -qiE '(frontend|react|next\.js|component)' && TAG_LIST="${TAG_LIST}\"frontend\","
echo "$AGENT_RESULT" | grep -qiE '(backend|api|controller|service|nestjs|fastapi)' && TAG_LIST="${TAG_LIST}\"backend\","
echo "$AGENT_RESULT" | grep -qiE '(prisma|migration|schema|database|sql)' && TAG_LIST="${TAG_LIST}\"database\","
echo "$AGENT_RESULT" | grep -qiE '(auth|token|session|permission)' && TAG_LIST="${TAG_LIST}\"auth\","
echo "$AGENT_RESULT" | grep -qiE '(mcp|tool|server)' && TAG_LIST="${TAG_LIST}\"mcp\","
echo "$AGENT_RESULT" | grep -qiE '(test|spec|jest|vitest)' && TAG_LIST="${TAG_LIST}\"testing\","
echo "$AGENT_RESULT" | grep -qiE '(deploy|k8s|argocd|docker)' && TAG_LIST="${TAG_LIST}\"infra\","

if [[ -n "$TAG_LIST" ]]; then
    TAG_LIST="${TAG_LIST%,}"  # trailing comma 제거
    TAGS="[${TAG_LIST}]"
fi

# 검증 상태 추출
VERIFICATION="not checked"
echo "$AGENT_RESULT" | grep -qiE '(pnpm build.*success|build passed|tsc.*0 error|tests? passed)' && VERIFICATION="build/test passed"
echo "$AGENT_RESULT" | grep -qiE '(build fail|tsc.*error|test fail)' && VERIFICATION="build/test failed"

# 결과 요약 (첫 200자)
RESULT_SUMMARY=$(echo "$AGENT_RESULT" | head -c 200 | tr '\n' ' ' | sed 's/  */ /g')

# 디렉토리 생성
mkdir -p "$TRAJ_DIR"

# JSONL 엔트리 생성
ENTRY=$(jq -n \
    --arg id "traj-${DATE_SHORT}-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')" \
    --arg ts "$TIMESTAMP" \
    --arg task_type "$TASK_TYPE" \
    --argjson completed "$COMPLETED" \
    --arg agent_name "$AGENT_NAME" \
    --arg agent_type "$AGENT_TYPE" \
    --argjson tags "$TAGS" \
    --arg result_summary "$RESULT_SUMMARY" \
    --arg verification "$VERIFICATION" \
    --arg failure_reason "$FAILURE_REASON" \
    '{
        id: $id,
        timestamp: $ts,
        task_type: $task_type,
        completed: $completed,
        agent_name: $agent_name,
        agent_type: $agent_type,
        tags: $tags,
        result_summary: $result_summary,
        verification: $verification
    } + (if $completed == false then {failure_reason: $failure_reason} else {} end)' 2>/dev/null)

if [[ -z "$ENTRY" ]]; then
    exit 0
fi

# 성공/실패 파일에 각각 append
if [[ "$COMPLETED" == "true" ]]; then
    echo "$ENTRY" >> "$TRAJ_DIR/success.jsonl"
else
    echo "$ENTRY" >> "$TRAJ_DIR/failure.jsonl"
fi

exit 0
