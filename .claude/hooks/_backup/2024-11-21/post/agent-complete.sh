#!/bin/bash
# .claude/hooks/post/agent-complete.sh
# Agent 완료 후 Impact Entry 자동 생성 + Phase 1 체인 추적

set -e
trap 'exit 0' ERR

REPO_ROOT=$(git rev-parse --show-toplevel)
IMPACT_MAP="$REPO_ROOT/docs/analysis/impact-map.yaml"
APPEND_SCRIPT="$REPO_ROOT/.claude/slash-commands/impact-analyzer/append-impact.sh"

# 성능 추적 유틸리티 로드
UTILS_DIR="$REPO_ROOT/.claude/hooks/utils"
if [[ -f "$UTILS_DIR/hook-performance-tracker.sh" ]]; then
  source "$UTILS_DIR/hook-performance-tracker.sh"
  start_timer
  PERFORMANCE_TRACKING_ENABLED=true
else
  PERFORMANCE_TRACKING_ENABLED=false
fi

# Step 0: stdin에서 session_id 받기 (동시 세션 지원)
event_info=$(cat)
SESSION_ID=$(echo "$event_info" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")

# Step 1: Agent 정보 수집 (stdin event_info 우선, 환경 변수 fallback)
AGENT_TYPE=$(echo "$event_info" | jq -r '.agent_type // empty' 2>/dev/null)
AGENT_TASK=$(echo "$event_info" | jq -r '.task_id // empty' 2>/dev/null)
AGENT_EPIC=$(echo "$event_info" | jq -r '.epic_id // empty' 2>/dev/null)
AGENT_STORY=$(echo "$event_info" | jq -r '.story_id // empty' 2>/dev/null)

# event_info에 없으면 환경 변수 fallback
AGENT_TYPE="${AGENT_TYPE:-${CLAUDE_AGENT_TYPE:-unknown}}"
AGENT_TASK="${AGENT_TASK:-${CLAUDE_TASK_ID:-}}"
AGENT_EPIC="${AGENT_EPIC:-${CLAUDE_EPIC_ID:-}}"
AGENT_STORY="${AGENT_STORY:-${CLAUDE_STORY_ID:-}}"

# Step 2: 변경 파일 확인
MODIFIED_FILES=$(git diff --name-status HEAD 2>/dev/null || echo "")

if [ -z "$MODIFIED_FILES" ]; then
  echo "⚠️ 변경된 파일 없음. Impact 기록 스킵."
  exit 0
fi

# Step 3: Pre-Analysis Agent 검증 (NEW)
validate_pre_analysis_output() {
  local AGENT_NAME="$1"
  local DOCS_ANALYSIS="$REPO_ROOT/docs/analysis"

  case "$AGENT_NAME" in
    "01-pre-analysis/code-structure-analyzer")
      # Primary 문서 검증
      if [ ! -f "$DOCS_ANALYSIS/code-structure.md" ]; then
        echo "⚠️ WARNING: code-structure.md 생성 실패! Agent가 문서를 생성하지 않았습니다." >&2
        exit 0  # Graceful degradation
      fi

      # 중복 검증 (Expert 권장: 버전 정보는 tech-stack.md 전용)
      if grep -qE "(Next\.js|React|TypeScript)\s+[0-9]+\.[0-9]+" "$DOCS_ANALYSIS/code-structure.md"; then
        echo "⚠️ WARNING: code-structure.md에 버전 정보 감지" >&2
        echo "   → tech-stack.md로 이관 필요" >&2
        echo "   → 해당 줄 제거 후 @docs/analysis/tech-stack.md 링크로 대체" >&2
      fi

      # 크기 검증 (300-500 tokens ≈ 1200-2000 bytes 목표)
      local FILE_SIZE=$(wc -c < "$DOCS_ANALYSIS/code-structure.md" | tr -d ' ')
      if [ "$FILE_SIZE" -gt 3500 ]; then
        echo "⚠️ WARNING: code-structure.md 파일이 너무 큼 (${FILE_SIZE} bytes > 3500)" >&2
        echo "   → 상세 내용을 architecture/*.md로 이관 필요" >&2
      fi

      echo "✅ code-structure.md 검증 완료 (${FILE_SIZE} bytes)"
      ;;

    "01-pre-analysis/tech-stack-analyzer")
      if [ ! -f "$DOCS_ANALYSIS/tech-stack.md" ]; then
        echo "⚠️ WARNING: tech-stack.md 생성 실패! Agent가 문서를 생성하지 않았습니다." >&2
        exit 0  # Graceful degradation
      fi

      # 중복 검증 (아키텍처 패턴은 code-structure.md 전용)
      if grep -qiE "(Feature-Sliced Design|FSD|MVC|Layered|Hexagonal)" "$DOCS_ANALYSIS/tech-stack.md"; then
        echo "⚠️ WARNING: tech-stack.md에 아키텍처 패턴 감지" >&2
        echo "   → code-structure.md로 이관 필요" >&2
      fi

      echo "✅ tech-stack.md 검증 완료"
      ;;

    "01-pre-analysis/business-analyzer")
      if [ ! -f "$DOCS_ANALYSIS/business-domain.md" ]; then
        echo "⚠️ WARNING: business-domain.md 저장 실패! Agent가 문서를 생성하지 않았습니다."  >&2
        exit 0  # Graceful degradation
      fi

      # 파일 크기 검증 (최소 500 bytes)
      local FILE_SIZE=$(wc -c < "$DOCS_ANALYSIS/business-domain.md" | tr -d ' ')
      if [ "$FILE_SIZE" -lt 500 ]; then
        echo "⚠️ WARNING: business-domain.md 파일이 너무 작음 (${FILE_SIZE} bytes)" >&2
      fi

      echo "✅ business-domain.md 검증 완료 (${FILE_SIZE} bytes)"
      ;;

    "01-pre-analysis/comprehensive-db-analyzer")
      if [ ! -f "$DOCS_ANALYSIS/database-schema.md" ]; then
        echo "⚠️ WARNING: database-schema.md 생성 실패" >&2
      else
        echo "✅ database-schema.md 검증 완료"
      fi
      ;;

    "01-pre-analysis/code-quality-inspector")
      if [ ! -f "$DOCS_ANALYSIS/code-quality-report.md" ]; then
        echo "⚠️ WARNING: code-quality-report.md 생성 실패" >&2
      else
        echo "✅ code-quality-report.md 검증 완료"
      fi
      ;;

    "01-pre-analysis/test-env-analyzer")
      if [ ! -f "$DOCS_ANALYSIS/test-environment.md" ]; then
        echo "⚠️ WARNING: test-environment.md 생성 실패" >&2
      else
        echo "✅ test-environment.md 검증 완료"
      fi
      ;;
  esac
}

