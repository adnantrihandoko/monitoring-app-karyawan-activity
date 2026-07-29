import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UrlEvent(Base):
    """Browser URL event tracking.

    Records when a user visits or switches between URLs in a browser.
    High-volume log table using BIGSERIAL PK.
    """

    __tablename__ = "url_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    url: Mapped[str] = mapped_column(String(2048), nullable=False)
    domain: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    page_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    browser: Mapped[str | None] = mapped_column(String(100), nullable=True)
    start_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    end_time: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    category: Mapped[str | None] = mapped_column(
        Enum(
            "productive",
            "neutral",
            "non_productive",
            name="productivity_category",
        ),
        nullable=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", backref="url_events")

    def __repr__(self) -> str:
        return (
            f"<UrlEvent(id={self.id}, user_id={self.user_id}, "
            f"domain={self.domain}, dur={self.duration_seconds})>"
        )
