# DB 계정 정책 (DBUSER)

> 출처: F&F DT DBUSER-001/002/003

## 핵심 원칙

1. **public 스키마 금지** — 서비스별 전용 스키마 사용
2. **Owner 3단 분리** (PostgreSQL):
   - `{서비스명}_adm` (LOGIN) = DB + Schema Owner
   - `{서비스명}_object_owner_role` (NOLOGIN) = Object Owner (DDL+DML)
   - `{스키마명}_dml_role` (NOLOGIN) = DML 전용
3. **서비스 계정(_svc)은 DML만** — DDL 실행 불가
4. **DDL은 SET ROLE object_owner_role을 통해서만** — Object Owner 통일

## 계정 체계

| 계정 | 네이밍 | LOGIN | 용도 |
|------|--------|:-----:|------|
| DB+Schema Owner | `{서비스명}_adm` | O | DBA/파트장급, 스키마 생성/삭제 |
| Object Owner Role | `{서비스명}_object_owner_role` | X | DDL+DML, 스키마 내 오브젝트 소유 |
| DML Role | `{스키마명}_dml_role` | X | SELECT/INSERT/UPDATE/DELETE + 시퀀스 |
| 개발자 | `{서비스명}_oper` | O | SET ROLE object_owner_role |
| 마이그레이션 도구 | `{서비스명}_{도구명}_ops` | O | SET ROLE object_owner_role |
| 앱 서비스 | `{서비스명}_svc` | O | SET ROLE dml_role (기본) |

## 새 앱 생성 시

`scripts/create-app.sh`가 자동으로 `init-db.sql`을 생성합니다.

```bash
# 1. DB 초기화 (postgres 유저로)
psql -U postgres -f apps/{app}/backend/scripts/init-db.sql

# 2. .env에 _svc 계정 설정 (앱 런타임)
# 3. alembic.ini 또는 MIGRATE_DATABASE_URL에 _ops 계정 설정 (마이그레이션)
```
