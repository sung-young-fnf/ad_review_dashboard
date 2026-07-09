"""업로드 presign 스키마."""
from typing import Literal

from pydantic import BaseModel


class PresignRequest(BaseModel):
    purpose: Literal["original", "generated"]
    filename: str
    content_type: str


class PresignResponse(BaseModel):
    upload_url: str
    key: str


class UploadResult(BaseModel):
    key: str
    file_name: str | None = None
    file_size: int | None = None
    content_type: str | None = None
