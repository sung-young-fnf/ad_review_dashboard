-- ============================================================
-- DBUSER 정책 기반 DB 초기화 스크립트 (NestJS + Prisma)
-- 서비스: {{APP_NAME}}
-- 실행: psql -U postgres -f init-db.sql
--
-- Owner 3단 분리:
--   _adm           = DB + Schema Owner (LOGIN, DBA/파트장급)
--   _object_owner_role = Object Owner (NOLOGIN, DDL+DML)
--   _dml_role      = DML 전용 (NOLOGIN)
--
-- 계정:
--   _oper          = 개발자 (LOGIN, SET ROLE object_owner_role)
--   _ops           = Prisma Migrate (LOGIN, SET ROLE object_owner_role)
--   _svc           = 앱 서비스 (LOGIN, DML 전용)
-- ============================================================

-- 0. Database
-- CREATE DATABASE {{APP_NAME_SNAKE}}_db OWNER {{APP_NAME_SNAKE}}_adm;
-- \c {{APP_NAME_SNAKE}}_db

-- ─── 1. Roles (NOLOGIN) ─────────────────────────────────

CREATE ROLE {{APP_NAME_SNAKE}}_object_owner_role NOLOGIN;
CREATE ROLE {{APP_NAME_SNAKE}}_dml_role NOLOGIN;

-- ─── 2. Login Accounts ──────────────────────────────────

CREATE USER {{APP_NAME_SNAKE}}_adm WITH LOGIN PASSWORD 'CHANGE_ME_ADM';

CREATE USER {{APP_NAME_SNAKE}}_oper WITH LOGIN PASSWORD 'CHANGE_ME_OPER';
GRANT {{APP_NAME_SNAKE}}_object_owner_role TO {{APP_NAME_SNAKE}}_oper;
ALTER USER {{APP_NAME_SNAKE}}_oper SET ROLE {{APP_NAME_SNAKE}}_object_owner_role;

-- Prisma Migrate 도구 계정
CREATE USER {{APP_NAME_SNAKE}}_prisma_ops WITH LOGIN PASSWORD 'CHANGE_ME_OPS';
GRANT {{APP_NAME_SNAKE}}_object_owner_role TO {{APP_NAME_SNAKE}}_prisma_ops;
ALTER USER {{APP_NAME_SNAKE}}_prisma_ops SET ROLE {{APP_NAME_SNAKE}}_object_owner_role;

CREATE USER {{APP_NAME_SNAKE}}_svc WITH LOGIN PASSWORD 'CHANGE_ME_SVC';
GRANT {{APP_NAME_SNAKE}}_dml_role TO {{APP_NAME_SNAKE}}_svc;
ALTER USER {{APP_NAME_SNAKE}}_svc SET ROLE {{APP_NAME_SNAKE}}_dml_role;

-- ─── 3. Database ────────────────────────────────────────

ALTER DATABASE {{APP_NAME_SNAKE}}_db OWNER TO {{APP_NAME_SNAKE}}_adm;

-- ─── 4. Schema ──────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS {{APP_NAME_SNAKE}} AUTHORIZATION {{APP_NAME_SNAKE}}_adm;

-- ─── 5. Schema 권한 ─────────────────────────────────────

GRANT CREATE, USAGE ON SCHEMA {{APP_NAME_SNAKE}} TO {{APP_NAME_SNAKE}}_object_owner_role;
GRANT USAGE ON SCHEMA {{APP_NAME_SNAKE}} TO {{APP_NAME_SNAKE}}_dml_role;

-- ─── 6. Default Privileges ──────────────────────────────

ALTER DEFAULT PRIVILEGES FOR ROLE {{APP_NAME_SNAKE}}_object_owner_role
    IN SCHEMA {{APP_NAME_SNAKE}}
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {{APP_NAME_SNAKE}}_dml_role;

ALTER DEFAULT PRIVILEGES FOR ROLE {{APP_NAME_SNAKE}}_object_owner_role
    IN SCHEMA {{APP_NAME_SNAKE}}
    GRANT USAGE, SELECT ON SEQUENCES TO {{APP_NAME_SNAKE}}_dml_role;

ALTER DEFAULT PRIVILEGES FOR ROLE {{APP_NAME_SNAKE}}_object_owner_role
    IN SCHEMA {{APP_NAME_SNAKE}}
    GRANT EXECUTE ON FUNCTIONS TO {{APP_NAME_SNAKE}}_dml_role;

-- ─── 7. search_path ─────────────────────────────────────

ALTER USER {{APP_NAME_SNAKE}}_oper SET search_path TO {{APP_NAME_SNAKE}};
ALTER USER {{APP_NAME_SNAKE}}_prisma_ops SET search_path TO {{APP_NAME_SNAKE}};
ALTER USER {{APP_NAME_SNAKE}}_svc SET search_path TO {{APP_NAME_SNAKE}};
