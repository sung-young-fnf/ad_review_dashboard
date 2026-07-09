"""Prompt router — 프롬프트 수정/삭제 + 중첩 AI 영상(list/create)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.database import get_db
from advertisement.schemas.generated_video import GeneratedVideoCreate, GeneratedVideoResponse
from advertisement.schemas.prompt import PromptResponse, PromptUpdate
from advertisement.security.auth import get_current_user
from advertisement.services.generated_video_service import GeneratedVideoService
from advertisement.services.prompt_service import PromptService

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.put("/{prompt_id}", response_model=PromptResponse)
async def update_prompt(prompt_id: UUID, dto: PromptUpdate, db: AsyncSession = Depends(get_db)):
    result = await PromptService.update(db, prompt_id, dto)
    if not result:
        raise HTTPException(status_code=404, detail="Prompt not found")
    return result


@router.delete("/{prompt_id}", status_code=204)
async def delete_prompt(prompt_id: UUID, db: AsyncSession = Depends(get_db)):
    if not await PromptService.delete(db, prompt_id):
        raise HTTPException(status_code=404, detail="Prompt not found")


# ── 중첩: AI 영상 ─────────────────────────────────────────────────────
@router.get("/{prompt_id}/generated-videos", response_model=list[GeneratedVideoResponse])
async def list_generated_videos(prompt_id: UUID, db: AsyncSession = Depends(get_db)):
    return await GeneratedVideoService.find_by_prompt(db, prompt_id)


@router.post("/{prompt_id}/generated-videos", response_model=GeneratedVideoResponse, status_code=201)
async def create_generated_video(prompt_id: UUID, dto: GeneratedVideoCreate, db: AsyncSession = Depends(get_db)):
    result = await GeneratedVideoService.create(db, prompt_id, dto)
    if not result:
        raise HTTPException(status_code=404, detail="Prompt not found")
    return result
