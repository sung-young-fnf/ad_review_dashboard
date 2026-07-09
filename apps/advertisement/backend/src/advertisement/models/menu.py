import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from advertisement.database import Base


class Menu(Base):
    __tablename__ = "menus"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    menu_key: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String(255), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(100))
    route: Mapped[str | None] = mapped_column(String(500))
    parent_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("advertisement.menus.id"))
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    children = relationship("Menu", back_populates="parent")
    parent = relationship("Menu", back_populates="children", remote_side=[id])
    permissions = relationship("MenuPermission", back_populates="menu", cascade="all, delete-orphan")


class MenuPermission(Base):
    __tablename__ = "menu_permissions"
    __table_args__ = {"schema": "advertisement"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    menu_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("advertisement.menus.id", ondelete="CASCADE"))
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("advertisement.roles.id", ondelete="CASCADE"))
    can_view: Mapped[bool] = mapped_column(Boolean, default=True)

    menu = relationship("Menu", back_populates="permissions")
    role = relationship("Role", back_populates="menu_permissions")
