import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from advertisement.database import Base


class UserRole(Base):
    __tablename__ = "user_roles"
    __table_args__ = {"schema": "advertisement"}

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("advertisement.users.id", ondelete="CASCADE"), primary_key=True)
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("advertisement.roles.id", ondelete="CASCADE"), primary_key=True)
