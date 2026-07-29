import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ProductivityRule(Base):
    __tablename__ = "productivity_rules"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    pattern_type: Mapped[str] = mapped_column(
        Enum(
            "app_name",
            "domain",
            "url_contains",
            name="pattern_type",
        ),
        nullable=False,
    )
    pattern: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    category: Mapped[str] = mapped_column(
        Enum(
            "productive",
            "neutral",
            "non_productive",
            name="productivity_category",
        ),
        nullable=False,
    )
    is_builtin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    def __repr__(self) -> str:
        return (
            f"<ProductivityRule(id={self.id}, pattern={self.pattern}, "
            f"category={self.category})>"
        )
