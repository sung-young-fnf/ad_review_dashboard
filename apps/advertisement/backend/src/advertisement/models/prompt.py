"""Prompt(분석 프롬프트, 수동 입력) 모델 — Video 하위."""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from advertisement.database import Base


class Prompt(Base):
    __tablename__ = "prompts"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    video_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("advertisement.videos.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    video: Mapped["Video"] = relationship(back_populates="prompts")  # noqa: F821
    generated_videos: Mapped[list["GeneratedVideo"]] = relationship(  # noqa: F821
        back_populates="prompt",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="GeneratedVideo.created_at",
    )
