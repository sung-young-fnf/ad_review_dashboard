"""Video(원본 영상) 모델 — 3단 트리의 루트.

Video 1──* Prompt 1──* GeneratedVideo
DB 레벨 ON DELETE CASCADE + passive_deletes 로 async 안전하게 하위 row 정리.
S3 객체 삭제는 서비스에서 별도 처리(키를 먼저 수집 후 삭제).
"""
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Float, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from advertisement.database import Base


class Video(Base):
    __tablename__ = "videos"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    s3_key: Mapped[str] = mapped_column(String(1024), nullable=False)
    file_name: Mapped[str | None] = mapped_column(String(512), nullable=True)
    file_size: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    content_type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    duration_sec: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    prompts: Mapped[list["Prompt"]] = relationship(  # noqa: F821
        back_populates="video",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