# Pre-Analysis Agent인 경우 검증 실행
if [[ "$AGENT_TYPE" =~ ^01-pre-analysis/ ]]; then
  echo "🔍 Pre-Analysis Agent 출력 검증 중..."
  validate_pre_analysis_output "$AGENT_TYPE"
fi

# Step 3.5: impact-map.yaml 존재 확인
if [ ! -f "$IMPACT_MAP" ]; then
  echo "⚠️ impact-map.yaml 없음. S01 Story 먼저 완료하세요."
  exit 0
fi

# Step 4: append-impact.sh 호출
if [ -x "$APPEND_SCRIPT" ]; then
  GIT_DIFF=$(git diff --numstat HEAD)

  "$APPEND_SCRIPT" \
    --epic "${AGENT_EPIC}" \
    --story "${AGENT_STORY}" \
    --task "${AGENT_TASK}" \
    --description "Agent ${AGENT_TYPE} 완료" \
    --files "$GIT_DIFF" \
    --effort "auto"

  echo "✅ Impact Entry 추가 완료"
else
  echo "💡 append-impact.sh 없음. S03 Story 먼저 완료하세요."
fi

# ============================================================================
# Phase 1: Agent Chain Tracking (Agent 체인 중단 방지)
# ============================================================================

track_agent_chain() {
  # code-writer Agent만 추적
  if [[ "$AGENT_TYPE" != "04-implementation/code-writer" ]]; then
    return 0
  fi

  # 체인 상태 저장 경로 (세션별 격리)
  local CHAIN_STATE_DIR="$REPO_ROOT/.claude/hooks-cache/${SESSION_ID}"
  local CHAIN_STATE="$CHAIN_STATE_DIR/agent-chain-state.json"
  mkdir -p "$CHAIN_STATE_DIR"

  # 체인 상태 업데이트
  cat > "$CHAIN_STATE" <<EOF
{
  "session_id": "$SESSION_ID",
  "current_agent": "none",
  "last_completed_agent": "$AGENT_TYPE",
  "last_task": "$AGENT_TASK",
  "last_story": "$AGENT_STORY",
  "last_epic": "$AGENT_EPIC",
  "timestamp": $(date +%s)
}
EOF

  echo "✅ Agent 체인 상태 저장 (Session: $SESSION_ID): $AGENT_TASK" >&2

  # 다음 Task 감지 및 알림
  detect_next_task
}

