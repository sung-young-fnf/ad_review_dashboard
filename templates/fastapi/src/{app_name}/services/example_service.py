"""Example service — 개발 패턴 레퍼런스

패턴:
- Router(Controller) → Service → DB (3-Layer)
- Service는 비즈니스 로직 + DB 접근
- _convert_to_response(): ORM 모델 → Pydantic 응답 변환 (mcp-orbit 패턴)
- async session으로 비동기 DB 접근
"""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from {{APP_NAME_SNAKE}}.models.example import Example
from {{APP_NAME_SNAKE}}.schemas.example import ExampleCreate, ExampleUpdate, ExampleResponse

logger = logging.getLogger(__name__)


class ExampleService:

    @staticmethod
    def _convert_to_response(model: Example) -> ExampleResponse:
        """ORM 모델 → Pydantic 응답 변환"""
        return ExampleResponse.model_validate(model)

    @staticmethod
    async def find_all(db: AsyncSession, skip: int = 0, limit: int = 20) -> list[ExampleResponse]:
        result = await db.execute(
            select(Example).offset(skip).limit(limit).order_by(Example.created_at.desc())
        )
        return [ExampleService._convert_to_response(row) for row in result.scalars().all()]

    @staticmethod
    async def find_by_id(db: AsyncSession, example_id: UUID) -> ExampleResponse | None:
        result = await db.execute(select(Example).where(Example.id == example_id))
        model = result.scalar_one_or_none()
        return ExampleService._convert_to_response(model) if model else None

    @staticmethod
    async def create(db: AsyncSession, dto: ExampleCreate) -> ExampleResponse:
        model = Example(**dto.model_dump())
        db.add(model)
        await db.commit()
        await db.refresh(model)
        logger.info(f"Created example: {model.id}")
        return ExampleService._convert_to_response(model)

    @staticmethod
    async def update(db: AsyncSession, example_id: UUID, dto: ExampleUpdate) -> ExampleResponse | None:
        result = await db.execute(select(Example).where(Example.id == example_id))
        model = result.scalar_one_or_none()
        if not model:
            return None

        for field, value in dto.model_dump(exclude_unset=True).items():
            setattr(model, field, value)

        await db.commit()
        await db.refresh(model)
        return ExampleService._convert_to_response(model)

    @staticmethod
    async def delete(db: AsyncSession, example_id: UUID) -> bool:
        result = await db.execute(select(Example).where(Example.id == example_id))
        model = result.scalar_one_or_none()
        if not model:
            return False

        await db.delete(model)
        await db.commit()
        return True
