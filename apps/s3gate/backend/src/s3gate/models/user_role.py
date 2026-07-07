import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from s3gate.database import Base


class UserRole(Base):
    __tablename__ = "user_roles"
    __table_args__ = {"schema": "s3gate"}

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("s3gate.users.id", ondelete="CASCADE"), primary_key=True)
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("s3gate.roles.id", ondelete="CASCADE"), primary_key=True)
