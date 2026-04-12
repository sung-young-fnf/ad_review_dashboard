#!/bin/bash
#
# SubagentStart Hook - Dynamic Context Injection (2.0.43)
#
# Purpose: Agent 실행 전 자동 컨텍스트 주입 (Reddit Hook 통합)
# Trigger: Sub-Agent (Task tool) 실행 시작 전
# Effect: Agent별 체크리스트, 주의사항, 품질 기준 자동 주입
#
# Input (stdin JSON):
# {
#   "agent_id": "agent-123",
#   "agent_type": "04-implementation/code-writer",
#   "prompt": "T001: 구현 요청..."
# }
#
# Output (stderr): Context injection message

# set -euo pipefail (disabled for Graceful Degradation)
set +e

# ============================================
# Configuration
# ============================================

PROJECT_ROOT="$(pwd)"
LOG_FILE="/tmp/claude-subagent-start.log"

# Agent Chain Tracking
AGENT_CHAIN_DIR="$PROJECT_ROOT/.claude/memory/agent-chain"
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
  log "No input or timeout - skipping context injection"
  exit 0
fi

# 빈 입력 처리
if [[ -z "$INPUT" ]] || [[ "${#INPUT}" -lt 2 ]]; then
  log "Empty input - skipping context injection"
  exit 0
fi

# JSON 파싱
AGENT_ID=""
AGENT_TYPE=""
PROMPT=""

if command -v jq &> /dev/null; then
  AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || echo "")
  AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // .subagent_type // "unknown"' 2>/dev/null || echo "unknown")
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
else
  log "jq not found - skipping context injection"
  exit 0
fi

log "SubagentStart: agent_type=$AGENT_TYPE, agent_id=$AGENT_ID, prompt_len=${#PROMPT}"

# Agent 이름 정규화
AGENT_BASENAME=$(basename "$AGENT_TYPE" | sed 's/\..*$//')

# ============================================
# Agent별 동적 컨텍스트 주입
# ============================================

inject_context() {
  local agent="$1"
  local context=""

  case "$agent" in
    # 04-implementation 카테고리
    "code-writer"|"reference-code-writer")
      context="
⚠️  [SubagentStart] code-writer 체크리스트 자동 주입

🔥 React Hook 무한 루프 방지 (CRITICAL):
   - useEffect 의존성: primitive 값만 (객체/함수 금지)
   - API hook 안정화: return useMemo(() => ({api}), [])
   - ESLint exhaustive-deps 경고 무시 절대 금지

📐 프로젝트 패턴:
   - Admin Impersonation: session.backendToken + X-Impersonate-User 헤더
   - API Routes: 405 방지 (모든 HTTP 메서드 구현)
   - 환경 변수 fallback: API_BASE_URL || BACKEND_URL

🗄️  Database:
   - ALWAYS use {project_schema}.table_name (public 금지)
   - Read @docs/analysis/database-schema.md first

✅ 구현 완료 시 Handoff 메시지 필수
"
      ;;

    "db-code-writer")
      context="
⚠️  [SubagentStart] db-code-writer 체크리스트 자동 주입

🗄️  DB Schema 규칙 (MANDATORY):
   - ALWAYS use {project_schema}.table_name
   - NEVER use public schema implicitly
   - Read @docs/analysis/database-schema.md FIRST

⚡ YAGNI 원칙:
   - 현재 필요한 필드만 추가
   - 미래 예측 컬럼 금지
   - 최소 제약 조건

🔒 안전 모드:
   - DB 스키마 변경: 사용자 승인 필수
   - Migration 생성만 (실행 금지)
   - Rollback 전략 필수
"
      ;;

    "ui-tester")
      context="
⚠️  [SubagentStart] ui-tester 체크리스트 자동 주입

🎨 Aesthetic Quality 검증:
   - Design Intent 준수 확인
   - Distinctive vs Generic 평가
   - CSS Variables 준수 (--accent, --primary)

♿ Accessibility 검증 (WCAG 2.1 AA):
   - Color Contrast >= 4.5:1
   - Keyboard Navigation 작동
   - ARIA labels 존재

