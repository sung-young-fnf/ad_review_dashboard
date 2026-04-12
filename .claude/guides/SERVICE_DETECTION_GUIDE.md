# Service Detection Guide

> Agent가 작업 대상 서비스를 자동 감지하고 적절한 체크리스트를 참조하는 방법

## WHY

모노레포에서 각 서비스는 서로 다른 기술 스택과 패턴을 사용함:
- **MCP-Orbit**: Python/FastAPI/SQLAlchemy/Alembic
- **AI-Agent**: TypeScript/NestJS/Prisma

잘못된 패턴을 적용하면 빌드 실패, 타입 에러, 런타임 버그 발생.
이 가이드는 "올바른 서비스에 올바른 패턴이 적용된 상태"를 보장함.

---

## 서비스 감지 규칙

### 1. 경로 기반 자동 감지 (Primary)

| 경로 패턴 | 서비스 | 체크리스트 |
|-----------|--------|-----------|
| `apps/mcp-orbit/**` | MCP-Orbit | `DATA_FIELD_CHECKLIST_MCP_ORBIT.md` |
| `apps/ai-agent/**` | AI-Agent | `DATA_FIELD_CHECKLIST_AI_AGENT.md` |

```markdown
## Agent 감지 로직 예시

Task 시작 시:
1. 수정 대상 파일 경로 확인
2. `apps/mcp-orbit/` 포함? → MCP-Orbit 체크리스트 로드
3. `apps/ai-agent/` 포함? → AI-Agent 체크리스트 로드
4. 두 서비스 모두 포함? → 경고 표시 + 양쪽 체크리스트 로드
```

### 2. 키워드 기반 감지 (Secondary)

경로가 명확하지 않을 때 키워드로 서비스 추론:

| 키워드 | 서비스 | 설명 |
|--------|--------|------|
| `marketplace`, `subscription`, `change-request`, `mcp-config` | MCP-Orbit | 마켓플레이스/구독 관련 |
| `project`, `team`, `visibility`, `approval` | MCP-Orbit | 접근 제어 관련 |
| `workflow`, `chat`, `slide`, `my-documents` | AI-Agent | 채팅/워크플로우 관련 |
| `agent`, `datalens`, `scheduled-task` | AI-Agent | 에이전트/분석 관련 |
| `knowhub`, `knowledge` | AI-Agent | 지식베이스 관련 |

### 3. 파일 확장자/패턴 기반 감지 (Tertiary)

| 파일 패턴 | 서비스 | 기술 스택 |
|-----------|--------|-----------|
| `*.py`, `alembic`, `sqlalchemy` | MCP-Orbit | Python/FastAPI |
| `prisma/schema.prisma` | AI-Agent | NestJS/Prisma |
| `*.module.ts`, `*.controller.ts`, `*.service.ts` | AI-Agent | NestJS |
| `schemas/*.py` (Pydantic) | MCP-Orbit | FastAPI |
| `dto/*.dto.ts` (class-validator) | AI-Agent | NestJS |

---

## Agent 프롬프트 템플릿

### Task 시작 시 서비스 감지

```markdown
## Phase 0: Service Detection

1. Task 파일 경로 확인: `{task_path}`
2. 수정 대상 파일 목록:
   - [ ] `apps/mcp-orbit/...` → MCP-Orbit
   - [ ] `apps/ai-agent/...` → AI-Agent

3. 적용할 체크리스트:
   - MCP-Orbit: @.claude/guides/DATA_FIELD_CHECKLIST_MCP_ORBIT.md
   - AI-Agent: @.claude/guides/DATA_FIELD_CHECKLIST_AI_AGENT.md

4. 새 필드 추가 작업이면:
   - 해당 체크리스트의 모든 Phase 완료 필수
   - 하나라도 누락 시 빌드 실패 또는 런타임 에러 위험
```

### code-writer Phase 0에 통합

```markdown
## Phase 0: Context Load + Service Detection

### Step 1: 서비스 감지
경로 분석:
- `apps/mcp-orbit/` 포함? → MCP-Orbit 체크리스트 로드
- `apps/ai-agent/` 포함? → AI-Agent 체크리스트 로드

### Step 2: 작업 유형 판단
- DB 필드 추가? → 해당 서비스의 DATA_FIELD_CHECKLIST 전체 따르기
- API 추가? → BFF 패턴 확인 (serena/read_memory → frontend-api-proxy-checklist)
- UI 수정? → UI_PATTERNS.md 참조
```

---

## 서비스별 핵심 차이점

