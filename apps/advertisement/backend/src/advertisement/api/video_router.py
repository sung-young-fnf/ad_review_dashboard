"""Video router — 원본 영상 CRUD + 중첩 프롬프트(list/create)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.database import get_db
from advertisement.schemas.prompt import PromptCreate, PromptResponse
from advertisement.schemas.video import VideoCreate, VideoResponse, VideoUpdate
from advertisement.security.auth import get_current_user
from advertisement.services.prompt_service import PromptService
from advertisement.services.video_service import VideoService

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.get("", response_model=list[VideoResponse])
async def list_videos(skip: int = 0, limit: int = 50, db: AsyncSession = Depends(get_db)):
    return await VideoService.find_all(db, skip=skip, limit=limit)


@router.post("", response_model=VideoResponse, status_code=201)
async def create_video(dto: VideoCreate, db: AsyncSession = Depends(get_db)):
    return await VideoService.create(db, dto)


@router.get("/{video_id}", response_model=VideoResponse)
async def get_video(video_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await VideoService.find_by_id(db, video_id)
    if not result:
        raise HTTPException(status_code=404, detail="Video not found")
    return result


@router.put("/{video_id}", response_model=VideoResponse)
async def update_video(video_id: UUID, dto: VideoUpdate, db: AsyncSession = Depends(get_db)):
    result = await VideoService.update(db, video_id, dto)
    if not result:
        raise HTTPException(status_code=404, detail="Video not found")
    return result


@router.delete("/{video_id}", status_code=204)
async def delete_video(video_id: UUID, db: AsyncSession = Depends(get_db)):
    if not await VideoService.delete(db, video_id):
        raise HTTPException(status_code=404, detail="Video not found")


# ── 중첩: 프롬프트 ────────────────────────────────────────────────────
@router.get("/{video_id}/prompts", response_model=list[PromptResponse])
async def list_prompts(video_id: UUID, db: AsyncSession = Depends(get_db)):
    return await PromptService.find_by_video(db, video_id)


@router.post("/{video_id}/prompts", response_model=PromptResponse, status_code=201)
async def create_prompt(video_id: UUID, dto: PromptCreate, db: AsyncSession = Depends(get_db)):
    result = await PromptService.create(db, video_id, dto)
    if not result:
        raise HTTPException(status_code=404, detail="Video not found")
    return result
