#!/bin/bash
# .claude/hooks/pre/service-detection-context-injector.sh
# PreToolUse Hook — 파일 경로 기반 서비스 자동 감지 + 체크리스트 additionalContext 주입
#
# v2.1.9+ additionalContext 기능 활용
# 트리거: PreToolUse (Edit|Write|MultiEdit|Task)
#
# WHY: SERVICE_DETECTION_GUIDE.md를 매번 수동 로드하지 않고,
#       파일 경로에서 자동으로 서비스를 감지하여 해당 체크리스트를 주입

trap 'exit 0' ERR

# ===== stdin에서 tool 정보 읽기 =====
tool_info=$(cat)
TOOL_NAME=$(echo "$tool_info" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
PROMPT=$(echo "$tool_info" | jq -r '.tool_input.prompt // empty' 2>/dev/null)

# ===== 서비스 감지 =====
SERVICE=""
CHECKLIST=""

# 1. Edit/Write/MultiEdit → file_path에서 감지
if [[ -n "$FILE_PATH" ]]; then
  if [[ "$FILE_PATH" == *"apps/mcp-orbit"* ]] || [[ "$FILE_PATH" == *"src/mcp_orch"* ]]; then
    SERVICE="mcp-orbit"
    CHECKLIST="DATA_FIELD_CHECKLIST_MCP_ORBIT.md"
  elif [[ "$FILE_PATH" == *"apps/ai-agent"* ]]; then
    SERVICE="ai-agent"
    CHECKLIST="DATA_FIELD_CHECKLIST_AI_AGENT.md"
  elif [[ "$FILE_PATH" == *"apps/app-hub"* ]]; then
    SERVICE="app-hub"
    CHECKLIST="DATA_FIELD_CHECKLIST_AI_AGENT.md"
  fi
fi

# 2. Task → prompt에서 키워드로 감지 (보조)
if [[ -z "$SERVICE" ]] && [[ -n "$PROMPT" ]]; then
  if echo "$PROMPT" | grep -qiE '(mcp.orbit|marketplace|subscription|change.request|mcp.config|project.*team|visibility|approval)'; then
    SERVICE="mcp-orbit"
    CHECKLIST="DATA_FIELD_CHECKLIST_MCP_ORBIT.md"
  elif echo "$PROMPT" | grep -qiE '(ai.agent|workflow|chat|slide|my.documents|knowhub|knowledge|datalens|scheduled)'; then
    SERVICE="ai-agent"
    CHECKLIST="DATA_FIELD_CHECKLIST_AI_AGENT.md"
  fi
fi

# 서비스 미감지 시 조용히 통과
if [[ -z "$SERVICE" ]]; then
  exit 0
fi

# ===== 서비스별 핵심 리마인더 생성 =====
if [[ "$SERVICE" == "mcp-orbit" ]]; then
  CONTEXT="[Service: MCP-Orbit] Python/FastAPI/SQLAlchemy/Alembic. DB schema: mcp_orch.*. Checklist: @.claude/guides/${CHECKLIST}. Pydantic Schema + _convert_to_response() + BFF 패턴 필수."
elif [[ "$SERVICE" == "ai-agent" ]]; then
  CONTEXT="[Service: AI-Agent] TypeScript/NestJS/Prisma. DB schema: ai_agent.*. Checklist: @.claude/guides/${CHECKLIST}. DTO(class-validator) + FSD 구조 + BFF 패턴 필수."
elif [[ "$SERVICE" == "app-hub" ]]; then
  CONTEXT="[Service: App-Hub] TypeScript/NestJS/Prisma. AI-Agent 체크리스트 참조: @.claude/guides/${CHECKLIST}. BFF 패턴 필수."
fi

# ===== DB 필드 작업 감지 (추가 컨텍스트) =====
DB_HINT=""
if [[ -n "$FILE_PATH" ]]; then
  if [[ "$FILE_PATH" == *"migration"* ]] || [[ "$FILE_PATH" == *"models/"* ]] || \
     [[ "$FILE_PATH" == *"schema.prisma"* ]] || [[ "$FILE_PATH" == *"schemas/"* ]] || \
     [[ "$FILE_PATH" == *".dto.ts"* ]]; then
    DB_HINT=" DB/Schema 변경 감지 — 체크리스트 전체 Phase 완료 필수 (Model→Schema→Service→Frontend Type→BFF)."
  fi
fi

# ===== JSON 응답 (approve + additionalContext) =====
FULL_CONTEXT="${CONTEXT}${DB_HINT}"
# JSON에 안전한 문자열로 이스케이프
ESCAPED_CONTEXT=$(echo "$FULL_CONTEXT" | sed 's/"/\\"/g' | tr '\n' ' ')

cat << EOF
{
  "decision": "approve",
  "additionalContext": "${ESCAPED_CONTEXT}"
}
EOF
exit 0
