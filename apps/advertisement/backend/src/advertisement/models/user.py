import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from advertisement.database import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(255))
    entra_object_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    department: Mapped[str | None] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(Enum("active", "inactive", name="user_status", schema="advertisement"), default="active")
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    roles = relationship("Role", secondary="advertisement.user_roles", back_populates="users")