| 구분 | MCP-Orbit | AI-Agent |
|------|-----------|----------|
| **Language** | Python 3.11+ | TypeScript |
| **Backend Framework** | FastAPI | NestJS |
| **ORM** | SQLAlchemy | Prisma |
| **Migration** | Alembic (수동 파일 생성) | Prisma Migrate (자동) |
| **Schema 위치** | `schemas/*.py` (Pydantic) | `modules/*/dto/*.dto.ts` |
| **Model 위치** | `models/*.py` | `prisma/schema.prisma` |
| **응답 변환** | `_convert_to_response()` 메서드 | 직접 반환 (Prisma 타입) |
| **DB Schema** | `mcp_orch.*` | `ai_agent.*` |
| **특수 패턴** | Change Request 패턴 | FSD (Feature-Sliced Design) |

---

## 공통 체크포인트

두 서비스 모두 공통으로 확인해야 하는 사항:

### Frontend BFF 패턴 (필수)

```
Browser → Next.js API Route → Backend
         (app/api/...)       (Python or NestJS)
```

- [ ] 브라우저에서 Backend 직접 호출 금지
- [ ] `auth()` wrapper로 인증 토큰 획득
- [ ] `backendToken` 사용 (accessToken 아님)

### 타입 동기화 (필수)

```
Backend DTO/Schema ←→ Frontend Type
   (Source)              (Mirror)
```

- [ ] Backend 응답 필드 = Frontend 타입 필드
- [ ] snake_case ↔ camelCase 변환 일관성
- [ ] Optional/Required 일치

### OpenAPI 타입 동기화 (Backend DTO/Controller 변경 시 필수)

```bash
# ai-agent (NestJS) — 서버 실행 중이어야 함
cd apps/ai-agent/backend && ./scripts/export-openapi.sh
cd apps/ai-agent/frontend && pnpm generate:api

# mcp-orbit (FastAPI) — 서버 불필요
cd apps/mcp-orbit/backend && uv run python scripts/export-openapi.py
cd apps/mcp-orbit/frontend && pnpm fetch:openapi && pnpm generate:types
```

- [ ] Backend DTO 변경 → openapi.json 재생성
- [ ] Frontend generated/api.ts 재생성
- [ ] pre-commit hook이 자동 실행 (서버 실행 시)

### 빌드 검증 (필수)

```bash
# 전체 빌드 (Root)
pnpm build

# 개별 서비스
cd apps/mcp-orbit && pnpm build
cd apps/ai-agent && pnpm build
```

---

## 자동화 예시

### Serena Memory에 현재 서비스 기록

```bash
# Task 시작 시 서비스 감지 결과 저장
mcp-cli call serena/write_memory '{
  "memory_file_name": "current_task_service",
  "content": "# Current Task Service\n\n**Service**: ai-agent\n**Checklist**: DATA_FIELD_CHECKLIST_AI_AGENT.md\n**Task**: EP105-S01-T001\n**Pattern**: FSD + Prisma"
}'
```

### Task 완료 시 체크리스트 검증

```markdown
## Completion Verification

Phase 완료 확인:
- [ ] Phase 1: Database Layer (Migration + Model)
- [ ] Phase 2: API Layer (DTO + Service + Controller)
- [ ] Phase 3: Frontend Layer (Type + BFF + Component)

빌드 결과:
- [ ] `pnpm build` 성공
- [ ] TypeScript 에러 0개
```

---

## 혼합 작업 (Cross-Service)

두 서비스를 동시에 수정해야 하는 경우:

### 예시: MCP-Orbit에서 AI-Agent로 데이터 전달

1. MCP-Orbit 먼저:
   - API 엔드포인트 추가
   - Response 스키마 정의

2. AI-Agent:
   - MCP-Orbit API 호출 코드 추가
   - 받은 데이터 처리

3. 각 서비스별 체크리스트 적용:
   - MCP-Orbit 변경 → `DATA_FIELD_CHECKLIST_MCP_ORBIT.md`
   - AI-Agent 변경 → `DATA_FIELD_CHECKLIST_AI_AGENT.md`

---

## Quick Reference

```
# 서비스 감지 → 체크리스트 매핑

apps/mcp-orbit/**  →  DATA_FIELD_CHECKLIST_MCP_ORBIT.md
                      ├── Alembic Migration (idempotent)
                      ├── SQLAlchemy Model
                      ├── Pydantic Schema (Request/Response)
                      ├── Service (_convert_to_response)
                      ├── Frontend Type (types/index.ts)
                      └── BFF Route (app/api/)

apps/ai-agent/**   →  DATA_FIELD_CHECKLIST_AI_AGENT.md
                      ├── Prisma Schema
                      ├── Prisma Migrate
                      ├── NestJS DTO (class-validator)
                      ├── NestJS Service/Controller
                      ├── Frontend Entity Type
                      ├── BFF Route (app/api/)
                      └── Feature UI (FSD)
```

---

_Version: 1.0 - 2026-01-30_
