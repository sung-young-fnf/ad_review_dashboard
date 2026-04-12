#!/bin/bash
# .claude/hooks/pre/user-correction-detector.sh
# UserPromptSubmit — 사용자 교정/불만 감지 시 LEARNINGS.md 자동 기록
# Version: 1.0

trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEARNINGS_FILE="$REPO_ROOT/.claude/learnings/LEARNINGS.md"

if [[ ! -f "$LEARNINGS_FILE" ]]; then
  exit 0
fi

# stdin에서 사용자 프롬프트 읽기
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
else
  exit 0
fi

USER_PROMPT=$(echo "$event_info" | jq -r '.prompt // empty' 2>/dev/null || echo "")
if [[ -z "$USER_PROMPT" ]]; then
  exit 0
fi

# 첫 2줄만 분석 (로그 붙여넣기 오탐 방지)
FIRST_LINES=$(echo "$USER_PROMPT" | head -2)

# 교정 키워드 감지
# "워크플로우 확인" 은 롤백 트리거이므로 여기선 제외
CORRECTION_DETECTED=false
CATEGORY=""

# === False Positive 필터링 (Insights P1 — 버그 리포트/긍정 피드백 제외) ===
# 1. 긍정 피드백 제외
if echo "$FIRST_LINES" | grep -qiE "^(좋아|잘된다|잘 된다|잘됐|완료|고마워|감사|맞어|맞아|ㅇㅇ|ㄱㄱ|go$|ok$|확인$)"; then
  exit 0
fi
# 2. 버그 리포트/조사 요청 제외 ("오류 확인해줘" = 진단 요청, 교정 아님)
if echo "$FIRST_LINES" | grep -qiE "(오류|에러|버그).*(확인|해결|봐봐|봐줘|해줘|검토|진단|원인)"; then
  exit 0
fi
# 3. 질문형 제외 ("~하겠죠?", "~인가요?")
if echo "$FIRST_LINES" | grep -qiE "(겠죠|인가요|인건지|인지$|할까요)[\?？]?$"; then
  exit 0
fi
# 4. URL/로그 붙여넣기 제외
if echo "$FIRST_LINES" | grep -qiE "^(https?://|{|\[|[0-9]{4}-[0-9]{2})"; then
  exit 0
fi
# 5. dev 서버 자동 출력 제외 (auto-promoted 규칙)
if echo "$FIRST_LINES" | grep -qiE "\[Fast Refresh\]|\[HMR\]|compiled.*successfully|webpack"; then
  exit 0
fi

if echo "$FIRST_LINES" | grep -qiE "잘못|틀렸|아닌데|아니야.*아니|그게 아니라|다시 해|왜 (이렇게|그렇게|저렇게)|엉뚱한|실수|버그.*만들|되돌려"; then
  CORRECTION_DETECTED=true
  CATEGORY="user_correction"
fi

if echo "$FIRST_LINES" | grep -qiE "하지 말라|하지마|금지|절대|안 된다고|규칙.*위반|따르라고|했잖아"; then
  CORRECTION_DETECTED=true
  CATEGORY="rule_violation"
fi

if echo "$FIRST_LINES" | grep -qiE "너무 (많이|복잡|느리|과하)|불필요|과도|오버"; then
  CORRECTION_DETECTED=true
  CATEGORY="over_engineering"
fi

if [[ "$CORRECTION_DETECTED" == "false" ]]; then
  exit 0
fi

# LEARNINGS.md에 구조화된 스키마로 기록
NOW=$(date +"%Y-%m-%d %H:%M")
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
USER_EXCERPT=$(echo "$FIRST_LINES" | head -1 | cut -c1-100)

# 동일 패턴 반복 횟수 카운트 (카테고리 기준)
EXISTING_COUNT=$(grep -c "## \[.*\] $CATEGORY" "$LEARNINGS_FILE" 2>/dev/null || echo "0")
NEW_COUNT=$((EXISTING_COUNT + 1))

# 반복 횟수 기반 confidence
CONFIDENCE="low"
if [[ "$NEW_COUNT" -ge 3 ]]; then
  CONFIDENCE="high"
elif [[ "$NEW_COUNT" -ge 2 ]]; then
  CONFIDENCE="medium"
fi

# 헤더 라인 수 계산 (--- 구분자까지)
HEADER_END=$(grep -n "^---$" "$LEARNINGS_FILE" | head -1 | cut -d: -f1)
HEADER_END=${HEADER_END:-17}

temp_file=$(mktemp)
{
  head -n "$HEADER_END" "$LEARNINGS_FILE"
  echo ""
  echo "## [$NOW] $CATEGORY"
  echo "- **Trigger**: \"$USER_EXCERPT\""
  echo "- **Wrong action**: (to be analyzed by agent)"
  echo "- **Correct action**: (to be analyzed by agent)"
  echo "- **Scope**: (to be analyzed by agent)"
  echo "- **Rule**: (to be filled by agent after analysis)"
  echo "- **Confidence**: $CONFIDENCE"
  echo "- **Count**: $NEW_COUNT"
  echo "- **Promoted**: none"
  echo "- **Related commit**: $COMMIT_HASH"
  echo ""
  tail -n +"$((HEADER_END + 1))" "$LEARNINGS_FILE"
} > "$temp_file"
mv "$temp_file" "$LEARNINGS_FILE"

# systemMessage로 에이전트에게 학습 알림 + 즉시 분석 강제 요청
ANALYSIS_MSG="Self-Improve: 교정 감지 → LEARNINGS.md 기록됨 ($CATEGORY, count=$NEW_COUNT)"
if [[ "$NEW_COUNT" -ge 3 ]]; then
  ANALYSIS_MSG="$ANALYSIS_MSG ⚠️ 반복 3회+ — Rule Promotion 검토 필요!"
fi

# stderr로 에이전트에게 즉시 분석 지시 (강제)
cat << FILL_EOF >&2

🔴 [Self-Improve] MANDATORY: 교정 감지됨 ($CATEGORY, count=$NEW_COUNT)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
사용자 교정: "$USER_EXCERPT"

지금 즉시 다음을 수행하세요:
1. LEARNINGS.md의 최신 항목에서 "(to be analyzed by agent)" 플레이스홀더를 채우세요
2. Wrong action: 에이전트가 실제로 한 행동
3. Correct action: 사용자가 원한 행동
4. Scope: 영향 범위
5. Rule: 재발 방지 규칙 (1문장)

파일: $LEARNINGS_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FILL_EOF

cat << EOF
{
  "outputToUser": "$ANALYSIS_MSG"
}
EOF

exit 0
