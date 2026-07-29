import uuid
from datetime import date, datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InputActivitySummary(Base):
    """Daily summary of input device activity (mouse + keyboard).

    Rollup table, one row per user per day per batch period.
    Uses BIGSERIAL PK for high-volume inserts.
    """

    __tablename__ = "input_activity_summaries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date] = mapped_column(
        String(10), nullable=False, index=True
    )  # YYYY-MM-DD
    total_mouse_clicks: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_key_presses: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_mouse_distance: Mapped[float] = mapped_column(
        Float, default=0.0, nullable=False
    )
    active_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    idle_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    batch_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", backref="input_activity_summaries")

    def __repr__(self) -> str:
        return (
            f"<InputActivitySummary(id={self.id}, user_id={self.user_id}, "
            f"date={self.date}, clicks={self.total_mouse_clicks})>"
        )
