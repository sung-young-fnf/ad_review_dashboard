#!/bin/bash
# .claude/hooks/post/pattern-compliance-checker.sh
# Defense Line 4 보조: 패턴 준수 Runtime 검증

set -e
trap 'exit 0' ERR

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
DOCS_EPICS="$REPO_ROOT/docs/epics"

# Step 0: stdin에서 event_info 받기 (Empty Input Safety)
event_info=$(cat)
if [ -z "$event_info" ]; then
  exit 0  # Silent skip
fi

SESSION_ID=$(echo "$event_info" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")

# Step 1: Agent 정보 수집 (환경 변수)
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-unknown}"
AGENT_TASK="${CLAUDE_TASK_ID:-}"
AGENT_EPIC="${CLAUDE_EPIC_ID:-}"
AGENT_STORY="${CLAUDE_STORY_ID:-}"

# Step 2: code-writer Agent만 검증
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
  exit 0  # Skip (다른 Agent)
fi

# Step 3: Task 파일 경로 결정
TASK_FILE=""
if [ -n "$AGENT_EPIC" ]; then
  TASK_FILE=$(find "$DOCS_EPICS/$AGENT_EPIC/tasks" -name "${AGENT_TASK}*.md" 2>/dev/null | head -1)
else
  TASK_FILE=$(find "$DOCS_EPICS/_backlog" -name "${AGENT_TASK}_*.md" -o -name "${AGENT_TASK}.md" 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
  exit 0  # Task 파일 없음
fi

echo "🔍 Defense Line 4: 패턴 준수 Runtime 검증 시작"
echo "   Task: $AGENT_TASK"
echo "   File: $(basename "$TASK_FILE")"

# Step 4: 패턴 체크리스트 확인
if ! grep -q "## 필수 패턴 준수 \[MANDATORY\]" "$TASK_FILE"; then
  exit 0  # 패턴 체크리스트 없음 (Defense Line 3에서 확인)
fi

# Step 5: 미체크 항목 추출
UNCHECKED_ITEMS=$(sed -n '/## 필수 패턴 준수 \[MANDATORY\]/,/^## /p' "$TASK_FILE" | grep -E "^\- \[ \]" || echo "")

if [ -z "$UNCHECKED_ITEMS" ]; then
  echo "✅ DEFENSE LINE 4 PASSED (모든 체크리스트 완료)"
  exit 0
fi

# Step 6: Git diff로 수정 파일 추출
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")

if [ -z "$MODIFIED_FILES" ]; then
  echo "⚠️ 수정된 파일 없음, 검증 스킵"
  exit 0
fi

echo "📝 수정된 파일: $(echo "$MODIFIED_FILES" | wc -l | tr -d ' ')개"

# Step 7: 패턴 위반 검증 (간단한 키워드 매칭)
VIOLATIONS=""

# API Routes 패턴
if echo "$UNCHECKED_ITEMS" | grep -q "GET 메서드 구현"; then
  if ! echo "$MODIFIED_FILES" | xargs -I {} grep -l "export async function GET" {} 2>/dev/null | grep -q "route.ts"; then
    VIOLATIONS="${VIOLATIONS}\n- GET 메서드 누락 (route.ts)"
  fi
fi

if echo "$UNCHECKED_ITEMS" | grep -q "POST 메서드 구현"; then
  if ! echo "$MODIFIED_FILES" | xargs -I {} grep -l "export async function POST" {} 2>/dev/null | grep -q "route.ts"; then
    VIOLATIONS="${VIOLATIONS}\n- POST 메서드 누락 (route.ts)"
  fi
fi

# Admin Impersonation 패턴
if echo "$UNCHECKED_ITEMS" | grep -q "session.backendToken"; then
  if ! echo "$MODIFIED_FILES" | xargs grep -l "session.backendToken" 2>/dev/null >/dev/null; then
    VIOLATIONS="${VIOLATIONS}\n- session.backendToken 누락"
  fi
fi

# Step 8: 위반 결과 출력
if [ -n "$VIOLATIONS" ]; then
  echo "❌ DEFENSE LINE 4 FAILURE"
  echo "   패턴 위반 감지:"
  echo -e "$VIOLATIONS"
  echo ""
  echo "   → Task 파일 체크리스트 확인 필요"
  echo "   → 미구현 항목을 완료하세요"
  exit 0  # Graceful degradation
fi

# Step 9: 검증 성공
echo "✅ DEFENSE LINE 4 PASSED"
echo "   패턴 준수 검증 완료"
echo "   미체크 항목: $(echo "$UNCHECKED_ITEMS" | wc -l | tr -d ' ')개"

exit 0
