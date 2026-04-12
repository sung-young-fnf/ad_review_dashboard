---
name: trace
description: "API 엔드포인트의 전체 데이터 흐름(BFF->BE->DB->Response->FE)을 자동 추적. Use when: 데이터 흐름 파악, 미들웨어 확인, Response shape 추적"
effort: medium
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__serena__find_symbol
  - mcp__serena__find_referencing_symbols
  - mcp__serena__get_symbols_overview
user-invocable: true
context: fork
---

# Data Flow Tracer

> "코드를 수정하기 전에 데이터가 어떻게 흘러가는지 알아야 한다"
> wrong_approach 95건 중 다수가 Response shape 오인, 미들웨어 누락에서 발생

## WHY

데이터 흐름을 모르고 코드를 수정하면:
- Response shape이 `[]`인데 `{ items, total }`로 가정 -> 런타임 에러
- 미들웨어가 필드를 변환하는데 모르고 원본 필드명으로 코딩 -> 필드 누락
- BFF에서 Backend로 전달하지 않는 필드를 프론트에서 사용 -> undefined

이 스킬은 API 엔드포인트의 전체 체인을 자동 추적하여 데이터 흐름 맵을 생성한다.

## 사용법

```
/trace POST /api/scheduled-tasks
/trace GET /api/workflows
/trace ScheduledTask          # 컴포넌트명/기능명으로도 검색 가능
```

## Pre-injected Context

**서비스 구조:**
!`ls -d apps/*/frontend/app/api/ 2>/dev/null | head -5`

**현재 브랜치:**
!`git branch --show-current 2>/dev/null`

## 5-Phase 추적 프로세스

### Phase 1: 입력 파싱 + 서비스 감지

사용자 입력에서 추적 대상을 파싱한다.

**HTTP 메서드 + 경로 형식:**
```
POST /api/scheduled-tasks  ->  method=POST, path=/api/scheduled-tasks
```

**기능명/컴포넌트명 형식:**
```
ScheduledTask  ->  Grep으로 관련 API 경로 역추적
```

**서비스 감지:**
- `apps/mcp-orbit/` 관련 -> Python/FastAPI (router, schemas, models)
- `apps/ai-agent/` 관련 -> TypeScript/NestJS (controller, dto, service)
- 경로에서 판단 불가 -> 양쪽 모두 검색

### Phase 2: BFF Route 추적

Next.js API Route (Browser -> Backend 프록시) 파일을 찾는다.

```bash
# API 경로에서 BFF Route 파일 검색
Grep "{path_segment}" apps/*/frontend/app/api/

# 예: /api/scheduled-tasks -> 
# apps/ai-agent/frontend/app/api/scheduled-tasks/route.ts
```

BFF Route 파일을 Read하여:
1. Backend API 호출 URL 추출 (backendFetch, fetch 호출)
2. 인증 방식 확인 (auth(), backendToken)
3. Request/Response 변환 로직 확인 (snake_case <-> camelCase)

### Phase 3: Backend Controller -> Service -> Repository 추적

```bash
# Controller 검색 (NestJS)
Grep "{path_segment}" apps/ai-agent/backend/src/ --include="*.controller.ts"

# Controller 검색 (FastAPI)
Grep "{path_segment}" apps/mcp-orbit/backend/ --include="*.py"
```

Controller에서 추적:
1. **데코레이터** — `@Post()`, `@Get()`, `@router.post()` 경로
2. **Service 메서드 호출** — `this.service.create()`, `service.list()`
3. **DTO/Schema** — Request DTO (class-validator / Pydantic), Response 타입

Service에서 추적:
1. **Repository/Prisma 호출** — `prisma.model.findMany()`, `session.query()`
2. **데이터 변환** — `_convert_to_response()`, spread, pick 패턴
3. **트랜잭션** — `prisma.$transaction()`, `session.begin()`

### Phase 4: 미들웨어/Guard 추적

```bash
# NestJS Guard/Interceptor
Grep "@UseGuards|@UseInterceptors" {controller_file}

# FastAPI Middleware
Grep "add_middleware|@app.middleware" apps/mcp-orbit/backend/

# NestJS Global 미들웨어
Grep "app.use|apply.*middleware" apps/ai-agent/backend/src/app.module.ts
```

확인 사항:
- 인증 Guard (JwtAuthGuard, ApiKeyGuard)
- 권한 Guard (RolesGuard, PermissionGuard)
- 로깅 Interceptor
- 변환 Interceptor (ClassSerializerInterceptor 등)

### Phase 5: 데이터 흐름 맵 출력

최종 결과를 구조화된 형식으로 출력한다.

```
## Data Flow: {METHOD} {PATH}

### Request Chain (Browser -> DB)
1. Frontend: `{component}` -> `fetch('/api/...')`
   - Payload: { field1, field2, ... }

2. BFF Route: `{bff_file}:{line}`
   - Auth: auth() -> backendToken
   - Transform: {변환 로직 또는 "pass-through"}
   - Backend Call: `backendFetch('{be_path}', { method: '{method}' })`

3. Guards/Middleware: [{guard_list}]
   - {각 Guard의 역할 1줄 설명}

4. Controller: `{controller_file}:{line}`
   - Decorator: @{Method}('{path}')
   - DTO: {RequestDto} (validated fields: [...])
   - -> `{service}.{method}(dto)`

5. Service: `{service_file}:{line}`
   - Logic: {핵심 비즈니스 로직 1줄}
   - -> `{prisma/repo}.{query}()`

6. DB: `{table_name}` (schema: {schema_name})
   - Operation: {SELECT|INSERT|UPDATE|DELETE}
   - Key columns: [{columns}]

### Response Chain (DB -> Browser)
6. DB -> {raw_result_shape}
5. Service -> {service_return_shape}
4. Controller -> {controller_return_shape}
3. Guards -> {interceptor_transform}
2. BFF Route -> {bff_response_shape}
1. Frontend -> {final_shape_used_in_component}

### Response Shape
{
  // 실제 Response 타입/인터페이스 표시
}

### Middleware/Interceptors
| 순서 | 이름 | 파일 | 역할 |
|------|------|------|------|
| 1 | {name} | {file} | {description} |

### 주의 지점
- [Response shape 변환이 있는 곳 표시]
- [snake_case -> camelCase 변환 지점]
- [미들웨어를 바이패스하는 경로]
- [Optional 필드가 Required로 바뀌는 지점]
```

## 완료 기준

- Browser -> DB까지 전체 체인이 추적됨
- Response shape이 각 레이어별로 명시됨
- 미들웨어/Guard가 모두 식별됨
- 주의 지점(변환, 바이패스)이 표시됨
- **코드 변경 0건** (분석 전용 스킬)

## 검색 실패 시 대안

경로 매칭 실패 시 단계별 대안 검색:

1. **경로 세그먼트 분리** — `/api/scheduled-tasks/123` -> `scheduled-tasks`로 재검색
2. **컨트롤러명/함수명** — `ScheduledTaskController`, `createScheduledTask`
3. **DTO/Entity명** — `CreateScheduledTaskDto`, `ScheduledTask`
4. **테이블명** — `scheduled_task`, `ScheduledTask` (Prisma model)

모든 대안 실패 시:
```
해당 API 경로를 찾을 수 없습니다.
검색한 경로: {path}
시도한 검색어: [{alternatives}]
가능한 원인: 미구현 / 다른 서비스에 존재 / 경로 오타
```
