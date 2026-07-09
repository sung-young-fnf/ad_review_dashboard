"""GeneratedVideo router — AI 영상 삭제(생성은 prompt 하위 라우트)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.database import get_db
from advertisement.schemas.generated_video import GeneratedVideoResponse
from advertisement.security.auth import get_current_user
from advertisement.services.generated_video_service import GeneratedVideoService

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.get("", response_model=list[GeneratedVideoResponse])
async def list_all_generated_videos(skip: int = 0, limit: int = 200, db: AsyncSession = Depends(get_db)):
    """전체 AI 영상 목록 — 비교 뷰 picker 용."""
    return await GeneratedVideoService.find_all(db, skip=skip, limit=limit)


@router.delete("/{gen_id}", status_code=204)
async def delete_generated_video(gen_id: UUID, db: AsyncSession = Depends(get_db)):
    if not await GeneratedVideoService.delete(db, gen_id):
        raise HTTPException(status_code=404, detail="Generated video not found")
