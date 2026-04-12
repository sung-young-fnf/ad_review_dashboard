#!/bin/bash
# Zombie Claude Process Cleanup (SessionStart hook)
# PPID=1인 고아 claude 프로세스를 자동 정리하여 메모리 누수 방지
# 현재 세션(CLAUDE_SESSION_ID 기반)은 보존

# 타임아웃 방지
trap 'exit 0' ERR

CURRENT_PID=${PPID:-0}
KILLED=0
FREED_MB=0

# PPID=1 (고아) + 1시간 이상 실행 중인 claude 프로세스 찾기
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  ppid=$(echo "$line" | awk '{print $2}')
  rss=$(echo "$line" | awk '{print $3}')

  # 현재 세션 프로세스 보호
  [ "$pid" = "$CURRENT_PID" ] && continue

  # PPID=1 (고아 프로세스)만 대상
  [ "$ppid" != "1" ] && continue

  # RSS 50MB 미만은 무시 (MCP 서버 등 경량 프로세스)
  [ "$rss" -lt 51200 ] 2>/dev/null && continue

  # SIGTERM 먼저, 1초 후 살아있으면 SIGKILL
  kill "$pid" 2>/dev/null
  sleep 0.5
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
  fi
  mb=$((rss / 1024))
  FREED_MB=$((FREED_MB + mb))
  KILLED=$((KILLED + 1))
done < <(ps -eo pid,ppid,rss,comm 2>/dev/null | grep -i claude | grep -v grep)

# orphan task output 파일 정리 (24시간 이상)
if [ -d "/private/tmp/claude-$(id -u)" ]; then
  find "/private/tmp/claude-$(id -u)" -name "*.output" -mmin +1440 -delete 2>/dev/null
fi

if [ "$KILLED" -gt 0 ]; then
  echo "🧹 Zombie cleanup: killed ${KILLED} orphan processes, freed ~${FREED_MB}MB" >&2
fi

exit 0
