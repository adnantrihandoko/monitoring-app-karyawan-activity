import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String, Text
from sqlalchemy import JSON as SA_JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ActivityLog(Base):
    """Activity log entry tracking user status over time.

    This is a high-volume log table using BIGSERIAL PK.
    """

    __tablename__ = "activity_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
    activity_type: Mapped[str] = mapped_column(
        Enum(
            "active",
            "idle",
            "away",
            "offline",
            name="activity_type",
        ),
        nullable=False,
        index=True,
    )
    duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    metadata_: Mapped[dict | None] = mapped_column(SA_JSON, nullable=True, default=None)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", backref="activity_logs")

    def __repr__(self) -> str:
        return (
            f"<ActivityLog(id={self.id}, user_id={self.user_id}, "
            f"type={self.activity_type}, ts={self.timestamp})>"
        )
