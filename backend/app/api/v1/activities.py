"""Activity Tracking API endpoints for agent-to-server communication.

All endpoints require authentication via JWT bearer token.
The agent (Flutter Desktop) sends tracking data through these endpoints.
"""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models import SystemConfig, User
from app.schemas.activities import (
    ActivityBatchRequest,
    ActivityBatchResponse,
    ActivityLogResponse,
    AppEventCreate,
    AppEventResponse,
    HeartbeatRequest,
    HeartbeatResponse,
    InputEventCreate,
    InputEventResponse,
    ScreenshotResponse,
    ScreenshotUploadRequest,
    UrlEventCreate,
    UrlEventResponse,
)
from app.services.activity_service import ActivityService
from app.services.screenshot_service import ScreenshotService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/activities", tags=["Activities"])

MAX_SCREENSHOT_SIZE = 10 * 1024 * 1024  # 10 MB


@router.post(
    "/batch",
    response_model=ActivityBatchResponse,
    status_code=status.HTTP_200_OK,
)
async def submit_activity_batch(
    batch: ActivityBatchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit a batch of activity log entries from the agent.

    The agent collects activity data offline and periodically
    submits them in batches (max 1000 items per request).
    """
    if not batch.items:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Batch must contain at least one item",
        )

    processed = await ActivityService.process_batch(
        db=db,
        user_id=current_user.id,
        batch=batch,
    )

    return ActivityBatchResponse(
        status="ok",
        processed_count=processed,
        message=f"Processed {processed} activity log entries",
    )


@router.post(
    "/heartbeat",
    response_model=HeartbeatResponse,
    status_code=status.HTTP_200_OK,
)
async def submit_heartbeat(
    heartbeat: HeartbeatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Receive heartbeat from the agent and return server configuration.

    The agent sends heartbeats every ~30 seconds to:
    1. Confirm it's still running
    2. Report current status (active/idle/away/offline/paused)
    3. Receive updated config (screenshot interval, idle threshold)
    """
    # Record heartbeat as activity log
    await ActivityService.record_heartbeat(
        db=db,
        user_id=current_user.id,
        activity_type=heartbeat.activity_type,
        timestamp=heartbeat.timestamp,
        duration_seconds=heartbeat.idle_duration_seconds,
    )

    # Fetch current system config to send back to agent
    config = await db.get(SystemConfig, 1)

    return HeartbeatResponse(
        status="ok",
        server_time=datetime.now(timezone.utc),
        screenshot_interval_seconds=(
            config.screenshot_interval_seconds
            if config
            else 300
        ),
        idle_threshold_seconds=(
            config.idle_threshold_seconds
            if config
            else 300
        ),
        config_version=1 if config else None,
    )


@router.post(
    "/screenshot",
    response_model=ScreenshotResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_screenshot(
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a screenshot captured by the agent.

    Accepts multipart form-data with:
    - file: The screenshot image (PNG/JPEG, max 10MB)
    - captured_at: ISO timestamp (form field)
    - width: Optional image width (form field)
    - height: Optional image height (form field)
    """
    # Validate file size
    contents = await file.read()
    if len(contents) > MAX_SCREENSHOT_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Screenshot too large. Max {MAX_SCREENSHOT_SIZE // (1024 * 1024)}MB",
        )

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="File must be an image",
        )

    # Parse metadata from form
    captured_at_str = (await request.form()).get("captured_at")
    width_str = (await request.form()).get("width")
    height_str = (await request.form()).get("height")

    try:
        captured_at = (
            datetime.fromisoformat(captured_at_str)
            if captured_at_str
            else datetime.now(timezone.utc)
        )
    except (ValueError, TypeError):
        captured_at = datetime.now(timezone.utc)

    width = int(width_str) if width_str else None
    height = int(height_str) if height_str else None

    # Save screenshot
    record = await ScreenshotService.save_screenshot(
        db=db,
        user_id=current_user.id,
        file_content=contents,
        file_name=file.filename or "screenshot.png",
        captured_at=captured_at,
        width=width,
        height=height,
    )

    # Trigger async compression task
    try:
        from tasks.screenshot_compress import compress_screenshot

        compress_screenshot.delay(
            screenshot_id=str(record.id),
            file_path=record.file_path,
            thumbnail_path=record.thumbnail_path,
        )
    except Exception as e:
        logger.warning("Failed to enqueue compression task: %s", e)

    return ScreenshotResponse(
        id=record.id,
        user_id=record.user_id,
        captured_at=record.captured_at,
        file_path=record.file_path,
        file_size_bytes=record.file_size_bytes,
        width=record.width,
        height=record.height,
        thumbnail_path=record.thumbnail_path,
    )


@router.post(
    "/app-event",
    response_model=AppEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_app_event(
    event: AppEventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Log a foreground application switch event.

    The agent tracks which application window is in the foreground
    and sends events when the user switches between apps.
    """
    record = await ActivityService.record_app_event(
        db=db,
        user_id=current_user.id,
        event=event,
    )

    return AppEventResponse(
        id=record.id,
        user_id=record.user_id,
        app_name=record.app_name,
        window_title=record.window_title,
        start_time=record.start_time,
        end_time=record.end_time,
        duration_seconds=record.duration_seconds,
        category=record.category,
    )


@router.post(
    "/url-event",
    response_model=UrlEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_url_event(
    event: UrlEventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Log a browser URL or tab switch event.

    The browser extension sends events when the user visits a new URL
    or switches between browser tabs.
    """
    record = await ActivityService.record_url_event(
        db=db,
        user_id=current_user.id,
        event=event,
    )

    return UrlEventResponse(
        id=record.id,
        user_id=record.user_id,
        url=record.url,
        domain=record.domain,
        page_title=record.page_title,
        browser=record.browser,
        start_time=record.start_time,
        end_time=record.end_time,
        duration_seconds=record.duration_seconds,
        category=record.category,
    )


@router.post(
    "/input-event",
    response_model=InputEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_input_event(
    event: InputEventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit a periodic summary of input device activity.

    The agent aggregates mouse clicks, key presses, and mouse movement
    distance over a batch period and sends the summary to the server.
    """
    record = await ActivityService.record_input_summary(
        db=db,
        user_id=current_user.id,
        event=event,
    )

    return InputEventResponse(
        id=record.id,
        user_id=record.user_id,
        date=record.date,
        total_mouse_clicks=record.total_mouse_clicks,
        total_key_presses=record.total_key_presses,
        total_mouse_distance=record.total_mouse_distance,
        active_seconds=record.active_seconds,
        idle_seconds=record.idle_seconds,
        batch_time=record.batch_time,
    )
