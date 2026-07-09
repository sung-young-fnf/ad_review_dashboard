"""Video service — 원본 영상. 목록은 프롬프트/AI영상 카운트 포함, 삭제는 S3 cascade."""
import logging
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.models.generated_video import GeneratedVideo
from advertisement.models.prompt import Prompt
from advertisement.models.video import Video
from advertisement.schemas.video import VideoCreate, VideoResponse, VideoUpdate
from advertisement.services.s3_service import S3Service

logger = logging.getLogger(__name__)


class VideoService:

    @staticmethod
    def _to_response(model: Video, prompt_count: int = 0, generated_count: int = 0) -> VideoResponse:
        resp = VideoResponse.model_validate(model)
        resp.prompt_count = prompt_count
        resp.generated_count = generated_count
        resp.play_url = S3Service.presign_get(model.s3_key)
        return resp

    @staticmethod
    async def find_all(db: AsyncSession, skip: int = 0, limit: int = 50) -> list[VideoResponse]:
        prompt_count = (
            select(func.count(Prompt.id)).where(Prompt.video_id == Video.id).correlate(Video).scalar_subquery()
        )
        generated_count = (
            select(func.count(GeneratedVideo.id))
            .select_from(GeneratedVideo)
            .join(Prompt, GeneratedVideo.prompt_id == Prompt.id)
            .where(Prompt.video_id == Video.id)
            .correlate(Video)
            .scalar_subquery()
        )
        result = await db.execute(
            select(Video, prompt_count, generated_count)
            .order_by(Video.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return [VideoService._to_response(v, pc, gc) for v, pc, gc in result.all()]

    @staticmethod
    async def _counts(db: AsyncSession, video_id: UUID) -> tuple[int, int]:
        pc = (await db.execute(select(func.count(Prompt.id)).where(Prompt.video_id == video_id))).scalar_one()
        gc = (
            await db.execute(
                select(func.count(GeneratedVideo.id))
                .join(Prompt, GeneratedVideo.prompt_id == Prompt.id)
                .where(Prompt.video_id == video_id)
            )
        ).scalar_one()
        return pc, gc

    @staticmethod
    async def find_by_id(db: AsyncSession, video_id: UUID) -> VideoResponse | None:
        result = await db.execute(select(Video).where(Video.id == video_id))
        model = result.scalar_one_or_none()
        if not model:
            return None
        pc, gc = await VideoService._counts(db, video_id)
        return VideoService._to_response(model, pc, gc)

    @staticmethod
    async def create(db: AsyncSession, dto: VideoCreate) -> VideoResponse:
        model = Video(**dto.model_dump())
        db.add(model)
        await db.commit()
        await db.refresh(model)
        logger.info(f"Created video: {model.id}")
        return VideoService._to_response(model)

    @staticmethod
    async def update(db: AsyncSession, video_id: UUID, dto: VideoUpdate) -> VideoResponse | None:
        result = await db.execute(select(Video).where(Video.id == video_id))
        model = result.scalar_one_or_none()
        if not model:
            return None
        for field, value in dto.model_dump(exclude_unset=True).items():
            setattr(model, field, value)
        await db.commit()
        return await VideoService.find_by_id(db, video_id)

    @staticmethod
    async def delete(db: AsyncSession, video_id: UUID) -> bool:
        result = await db.execute(select(Video).where(Video.id == video_id))
        model = result.scalar_one_or_none()
        if not model:
            return False
        # 삭제 전 S3 키 수집: 원본 + 하위 모든 AI 영상
        keys = [model.s3_key]
        gen_keys = (
            await db.execute(
                select(GeneratedVideo.s3_key)
                .join(Prompt, GeneratedVideo.prompt_id == Prompt.id)
                .where(Prompt.video_id == video_id)
            )
        ).scalars().all()
        keys.extend(gen_keys)

        await db.delete(model)  # DB cascade → prompts + generated_videos row 삭제
        await db.commit()

        for key in keys:
            try:
                await S3Service.delete(key)
            except Exception as exc:
                logger.warning(f"S3 delete failed for {key}: {exc}")
        return True
