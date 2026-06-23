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
"""
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from {{APP_NAME_SNAKE}}.database import get_db
from {{APP_NAME_SNAKE}}.models.user import User

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Bearer 토큰에서 사용자 추출 — BFF proxy가 전달한 JWT

    SSO email 흐름: NextAuth(token.email) → session.user.email → BFF → 여기.
      ① Bearer JWT 검증 시: payload 의 email → preferred_username → upn 순으로 추출.
         Entra(Azure AD) 는 email claim 이 비어있고 preferred_username/upn 에 오는 경우가 많다.
      ② BFF 가 X-Auth-Email 헤더로 직접 전달하는 패턴(관리 UI 등)도 가능.
      두 경우 모두 email 이 빈 값/"unknown" 이면 401 로 거부 — 조용히 'unknown' user 를 만들지 말 것.
    """
    token = credentials.credentials

    # TODO: JWT 검증 (python-jose 또는 pyjwt)
    # payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    # email = payload.get("email") or payload.get("preferred_username") or payload.get("upn")
    # if not email: raise HTTPException(401, "email claim 누락 (재로그인 필요)")  # unknown 저장 금지

    # Placeholder: 토큰에서 user_id 추출 후 DB 조회
    # 실제 구현 시 JWT 검증 + DB 조회로 교체
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="JWT verification not implemented")


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