detect_next_task() {
  local TASK_DIR="$REPO_ROOT/docs/epics/${AGENT_EPIC}/tasks"

  # Task 디렉토리 존재 확인
  if [[ ! -d "$TASK_DIR" ]] || [[ -z "$AGENT_TASK" ]]; then
    return 0
  fi

  # 현재 Task 번호 추출 (예: T001-S03 → 001)
  local CURRENT_NUM=$(echo "$AGENT_TASK" | sed -E 's/T0*([0-9]+)-.*/\1/')

  # 숫자 추출 실패 시 종료
  if [[ -z "$CURRENT_NUM" ]] || [[ ! "$CURRENT_NUM" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  local NEXT_NUM=$((CURRENT_NUM + 1))

  # 다음 Task 파일 찾기 (예: T002-S03.md)
  local NEXT_TASK_FILE=$(find "$TASK_DIR" -name "T$(printf '%03d' $NEXT_NUM)-*.md" 2>/dev/null | head -1)

  if [[ -n "$NEXT_TASK_FILE" ]]; then
    local NEXT_TASK_ID=$(basename "$NEXT_TASK_FILE" .md)
    local NEXT_TASK_TITLE=$(grep -m 1 '^# ' "$NEXT_TASK_FILE" 2>/dev/null | sed 's/^# //' || echo "Unknown")

    # 상태 파일에 저장 (Strategy 1: State File System)
    local STATE_DIR="$REPO_ROOT/.claude/hooks-cache/${SESSION_ID}"
    local NEXT_TASK_STATE="$STATE_DIR/next-task.json"
    mkdir -p "$STATE_DIR"

    cat > "$NEXT_TASK_STATE" <<EOF
{
  "session_id": "$SESSION_ID",
  "completed_task": "$AGENT_TASK",
  "next_task_id": "$NEXT_TASK_ID",
  "next_task_title": "$NEXT_TASK_TITLE",
  "next_task_file": "$NEXT_TASK_FILE",
  "agent_type": "04-implementation/code-writer",
  "timestamp": $(date +%s)
}
EOF

    # 간소화된 메시지 (100줄 → 3줄)
    echo "" >&2
    echo "✅ $AGENT_TASK 완료 → 🔄 다음: $NEXT_TASK_ID ($NEXT_TASK_TITLE)" >&2
    echo "📋 Task(subagent_type: \"04-implementation/code-writer\", prompt: \"$NEXT_TASK_ID 구현\")" >&2
    echo "" >&2

    # Serena Memory에 handoff 저장 (자동 실행 트리거)
    local HANDOFF_MEMORY="handoff_code_writer_${NEXT_TASK_ID}"
    local HANDOFF_CONTENT=$(cat <<EOF
{
  "source_agent": "04-implementation/code-writer",
  "completed_task": "$AGENT_TASK",
  "next_task_id": "$NEXT_TASK_ID",
  "next_task_title": "$NEXT_TASK_TITLE",
  "next_task_file": "$NEXT_TASK_FILE",
  "epic_id": "$AGENT_EPIC",
  "story_id": "$AGENT_STORY",
  "agent_type": "04-implementation/code-writer",
  "auto_execute": true,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    # Claude Code MCP를 통해 Memory 저장
    echo "$HANDOFF_CONTENT" | claude mcp serena write_memory \
      --memory-file-name "$HANDOFF_MEMORY" \
      --content - 2>/dev/null || true

    echo "💾 Handoff Memory 저장: $HANDOFF_MEMORY" >&2
  else
    echo "" >&2
    echo "✅ 모든 Task 완료! Story $AGENT_STORY 완료 보고" >&2
    echo "" >&2
  fi
}

# Agent 체인 추적 실행
track_agent_chain

# 성능 로그 업데이트
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  end_timer "agent-complete"
fi
