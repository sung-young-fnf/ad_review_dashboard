#!/bin/bash
# Ralph Loop Enforcer - Stop Hook (Simplified)
# 완료 보증 메커니즘 - 단순화 버전

SISYPHUS_DIR="${CLAUDE_PROJECT_DIR:-.}/.sisyphus"
RALPH_FILE="$SISYPHUS_DIR/ralph.json"

# ralph.json이 없으면 통과
if [ ! -f "$RALPH_FILE" ]; then
    exit 0
fi

# active 상태 확인
ACTIVE=$(jq -r '.active // false' "$RALPH_FILE" 2>/dev/null || echo "false")

if [ "$ACTIVE" != "true" ]; then
    exit 0
fi

# 미완료 TODO 수 확인
INCOMPLETE=$(jq -r '.incomplete_count // 0' "$RALPH_FILE" 2>/dev/null || echo "0")

if [ "$INCOMPLETE" -gt 0 ]; then
    # 미완료 작업 있음 → 경고 (non-blocking)
    cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ [완료 보증] 미완료 작업 ${INCOMPLETE}개
   └─ 계속 진행하거나 /cancel-ralph로 취소
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    # non-blocking warning만 (exit 0)
    exit 0
fi

# incomplete_count == 0 → 자동 완료 처리
jq '.active = false | .completed_at = (now | todate)' "$RALPH_FILE" > "${RALPH_FILE}.tmp" 2>/dev/null || true
mv "${RALPH_FILE}.tmp" "$RALPH_FILE" 2>/dev/null || true

echo "✅ [완료 보증] 작업 완료 - 자동 비활성화됨" >&2
exit 0
