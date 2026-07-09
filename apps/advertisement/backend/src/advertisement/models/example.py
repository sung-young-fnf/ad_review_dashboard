"""Example SQLAlchemy model — 개발 패턴 레퍼런스

패턴:
- __table_args__ = {"schema": "..."} — DBUSER 정책: 전용 스키마 필수, public 금지
- UUID PK, server_default=func.now() for timestamps
- relationship()으로 연관 모델 정의
"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from advertisement.database import Base


class Example(Base):
    __tablename__ = "examples"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
