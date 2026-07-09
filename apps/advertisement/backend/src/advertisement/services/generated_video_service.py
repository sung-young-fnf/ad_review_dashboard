"""GeneratedVideo service — AI 영상(등록만)."""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.models.generated_video import GeneratedVideo
from advertisement.models.prompt import Prompt
from advertisement.schemas.generated_video import GeneratedVideoCreate, GeneratedVideoResponse
from advertisement.services.s3_service import S3Service

logger = logging.getLogger(__name__)


class GeneratedVideoService:

    @staticmethod
    def _to_response(model: GeneratedVideo) -> GeneratedVideoResponse:
        resp = GeneratedVideoResponse.model_validate(model)
        resp.play_url = S3Service.presign_get(model.s3_key)
        return resp

    @staticmethod
    async def find_all(db: AsyncSession, skip: int = 0, limit: int = 200) -> list[GeneratedVideoResponse]:
        """전체 AI 영상 목록 — 비교 뷰 picker 용."""
        result = await db.execute(
            select(GeneratedVideo).order_by(GeneratedVideo.created_at.desc()).offset(skip).limit(limit)
        )
        return [GeneratedVideoService._to_response(row) for row in result.scalars().all()]

    @staticmethod
    async def find_by_prompt(db: AsyncSession, prompt_id: UUID) -> list[GeneratedVideoResponse]:
        result = await db.execute(
            select(GeneratedVideo).where(GeneratedVideo.prompt_id == prompt_id).order_by(GeneratedVideo.created_at)
        )
        return [GeneratedVideoService._to_response(row) for row in result.scalars().all()]

    @staticmethod
    async def create(db: AsyncSession, prompt_id: UUID, dto: GeneratedVideoCreate) -> GeneratedVideoResponse | None:
        # 프롬프트 존재 확인 (없으면 None → 라우터 404)
        exists = await db.execute(select(Prompt.id).where(Prompt.id == prompt_id))
        if exists.scalar_one_or_none() is None:
            return None
        model = GeneratedVideo(prompt_id=prompt_id, **dto.model_dump())
        db.add(model)
        await db.commit()
        await db.refresh(model)
        logger.info(f"Created generated_video: {model.id} (prompt={prompt_id})")
        return GeneratedVideoService._to_response(model)

    @staticmethod
    async def delete(db: AsyncSession, gen_id: UUID) -> bool:
        result = await db.execute(select(GeneratedVideo).where(GeneratedVideo.id == gen_id))
        model = result.scalar_one_or_none()
        if not model:
            return False
        key = model.s3_key
        await db.delete(model)
        await db.commit()
        try:
            await S3Service.delete(key)
        except Exception as exc:  # S3 삭제 실패해도 DB 삭제는 유지 (고아 객체는 로그로 추적)
            logger.warning(f"S3 delete failed for {key}: {exc}")
        return True
