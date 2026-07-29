"""initial migration

Revision ID: 0001
Revises:
Create Date: 2026-07-29 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create enum types
    op.execute("CREATE TYPE user_role AS ENUM ('admin', 'supervisor', 'employee')")
    op.execute(
        "CREATE TYPE pattern_type AS ENUM ('app_name', 'domain', 'url_contains')"
    )
    op.execute(
        "CREATE TYPE productivity_category AS ENUM ('productive', 'neutral', 'non_productive')"
    )

    # ─── Departments ──────────────────────────────────────────────────────────
    op.create_table(
        "departments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(100), unique=True, nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── Users ────────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), unique=True, nullable=False, index=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(150), nullable=False),
        sa.Column(
            "role",
            sa.Enum("admin", "supervisor", "employee", name="user_role"),
            server_default="employee",
            nullable=False,
        ),
        sa.Column(
            "department_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("departments.id"),
            nullable=True,
        ),
        sa.Column("computer_name", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean, server_default="true", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── User Sessions ────────────────────────────────────────────────────────
    op.create_table(
        "user_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "access_token_jti", sa.String(64), unique=True, nullable=False, index=True
        ),
        sa.Column("refresh_token_hash", sa.String(255), nullable=False),
        sa.Column("ip_address", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.Text, nullable=True),
        sa.Column("is_active", sa.Boolean, server_default="true", nullable=False),
        sa.Column(
            "logged_in_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "last_activity_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("logged_out_at", sa.DateTime(timezone=True), nullable=True),
    )

    # ─── Productivity Rules ───────────────────────────────────────────────────
    op.create_table(
        "productivity_rules",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "pattern_type",
            sa.Enum("app_name", "domain", "url_contains", name="pattern_type"),
            nullable=False,
        ),
        sa.Column("pattern", sa.String(500), nullable=False, index=True),
        sa.Column(
            "category",
            sa.Enum(
                "productive", "neutral", "non_productive", name="productivity_category"
            ),
            nullable=False,
        ),
        sa.Column("is_builtin", sa.Boolean, server_default="false", nullable=False),
        sa.Column(
            "created_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── System Config ────────────────────────────────────────────────────────
    op.create_table(
        "system_config",
        sa.Column("id", sa.Integer, primary_key=True, server_default="1"),
        sa.Column(
            "screenshot_interval_seconds",
            sa.Integer,
            server_default="300",
            nullable=False,
        ),
        sa.Column(
            "idle_threshold_seconds", sa.Integer, server_default="300", nullable=False
        ),
        sa.Column(
            "work_start_hour", sa.Time, server_default="08:00:00", nullable=False
        ),
        sa.Column("work_end_hour", sa.Time, server_default="17:00:00", nullable=False),
        sa.Column(
            "work_days", sa.String(50), server_default="[1,2,3,4,5]", nullable=False
        ),
        sa.Column(
            "screenshot_retention_days", sa.Integer, server_default="30", nullable=False
        ),
        sa.Column(
            "data_purge_enabled", sa.Boolean, server_default="true", nullable=False
        ),
        sa.Column(
            "max_sessions_per_user", sa.Integer, server_default="3", nullable=False
        ),
        sa.Column(
            "updated_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ─── Additional Indexes ───────────────────────────────────────────────────
    op.create_index("idx_users_email", "users", ["email"], unique=True)
    op.create_index("idx_users_department", "users", ["department_id"])
    op.create_index("idx_users_role", "users", ["role"])
    op.create_index("idx_sessions_user", "user_sessions", ["user_id"])
    op.create_index("idx_sessions_active", "user_sessions", ["is_active"])
    op.create_index(
        "idx_sessions_jti", "user_sessions", ["access_token_jti"], unique=True
    )
    op.create_index("idx_rules_pattern", "productivity_rules", ["pattern"])
    op.create_index("idx_rules_category", "productivity_rules", ["category"])


def downgrade() -> None:
    op.drop_table("system_config")
    op.drop_table("productivity_rules")
    op.drop_table("user_sessions")
    op.drop_table("users")
    op.drop_table("departments")

    op.execute("DROP TYPE IF EXISTS productivity_category")
    op.execute("DROP TYPE IF EXISTS pattern_type")
    op.execute("DROP TYPE IF EXISTS user_role")
