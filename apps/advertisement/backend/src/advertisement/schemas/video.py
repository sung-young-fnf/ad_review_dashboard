"""Video 스키마 — 원본 영상."""
import uuid
from datetime import datetime

from pydantic import BaseModel


class VideoCreate(BaseModel):
    title: str
    description: str | None = None
    s3_key: str  # presign 으로 업로드 후 받은 키
    file_name: str | None = None
    file_size: int | None = None
    content_type: str | None = None
    duration_sec: float | None = None


class VideoUpdate(BaseModel):
    title: str | None = None
    description: str | None = None


class VideoResponse(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    s3_key: str
    file_name: str | None
    file_size: int | None
    content_type: str | None
    duration_sec: float | None
    created_at: datetime
    prompt_count: int = 0
    generated_count: int = 0
    play_url: str | None = None  # 서비스에서 presigned GET URL 주입

    model_config = {"from_attributes": True}
