#!/bin/bash
# .claude/hooks/post/post-compact-context-restore.sh
# PostCompact Hook: Compaction 후 핵심 컨텍스트 복원 힌트 제공
# Version: 1.0

set +e
trap 'exit 0' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_FILE="$PROJECT_DIR/.claude/hooks/compact.log"

# 로그 기록
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PostCompact triggered" >> "$LOG_FILE" 2>/dev/null || true

# 활성 Epic 감지
ACTIVE_EPIC=""
if [ -f "$PROJECT_DIR/docs/PROGRESS.md" ]; then
  ACTIVE_EPIC=$(grep -m1 '진행 중\|🔄\|in.progress' "$PROJECT_DIR/docs/PROGRESS.md" 2>/dev/null | head -1 || echo "")
fi

# systemMessage로 컨텍스트 힌트 출력
HINT="Compaction 완료. 핵심 컨텍스트 재확인 권장: CLAUDE.md 규칙, 활성 Task AC"
if [ -n "$ACTIVE_EPIC" ]; then
  HINT="$HINT | 활성 Epic: $ACTIVE_EPIC"
fi

cat <<EOF
{"systemMessage":"$HINT"}
EOF
