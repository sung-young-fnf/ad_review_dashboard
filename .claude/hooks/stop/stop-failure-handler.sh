#!/bin/bash
# StopFailure Hook — API 에러(rate limit, auth 실패)로 턴 종료 시 실행
# 목적: 에러 유형별 가이드 메시지 출력 + 에러 로그 기록
# v2.1.78 신규 기능 활용

set -eo pipefail
trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ERRORS_FILE="$REPO_ROOT/.claude/learnings/ERRORS.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# stdin에서 Hook 이벤트 JSON 읽기
INPUT=$(cat 2>/dev/null || echo "{}")

if command -v jq &>/dev/null; then
    ERROR_TYPE=$(echo "$INPUT" | jq -r '.error_type // "unknown"' 2>/dev/null || echo "unknown")
    ERROR_MSG=$(echo "$INPUT" | jq -r '.error_message // ""' 2>/dev/null || echo "")
    LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null | head -c 200 || echo "")
else
    ERROR_TYPE="unknown"
    ERROR_MSG=""
    LAST_MSG=""
fi

# 에러 유형별 가이드 메시지
case "$ERROR_TYPE" in
    *rate_limit*|*429*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ [StopFailure] Rate Limit 도달
   └─ 잠시 대기 후 자동 재시도됩니다
   └─ /effort low 로 토큰 소비 줄이기 가능
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *auth*|*401*|*403*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [StopFailure] 인증 에러
   └─ /login 으로 재인증 필요
   └─ OAuth 토큰 만료 가능성
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *overloaded*|*529*|*500*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ [StopFailure] API 서버 과부하
   └─ 1-2분 후 자동 재시도됩니다
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *invalid_request*|*400*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [StopFailure] 400 Invalid Request (12건/월 최빈 에러)
   원인: 컨텍스트 과다 또는 메시지 크기 초과
   대응:
   └─ 1) praetorian_compact 호출하여 컨텍스트 압축
   └─ 2) 대형 분석 결과를 요약한 뒤 구현 agent 생성
   └─ 3) 한 턴에 파일 2개 이하로 제한
   └─ 4) 반복 시 세션 재시작 (/clear 또는 새 세션)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *stream*idle*|*partial*response*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ [StopFailure] Stream Idle Timeout
   원인: API 응답 생성 중 스트림 끊김
   대응:
   └─ 1) SendMessage로 agent 재개 시도
   └─ 2) 작업을 더 작은 단위로 분할
   └─ 3) 컨텍스트 압축 후 재시도
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *sso*|*expired*token*|*aws*sso*)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [StopFailure] SSO/토큰 만료
   └─ ! aws sso login 실행 필요
   └─ 또는 터미널에서 직접: aws sso login
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
    *)
        cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ [StopFailure] API 에러: ${ERROR_TYPE}
   └─ ${ERROR_MSG:0:100}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        ;;
esac

# ERRORS.md에 기록 (간결하게)
if [ -f "$ERRORS_FILE" ]; then
    echo "" >> "$ERRORS_FILE"
    echo "## [${TIMESTAMP}] StopFailure: ${ERROR_TYPE}" >> "$ERRORS_FILE"
    echo "- Message: ${ERROR_MSG:0:200}" >> "$ERRORS_FILE"
    if [ -n "$LAST_MSG" ]; then
        echo "- Last context: ${LAST_MSG:0:100}..." >> "$ERRORS_FILE"
    fi
fi

exit 0
