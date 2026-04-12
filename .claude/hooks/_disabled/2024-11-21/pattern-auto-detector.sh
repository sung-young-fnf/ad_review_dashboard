#!/bin/bash
# .claude/hooks/post/pattern-auto-detector.sh
# Bash-only Pattern Detection: Git history 기반 반복 패턴 감지
# MANDATORY: Bash only (CLAUDE.md Hook Development Rules 준수)

set -e
trap 'exit 0' ERR

# Debug logging
log_debug() {
    echo "[pattern-detector $(date +%H:%M:%S)] $1" >&2
}

log_debug "Hook started"

# Read stdin (event_info)
if [ ! -t 0 ]; then
    event_info=$(cat 2>/dev/null || echo "")
else
    event_info=""
fi

# Extract agent type
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"
log_debug "AGENT_TYPE: $AGENT_TYPE"

# Only run for code-writer Agent
if [[ "$AGENT_TYPE" != *"code-writer"* ]]; then
    log_debug "Skipped: Not code-writer Agent"
    exit 0
fi

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# ============================================================================
# Step 1: Git History 분석 (최근 20개 커밋)
# ============================================================================

log_debug "Analyzing Git history..."

# 최근 20개 커밋에서 수정된 파일 목록 (중복 포함)
MODIFIED_FILES=$(git log -20 --name-only --pretty=format: 2>/dev/null | grep -v '^$' | sort || echo "")

if [ -z "$MODIFIED_FILES" ]; then
    log_debug "No Git history found"
    exit 0
fi

# ============================================================================
# Step 2: 반복 수정 파일 감지 (3회 이상)
# ============================================================================

log_debug "Detecting repeated modifications..."

# 파일별 수정 횟수 카운트 (uniq -c)
REPEATED_FILES=$(echo "$MODIFIED_FILES" | uniq -c | sort -rn | awk '$1 >= 3 {print $1, $2}' || echo "")

if [ -z "$REPEATED_FILES" ]; then
    log_debug "No repeated patterns detected"
    exit 0
fi

# ============================================================================
# Step 3: 패턴 가능성 분석 (코드 파일만)
# ============================================================================

PATTERN_CANDIDATES=""
CANDIDATE_COUNT=0

while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    file=$(echo "$line" | awk '{print $2}')

    # 코드 파일만 (문서 제외)
    if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]] && [[ ! "$file" =~ /docs/ ]]; then
        # ASCII 출력 (UTF-8 문제 회피)
        PATTERN_CANDIDATES="${PATTERN_CANDIDATES}
  - ${file} (${count}회 수정)"
        CANDIDATE_COUNT=$((CANDIDATE_COUNT + 1))
    fi
done <<< "$REPEATED_FILES"

if [ $CANDIDATE_COUNT -eq 0 ]; then
    log_debug "No code file patterns detected"
    exit 0
fi

# ============================================================================
# Step 4: 패턴 문서화 제안 출력
# ============================================================================

cat <<EOF

╔═══════════════════════════════════════════════════════════════════════════╗
║              🎯 PATTERN LEARNING (자동 감지)                              ║
╚═══════════════════════════════════════════════════════════════════════════╝

📊 반복 수정 패턴 감지:

최근 20개 커밋에서 ${CANDIDATE_COUNT}개 파일이 3회 이상 수정되었습니다:
${PATTERN_CANDIDATES}

💡 권장 사항:

1. **패턴 문서화** (재사용 가능한 패턴 발견 시):
   /pattern-documenter:analyze-with-confidence

2. **수동 확인** (복잡한 패턴):
   - 각 파일의 수정 내역 확인 (git log --follow)
   - 공통 패턴 추출 (예: API 인증, 에러 처리)
   - docs/patterns/custom/ 에 문서화

3. **Hot Spot 주의** (8회 이상 수정):
   - 코드 품질 저하 가능성
   - 리팩토링 고려 (복잡도 감소)

───────────────────────────────────────────────────────────────────────────

⚠️ 참고:
  - 이것은 자동 제안일 뿐, 강제 아님
  - 진짜 패턴인지 수동 확인 필요
  - 단순 버그 수정 반복은 패턴이 아닐 수 있음

EOF

log_debug "Pattern detection completed ($CANDIDATE_COUNT candidates)"
exit 0
