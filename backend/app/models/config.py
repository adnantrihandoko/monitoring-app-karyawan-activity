import datetime
import uuid
from datetime import datetime as dt, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Time, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class SystemConfig(Base):
    __tablename__ = "system_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    screenshot_interval_seconds: Mapped[int] = mapped_column(
        Integer, default=300, nullable=False
    )
    idle_threshold_seconds: Mapped[int] = mapped_column(
        Integer, default=300, nullable=False
    )
    work_start_hour: Mapped[datetime.time] = mapped_column(
        Time,
        default=lambda: datetime.datetime.strptime("08:00", "%H:%M").time(),
        nullable=False,
    )
    work_end_hour: Mapped[datetime.time] = mapped_column(
        Time,
        default=lambda: datetime.datetime.strptime("17:00", "%H:%M").time(),
        nullable=False,
    )
    work_days: Mapped[str] = mapped_column(
        String(50), default="[1,2,3,4,5]", nullable=False
    )
    screenshot_retention_days: Mapped[int] = mapped_column(
        Integer, default=30, nullable=False
    )
    data_purge_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    max_sessions_per_user: Mapped[int] = mapped_column(
        Integer, default=3, nullable=False
    )
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    updated_at: Mapped[dt] = mapped_column(
        DateTime(timezone=True),
        default=lambda: dt.now(timezone.utc),
        onupdate=lambda: dt.now(timezone.utc),
    )

    def __repr__(self) -> str:
        return f"<SystemConfig(id={self.id})>"
