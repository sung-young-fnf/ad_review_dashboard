#!/bin/bash
# .claude/hooks/post/trajectory-warning.sh
# PostToolUse — 사용자 프롬프트 시 과거 실패율 높은 영역 경고
# ERRORS.md에서 최근 30일 에러 키워드 빈도를 분석하고
# 현재 사용자 입력과 매칭되면 주의 경고 출력
#
# 트리거: Notification (SessionStart) 또는 UserPromptSubmit
# Version: 1.0

trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ERRORS_FILE="$REPO_ROOT/.claude/learnings/ERRORS.md"

# ERRORS.md가 없으면 스킵
if [ ! -f "$ERRORS_FILE" ]; then
  exit 0
fi

# stdin에서 이벤트 읽기 (기존 Hook 패턴과 통일)
INPUT=$(cat 2>/dev/null || echo "")

# 사용자 메시지 추출 (jq가 있으면 JSON 파싱, 없으면 전체 input 사용)
USER_MSG=""
if command -v jq &>/dev/null && [ -n "$INPUT" ]; then
  USER_MSG=$(echo "$INPUT" | jq -r '.user_message // .message // .query // ""' 2>/dev/null || echo "")
fi

# 사용자 메시지가 없으면 스킵
if [ -z "$USER_MSG" ]; then
  exit 0
fi

# 30일 전 날짜 계산
if date -v-30d &>/dev/null 2>&1; then
  # macOS
  CUTOFF_DATE=$(date -v-30d -u +"%Y-%m-%d")
else
  # Linux
  CUTOFF_DATE=$(date -u -d "30 days ago" +"%Y-%m-%d" 2>/dev/null || date -u +"%Y-%m-%d")
fi

# 고위험 키워드 목록 + 이 영역의 에러 건수를 카운트
# 키워드: domain/기술 영역별 분류
declare -A KEYWORD_COUNT
KEYWORDS="OAuth SSE Prisma Migration Sandbox Soul token auth MCP WebSocket streaming schedule cron artifact workspace"

for KW in $KEYWORDS; do
  # ERRORS.md에서 날짜가 CUTOFF 이후인 항목 중 해당 키워드 포함 건수
  COUNT=$(grep -i "$KW" "$ERRORS_FILE" 2>/dev/null | awk -v cutoff="$CUTOFF_DATE" '/^\[[0-9]{4}-[0-9]{2}-[0-9]{2}/ { d=substr($1,2,10); if(d>=cutoff) found++ } END { print found+0 }' 2>/dev/null || echo "0")
  if [ "$COUNT" -gt 0 ]; then
    KEYWORD_COUNT["$KW"]=$COUNT
  fi
done

# Top 3 고위험 키워드 추출 (빈도순)
TOP_KEYWORDS=""
TOP_COUNT=0
for KW in "${!KEYWORD_COUNT[@]}"; do
  C=${KEYWORD_COUNT[$KW]}
  TOP_KEYWORDS="${TOP_KEYWORDS}${C} ${KW}\n"
done

if [ -z "$TOP_KEYWORDS" ]; then
  exit 0
fi

# 정렬하여 상위 3개 추출
TOP3=$(echo -e "$TOP_KEYWORDS" | sort -rn | head -3)

if [ -z "$TOP3" ]; then
  exit 0
fi

# 사용자 메시지와 Top3 키워드 매칭
MATCHED=""
while IFS= read -r LINE; do
  CNT=$(echo "$LINE" | awk '{print $1}')
  KW=$(echo "$LINE" | awk '{print $2}')
  if [ -z "$KW" ]; then
    continue
  fi
  if echo "$USER_MSG" | grep -qi "$KW"; then
    MATCHED="${MATCHED}  - ${KW}: 최근 30일간 ${CNT}건 실패\n"
  fi
done <<< "$TOP3"

# 매칭된 키워드가 없으면 스킵
if [ -z "$MATCHED" ]; then
  exit 0
fi

# 경고 출력
echo "" >&2
echo "======================================================" >&2
echo "  [Trajectory Warning] 과거 실패율 높은 영역" >&2
echo "======================================================" >&2
echo -e "$MATCHED" >&2
echo "  historian/get_error_solutions 먼저 호출을 권장합니다." >&2
echo "======================================================" >&2
echo "" >&2

exit 0
