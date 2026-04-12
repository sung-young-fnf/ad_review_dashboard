#!/bin/bash
# .claude/hooks/post/code-writer-impact-analyzer.sh
# code-writer 완료 후 수정된 파일들의 영향 범위 자동 분석
#
# 목적: 공유 컴포넌트 수정 시 영향받는 다른 페이지/컴포넌트 식별
# 트리거: SubagentStop (code-writer만)

# Graceful Degradation (에러 시 조용히 종료)
trap 'exit 0' ERR

# ===== 설정 =====
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FRONTEND_SRC="$REPO_ROOT/apps/frontend/src"
LOG_FILE="/tmp/claude-impact-analysis.log"
TEMP_DIR="/tmp/claude-impact-$$"
MAX_USAGES_DISPLAY=15
HIGH_IMPACT_THRESHOLD=5
CRITICAL_IMPACT_THRESHOLD=10

# 임시 디렉토리 생성
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"; exit 0' EXIT

# ===== 유틸리티 함수 =====
log() {
  echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# ===== Step 0: stdin에서 event 정보 읽기 =====
event_info=$(cat)

# Agent 타입 확인 (code-writer만 처리)
AGENT_TYPE=$(echo "$event_info" | jq -r '.agent_type // empty' 2>/dev/null)
AGENT_TYPE="${AGENT_TYPE:-${CLAUDE_AGENT_TYPE:-unknown}}"

# code-writer가 아니면 스킵
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
  log "Skipped: Agent type is $AGENT_TYPE (not code-writer)"
  exit 0
fi

# ===== Step 1: 변경된 파일 목록 수집 =====
# git diff로 수정된 파일 + 새 파일 확인
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | head -10 || echo "")

ALL_CHANGED_FILES=$(echo -e "$MODIFIED_FILES\n$STAGED_FILES\n$UNTRACKED_FILES" | \
                    grep -E '\.(tsx?|jsx?)$' | \
                    grep -v 'node_modules' | \
                    sort -u)

if [[ -z "$ALL_CHANGED_FILES" ]]; then
  log "No TypeScript/React files changed"
  exit 0
fi

log "Changed files: $(echo "$ALL_CHANGED_FILES" | wc -l | tr -d ' ')"

# ===== Step 2: 각 파일의 영향도 분석 =====
TOTAL_IMPACT_COUNT=0
COMPONENT_COUNT=0
RESULTS_FILE="$TEMP_DIR/results.txt"
HIGH_IMPACT_FILE="$TEMP_DIR/high_impact.txt"
touch "$RESULTS_FILE" "$HIGH_IMPACT_FILE"

