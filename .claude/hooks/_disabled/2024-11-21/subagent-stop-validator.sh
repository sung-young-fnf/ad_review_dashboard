#!/bin/bash
#
# SubagentStop Hook - Intelligent Sub-Agent Completion Validator
#
# Purpose: Sub-Agent 완료 조건 자동 판단 및 무한 루프 방지
# Trigger: Sub-Agent (Task tool) 실행 완료 후
# Effect: Agent별 완료 시그널 확인, 반복 제한, 토큰 절감
#
# Input (stdin JSON):
# {
#   "session_id": "uuid",
#   "agent_name": "file-analyzer",
#   "agent_id": "agent-123",  # 🆕 NEW (2.0.42)
#   "agent_transcript_path": "/path/to/transcript.json",  # 🆕 NEW (2.0.42)
#   "output": "분석 완료...",
#   "iteration": 2,
#   "transcript_path": "/path/to/transcript.json"  # DEPRECATED (legacy support)
# }
#
# Exit Codes:
#   0: Complete (Agent 완료, 다음 단계 진행)
#   1: Continue (Agent 계속 실행 필요)
#   2: Escalate (사용자 개입 필요)

set -euo pipefail

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
LOG_FILE="/tmp/claude-subagent-stop.log"
MAX_ITERATIONS=3  # 최대 반복 횟수

# 🆕 Agent Chain Tracking (2.0.42)
AGENT_CHAIN_DIR="$PROJECT_ROOT/.claude/memory/agent-chain"
AGENT_CHAIN_HISTORY="$AGENT_CHAIN_DIR/history.jsonl"
mkdir -p "$AGENT_CHAIN_DIR"

# ============================================
# Logging
# ============================================

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ============================================
# Input Processing
# ============================================

# stdin에서 JSON 읽기 (타임아웃 1초)
INPUT=""
if read -t 1 INPUT; then
  log "Input received: ${#INPUT} bytes"
else
  log "No input or timeout - allowing continuation"
  exit 1  # Continue (기본 동작: Agent 계속 실행)
fi

# 빈 입력 처리
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - allowing continuation"
  exit 1  # Continue
fi

# JSON 파싱
AGENT_NAME=""
AGENT_ID=""
AGENT_TRANSCRIPT_PATH=""
OUTPUT=""
ITERATION=0

if command -v jq &> /dev/null; then
  AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null || echo "unknown")
  AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || echo "")  # 🆕 NEW
  AGENT_TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // .transcript_path // ""' 2>/dev/null || echo "")  # 🆕 NEW (fallback)
  OUTPUT=$(echo "$INPUT" | jq -r '.output // ""' 2>/dev/null || echo "")
  ITERATION=$(echo "$INPUT" | jq -r '.iteration // 0' 2>/dev/null || echo "0")
else
  log "jq not found - allowing continuation"
  exit 1  # Continue
fi

log "SubagentStop: agent=$AGENT_NAME, id=$AGENT_ID, iteration=$ITERATION, output_len=${#OUTPUT}"
log "Transcript: $AGENT_TRANSCRIPT_PATH"

# ============================================
# Agent별 완료 시그널 정의
# ============================================

# Agent 이름 정규화 (경로 제거)
AGENT_BASENAME=$(basename "$AGENT_NAME" | sed 's/\..*$//')

