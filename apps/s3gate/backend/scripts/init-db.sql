-- ============================================================
-- DBUSER 정책 기반 DB 초기화 스크립트
-- 서비스: s3gate
-- 실행: psql -U postgres -f init-db.sql
--
-- Owner 3단 분리:
--   _adm           = DB + Schema Owner (LOGIN, DBA/파트장급)
--   _object_owner_role = Object Owner (NOLOGIN, DDL+DML)
--   _dml_role      = DML 전용 (NOLOGIN)
--
-- 계정:
--   _oper          = 개발자 (LOGIN, SET ROLE object_owner_role)
--   _ops           = 마이그레이션 도구 (LOGIN, SET ROLE object_owner_role)
--   _svc           = 앱 서비스 (LOGIN, DML 전용)
-- ============================================================

-- 0. Database 생성 (postgres 유저로 실행)
-- CREATE DATABASE s3gate_db OWNER s3gate_adm;
-- \c s3gate_db

-- ─── 1. Roles (NOLOGIN) ─────────────────────────────────

-- Object Owner Role: DDL + DML (스키마 내 모든 오브젝트 소유)
CREATE ROLE s3gate_object_owner_role NOLOGIN;

-- DML Role: DML + 시퀀스 + EXECUTE (스키마 단위)
CREATE ROLE s3gate_dml_role NOLOGIN;

-- ─── 2. Login Accounts ──────────────────────────────────

-- Admin: DB + Schema Owner
CREATE USER s3gate_adm WITH LOGIN PASSWORD 'CHANGE_ME_ADM';

-- 개발자 (공유)
CREATE USER s3gate_oper WITH LOGIN PASSWORD 'CHANGE_ME_OPER';
GRANT s3gate_object_owner_role TO s3gate_oper;
ALTER USER s3gate_oper SET ROLE s3gate_object_owner_role;

-- 마이그레이션 도구 (Alembic)
CREATE USER s3gate_alembic_ops WITH LOGIN PASSWORD 'CHANGE_ME_OPS';
GRANT s3gate_object_owner_role TO s3gate_alembic_ops;
ALTER USER s3gate_alembic_ops SET ROLE s3gate_object_owner_role;

-- 서비스 (앱용, DML 전용)
CREATE USER s3gate_svc WITH LOGIN PASSWORD 'CHANGE_ME_SVC';
GRANT s3gate_dml_role TO s3gate_svc;
ALTER USER s3gate_svc SET ROLE s3gate_dml_role;

-- ─── 3. Database 소유권 ─────────────────────────────────

ALTER DATABASE s3gate_db OWNER TO s3gate_adm;

-- ─── 4. Schema 생성 (adm으로 실행 또는 postgres) ────────

CREATE SCHEMA IF NOT EXISTS s3gate AUTHORIZATION s3gate_adm;

-- ─── 5. Schema 권한 부여 ────────────────────────────────

-- object_owner_role: CREATE + USAGE (DDL 실행 가능)
GRANT CREATE, USAGE ON SCHEMA s3gate TO s3gate_object_owner_role;

-- dml_role: USAGE만 (DDL 불가)
GRANT USAGE ON SCHEMA s3gate TO s3gate_dml_role;

-- ─── 6. Default Privileges ──────────────────────────────
-- object_owner_role이 생성하는 오브젝트에 대해 dml_role에 자동 부여

ALTER DEFAULT PRIVILEGES FOR ROLE s3gate_object_owner_role
    IN SCHEMA s3gate
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO s3gate_dml_role;

ALTER DEFAULT PRIVILEGES FOR ROLE s3gate_object_owner_role
    IN SCHEMA s3gate
    GRANT USAGE, SELECT ON SEQUENCES TO s3gate_dml_role;

ALTER DEFAULT PRIVILEGES FOR ROLE s3gate_object_owner_role
    IN SCHEMA s3gate
    GRANT EXECUTE ON FUNCTIONS TO s3gate_dml_role;

-- ─── 7. search_path 설정 ────────────────────────────────
-- public 스키마 사용 금지 — 서비스 전용 스키마만 사용

ALTER USER s3gate_oper SET search_path TO s3gate;
ALTER USER s3gate_alembic_ops SET search_path TO s3gate;
ALTER USER s3gate_svc SET search_path TO s3gate;

-- ─── Done ───────────────────────────────────────────────
-- 비밀번호는 반드시 변경하세요!
-- Production: AWS Secrets Manager 또는 K8s Secrets 사용
