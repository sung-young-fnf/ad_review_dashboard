# Claude Code Rules (fnf-mono-starter)

> Think carefully. Concise solutions. Minimal changes. Korean.

## Tech Stack (앱별 상이)

| Layer | Tech |
|-------|------|
| Frontend (공통) | Next.js 16+ React 19 TypeScript |
| Backend (선택) | FastAPI (Python) 또는 NestJS (TypeScript) |
| Infra | K8s, Helm, ArgoCD, GitHub Actions |
| Package | uv (Python) / pnpm (TypeScript) |

## 앱별 스택 감지
- `apps/{app}/backend/pyproject.toml` → FastAPI (SQLAlchemy + Alembic)
- `apps/{app}/backend/nest-cli.json` → NestJS (Prisma)
- `apps/{app}/CLAUDE.md` → 앱별 상세 규칙

## Core Rules

### BFF 필수
```
Browser → Next.js API Route (/api/v1/...) → Backend
```
- ❌ 브라우저에서 Backend 직접 호출 금지
- ✅ `/api/v1/[...path]/route.ts` catch-all proxy 사용

### DB 정책 (DBUSER)
- ❌ public 스키마 금지
- ✅ 서비스 전용 스키마 (`{app_name}`)
- ✅ Owner 3단 분리: `_adm` / `_object_owner_role` / `_dml_role`
- ✅ 앱 런타임: `_svc` 계정 (DML 전용)

### OpenAPI 타입 동기화
- Backend DTO 변경 후 반드시:
  - FastAPI: `uv run python scripts/export-openapi.py`
  - NestJS: `./scripts/export-openapi.sh` (서버 실행 중)
  - Frontend: `pnpm generate:api`

## Post-Change Checklist
1. TypeScript: `pnpm tsc --noEmit`
2. Backend DTO 변경 시: OpenAPI 재생성
3. 커밋 전 사용자 확인

## Absolute Rules
YAGNI | DRY | NO PARTIAL | NO DEAD CODE
