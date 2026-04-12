#!/bin/bash
# .claude/hooks/pre/cwd-service-detector.sh
# CwdChanged Hook — 작업 디렉토리 변경 시 서비스 자동 감지
#
# 2.1.83+ CwdChanged 이벤트 활용
# PreToolUse 매 호출 대신 디렉토리 변경 시에만 실행 → 효율적
#
# WHY: 모노레포에서 apps/ 하위로 이동할 때 서비스 컨텍스트 자동 주입
#       PreToolUse service-detection-context-injector.sh의 보조 역할

trap 'exit 0' ERR

# stdin에서 CwdChanged 이벤트 정보 읽기
event_info=$(cat)
NEW_CWD=$(echo "$event_info" | jq -r '.cwd // empty' 2>/dev/null)

if [[ -z "$NEW_CWD" ]]; then
  exit 0
fi

# 서비스 감지
SERVICE=""
TECH=""

if [[ "$NEW_CWD" == *"apps/mcp-orbit"* ]] || [[ "$NEW_CWD" == *"src/mcp_orch"* ]]; then
  SERVICE="mcp-orbit"
  TECH="Python/FastAPI/SQLAlchemy/Alembic | DB: mcp_orch.* | Checklist: DATA_FIELD_CHECKLIST_MCP_ORBIT.md"
elif [[ "$NEW_CWD" == *"apps/ai-agent"* ]]; then
  SERVICE="ai-agent"
  TECH="TypeScript/NestJS/Prisma | DB: ai_agent.* | Checklist: DATA_FIELD_CHECKLIST_AI_AGENT.md"
elif [[ "$NEW_CWD" == *"apps/app-hub"* ]]; then
  SERVICE="app-hub"
  TECH="TypeScript/NestJS/Prisma | AI-Agent 체크리스트 참조"
elif [[ "$NEW_CWD" == *"apps/agent-office"* ]]; then
  SERVICE="agent-office-phaser"
  TECH="TypeScript/Vite+Phaser/Colyseus | DB 없음"
fi

# 서비스 미감지 시 조용히 통과
if [[ -z "$SERVICE" ]]; then
  exit 0
fi

# systemMessage로 서비스 컨텍스트 알림
cat << EOF
{
  "systemMessage": "[CwdChanged → ${SERVICE}] ${TECH}"
}
EOF
exit 0