🌗 Dark Mode 동작:
   - .dark 클래스 토글 테스트
   - 모든 색상 변수 대응
"
      ;;

    "test-creator")
      context="
⚠️  [SubagentStart] test-creator 체크리스트 자동 주입

✅ 테스트 원칙:
   - NO MOCK: 실제 서비스 사용 (Mock 금지)
   - Verbose: 디버깅 가능한 상세 출력
   - 실패 시: 테스트 구조 먼저 확인

📋 Epic/Task 구조:
   - docs/epics/{epic_id}/tasks/ 경로 준수
   - Test file naming: {component}.test.ts

🚫 EP121 금지 패턴:
   - expect(true).toBe(true), assert True 등 무의미 assertion 금지
   - 빈 테스트 바디 금지, mock-only 검증 금지
   - DB 테스트: TRUNCATE/DROP 금지 -> UUID prefix 격리 사용
   - Goal-Driven: '에러 처리 추가' -> '네트워크 에러 시 토스트+Retry 표시'
   - 참조: @.claude/rules/test-safety-rules.md
"
      ;;

    # 03-design 카테고리
    "task-planner")
      context="
⚠️  [SubagentStart] task-planner 체크리스트 자동 주입

⚡ 병렬 실행 분석 (CRITICAL):
   - Task 간 의존성 분석 필수
   - 독립적 Task → 병렬 그룹 생성
   - 예상 시간 비교 (병렬 vs 순차)

📝 TodoWrite 병렬 표시:
   - [병렬] 태그로 동시 실행 명시
   - 의존성 명시: (depends: T001, T002)

🎯 YAGNI 준수:
   - 현재 필요한 Task만 생성
   - 미래 예측 Task 금지
"
      ;;

    # 02-requirements 카테고리
    "story-creator"|"epic-creator")
      context="
⚠️  [SubagentStart] $agent 체크리스트 자동 주입

📋 문서 구조:
   - Epic: docs/epics/EP{nnn}/
   - Story: docs/epics/{epic_id}/stories/S##_*.md
   - _backlog: Epic 없는 독립 작업

✅ 완료 시그널:
   - Story/Epic 파일 생성 확인
   - PROGRESS.md 업데이트
   - Write tool 사용 확인
"
      ;;

    # 01-pre-analysis 카테고리
    *"-analyzer")
      context="
⚠️  [SubagentStart] analyzer 체크리스트 자동 주입

📊 분석 원칙:
   - Context Firewall: Sub-Agent 활용 (80-90% 토큰 절감)
   - 분석 완료 시그널 필수
   - 리포트 저장: docs/analysis/

🚨 Context Firewall:
   - Log 파일 → file-analyzer Sub-Agent
   - 코드 분석 → code-analyzer Sub-Agent
   - 직접 Read 금지 (Verbose 파일)
"
      ;;

    *)
      # 기본 컨텍스트 (모든 Agent 공통)
      context="
⚠️  [SubagentStart] $agent 실행 시작

📋 공통 체크리스트:
   - YAGNI: 현재 필요한 것만 구현
   - NO CODE DUPLICATION: 기존 코드 재사용
   - 완료 시그널: 명확한 완료 메시지 필수
"
      ;;
  esac

  # 컨텍스트 출력 (stderr로)
  if [[ -n "$context" ]]; then
    echo "$context" >&2
    log "✅ Context injected for: $agent"
  fi
}

# ============================================
# Agent 실행 로그
# ============================================

