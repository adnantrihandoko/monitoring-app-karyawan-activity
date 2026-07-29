"""Pydantic v2 schemas for Activity Tracking endpoints."""

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ─── Mixins ──────────────────────────────────────────────────────────────


class ActivityBaseMixin(BaseModel):
    """Common fields shared across activity schemas."""

    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="Event timestamp (UTC)",
    )


# ─── Heartbeat ───────────────────────────────────────────────────────────


class HeartbeatRequest(BaseModel):
    """Heartbeat ping from agent to server."""

    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
    )
    status: str = Field(
        "active",
        pattern="^(active|idle|away|offline|paused)$",
        description="Current agent status",
    )
    activity_type: str = Field(
        "active",
        pattern="^(active|idle|away|offline)$",
        description="Current activity type",
    )
    current_app: Optional[str] = Field(None, max_length=255)
    current_window_title: Optional[str] = Field(None, max_length=500)
    idle_duration_seconds: Optional[float] = Field(None, ge=0)


class HeartbeatResponse(BaseModel):
    """Response to heartbeat containing server-side config."""

    status: str = "ok"
    server_time: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
    )
    screenshot_interval_seconds: int = 300
    idle_threshold_seconds: int = 300
    config_version: Optional[int] = None


# ─── App Event ───────────────────────────────────────────────────────────


class AppEventCreate(BaseModel):
    """Log a foreground application switch event."""

    app_name: str = Field(..., max_length=255, description="Application name")
    window_title: Optional[str] = Field(None, max_length=500)
    start_time: datetime = Field(..., description="When this app became foreground")
    end_time: Optional[datetime] = Field(None)
    duration_seconds: Optional[float] = Field(None, ge=0)
    category: Optional[str] = Field(
        None, pattern="^(productive|neutral|non_productive)$"
    )


class AppEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: UUID
    app_name: str
    window_title: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    category: Optional[str] = None


# ─── URL Event ───────────────────────────────────────────────────────────


class UrlEventCreate(BaseModel):
    """Log a browser URL change event."""

    url: str = Field(..., max_length=2048)
    domain: str = Field(..., max_length=255)
    page_title: Optional[str] = Field(None, max_length=500)
    browser: Optional[str] = Field(None, max_length=100)
    start_time: datetime = Field(...)
    end_time: Optional[datetime] = Field(None)
    duration_seconds: Optional[float] = Field(None, ge=0)
    category: Optional[str] = Field(
        None, pattern="^(productive|neutral|non_productive)$"
    )


class UrlEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: UUID
    url: str
    domain: str
    page_title: Optional[str] = None
    browser: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    category: Optional[str] = None


# ─── Input Event ─────────────────────────────────────────────────────────


class InputEventCreate(BaseModel):
    """Submit a periodic summary of input device activity."""

    date: str = Field(
        ..., pattern=r"^\d{4}-\d{2}-\d{2}$", description="Date in YYYY-MM-DD"
    )
    total_mouse_clicks: int = Field(0, ge=0)
    total_key_presses: int = Field(0, ge=0)
    total_mouse_distance: float = Field(0.0, ge=0.0)
    active_seconds: int = Field(0, ge=0)
    idle_seconds: int = Field(0, ge=0)
    batch_time: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
    )


class InputEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: UUID
    date: str
    total_mouse_clicks: int
    total_key_presses: int
    total_mouse_distance: float
    active_seconds: int
    idle_seconds: int
    batch_time: datetime


# ─── Screenshot ──────────────────────────────────────────────────────────


class ScreenshotUploadRequest(BaseModel):
    """Upload a screenshot captured by the agent."""

    captured_at: datetime = Field(..., description="When the screenshot was captured")
    file_name: str = Field(..., max_length=255)
    width: Optional[int] = Field(None, gt=0)
    height: Optional[int] = Field(None, gt=0)
    # The actual image file is uploaded via multipart form-data.
    # This schema is used for the JSON metadata part.


class ScreenshotResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    captured_at: datetime
    file_path: str
    file_size_bytes: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnail_path: Optional[str] = None


# ─── Batch ───────────────────────────────────────────────────────────────


class ActivityBatchItem(BaseModel):
    """A single activity log entry within a batch submit."""

    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
    )
    activity_type: str = Field(..., pattern="^(active|idle|away|offline)$")
    duration_seconds: Optional[float] = Field(None, ge=0)
    metadata: Optional[dict] = None


class ActivityBatchRequest(BaseModel):
    """Submit a batch of activity logs at once."""

    items: list[ActivityBatchItem] = Field(
        ...,
        min_length=1,
        max_length=1000,
        description="Batch of activity log entries (max 1000)",
    )


class ActivityBatchResponse(BaseModel):
    """Response for a batch activity submit."""

    status: str = "ok"
    processed_count: int = 0
    message: str = "Activity batch processed successfully"


# ─── Activity Log ────────────────────────────────────────────────────────


class ActivityLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: UUID
    timestamp: datetime
    activity_type: str
    duration_seconds: Optional[float] = None
    metadata: Optional[dict] = None
