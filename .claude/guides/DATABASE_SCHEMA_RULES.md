# 🗄️ DATABASE SCHEMA RULES (Mandatory)

## ⚠️ CRITICAL: 프로젝트별 스키마 spec 문서 참조 필수

**절대 규칙**:
- ❌ NEVER use `public` schema implicitly
- ✅ ALWAYS read schema from `@docs/analysis/database-schema.md` first
- ✅ ALWAYS read schema from `@docs/analysis/guides/schema-configuration.md` if exists
- ✅ ALL SQL queries MUST include schema prefix: `{project_schema}.table_name`

## 스키마 확인 절차
```bash
# Step 1: 프로젝트 스키마 문서 읽기
Read @docs/analysis/database-schema.md
# 또는
Read @docs/analysis/guides/schema-configuration.md

# Step 2: 문서에서 프로젝트 스키마명 확인
# 예: "프로젝트 전용 스키마: sparknote"
# 예: "Schema: custom_schema_name"

# Step 3: 확인한 스키마명 사용
```

## Prisma 설정 템플릿
```prisma
// apps/backend/prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  schemas  = ["{project_schema}"]  // ⚠️ 문서에서 확인한 스키마명
}

model User {
  // ... fields
  @@schema("{project_schema}")  // ⚠️ 모든 모델에 문서의 스키마명 사용
}
```

## Raw SQL 쿼리 템플릿
```sql
-- ❌ 금지 (스키마 미명시)
SELECT * FROM users;
SELECT * FROM campaigns WHERE status = 'active';

-- ✅ 필수 (프로젝트 스키마 명시)
SELECT * FROM {project_schema}.users;
SELECT * FROM {project_schema}.campaigns WHERE status = 'active';
```

## Migration 스크립트 템플릿
```sql
-- ✅ 필수 (프로젝트 스키마 명시)
CREATE TABLE {project_schema}.new_table (...);
ALTER TABLE {project_schema}.existing_table ADD COLUMN ...;
```

## psql 명령어 템플릿
```bash
# ✅ 방법 1: search_path 설정
docker exec -i {db_container} psql -U {user} -d {dbname} -c "SET search_path TO {project_schema}; SELECT * FROM campaigns;"

# ✅ 방법 2: 스키마 prefix 사용
docker exec -i {db_container} psql -U {user} -d {dbname} -c "SELECT * FROM {project_schema}.campaigns;"
```

## 에러 예방
일반적인 에러 패턴:
```
ERROR: relation "table_name" does not exist
원인: public 스키마에서 검색 시도
해결: docs/analysis/database-schema.md에서 스키마 확인 → {project_schema}.table_name 사용
```

---

## 🛡️ Soft Delete 및 FK CASCADE 규칙 (Mandatory)

### ⚠️ CRITICAL: CASCADE DELETE 금지

**절대 규칙**:
- ❌ NEVER use `ON DELETE CASCADE` for user-related FKs
- ✅ ALWAYS use `ON DELETE SET NULL` for user references
- ✅ ALWAYS implement soft delete (`deleted_at`) for critical data

### 왜 CASCADE를 금지하는가?

실제 발생한 문제:
```
사용자 삭제 시 marketplace_servers.publisher_id가 CASCADE로 설정되어
→ 45개 중복 사용자 정리 시 마켓플레이스 서버, MCP 서버 등 핵심 데이터 삭제됨
→ 복구 불가능한 데이터 손실
```

사용자는 퇴사하거나 비활성화될 수 있지만, 해당 사용자가 생성한 데이터는 유지되어야 합니다.

### FK 설정 표준

```sql
-- ❌ 금지 (CASCADE)
ALTER TABLE {schema}.marketplace_servers
  ADD CONSTRAINT fk_publisher
  FOREIGN KEY (publisher_id) REFERENCES {schema}.users(id)
  ON DELETE CASCADE;

-- ✅ 필수 (SET NULL)
ALTER TABLE {schema}.marketplace_servers
  ADD CONSTRAINT fk_publisher
  FOREIGN KEY (publisher_id) REFERENCES {schema}.users(id)
  ON DELETE SET NULL;
```

### SET NULL 적용 대상 컬럼

| 테이블 | 컬럼 | 설명 |
|--------|------|------|
| marketplace_servers | publisher_id | 배포자 정보 유지 |
| server_installations | user_id | 설치 이력 유지 |
| subscription_approvers | approver_user_id | 승인 이력 유지 |
| server_access_control | granted_by | 권한 부여 이력 유지 |
| server_approval_queue | requested_by | 요청 이력 유지 |
| mcp_servers | created_by | 생성자 정보 유지 |
| api_keys | user_id | API 키 소유자 기록 |

### Soft Delete 구현

```sql
-- 모든 주요 테이블에 deleted_at 컬럼 추가
ALTER TABLE {schema}.users ADD COLUMN deleted_at TIMESTAMP NULL;
ALTER TABLE {schema}.marketplace_servers ADD COLUMN deleted_at TIMESTAMP NULL;
ALTER TABLE {schema}.mcp_servers ADD COLUMN deleted_at TIMESTAMP NULL;

-- 삭제 대신 soft delete 수행
UPDATE {schema}.users SET deleted_at = NOW() WHERE id = '{user_id}';

-- 조회 시 deleted_at IS NULL 조건 필수
SELECT * FROM {schema}.users WHERE deleted_at IS NULL;
```

### SQLAlchemy 모델 패턴

```python
from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID

class BaseModel:
    deleted_at = Column(DateTime, nullable=True, index=True)

    def soft_delete(self):
        self.deleted_at = datetime.utcnow()

class MarketplaceServer(Base):
    # ✅ SET NULL - 사용자 삭제해도 서버 유지
    publisher_id = Column(
        UUID(as_uuid=True),
        ForeignKey("mcp_orch.users.id", ondelete="SET NULL"),
        nullable=True  # SET NULL 위해 nullable 필수
    )
```

### Alembic Migration 템플릿

```python
# CASCADE → SET NULL 변경
def upgrade():
    # 1. 기존 FK 제거
    op.drop_constraint('fk_publisher_id', 'marketplace_servers', type_='foreignkey')

    # 2. SET NULL FK 재생성
    op.create_foreign_key(
        'fk_publisher_id',
        'marketplace_servers', 'users',
        ['publisher_id'], ['id'],
        ondelete='SET NULL',
        source_schema='mcp_orch',
        referent_schema='mcp_orch'
    )
```

---

**참조**: `.claude/CLAUDE.md` → AUTO-WORKFLOW (DB Chain), db-code-writer Agent
