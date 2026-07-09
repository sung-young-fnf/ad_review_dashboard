from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    app_name: str = "advertisement"
    debug: bool = False
    api_prefix: str = "/api"

    # ── Database ─────────────────────────────────────────────────────────
    # cloudy 테넌트가 표준 이름 DATABASE_URL 로 제공한다(env_prefix 미적용).
    #   예: postgresql://advertisement_svc:***@...ap-northeast-2.rds.amazonaws.com:5432/advertisement
    # async(asyncpg) / sync(psycopg2) URL 은 아래 property 로 파생한다.
    database_url_raw: str = Field(
        default="postgresql://advertisement_svc:changeme@localhost:5432/advertisement",
        validation_alias=AliasChoices("DATABASE_URL", "ADVERTISEMENT_DATABASE_URL"),
    )
    db_schema: str = "advertisement"

    # Connection Pool
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_pool_timeout: int = 30
    db_pool_recycle: int = 1800  # 30분 — RDS idle timeout 대비

    # ── S3 (cloudy) ──────────────────────────────────────────────────────
    # AWS SDK 는 프로필 cloudy-advertisement 사용, S3 는 advertisement/ prefix 아래만 접근.
    s3_bucket: str = Field(default="dt-ane2-s3-dev-dcs-cloudy", validation_alias=AliasChoices("S3_BUCKET"))
    s3_prefix: str = Field(default="advertisement/", validation_alias=AliasChoices("S3_PREFIX"))
    aws_region: str = Field(default="ap-northeast-2", validation_alias=AliasChoices("AWS_REGION"))
    aws_profile: str | None = Field(default="cloudy-advertisement", validation_alias=AliasChoices("AWS_PROFILE"))
    s3_presign_expiry: int = 3600  # presigned URL TTL(초)

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
    cors_origins: list[str] = ["http://localhost:3200"]

    model_config = {
        "env_file": ".env",
        "env_prefix": "ADVERTISEMENT_",
        "extra": "ignore",  # .env 의 프론트/공용 키(AUTH_SECRET 등)는 무시
    }

    @property
    def database_url(self) -> str:
        """비동기 드라이버(asyncpg) URL — 앱 런타임."""
        url = self.database_url_raw
        if "+asyncpg" in url:
            return url
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)

    @property
    def database_url_sync(self) -> str:
        """동기 드라이버(psycopg2) URL — Alembic 마이그레이션."""
        return self.database_url_raw.replace("postgresql+asyncpg://", "postgresql://", 1)


settings = Settings()
