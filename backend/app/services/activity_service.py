"""Activity Service — processes batch data, stores to database."""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    ActivityLog,
    AppEvent,
    InputActivitySummary,
    Screenshot,
    UrlEvent,
)
from app.schemas.activities import (
    ActivityBatchRequest,
    AppEventCreate,
    InputEventCreate,
    UrlEventCreate,
)

logger = logging.getLogger(__name__)


class ActivityService:
    """Service for processing and storing activity tracking data."""

    @staticmethod
    async def process_batch(
        db: AsyncSession,
        user_id: UUID,
        batch: ActivityBatchRequest,
    ) -> int:
        """Process a batch of activity log entries.

        Args:
            db: Database session.
            user_id: ID of the user submitting the batch.
            batch: Batch request containing activity items.

        Returns:
            Number of items processed.
        """
        now = datetime.now(timezone.utc)
        entries = []
        for item in batch.items:
            entry = ActivityLog(
                user_id=user_id,
                timestamp=item.timestamp,
                activity_type=item.activity_type,
                duration_seconds=item.duration_seconds,
                metadata_=item.metadata,
                created_at=now,
            )
            entries.append(entry)

        db.add_all(entries)
        await db.flush()
        logger.info(
            "Processed %d activity log entries for user %s",
            len(entries),
            user_id,
        )
        return len(entries)

    @staticmethod
    async def record_heartbeat(
        db: AsyncSession,
        user_id: UUID,
        activity_type: str,
        timestamp: Optional[datetime] = None,
        duration_seconds: Optional[float] = None,
    ) -> ActivityLog:
        """Record a heartbeat as an activity log entry.

        Args:
            db: Database session.
            user_id: ID of the user.
            activity_type: Current activity type (active/idle/away/offline).
            timestamp: Heartbeat timestamp (defaults to now).
            duration_seconds: Optional duration of current state.

        Returns:
            The created ActivityLog entry.
        """
        now = timestamp or datetime.now(timezone.utc)
        entry = ActivityLog(
            user_id=user_id,
            timestamp=now,
            activity_type=activity_type,
            duration_seconds=duration_seconds,
            metadata_={"source": "heartbeat"},
            created_at=now,
        )
        db.add(entry)
        await db.flush()
        return entry

    @staticmethod
    async def record_app_event(
        db: AsyncSession,
        user_id: UUID,
        event: AppEventCreate,
    ) -> AppEvent:
        """Record an application foreground event.

        Args:
            db: Database session.
            user_id: ID of the user.
            event: App event data.

        Returns:
            The created AppEvent record.
        """
        record = AppEvent(
            user_id=user_id,
            app_name=event.app_name,
            window_title=event.window_title,
            start_time=event.start_time,
            end_time=event.end_time,
            duration_seconds=event.duration_seconds,
            category=event.category,
            created_at=datetime.now(timezone.utc),
        )
        db.add(record)
        await db.flush()
        return record

    @staticmethod
    async def record_url_event(
        db: AsyncSession,
        user_id: UUID,
        event: UrlEventCreate,
    ) -> UrlEvent:
        """Record a browser URL event.

        Args:
            db: Database session.
            user_id: ID of the user.
            event: URL event data.

        Returns:
            The created UrlEvent record.
        """
        record = UrlEvent(
            user_id=user_id,
            url=event.url,
            domain=event.domain,
            page_title=event.page_title,
            browser=event.browser,
            start_time=event.start_time,
            end_time=event.end_time,
            duration_seconds=event.duration_seconds,
            category=event.category,
            created_at=datetime.now(timezone.utc),
        )
        db.add(record)
        await db.flush()
        return record

    @staticmethod
    async def record_input_summary(
        db: AsyncSession,
        user_id: UUID,
        event: InputEventCreate,
    ) -> InputActivitySummary:
        """Record an input activity summary.

        Uses upsert logic: if a summary for the same user+date+batch_time
        exists, update it; otherwise create a new one.

        Args:
            db: Database session.
            user_id: ID of the user.
            event: Input summary data.

        Returns:
            The created/updated InputActivitySummary record.
        """
        # Try to find existing record for this user + date + batch_time
        result = await db.execute(
            select(InputActivitySummary).where(
                InputActivitySummary.user_id == user_id,
                InputActivitySummary.date == event.date,
                InputActivitySummary.batch_time == event.batch_time,
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            # Update existing record
            existing.total_mouse_clicks += event.total_mouse_clicks
            existing.total_key_presses += event.total_key_presses
            existing.total_mouse_distance += event.total_mouse_distance
            existing.active_seconds += event.active_seconds
            existing.idle_seconds += event.idle_seconds
            await db.flush()
            await db.refresh(existing)
            return existing

        record = InputActivitySummary(
            user_id=user_id,
            date=event.date,
            total_mouse_clicks=event.total_mouse_clicks,
            total_key_presses=event.total_key_presses,
            total_mouse_distance=event.total_mouse_distance,
            active_seconds=event.active_seconds,
            idle_seconds=event.idle_seconds,
            batch_time=event.batch_time,
            created_at=datetime.now(timezone.utc),
        )
        db.add(record)
        await db.flush()
        await db.refresh(record)
        return record
