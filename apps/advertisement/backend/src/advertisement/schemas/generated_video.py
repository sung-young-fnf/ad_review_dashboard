"""GeneratedVideo 스키마."""
import uuid
from datetime import datetime

from pydantic import BaseModel


class GeneratedVideoCreate(BaseModel):
    title: str
    s3_key: str
    file_name: str | None = None
    file_size: int | None = None
    content_type: str | None = None


class GeneratedVideoResponse(BaseModel):
    id: uuid.UUID
    prompt_id: uuid.UUID
    title: str
    s3_key: str
    file_name: str | None
    file_size: int | None
    content_type: str | None
    created_at: datetime
    play_url: str | None = None  # 서비스에서 presigned GET URL 주입

    model_config = {"from_attributes": True}