# 각 변경 파일 분석 (함수 대신 인라인으로 처리)
while IFS= read -r FILE_PATH; do
  [[ -z "$FILE_PATH" ]] && continue

  FILE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')

  # 파일이 컴포넌트인지 확인 (대문자 시작 또는 use 접두사)
  if [[ ! "$FILE_NAME" =~ ^[A-Z] ]] && [[ ! "$FILE_NAME" =~ ^use ]]; then
    continue
  fi

  # 해당 파일/컴포넌트를 사용하는 곳 검색
  USAGES_FILE="$TEMP_DIR/${FILE_NAME}_usages.txt"
  grep -rn --include="*.tsx" --include="*.ts" \
       -E "(import.*['\"].*${FILE_NAME}['\"]|import.*${FILE_NAME}|from.*${FILE_NAME}|<${FILE_NAME})" \
       "$FRONTEND_SRC" 2>/dev/null | \
       grep -v "node_modules" | \
       grep -v "$FILE_PATH" | \
       head -$MAX_USAGES_DISPLAY > "$USAGES_FILE" || true

  if [[ -s "$USAGES_FILE" ]]; then
    USAGE_COUNT=$(wc -l < "$USAGES_FILE" | tr -d ' ')
    TOTAL_IMPACT_COUNT=$((TOTAL_IMPACT_COUNT + USAGE_COUNT))
    COMPONENT_COUNT=$((COMPONENT_COUNT + 1))

    # 결과 저장 (파일 기반)
    echo "$FILE_NAME|$USAGE_COUNT" >> "$RESULTS_FILE"

    if [[ $USAGE_COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
      echo "$FILE_NAME:$USAGE_COUNT" >> "$HIGH_IMPACT_FILE"
    fi
  fi
done <<< "$ALL_CHANGED_FILES"

# ===== Step 3: 결과 출력 =====
if [[ ! -s "$RESULTS_FILE" ]]; then
  log "No shared components modified"
  exit 0
fi

# 헤더 출력
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 POST-IMPLEMENTATION IMPACT ANALYSIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 심각도 판단
if [[ $TOTAL_IMPACT_COUNT -ge $CRITICAL_IMPACT_THRESHOLD ]]; then
  echo "⚠️  CRITICAL: 총 ${TOTAL_IMPACT_COUNT}개 파일이 영향받을 수 있습니다!"
  echo ""
elif [[ $TOTAL_IMPACT_COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
  echo "⚠️  HIGH: 총 ${TOTAL_IMPACT_COUNT}개 파일이 영향받을 수 있습니다"
  echo ""
else
  echo "ℹ️  총 ${TOTAL_IMPACT_COUNT}개 파일이 영향받을 수 있습니다"
  echo ""
fi

# 각 컴포넌트별 영향도 표시
while IFS='|' read -r COMPONENT COUNT; do
  [[ -z "$COMPONENT" ]] && continue

  # 위험도 아이콘 선택
  if [[ $COUNT -ge $CRITICAL_IMPACT_THRESHOLD ]]; then
    ICON="🔴"
    RISK="CRITICAL"
  elif [[ $COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
    ICON="🟠"
    RISK="HIGH"
  else
    ICON="🟡"
    RISK="MEDIUM"
  fi

  echo "$ICON $COMPONENT ($COUNT곳에서 사용, $RISK)"
  echo "   영향받는 파일:"

  # 영향받는 파일 목록 (경로만 추출, 중복 제거)
  USAGES_FILE="$TEMP_DIR/${COMPONENT}_usages.txt"
  if [[ -f "$USAGES_FILE" ]]; then
    cut -d':' -f1 "$USAGES_FILE" | sort -u | head -8 | while read -r usage_file; do
      # 상대 경로로 변환
      REL_PATH=$(echo "$usage_file" | sed "s|$FRONTEND_SRC/||")
      echo "   - $REL_PATH"
    done

    # 더 많은 파일이 있으면 표시
    TOTAL_UNIQUE=$(cut -d':' -f1 "$USAGES_FILE" | sort -u | wc -l | tr -d ' ')
    if [[ $TOTAL_UNIQUE -gt 8 ]]; then
      echo "   ... 외 $((TOTAL_UNIQUE - 8))개 파일"
    fi
  fi
  echo ""
done < "$RESULTS_FILE"

# 권장 조치
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 권장 조치:"

if [[ $TOTAL_IMPACT_COUNT -ge $CRITICAL_IMPACT_THRESHOLD ]]; then
  echo "   1. 🔴 모든 영향받는 페이지 UI 테스트 필수"
  echo "   2. 🔴 QA 팀 리뷰 권장"
  echo "   3. 🔴 단계적 배포(Staged Rollout) 고려"
elif [[ $TOTAL_IMPACT_COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
  echo "   1. 🟠 영향받는 주요 페이지 테스트 필요"
  echo "   2. 🟠 관련 기능 회귀 테스트 권장"
else
  echo "   1. 🟡 영향받는 파일 간단히 확인"
  echo "   2. 🟡 주요 사용처 동작 테스트"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 로그 기록
log "Impact analysis complete: $COMPONENT_COUNT components, $TOTAL_IMPACT_COUNT total usages"

exit 0
