---
name: orbit-replicate
description: "Orbit 기능을 AI Agent로 복제하는 구조화된 파이프라인. 탐색만 하고 코드 생성 안 하는 문제 방지. Use when: Orbit→AI Agent 기능 마이그레이션"
effort: high
preconditions:
  - 복제 대상 Orbit 기능이 명확히 지정됨
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Grep
  - Glob
  - Bash
  - Task
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__serena__search_for_pattern
  - mcp__serena__write_memory
context: fork
---

# Orbit Replicate Skill

> "Orbit 원본을 정확히 복제한다. 사용자 지정 개선 금지."
> -- Insights 마찰 분석: 복제 대신 커스텀 구현으로 세션 낭비 반복

## 핵심 원칙

1. **원본 충실 복제** - Orbit 코드를 먼저 읽고, 정확히 복제. 자체 해석/개선 금지
2. **인벤토리 우선** - 코드 작성 전에 전체 컴포넌트 맵 완성
3. **체크리스트 기반** - 모든 행이 처리되어야 완료

## Phase 1: INVENTORY (코드 변경 금지)

대상: `apps/mcp-orbit/` 에서 관련 기능 전체 매핑

```bash
# 컴포넌트 검색
Grep "{기능명}" apps/mcp-orbit/ --type ts --type tsx
Glob "apps/mcp-orbit/**/*{기능명}*"

# API 라우트 검색
Grep "{api_path}" apps/mcp-orbit/frontend/src/app/api/
Grep "{endpoint}" apps/mcp-orbit/backend/

# 타입 정의 검색
Grep "interface.*{Feature}" apps/mcp-orbit/ --type ts
Grep "type.*{Feature}" apps/mcp-orbit/ --type ts
```

### 인벤토리 출력 (필수)

```markdown
## Orbit 기능 인벤토리: {기능명}

| # | Component | Orbit Path | Purpose | AI Agent Equivalent | Status |
|---|-----------|------------|---------|---------------------|--------|
| 1 | {컴포넌트} | {경로} | {역할} | {있으면 경로/없으면 "NEW"} | - |
| 2 | ... | ... | ... | ... | - |

Total: {N}개 컴포넌트
```

❌ 인벤토리 테이블 없이 Phase 2 진행 = VIOLATION

## Phase 2: GAP ANALYSIS

각 컴포넌트별 판정:

| 판정 | 설명 | 행동 |
|------|------|------|
| COPY | 로직 동일, 경로만 변경 | 복사 + import 수정 |
| ADAPT | 패턴 차이 (Python→TS, auth 등) | 로직 유지 + 패턴 변환 |
| SKIP | AI Agent에 이미 동일 구현 존재 | 확인만 |

### 적응 규칙 (ADAPT)

| Orbit (Python/FastAPI) | AI Agent (TypeScript/NestJS) |
|----------------------|---------------------------|
| `@router.get()` | `@Get()` |
| Pydantic Schema | class-validator DTO |
| SQLAlchemy Model | Prisma Schema |
| `_convert_to_response()` | 직접 반환 |
| `app/api/route.py` | `app/api/route.ts` (Next.js BFF) |

## Phase 3: IMPLEMENT

인벤토리 테이블 순서대로 구현:

```
FOR each row in inventory:
  1. Orbit 원본 코드 Read
  2. AI Agent에 복제/적응
  3. pnpm tsc --noEmit (해당 파일)
  4. Status 업데이트: ✅
```

❌ 인벤토리에 없는 파일 생성 = VIOLATION (scope creep)
❌ Orbit에 없는 기능 추가 = VIOLATION (custom improvement)

## Phase 4: VERIFY

```markdown
## 복제 완료 검증

| # | Component | Status | Notes |
|---|-----------|--------|-------|
| 1 | {컴포넌트} | ✅/❌ | {비고} |

- [ ] 모든 행 ✅
- [ ] pnpm build 성공
- [ ] 누락 컴포넌트 0개
```

## 금지사항

- ❌ Orbit 코드를 읽기 전에 구현 시작
- ❌ "개선된 버전"으로 자체 구현
- ❌ 인벤토리 없이 탐색만 반복
- ❌ dev guide, settings, 필터 등 부수 기능 누락