log_agent_start() {
  local agent_id="$1"
  local agent_type="$2"

  # 로그 디렉토리 생성
  mkdir -p "$PROJECT_ROOT/.claude/logs"
  mkdir -p "$PROJECT_ROOT/.agent-office/agents"

  # Agent 실행 시작 로그
  echo "[$(date)] Agent Start: $agent_type (ID: $agent_id)" >> "$PROJECT_ROOT/.claude/logs/agent-execution.log"

  # Agent Chain 데이터 저장 (시작 시점)
  if command -v jq &> /dev/null && [[ -n "$agent_id" ]]; then
    local start_data
    start_data=$(jq -n \
      --arg id "$agent_id" \
      --arg type "$agent_type" \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        agent_id: $id,
        agent_type: $type,
        event: "start",
        timestamp: $timestamp
      }' 2>/dev/null)

    if [[ -n "$start_data" ]]; then
      echo "$start_data" >> "$AGENT_CHAIN_DIR/history.jsonl"
      log "✅ Agent start event logged: $agent_id"
    fi

    # 📡 Live Tracking: 활성 에이전트 파일 생성
    local agent_file="$PROJECT_ROOT/.agent-office/agents/${agent_id}.json"
    jq -n \
      --arg id "$agent_id" \
      --arg type "$agent_type" \
      --arg basename "$AGENT_BASENAME" \
      --arg prompt "${PROMPT:0:100}" \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        agent_id: $id,
        agent_type: $type,
        agent_name: $basename,
        status: "running",
        prompt_preview: $prompt,
        started_at: $timestamp
      }' > "$agent_file" 2>/dev/null
    log "📡 Live tracking file created: $agent_file"
  fi
}

# ============================================
# Main
# ============================================

## ============================================
## Learning Retrieval (Self-Improving Agent P0)
## ============================================

inject_learnings() {
  local agent="$1"
  local prompt="$2"
  local learnings_dir="$PROJECT_ROOT/.claude/learnings"
  local output=""

  # ERRORS.md에서 같은 에이전트 타입의 과거 에러 검색 (최근 5개)
  if [[ -f "$learnings_dir/ERRORS.md" ]]; then
    local past_errors=$(grep -A2 "$agent" "$learnings_dir/ERRORS.md" 2>/dev/null | head -15)
    if [[ -n "$past_errors" ]]; then
      output="${output}
🧠 [Self-Improve] 이 에이전트($agent)의 과거 에러:
$past_errors
"
    fi
  fi

  # LEARNINGS.md에서 승격된 규칙 검색 (promoted 상태만)
  if [[ -f "$learnings_dir/LEARNINGS.md" ]]; then
    local rules=$(grep -B1 -A1 "promoted\|PROMOTED\|Rule.*:" "$learnings_dir/LEARNINGS.md" 2>/dev/null | grep -v "to be filled" | head -10)
    if [[ -n "$rules" ]]; then
      output="${output}
📋 [Self-Improve] 사용자 교정에서 도출된 규칙:
$rules
"
    fi
  fi

  # 프롬프트에서 키워드 추출 → ERRORS.md에서 관련 에러 검색
  if [[ -n "$prompt" ]] && [[ -f "$learnings_dir/ERRORS.md" ]]; then
    # 프롬프트 첫 줄에서 핵심 키워드 추출 (파일명, 컴포넌트명 등)
    local keywords=$(echo "$prompt" | head -1 | grep -oE '[A-Z][a-z]+[A-Z][a-zA-Z]*|[a-z]+-[a-z]+|\.tsx?|\.py' | head -3 | tr '\n' '|' | sed 's/|$//')
    if [[ -n "$keywords" ]]; then
      local related=$(grep -iE "$keywords" "$learnings_dir/ERRORS.md" 2>/dev/null | head -5)
      if [[ -n "$related" ]]; then
        output="${output}
⚠️  [Self-Improve] 관련 키워드($keywords) 과거 에러:
$related
"
      fi
    fi
  fi

  if [[ -n "$output" ]]; then
    echo "$output" >&2
    log "🧠 Learning retrieval injected for: $agent"
  fi
}

main() {
  log "=== SubagentStart Hook Started ==="
  log "Agent: $AGENT_BASENAME, ID: $AGENT_ID"

  # 1. 동적 컨텍스트 주입
  inject_context "$AGENT_BASENAME"

  # 2. 학습 자동 주입 (Self-Improving Agent)
  inject_learnings "$AGENT_BASENAME" "$PROMPT"

  # 3. Agent 실행 로그
  log_agent_start "$AGENT_ID" "$AGENT_TYPE"

  log "=== SubagentStart Hook Completed ==="
}

# Graceful error handling
trap 'log "Error occurred, continuing anyway"; exit 0' ERR

main
