import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AppEvent(Base):
    """Foreground application event tracking.

    Records when a user switches between applications/windows.
    High-volume log table using BIGSERIAL PK.
    """

    __tablename__ = "app_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    app_name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    window_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
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
    user = relationship("User", backref="app_events")

    def __repr__(self) -> str:
        return (
            f"<AppEvent(id={self.id}, user_id={self.user_id}, "
            f"app={self.app_name}, dur={self.duration_seconds})>"
        )
