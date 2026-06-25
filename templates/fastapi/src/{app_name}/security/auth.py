"""인증 의존성 — FastAPI Depends 패턴

사용법:
  @router.get("/me")
  async def me(user = Depends(get_current_user)):
      return user

  @router.post("/admin-only")
  async def admin(user = Depends(require_admin)):
      return {"admin": True}

  @router.get("/editor-page")
  async def editor(user = Depends(require_role("editor"))):
      return {"role": "editor"}

── 인증 흐름(SSO) ───────────────────────────────────────────────────────────
  Browser → NextAuth(BFF) → /api/v1/* proxy → 이 backend.
  BFF 는 Entra id_token(RS256, JWKS 서명) 을 `Authorization: Bearer <jwt>` 로 전달하고,
  편의를 위해 `X-Auth-Email` 헤더도 함께 보낸다.

  get_current_user 는:
    1) entra_tenant_id 가 설정돼 있으면 → JWKS 로 Bearer JWT 서명/만료(/aud) 를 실제 검증하고
       payload 의 email → preferred_username → upn 순으로 이메일을 추출한다(Entra 는 email claim 이
       비어 있고 preferred_username/upn 에 들어오는 경우가 많다).
    2) entra_tenant_id 가 없고 auth_trust_email_header=true(개발 모드) 이면 → 서명 검증 없이
       X-Auth-Email 헤더만 신뢰한다. **운영에서는 절대 사용 금지.**
  추출한 이메일로 DB User 를 조회하고, 없으면 auth_auto_provision_users 에 따라 생성 또는 401.
  email 이 비어있거나 'unknown' 이면 조용히 통과시키지 않고 항상 401 로 거부한다.
"""
from functools import lru_cache

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from {{APP_NAME_SNAKE}}.config import settings
from {{APP_NAME_SNAKE}}.database import get_db
from {{APP_NAME_SNAKE}}.models.user import User

# auto_error=False: Bearer 가 없어도 즉시 403 내지 않고, header-trust(개발) 경로를 허용하기 위함.
security = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Not authenticated",
    headers={"WWW-Authenticate": "Bearer"},
)


@lru_cache(maxsize=4)
def _jwks_client(tenant_id: str) -> PyJWKClient:
    """Entra JWKS 클라이언트(테넌트별 캐시). 서명 키를 자동 fetch + 캐시한다."""
    uri = f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys"
    return PyJWKClient(uri)


def _extract_email(payload: dict) -> str | None:
    """Entra claim 에서 이메일 추출 — email → preferred_username → upn 순."""
    return payload.get("email") or payload.get("preferred_username") or payload.get("upn")


def _verify_entra_jwt(token: str) -> dict:
    """Entra id_token(RS256) 서명/만료/(aud) 검증 후 payload 반환."""
    try:
        signing_key = _jwks_client(settings.entra_tenant_id).get_signing_key_from_jwt(token)
        options = {"verify_aud": bool(settings.entra_client_id)}
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.entra_client_id if settings.entra_client_id else None,
            options=options,
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired (재로그인 필요)",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def _get_or_create_user(db: AsyncSession, email: str, name: str | None, entra_oid: str | None) -> User:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is not None:
        return user

    if not settings.auth_auto_provision_users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not registered")

    user = User(email=email, name=name, entra_object_id=entra_oid)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Bearer 토큰(Entra id_token) 을 검증하고 DB User 를 반환한다.

    email/preferred_username/upn 이 모두 비거나 'unknown' 이면 401. (조용히 'unknown' user 금지)
    """
    email: str | None = None
    name: str | None = None
    entra_oid: str | None = None

    if settings.entra_tenant_id:
        # 운영 경로 — JWT 서명 실제 검증
        if credentials is None:
            raise _UNAUTHORIZED
        payload = _verify_entra_jwt(credentials.credentials)
        email = _extract_email(payload)
        name = payload.get("name")
        entra_oid = payload.get("oid")
    elif settings.auth_trust_email_header:
        # 개발 경로 — 서명 검증 없이 BFF 헤더만 신뢰 (운영 금지)
        email = request.headers.get("X-Auth-Email")
    else:
        # SSO 미구성 — 인증 불가
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Auth not configured (set entra_tenant_id, or auth_trust_email_header for dev)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not email or email.lower() == "unknown":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="email claim 누락 (재로그인 필요)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return await _get_or_create_user(db, email=email, name=name, entra_oid=entra_oid)


async def require_admin(user: User = Depends(get_current_user)) -> User:
    """관리자 권한 필수"""
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def require_role(*role_names: str):
    """특정 역할 필수 — require_role("editor", "admin")"""
    async def dependency(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> User:
        result = await db.execute(
            select(User).where(User.id == user.id).options(selectinload(User.roles))
        )
        user_with_roles = result.scalar_one()
        user_role_names = {r.name for r in user_with_roles.roles}

        if not user_role_names.intersection(role_names):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required roles: {', '.join(role_names)}",
            )
        return user_with_roles
    return dependency