check_completion_signals() {
  local agent="$1"
  local output="$2"

  case "$agent" in
    # 99-utils 카테고리
    "file-analyzer")
      # 요약 섹션 존재 확인
      if echo "$output" | grep -qE "(## 핵심 요약|## 결론|## Summary)"; then
        log "✅ file-analyzer: Summary section found"
        return 0
      fi
      ;;

    "error-fixer")
      # 수정 완료 시그널
      if echo "$output" | grep -qE "(✅.*완료|수정.*완료|fixed|resolved)"; then
        log "✅ error-fixer: Fix completed"
        return 0
      fi
      # 테스트 통과 시그널
      if echo "$output" | grep -qE "(tests? passing|All tests passed)"; then
        log "✅ error-fixer: Tests passing"
        return 0
      fi
      ;;

    "commit-manager"|"commit-manager-auto")
      # 커밋 완료 시그널
      if echo "$output" | grep -qE "(committed|커밋.*완료|\[.*\])"; then
        log "✅ commit-manager: Commit completed"
        return 0
      fi
      ;;

    # 04-implementation 카테고리
    "code-writer"|"reference-code-writer")
      # Handoff 메시지
      if echo "$output" | grep -qE "(handoff|구현.*완료|implementation complete)"; then
        log "✅ code-writer: Implementation complete"
        return 0
      fi
      # 파일 생성/수정 완료
      if echo "$output" | grep -qE "(Created file|Modified file|✅.*파일)"; then
        log "✅ code-writer: Files modified"
        return 0
      fi
      ;;

    "test-creator")
      # 테스트 작성 완료
      if echo "$output" | grep -qE "(test.*created|테스트.*작성.*완료|✅.*test)"; then
        log "✅ test-creator: Tests created"
        return 0
      fi
      ;;

    "ui-tester")
      # UI 검증 완료
      if echo "$output" | grep -qE "(verification complete|검증.*완료|✅.*UI)"; then
        log "✅ ui-tester: UI verified"
        return 0
      fi
      ;;

    # 03-design 카테고리
    "task-planner"|"reference-task-planner")
      # Task 파일 생성 완료
      if echo "$output" | grep -qE "(Task.*저장|docs/epics.*tasks|✅.*Task)"; then
        log "✅ task-planner: Tasks created"
        return 0
      fi
      ;;

    "tech-spec-engineer"|"reference-tech-spec")
      # Tech Spec 파일 생성 완료
      if echo "$output" | grep -qE "(Tech Spec.*저장|tech-specs.*\.md|✅.*Spec)"; then
        log "✅ tech-spec-engineer: Spec created"
        return 0
      fi
      ;;

    # 02-requirements 카테고리
    "story-creator"|"reference-story-creator"|"02-story-creator")
      # Story 파일 생성 완료 (더 관대한 패턴)
      if echo "$output" | grep -qE "(Story.*저장|stories.*\.md|✅.*Story|Write.*stories|파일.*생성|created.*S[0-9]+)"; then
        log "✅ story-creator: Stories created"
        return 0
      fi
      ;;

    "epic-creator"|"reference-epic-creator"|"01-epic-creator")
      # Epic 파일 생성 완료 (더 관대한 패턴)
      if echo "$output" | grep -qE "(Epic.*저장|epics.*\.md|✅.*Epic|Write.*epic|폴더.*생성|created.*EP[0-9]+)"; then
        log "✅ epic-creator: Epic created"
        return 0
      fi
      ;;

    # 01-pre-analysis 카테고리
    *"-analyzer")
      # 분석 완료 시그널
      if echo "$output" | grep -qE "(분석.*완료|analysis complete|✅.*분석)"; then
        log "✅ analyzer: Analysis complete"
        return 0
      fi
      # 리포트 저장 시그널
      if echo "$output" | grep -qE "(리포트.*저장|report saved|docs/analysis)"; then
        log "✅ analyzer: Report saved"
        return 0
      fi
      ;;

    *)
      # 기본 완료 시그널 (모든 Agent 공통)
      if echo "$output" | grep -qE "(완료|complete|done|finished|✅)"; then
        log "✅ $agent: Generic completion signal found"
        return 0
      fi
      ;;
  esac

  return 1  # Not completed
}

# ============================================
# Iteration Limit Check
# ============================================

