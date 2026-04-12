#!/bin/bash
# .claude/hooks/pre/pre-tool-use-agent-chain-guard.sh
# Phase 2: Agent 체인 중단 방지 (조건부 차단)
#
# Purpose: Write/Edit 직접 사용 시 Agent 체인 확인 및 조건부 차단
# Trigger: Write, Edit, MultiEdit 호출 전
# Strategy: Option 3 (조건부 차단)
#
# 차단 조건 (모두 충족 시 exit 1):
#   1. Agent 체인 활성 (agent-chain-state.json 존재)
#   2. 마지막 Agent 완료 10분 이내 (최근 작업)
#   3. 코드 파일 (.ts, .tsx, .js, .jsx)
#
# 경고만 (exit 0):
#   - 체인 비활성 (state.json 없음)
#   - 10분 경과 (긴급 상황 간주)
#   - 설정 파일 (.json, .config.js, .env 등)
#   - Markdown 파일 (.md)

set -e
trap 'exit 0' ERR

# ============================================================================
# Configuration
# ============================================================================

# 체인 활성 시간 임계값 (초)
CHAIN_TIMEOUT=600  # 10분

# 차단 대상 파일 확장자 (코드 파일만)
CODE_EXTENSIONS="\.(ts|tsx|js|jsx)$"

# 제외 대상 파일 패턴
EXCLUDE_PATTERNS=(
  "\\.md$"                    # Markdown
  "\\.markdown$"              # Markdown
  "\\.json$"                  # JSON 설정
  "\\.ya?ml$"                 # YAML 설정
  "\\.env"                    # 환경 변수
  "config\\.(js|ts)"          # Config 파일
  "\\.(sh|bash)$"             # Shell 스크립트
)

# ============================================================================
# Input Processing
# ============================================================================

# stdin에서 tool_info 읽기
tool_info=$(cat)

# 필수 정보 추출
tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
session_id=$(echo "$tool_info" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")

# ============================================================================
# Early Exit Conditions
# ============================================================================

# Write/Edit/MultiEdit 도구만 체크
if [[ ! "$tool_name" =~ ^(Write|Edit|MultiEdit)$ ]]; then
  exit 0
fi

# 파일 경로 없으면 스킵
if [[ -z "$file_path" ]]; then
  exit 0
fi

# 제외 패턴 확인
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  if [[ "$file_path" =~ $pattern ]]; then
    # 제외 대상 파일 → 경고 없이 통과
    exit 0
  fi
done

# ============================================================================
# Agent Chain State Check
# ============================================================================

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CHAIN_STATE_DIR="$REPO_ROOT/.claude/hooks-cache/${session_id}"
CHAIN_STATE="$CHAIN_STATE_DIR/agent-chain-state.json"

# 체인 상태 파일 없으면 → 체인 비활성 (통과)
if [[ ! -f "$CHAIN_STATE" ]]; then
  exit 0
fi

# jq 필수
if ! command -v jq &> /dev/null; then
  # jq 없으면 검증 불가 → 조용히 통과
  exit 0
fi

# 체인 상태 로드
LAST_AGENT=$(jq -r '.last_completed_agent // "none"' "$CHAIN_STATE" 2>/dev/null || echo "none")
LAST_TASK=$(jq -r '.last_task // ""' "$CHAIN_STATE" 2>/dev/null || echo "")
LAST_TIMESTAMP=$(jq -r '.timestamp // 0' "$CHAIN_STATE" 2>/dev/null || echo "0")

# 체인 비활성 (last_agent = none) → 통과
if [[ "$LAST_AGENT" == "none" ]]; then
  exit 0
fi

# ============================================================================
# Timeout Check (10분 경과 시 긴급 상황 간주)
# ============================================================================

CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_TIMESTAMP))

if [[ $TIME_DIFF -ge $CHAIN_TIMEOUT ]]; then
  # 10분 경과 → 긴급 상황 간주 (통과)
  exit 0
fi

# ============================================================================
# File Type Check (코드 파일만 차단)
# ============================================================================

# 코드 파일이 아니면 → 경고만
if [[ ! "$file_path" =~ $CODE_EXTENSIONS ]]; then
  # 설정 파일 등 → 경고 표시
  cat <<EOF >&2

⚠️ Agent 체인 외부 직접 구현 감지
파일: $file_path
마지막 Agent: $LAST_AGENT ($LAST_TASK)
경과 시간: $((TIME_DIFF / 60))분 전

💡 권장: code-writer Agent 호출 (CLAUDE.md 규칙)
   하지만 설정 파일이므로 직접 수정 허용

EOF
  exit 0
fi

# ============================================================================
# Conditional Block (조건부 차단)
# ============================================================================

# 모든 조건 충족:
#   1. ✅ 체인 활성 (CHAIN_STATE 존재)
#   2. ✅ 10분 이내 (TIME_DIFF < 600)
#   3. ✅ 코드 파일 (.ts/.tsx/.js/.jsx)
#
# → 차단!

cat <<EOF >&2

╔═══════════════════════════════════════════════════════════════════════════╗
║              ⛔ AGENT CHAIN INTERRUPTION BLOCKED (Phase 2)                ║
╚═══════════════════════════════════════════════════════════════════════════╝

Violation: Direct $tool_name call outside code-writer Agent
File: $file_path
Session: $session_id

Agent 체인 활성 상태:
  - 마지막 Agent: $LAST_AGENT
  - 마지막 Task: $LAST_TASK
  - 경과 시간: $((TIME_DIFF / 60))분 전

⚠️ CLAUDE.md 규칙 위반:
  "Agent 체인 실행 중 절대 직접 구현 금지"
  "모든 Task는 code-writer Agent 호출 필수"

Required Action:
  1. 현재 $tool_name 작업 중단
  2. Task tool로 code-writer Agent 호출
  3. Agent가 구현 완료할 때까지 대기

Example:
  Task(
    subagent_type: "04-implementation/code-writer",
    prompt: "파일 수정 구현",
    description: "$(basename "$file_path") 수정"
  )

💡 긴급 상황 (Hotfix):
  10분 경과 시 자동 허용됩니다. 긴급하다면 10분 후 다시 시도하거나,
  체인 상태 파일을 삭제하세요:
    rm -f "$CHAIN_STATE"

═══════════════════════════════════════════════════════════════════════════

EOF

# 차단 (exit 1)
exit 1
