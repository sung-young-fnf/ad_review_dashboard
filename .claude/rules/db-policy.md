## DB 정책 (DBUSER)

- ❌ public 스키마 금지 → 서비스 전용 스키마
- ❌ DDL을 _svc 계정으로 실행 금지
- ✅ Owner 3단 분리:
  - `_adm` (LOGIN) = DB + Schema Owner
  - `_object_owner_role` (NOLOGIN) = Object Owner
  - `_dml_role` (NOLOGIN) = DML 전용
- ✅ 앱 런타임: `_svc` 계정 (DML 전용)
- ✅ 마이그레이션: `_ops` 계정 (SET ROLE object_owner_role)

### 모델 정의 시 필수
- FastAPI: `__table_args__ = {"schema": "{app_name}"}` (SQLAlchemy)
- NestJS: `@@schema("{app_name}")` (Prisma)
