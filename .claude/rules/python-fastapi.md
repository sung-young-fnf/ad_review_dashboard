---
paths:
  - "apps/mcp-orbit/backend/**/*.py"
  - "apps/mcp-orbit/backend/migrations/**"
---

# MCP-Orbit Backend Rules (Python/FastAPI)

> 상세 체크리스트: @.claude/guides/DATA_FIELD_CHECKLIST_MCP_ORBIT.md

## DB Schema
- `mcp_orch.*` 스키마 필수 (public 금지)
- Alembic migration: **idempotent check** 함수 포함 (`column_exists`, `table_exists`)
- Migration 파일명: `{YYYYMMDD}_{HHMM}_{epic_id}_{description}.py`
- `revision`/`down_revision` 올바르게 설정, `upgrade()` + `downgrade()` 쌍

## SQLAlchemy Model
- `nullable`, `server_default`, `comment` 명시
- relationship 정의 시 lazy loading 주의
- `__init__.py`에서 export 확인

## Pydantic Schema
- Create: 필수 `...`, 선택 `default`
- Update: `Optional[Type]` + `None` 기본값
- Response: `_convert_to_response()` 메서드로 변환

## API Pattern
- FastAPI router에 `tags`, `summary`, `description` 명시
- Change Request 패턴: 직접 수정 아닌 변경 요청 → 승인 → 적용 흐름
- snake_case 유지 (Frontend camelCase와 변환 일관성)

## Encryption
- 민감 데이터: `MCP_ENCRYPTION_KEY` 암호화 필수
- `encrypt_value()` / `decrypt_value()` 유틸 사용
