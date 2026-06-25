from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    app_name: str = "{{APP_NAME}}"
    debug: bool = False
    api_prefix: str = "/api"

    # Database — DBUSER 정책: 전용 스키마, public 금지
    database_url: str = "postgresql+asyncpg://{{APP_NAME_SNAKE}}_svc:changeme@localhost:5432/{{APP_NAME_SNAKE}}_db"
    database_url_sync: str = "postgresql://{{APP_NAME_SNAKE}}_svc:changeme@localhost:5432/{{APP_NAME_SNAKE}}_db"
    db_schema: str = "{{APP_NAME_SNAKE}}"

    # Connection Pool
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_pool_timeout: int = 30
    db_pool_recycle: int = 1800  # 30분 — RDS idle timeout 대비

    # JWT (자체 발급 HS256 토큰용 — 선택)
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60

    # ── MS Entra ID(Azure AD) JWT 검증 ───────────────────────────────────
    # BFF 가 Bearer 로 전달하는 토큰은 Entra id_token(RS256, JWKS 서명) 이다.
    # entra_tenant_id 가 설정되면 get_current_user 가 JWKS 로 서명을 실제 검증한다.
    # entra_client_id(= audience) 를 채우면 aud 까지 검증한다(권장). 비우면 aud 검증 생략.
    entra_tenant_id: str | None = None
    entra_client_id: str | None = None  # = JWT aud (Application/Client ID)
    # 신규 SSO 사용자 자동 등록(첫 로그인 시 User row 생성). false 면 미등록 사용자는 401.
    auth_auto_provision_users: bool = True
    # 개발 편의: JWT 없이 BFF 의 X-Auth-Email 헤더만 신뢰(서명 검증 우회). 운영에서 절대 true 금지.
    auth_trust_email_header: bool = False

    # CORS
    cors_origins: list[str] = ["http://localhost:{{FRONTEND_PORT}}"]

    model_config = {"env_file": ".env", "env_prefix": "{{APP_NAME_SNAKE}}_".upper()}


settings = Settings()
