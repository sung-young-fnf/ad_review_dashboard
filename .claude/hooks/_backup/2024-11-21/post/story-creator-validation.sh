#!/bin/bash

# Story Creator Agent 파일 생성 검증 Hook
# 목적: story-creator Agent가 실제로 Story 파일을 생성했는지 확인

set -e

INPUT=$(cat)
INPUT_LENGTH=$(echo "$INPUT" | wc -c)

log() {
    echo "[story-creator-validation] $1" >&2
}

# 빈 입력 처리
if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    exit 0
fi

# Agent type 확인
AGENT_TYPE=$(echo "$INPUT" | grep -oP 'subagent_type["\s:]+\K[^"]+' | head -1 || echo "")

# story-creator Agent인 경우만 처리
if [[ "$AGENT_TYPE" == *"story-creator"* ]]; then
    log "Story Creator Agent 완료 감지"

    # Story 파일 생성 여부 확인
    # 최근 5분 이내 생성된 Story 파일 찾기
    RECENT_STORY=$(find docs/epics -name "S*.md" -type f -mmin -5 2>/dev/null | head -1 || echo "")

    if [[ -z "$RECENT_STORY" ]]; then
        # Story 파일이 생성되지 않음
        cat <<EOF

⚠️ STORY FILE NOT CREATED WARNING
─────────────────────────────────────
Story Creator Agent가 분석은 완료했지만 파일을 생성하지 않았습니다.

필수 조치:
1. ❌ 직접 파일 생성 금지
2. ✅ story-creator Agent 재실행 필수

다시 실행:
Task --subagent_type story-creator --prompt "이전 분석 기반으로 Story 파일을 생성해주세요. 반드시 docs/epics/에 .md 파일로 저장하세요."

Agent Chain Rule #1 위반 방지:
- Agent가 작업을 완료하지 않았을 때는 반드시 같은 Agent를 재실행
- 직접 구현은 VIOLATION입니다
EOF
    else
        log "✅ Story 파일 생성 확인: $RECENT_STORY"
    fi
fi

# 원본 입력 그대로 전달
echo "$INPUT"
exit 0