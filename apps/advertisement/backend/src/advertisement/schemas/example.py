"""Example Pydantic schemas — 개발 패턴 레퍼런스

패턴:
- Request: 생성/수정용 (필수 필드만)
- Response: API 응답 (from_attributes=True로 ORM 모델 자동 변환)
- 필드명: snake_case (Python 표준)
"""
import uuid
from datetime import datetime

from pydantic import BaseModel


class ExampleCreate(BaseModel):
    name: str
    description: str | None = None


class ExampleUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


class ExampleResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
