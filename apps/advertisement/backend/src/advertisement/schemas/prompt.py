"""Prompt 스키마 — 수동 입력(title + content)."""
import uuid
from datetime import datetime

from pydantic import BaseModel

from advertisement.schemas.generated_video import GeneratedVideoResponse


class PromptCreate(BaseModel):
    title: str
    content: str


class PromptUpdate(BaseModel):
    title: str | None = None
    content: str | None = None


class PromptResponse(BaseModel):
    id: uuid.UUID
    video_id: uuid.UUID
    title: str
    content: str
    created_at: datetime
    generated_videos: list[GeneratedVideoResponse] = []  # 중첩: 이 프롬프트로 만든 AI 영상

    model_config = {"from_attributes": True}
