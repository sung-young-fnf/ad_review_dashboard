---
paths:
  - "apps/ai-agent/backend/**/*.ts"
  - "apps/ai-agent/backend/prisma/**"
  - "apps/app-hub/backend/**/*.ts"
  - "apps/app-hub/backend/prisma/**"
---

# AI-Agent / App-Hub Backend Rules (NestJS/Prisma)

> 상세 체크리스트: @.claude/guides/DATA_FIELD_CHECKLIST_AI_AGENT.md

## Prisma Schema
- `@@schema("ai_agent")` 명시 (app-hub은 `app_hub`)
- 필드명 camelCase, DB 컬럼 snake_case → `@map("snake_case")` 사용
- Optional 필드: `?` 추가, 기본값: `@default(...)`
- 변경 후 반드시: `pnpm prisma migrate dev --name {description}` → `pnpm prisma generate`
- `prisma generate` 누락 시 타입 에러 100+ 발생

## NestJS DTO
- Request: `class-validator` 데코레이터 (`@IsString()`, `@IsOptional()`, `@MaxLength()`)
- Response: `@ApiProperty()` / `@ApiPropertyOptional()` 문서화
- DTO 위치: `src/modules/{module}/dto/{feature}.dto.ts`

## Module Structure
- Controller → Service → Prisma (3-Layer)
- Guard/Decorator로 권한 체크
- Module 등록: `{feature}.module.ts`에 providers/controllers 등록

## OpenAPI 동기화
- DTO/Controller 변경 시: `./scripts/export-openapi.sh` → Frontend `pnpm generate:api`

## Naming
- camelCase (변수, 메서드, DTO 필드)
- PascalCase (클래스, DTO, Interface)
- kebab-case (파일명)
