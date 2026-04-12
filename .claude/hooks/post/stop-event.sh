#!/bin/bash
# .claude/hooks/post/stop-event.sh
# Reddit Stop Event 패턴 - code-writer 완료 후 품질 검증 트리거

# set -e (disabled for Graceful Degradation)
trap 'exit 0' ERR

# Read stdin (required by Claude Code)
event_info=$(cat)

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QUALITY_GATE="$REPO_ROOT/.claude/hooks/utils/quality-gate.sh"

# 성능 추적 유틸리티 로드
UTILS_DIR="$REPO_ROOT/.claude/hooks/utils"
if [[ -f "$UTILS_DIR/hook-performance-tracker.sh" ]]; then
  source "$UTILS_DIR/hook-performance-tracker.sh"
  start_timer
  PERFORMANCE_TRACKING_ENABLED=true
else
  PERFORMANCE_TRACKING_ENABLED=false
fi

# Step 1: Agent 타입 및 메타데이터 확인
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
AGENT_ID="${CLAUDE_AGENT_ID:-}"
AGENT_TRANSCRIPT="${CLAUDE_AGENT_TRANSCRIPT_PATH:-}"

# Agent 완료 로그 자동 기록 (2.0.42+)
if [[ -n "$AGENT_ID" ]] && [[ -n "$AGENT_TRANSCRIPT" ]]; then
  echo "📋 Agent 완료: $AGENT_ID"
  echo "   Transcript: $AGENT_TRANSCRIPT"

  # 핵심 Agent 완료 시 PROGRESS.md 자동 업데이트 트리거
  if [[ "$AGENT_ID" =~ (code-writer|task-planner|story-creator|epic-creator) ]]; then
    echo "💡 자동 진행률 업데이트 권장 (progress-updater Agent)"
  fi
fi

# code-writer 완료 시에만 품질 검증 실행
if [[ "$AGENT_TYPE" != "code-writer" ]]; then
  exit 0
fi

# Step 2: 변경된 파일 타입 확인
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
CODE_FILES=$(echo "$MODIFIED_FILES" | grep -E '\.(tsx?|jsx?)$' || true)

if [ -z "$CODE_FILES" ]; then
  echo "✅ 코드 파일 변경 없음. 품질 검증 스킵."
  exit 0
fi

# Step 3: Quality Gate 실행
if [ -x "$QUALITY_GATE" ]; then
  echo "🔍 Quality Gate 실행 중..."
  "$QUALITY_GATE"
else
  echo "💡 quality-gate.sh 없음. T003 먼저 완료하세요."
fi

# 성능 로그 업데이트
if [[ "$PERFORMANCE_TRACKING_ENABLED" == "true" ]]; then
  end_timer "stop-event"
fi

# === Pattern Learning System (T001 추가) ===

echo "🧠 Starting pattern learning analysis..."

# 1. Claude Headless 실행 (60초 타임아웃)
ANALYSIS_PROMPT="Analyze this conversation for mistakes and learnings. Focus on:
- YAGNI violations (proposing non-existent features)
- Context ignored (not checking project structure)
- Forced patterns (fitting patterns unnecessarily)

Output JSON with:
{
  \"mistakes\": [\"mistake description 1\", \"mistake description 2\"],
  \"learnings\": [\"learning point 1\", \"learning point 2\"],
  \"categories\": [\"YAGNI_VIOLATION\", \"CONTEXT_IGNORED\", \"FORCED_PATTERN\"]
}"

# Transcript 파일에서 대화 내용 읽기 (있을 경우)
CONVERSATION_CONTEXT=""
if [[ -f "$AGENT_TRANSCRIPT" ]]; then
  CONVERSATION_CONTEXT=$(cat "$AGENT_TRANSCRIPT" 2>/dev/null || echo "")
fi

# Claude 분석 실행 (Graceful Degradation)
if timeout 60s claude -p "$ANALYSIS_PROMPT" --output-format json > /tmp/conversation-analysis.json 2>/dev/null; then

    # 2. JSON 파싱 (Graceful Degradation)
    MISTAKES=$(jq -r '.mistakes[]' /tmp/conversation-analysis.json 2>/dev/null || echo "")
    LEARNINGS=$(jq -r '.learnings[]' /tmp/conversation-analysis.json 2>/dev/null || echo "")
    CATEGORIES=$(jq -r '.categories[]' /tmp/conversation-analysis.json 2>/dev/null || echo "")

    # 3. 실수 표시 (ANSI 색상)
    if [[ -n "$MISTAKES" ]]; then
        echo -e "\n\033[1;31m🔍 Pattern Learning: 실수 감지됨\033[0m"
        echo "$MISTAKES" | while IFS= read -r line; do
            [[ -n "$line" ]] && echo -e "  \033[33m❌ $line\033[0m"
        done
    fi

    # 4. 학습 데이터 저장 (JSONL 형식)
    if [[ -n "$LEARNINGS" ]] || [[ -n "$MISTAKES" ]]; then
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # .claude/memory 디렉토리 확인
        mkdir -p "$REPO_ROOT/.claude/memory"

        # JSONL 저장 (Bash 배열 처리 개선)
        {
            echo "{"
            echo "  \"timestamp\": \"$TIMESTAMP\","
            echo "  \"agent_id\": \"$AGENT_ID\","
            echo "  \"mistakes\": ["
            FIRST=true
            echo "$MISTAKES" | while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if [[ "$FIRST" == "true" ]]; then
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                    FIRST=false
                else
                    echo ","
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                fi
            done
            echo ""
            echo "  ],"
            echo "  \"learnings\": ["
            FIRST=true
            echo "$LEARNINGS" | while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if [[ "$FIRST" == "true" ]]; then
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                    FIRST=false
                else
                    echo ","
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                fi
            done
            echo ""
            echo "  ],"
            echo "  \"categories\": ["
            FIRST=true
            echo "$CATEGORIES" | while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if [[ "$FIRST" == "true" ]]; then
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                    FIRST=false
                else
                    echo ","
                    echo -n "    \"$(echo "$line" | sed 's/"/\\"/g')\""
                fi
            done
            echo ""
            echo "  ]"
            echo "}"
        } >> "$REPO_ROOT/.claude/memory/pattern-learnings.jsonl" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            echo -e "\n\033[1;32m✅ 학습 데이터 저장 완료: .claude/memory/pattern-learnings.jsonl\033[0m"
        fi
    fi

    # Cleanup
    rm -f /tmp/conversation-analysis.json 2>/dev/null
else
    echo "💡 Pattern learning analysis skipped (Claude timeout or error)"
fi

# === End of Pattern Learning ===

exit 0
