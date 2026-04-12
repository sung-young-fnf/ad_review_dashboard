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

    # JWT
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60

    # CORS
    cors_origins: list[str] = ["http://localhost:{{FRONTEND_PORT}}"]

    model_config = {"env_file": ".env", "env_prefix": "{{APP_NAME_SNAKE}}_".upper()}


settings = Settings()
