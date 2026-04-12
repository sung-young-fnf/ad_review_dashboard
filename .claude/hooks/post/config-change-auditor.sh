#!/bin/bash
# .claude/hooks/post/config-change-auditor.sh
# ConfigChange Hook — 설정 파일 변경 감사 로그
# Version: 1.0 (2.1.49+ ConfigChange hook 활용)
#
# WHY: settings.json, CLAUDE.md 등 설정 변경이 세션 중간에 발생 시
#      변경 내용을 로그에 기록하여 추적 가능하게 한다.

trap 'exit 0' ERR

# stdin에서 이벤트 정보 읽기
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
else
  event_info=""
fi

# 빈 입력 시 통과
if [[ -z "$event_info" ]] || [[ "${#event_info}" -lt 2 ]]; then
  exit 0
fi

# 변경된 파일 정보 추출
CHANGED_FILE=$(echo "$event_info" | jq -r '.file_path // empty' 2>/dev/null || echo "")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 로그 디렉토리 확인
LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null

# 감사 로그 기록
if [[ -n "$CHANGED_FILE" ]]; then
  echo "[$TIMESTAMP] ConfigChange: $CHANGED_FILE" >> "$LOG_DIR/config-changes.log"
fi

# 보안 관련 설정 변경 시 경고
if [[ "$CHANGED_FILE" == *"settings.json"* ]]; then
  echo "{\"systemMessage\": \"⚠️ settings.json 변경 감지. 권한/hook 규칙 확인 권장.\"}"
else
  exit 0
fi