check_iteration_limit() {
  local iteration=$1

  if [[ $iteration -ge $MAX_ITERATIONS ]]; then
    log "⚠️ Iteration limit reached: $iteration >= $MAX_ITERATIONS"
    echo "⚠️ Sub-Agent 반복 제한 ($MAX_ITERATIONS회) 도달" >&2
    echo "   Agent: $AGENT_BASENAME" >&2
    echo "   다음 작업을 명확히 지시해주세요." >&2
    return 0  # Escalate needed
  fi

  return 1  # Continue
}

# ============================================
# 🆕 Agent Chain Tracking (2.0.42)
# ============================================

save_agent_chain_data() {
  local agent_id="$1"
  local agent_name="$2"
  local transcript_path="$3"
  local status="$4"  # complete/error/continue

  # agent_id가 없으면 저장 스킵
  if [[ -z "$agent_id" ]]; then
    log "Agent ID not available - skipping chain tracking"
    return 0
  fi

  # JSON 데이터 생성
  local chain_data
  chain_data=$(jq -n \
    --arg id "$agent_id" \
    --arg name "$agent_name" \
    --arg transcript "$transcript_path" \
    --arg status "$status" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      agent_id: $id,
      agent_name: $name,
      transcript_path: $transcript,
      status: $status,
      timestamp: $timestamp
    }' 2>/dev/null)

  # 저장 성공 여부 확인
  if [[ -n "$chain_data" ]]; then
    echo "$chain_data" >> "$AGENT_CHAIN_HISTORY"
    log "✅ Agent Chain data saved: $agent_id ($status)"
  else
    log "⚠️ Failed to create chain data JSON"
  fi
}

# ============================================
# Error Detection
# ============================================

check_for_errors() {
  local output="$1"

  # 에러 패턴 감지
  if echo "$output" | grep -qE "(Error:|ERROR:|❌|실패|failed|cannot|unable to)"; then
    log "⚠️ Error detected in output"

    # 하지만 "fixed" 또는 "resolved"도 함께 있으면 수정 완료로 간주
    if echo "$output" | grep -qE "(fixed|resolved|수정.*완료)"; then
      log "✅ Error was fixed"
      return 1  # Not blocking
    fi

    return 0  # Error found
  fi

  return 1  # No error
}

# ============================================
# Main Decision Logic
# ============================================

main() {
  log "=== SubagentStop Hook Started ==="
  log "Agent: $AGENT_BASENAME, Iteration: $ITERATION"

  # 1. 반복 제한 체크 (최우선)
  if check_iteration_limit "$ITERATION"; then
    log "Decision: ESCALATE (iteration limit)"
    save_agent_chain_data "$AGENT_ID" "$AGENT_BASENAME" "$AGENT_TRANSCRIPT_PATH" "escalate"  # 🆕
    exit 2  # Escalate
  fi

  # 2. 완료 시그널 체크
  if check_completion_signals "$AGENT_BASENAME" "$OUTPUT"; then
    log "Decision: COMPLETE (signals found)"
    save_agent_chain_data "$AGENT_ID" "$AGENT_BASENAME" "$AGENT_TRANSCRIPT_PATH" "complete"  # 🆕
    echo "✅ Sub-Agent 완료: $AGENT_BASENAME" >&2
    exit 0  # Complete
  fi

  # 3. 에러 감지
  if check_for_errors "$OUTPUT"; then
    log "Decision: ESCALATE (error detected)"
    save_agent_chain_data "$AGENT_ID" "$AGENT_BASENAME" "$AGENT_TRANSCRIPT_PATH" "error"  # 🆕
    echo "⚠️ Sub-Agent 에러 감지: $AGENT_BASENAME" >&2
    exit 2  # Escalate
  fi

  # 4. 기본 동작: 계속 실행
  log "Decision: CONTINUE (no completion signals)"
  save_agent_chain_data "$AGENT_ID" "$AGENT_BASENAME" "$AGENT_TRANSCRIPT_PATH" "continue"  # 🆕
  exit 1  # Continue
}

# Graceful error handling (기본값: Continue)
trap 'log "Error occurred, allowing continuation"; exit 1' ERR

main
