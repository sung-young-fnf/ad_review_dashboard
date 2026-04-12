#!/bin/bash
# .claude/hooks/pre/agent-chain-auto-continue.sh
# Agent Chain Auto-Continue: 미완료 Task 자동 감지 및 권장
# Phase 1: 키워드 기반 부드러운 가이드

set -e
trap 'exit 0' ERR

# ============================================================================
# Phase 0: stdin 읽기 및 환경 변수 설정
# ============================================================================

# 사용자 입력 읽기 (우선순위: 환경 변수 > stdin)
USER_INPUT="${CLAUDE_USER_PROMPT:-}"

if [[ -z "$USER_INPUT" ]] && [ ! -t 0 ]; then
  USER_INPUT=$(cat 2>/dev/null || echo "")
fi

# 빈 입력이면 조용히 종료
if [[ -z "$USER_INPUT" ]] || [[ ${#USER_INPUT} -lt 2 ]]; then
  exit 0
fi

# ============================================================================
# Phase 1: 키워드 감지
# ============================================================================

# "이어서 진행" 관련 키워드
CONTINUE_KEYWORDS="이어서|진행|계속|이어|네"

if ! echo "$USER_INPUT" | grep -iEq "$CONTINUE_KEYWORDS"; then
  # 키워드 없으면 종료
  exit 0
fi

# ============================================================================
# Phase 2: Agent Chain 상태 확인
# ============================================================================

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
STATE_FILE="$REPO_ROOT/.claude/.agent-chain-state"
LAST_AGENT="none"

if [[ -f "$STATE_FILE" ]]; then
  LAST_AGENT=$(cat "$STATE_FILE" 2>/dev/null || echo "none")
fi

# ============================================================================
# Phase 3: 미완료 Task 탐색
# ============================================================================

# docs/epics/**/tasks/ 에서 최근 수정된 Task 파일 찾기
RECENT_TASKS=$(find "$REPO_ROOT/docs/epics" -name "T*.md" -type f -mtime -1 2>/dev/null | sort -r | head -5)

UNCOMPLETED_TASK=""

# Task 파일에서 미완료 체크박스 확인
for task_file in $RECENT_TASKS; do
  # "- [ ]" 체크박스가 있으면 미완료
  if grep -q "^- \[ \]" "$task_file" 2>/dev/null; then
    UNCOMPLETED_TASK="$task_file"
    break
  fi
done

# ============================================================================
# Phase 4: 자동 권장 출력
# ============================================================================

if [[ -n "$UNCOMPLETED_TASK" ]]; then
  TASK_NAME=$(basename "$UNCOMPLETED_TASK" .md)

  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║               🚀 AGENT CHAIN AUTO-CONTINUE (Phase 1)                      ║
╚═══════════════════════════════════════════════════════════════════════════╝

감지: "이어서 진행" 키워드
상태: Agent Chain 실행 가능

📋 미완료 Task 발견:
  - Task: $TASK_NAME
  - 파일: $UNCOMPLETED_TASK

💡 권장 액션:
  Task --subagent_type 04-implementation/code-writer \\
    --prompt "$TASK_NAME 구현" \\
    --description "$TASK_NAME"

⚠️ 중요:
  - "이어서"는 선언이 아닌 실행 명령입니다
  - 즉시 Task tool을 호출하세요!
  - 선언만 하고 실행 안 하면 Hook 미작동

───────────────────────────────────────────────────────────────────────────
📚 참조: @.claude/guides/AGENT_CHAIN_RULES.md

EOF
else
  # 미완료 Task 없으면 완료 안내
  cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║               ✅ AGENT CHAIN COMPLETE                                      ║
╚═══════════════════════════════════════════════════════════════════════════╝

감지: "이어서 진행" 키워드
상태: 미완료 Task 없음

📊 최근 실행:
  - 마지막 Agent: $LAST_AGENT

💡 다음 액션:
  - 새로운 Story/Epic 시작?
  - 완료된 Task 검증?

EOF
fi

exit 0
