"""Prompt service — 수동 입력 프롬프트. 중첩 AI 영상까지 함께 반환."""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from advertisement.models.prompt import Prompt
from advertisement.models.video import Video
from advertisement.schemas.prompt import PromptCreate, PromptResponse, PromptUpdate
from advertisement.services.s3_service import S3Service

logger = logging.getLogger(__name__)


class PromptService:

    @staticmethod
    def _to_response(model: Prompt) -> PromptResponse:
        """generated_videos 는 selectinload 로 미리 로드돼 있어야 함(async lazy-load 금지)."""
        resp = PromptResponse.model_validate(model)
        for gv in resp.generated_videos:
            gv.play_url = S3Service.presign_get(gv.s3_key)
        return resp

    @staticmethod
    async def _fetch_one(db: AsyncSession, prompt_id: UUID) -> PromptResponse | None:
        result = await db.execute(
            select(Prompt).where(Prompt.id == prompt_id).options(selectinload(Prompt.generated_videos))
        )
        model = result.scalar_one_or_none()
        return PromptService._to_response(model) if model else None

    @staticmethod
    async def find_by_video(db: AsyncSession, video_id: UUID) -> list[PromptResponse]:
        result = await db.execute(
            select(Prompt)
            .where(Prompt.video_id == video_id)
            .options(selectinload(Prompt.generated_videos))
            .order_by(Prompt.created_at)
        )
        return [PromptService._to_response(row) for row in result.scalars().all()]

    @staticmethod
    async def create(db: AsyncSession, video_id: UUID, dto: PromptCreate) -> PromptResponse | None:
        # 영상 존재 확인 (없으면 None → 404)
        exists = await db.execute(select(Video.id).where(Video.id == video_id))
        if exists.scalar_one_or_none() is None:
            return None
        model = Prompt(video_id=video_id, **dto.model_dump())
        db.add(model)
        await db.commit()
        logger.info(f"Created prompt: {model.id} (video={video_id})")
        return await PromptService._fetch_one(db, model.id)

    @staticmethod
    async def update(db: AsyncSession, prompt_id: UUID, dto: PromptUpdate) -> PromptResponse | None:
        result = await db.execute(select(Prompt).where(Prompt.id == prompt_id))
        model = result.scalar_one_or_none()
        if not model:
            return None
        for field, value in dto.model_dump(exclude_unset=True).items():
            setattr(model, field, value)
        await db.commit()
        return await PromptService._fetch_one(db, prompt_id)

    @staticmethod
    async def delete(db: AsyncSession, prompt_id: UUID) -> bool:
        result = await db.execute(
            select(Prompt).where(Prompt.id == prompt_id).options(selectinload(Prompt.generated_videos))
        )
        model = result.scalar_one_or_none()
        if not model:
            return False
        keys = [gv.s3_key for gv in model.generated_videos]  # 하위 AI 영상 S3 키
        await db.delete(model)  # DB cascade → generated_videos row 삭제
        await db.commit()
        for key in keys:
            try:
                await S3Service.delete(key)
            except Exception as exc:
                logger.warning(f"S3 delete failed for {key}: {exc}")
        return True
