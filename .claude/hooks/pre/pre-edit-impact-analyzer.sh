#!/bin/bash
# .claude/hooks/pre/pre-edit-impact-analyzer.sh
# Edit/Write 실행 전 영향 범위 분석 (Main Agent 직접 수정 시)
#
# 목적: Main Agent가 직접 파일 수정 시에도 영향도 표시
# 트리거: PreToolUse (Edit|Write 매칭)

# Graceful Degradation
trap 'exit 0' ERR

# ===== 설정 =====
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FRONTEND_SRC="$REPO_ROOT/apps/frontend/src"
LOG_FILE="/tmp/claude-pre-edit-impact.log"
HIGH_IMPACT_THRESHOLD=5
CRITICAL_IMPACT_THRESHOLD=10

# ===== 유틸리티 함수 =====
log() {
  echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# ===== Step 0: stdin에서 tool 정보 읽기 =====
tool_info=$(cat)

# Tool 이름과 파일 경로 추출
TOOL_NAME=$(echo "$tool_info" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Edit 또는 Write가 아니면 스킵
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# 파일 경로가 없으면 스킵
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Frontend 소스가 아니면 스킵
if [[ "$FILE_PATH" != *"apps/frontend/src"* ]]; then
  exit 0
fi

# TypeScript/React 파일이 아니면 스킵
if [[ ! "$FILE_PATH" =~ \.(tsx?|jsx?)$ ]]; then
  exit 0
fi

# ===== Step 1: 파일명에서 컴포넌트명 추출 =====
FILE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')

# 컴포넌트인지 확인 (대문자 시작 또는 use 접두사)
if [[ ! "$FILE_NAME" =~ ^[A-Z] ]] && [[ ! "$FILE_NAME" =~ ^use ]]; then
  exit 0
fi

# ===== Step 2: 사용처 검색 =====
USAGES=$(grep -rn --include="*.tsx" --include="*.ts" \
     -E "(import.*['\"].*${FILE_NAME}['\"]|import.*${FILE_NAME}|from.*${FILE_NAME}|<${FILE_NAME})" \
     "$FRONTEND_SRC" 2>/dev/null | \
     grep -v "node_modules" | \
     grep -v "$FILE_PATH" | \
     head -20 || true)

if [[ -z "$USAGES" ]]; then
  exit 0
fi

USAGE_COUNT=$(echo "$USAGES" | wc -l | tr -d ' ')

# 임계값 미만이면 조용히 종료
if [[ $USAGE_COUNT -lt 3 ]]; then
  exit 0
fi

# ===== Step 3: 위험도 판단 =====
if [[ $USAGE_COUNT -ge $CRITICAL_IMPACT_THRESHOLD ]]; then
  ICON="🔴"
  RISK="CRITICAL"
elif [[ $USAGE_COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
  ICON="🟠"
  RISK="HIGH"
else
  ICON="🟡"
  RISK="MEDIUM"
fi

# ===== Step 4: 영향받는 파일 목록 생성 =====
AFFECTED_FILES=$(echo "$USAGES" | cut -d':' -f1 | sort -u | head -8 | while read -r usage_file; do
  [[ -z "$usage_file" ]] && continue
  echo "$usage_file" | sed "s|$FRONTEND_SRC/||"
done | tr '\n' ', ' | sed 's/,$//')

TOTAL_UNIQUE=$(echo "$USAGES" | cut -d':' -f1 | sort -u | wc -l | tr -d ' ')

# ===== Step 5: HIGH/CRITICAL 영향도 시 차단 (JSON 응답) =====
if [[ $USAGE_COUNT -ge $HIGH_IMPACT_THRESHOLD ]]; then
  BLOCK_MSG="$ICON HIGH IMPACT: $FILE_NAME (${USAGE_COUNT}곳에서 사용). 직접 수정 차단. code-writer 사용 필요. 영향 파일: $AFFECTED_FILES"
  if [[ $TOTAL_UNIQUE -gt 8 ]]; then
    BLOCK_MSG="$BLOCK_MSG 외 $((TOTAL_UNIQUE - 8))개"
  fi

  log "BLOCKED: $FILE_NAME ($USAGE_COUNT usages >= $HIGH_IMPACT_THRESHOLD)"

  # JSON 응답 (v2.1.0+ decision: block + additionalContext)
  cat << EOF
{
  "decision": "block",
  "reason": "$ICON HIGH IMPACT: $FILE_NAME (${USAGE_COUNT}곳에서 사용). code-writer 사용 필요.",
  "additionalContext": "$BLOCK_MSG"
}
EOF
  exit 0
fi

# ===== Step 6: MEDIUM 위험도는 경고만 (JSON 응답) =====
WARN_MSG="$ICON $FILE_NAME (${USAGE_COUNT}곳에서 사용, $RISK). 영향 파일: $AFFECTED_FILES"
if [[ $TOTAL_UNIQUE -gt 8 ]]; then
  WARN_MSG="$WARN_MSG 외 $((TOTAL_UNIQUE - 8))개"
fi

log "ALLOWED: $FILE_NAME ($USAGE_COUNT usages, $RISK)"

# JSON 응답 (v2.1.0+ decision: approve + additionalContext)
cat << EOF
{
  "decision": "approve",
  "additionalContext": "$WARN_MSG"
}
EOF
exit 0
