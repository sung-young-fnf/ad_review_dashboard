import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from {{APP_NAME_SNAKE}}.database import Base


class UserRole(Base):
    __tablename__ = "user_roles"
    __table_args__ = {"schema": "{{APP_NAME_SNAKE}}"}

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("{{APP_NAME_SNAKE}}.users.id", ondelete="CASCADE"), primary_key=True)
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("{{APP_NAME_SNAKE}}.roles.id", ondelete="CASCADE"), primary_key=True)
