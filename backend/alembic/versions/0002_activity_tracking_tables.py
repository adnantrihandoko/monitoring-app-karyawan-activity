"""Create activity tracking tables (activity_logs, app_events, url_events, input_activity_summaries, screenshots)

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-29 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create new enum types
    op.execute(
        "CREATE TYPE activity_type AS ENUM ('active', 'idle', 'away', 'offline')"
    )

    # ─── Activity Logs ──────────────────────────────────────────────────────
    op.create_table(
        "activity_logs",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "activity_type",
            sa.Enum("active", "idle", "away", "offline", name="activity_type"),
            nullable=False,
            index=True,
        ),
        sa.Column("duration_seconds", sa.Float, nullable=True),
        sa.Column("metadata_", postgresql.JSONB, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── App Events ─────────────────────────────────────────────────────────
    op.create_table(
        "app_events",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("app_name", sa.String(255), nullable=False, index=True),
        sa.Column("window_title", sa.String(500), nullable=True),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Float, nullable=True),
        sa.Column(
            "category",
            sa.Enum(
                "productive", "neutral", "non_productive", name="productivity_category"
            ),
            nullable=True,
            index=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── URL Events ─────────────────────────────────────────────────────────
    op.create_table(
        "url_events",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("url", sa.String(2048), nullable=False),
        sa.Column("domain", sa.String(255), nullable=False, index=True),
        sa.Column("page_title", sa.String(500), nullable=True),
        sa.Column("browser", sa.String(100), nullable=True),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Float, nullable=True),
        sa.Column(
            "category",
            sa.Enum(
                "productive", "neutral", "non_productive", name="productivity_category"
            ),
            nullable=True,
            index=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── Input Activity Summaries ───────────────────────────────────────────
    op.create_table(
        "input_activity_summaries",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("date", sa.String(10), nullable=False, index=True),
        sa.Column("total_mouse_clicks", sa.Integer, server_default="0", nullable=False),
        sa.Column("total_key_presses", sa.Integer, server_default="0", nullable=False),
        sa.Column(
            "total_mouse_distance", sa.Float, server_default="0.0", nullable=False
        ),
        sa.Column("active_seconds", sa.Integer, server_default="0", nullable=False),
        sa.Column("idle_seconds", sa.Integer, server_default="0", nullable=False),
        sa.Column(
            "batch_time",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── Screenshots ────────────────────────────────────────────────────────
    op.create_table(
        "screenshots",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "captured_at",
            sa.DateTime(timezone=True),
            nullable=False,
            index=True,
        ),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_size_bytes", sa.BigInteger, nullable=True),
        sa.Column("width", sa.Integer, nullable=True),
        sa.Column("height", sa.Integer, nullable=True),
        sa.Column("thumbnail_path", sa.String(500), nullable=True),
        sa.Column("is_deleted", sa.Boolean, server_default="false", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── Indexes ────────────────────────────────────────────────────────────
    # Activity logs
    op.create_index("idx_activity_user_ts", "activity_logs", ["user_id", "timestamp"])
    op.create_index(
        "idx_activity_type_ts", "activity_logs", ["activity_type", "timestamp"]
    )
    op.create_index("idx_activity_created", "activity_logs", ["created_at"])

    # App events
    op.create_index("idx_app_user_ts", "app_events", ["user_id", "start_time"])
    op.create_index("idx_app_name", "app_events", ["app_name"])
    op.create_index("idx_app_category", "app_events", ["category"])

    # URL events
    op.create_index("idx_url_user_ts", "url_events", ["user_id", "start_time"])
    op.create_index("idx_url_domain", "url_events", ["domain"])
    op.create_index("idx_url_category", "url_events", ["category"])

    # Input summaries
    op.create_index(
        "idx_input_user_date", "input_activity_summaries", ["user_id", "date"]
    )
    op.create_index("idx_input_date", "input_activity_summaries", ["date"])

    # Screenshots
    op.create_index("idx_screenshot_user_ts", "screenshots", ["user_id", "captured_at"])
    op.create_index("idx_screenshot_captured", "screenshots", ["captured_at"])
    op.create_index(
        "idx_screenshot_undeleted", "screenshots", ["is_deleted", "user_id"]
    )


def downgrade() -> None:
    # Drop indexes
    op.drop_index("idx_activity_user_ts", table_name="activity_logs")
    op.drop_index("idx_activity_type_ts", table_name="activity_logs")
    op.drop_index("idx_activity_created", table_name="activity_logs")
    op.drop_index("idx_app_user_ts", table_name="app_events")
    op.drop_index("idx_app_name", table_name="app_events")
    op.drop_index("idx_app_category", table_name="app_events")
    op.drop_index("idx_url_user_ts", table_name="url_events")
    op.drop_index("idx_url_domain", table_name="url_events")
    op.drop_index("idx_url_category", table_name="url_events")
    op.drop_index("idx_input_user_date", table_name="input_activity_summaries")
    op.drop_index("idx_input_date", table_name="input_activity_summaries")
    op.drop_index("idx_screenshot_user_ts", table_name="screenshots")
    op.drop_index("idx_screenshot_captured", table_name="screenshots")
    op.drop_index("idx_screenshot_undeleted", table_name="screenshots")

    # Drop tables
    op.drop_table("screenshots")
    op.drop_table("input_activity_summaries")
    op.drop_table("url_events")
    op.drop_table("app_events")
    op.drop_table("activity_logs")

    # Drop enum type
    op.execute("DROP TYPE IF EXISTS activity_type")
