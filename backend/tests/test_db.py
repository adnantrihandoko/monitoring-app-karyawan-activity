"""
Tests for database connection and models.
"""

import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Department, ProductivityRule, SystemConfig, User, UserSession
from app.services.auth_service import hash_password, hash_token


class TestDatabaseConnection:
    """Test database connection health."""

    async def test_db_session_works(self, db_session: AsyncSession):
        """Test that we can execute a query."""
        result = await db_session.execute(select(1))
        assert result.scalar() == 1

    async def test_connection_pool(self, db_session: AsyncSession):
        """Test that the connection pool works."""
        result = await db_session.execute(select(1))
        assert result.scalar() == 1


class TestUserModel:
    """Test User model CRUD operations."""

    async def test_create_user(self, db_session: AsyncSession):
        """Test creating a user."""
        user = User(
            id=uuid.uuid4(),
            email="newuser@test.com",
            password_hash=hash_password("test123"),
            full_name="New User",
            role="employee",
            is_active=True,
        )
        db_session.add(user)
        await db_session.commit()
        await db_session.refresh(user)

        assert user.id is not None
        assert user.email == "newuser@test.com"
        assert user.full_name == "New User"
        assert user.role == "employee"
        assert user.is_active is True
        assert user.created_at is not None
        assert user.updated_at is not None

    async def test_read_user(self, db_session: AsyncSession):
        """Test reading a user."""
        user = User(
            id=uuid.uuid4(),
            email="readuser@test.com",
            password_hash=hash_password("test123"),
            full_name="Read User",
            role="supervisor",
            is_active=True,
        )
        db_session.add(user)
        await db_session.commit()

        # Read back
        result = await db_session.execute(
            select(User).where(User.email == "readuser@test.com")
        )
        found = result.scalar_one()
        assert found.full_name == "Read User"
        assert found.role == "supervisor"

    async def test_update_user(self, db_session: AsyncSession):
        """Test updating a user."""
        user = User(
            id=uuid.uuid4(),
            email="updateuser@test.com",
            password_hash=hash_password("test123"),
            full_name="Update User",
            role="employee",
            is_active=True,
        )
        db_session.add(user)
        await db_session.commit()

        # Update
        user.full_name = "Updated Name"
        user.is_active = False
        await db_session.commit()

        # Verify
        result = await db_session.execute(select(User).where(User.id == user.id))
        updated = result.scalar_one()
        assert updated.full_name == "Updated Name"
        assert updated.is_active is False

    async def test_delete_user(self, db_session: AsyncSession):
        """Test deleting a user."""
        user = User(
            id=uuid.uuid4(),
            email="deleteuser@test.com",
            password_hash=hash_password("test123"),
            full_name="Delete User",
            role="employee",
            is_active=True,
        )
        db_session.add(user)
        await db_session.commit()

        await db_session.delete(user)
        await db_session.commit()

        result = await db_session.execute(
            select(User).where(User.email == "deleteuser@test.com")
        )
        assert result.scalar_one_or_none() is None

    async def test_unique_email_constraint(self, db_session: AsyncSession):
        """Test that duplicate email raises an error."""
        user1 = User(
            id=uuid.uuid4(),
            email="duplicate@test.com",
            password_hash=hash_password("test123"),
            full_name="User One",
            role="employee",
        )
        db_session.add(user1)
        await db_session.commit()

        user2 = User(
            id=uuid.uuid4(),
            email="duplicate@test.com",
            password_hash=hash_password("test456"),
            full_name="User Two",
            role="employee",
        )
        db_session.add(user2)
        with pytest.raises(Exception):
            await db_session.commit()


class TestDepartmentModel:
    """Test Department model CRUD operations."""

    async def test_create_department(self, db_session: AsyncSession):
        """Test creating a department."""
        dept = Department(
            id=uuid.uuid4(),
            name="Engineering",
            description="Engineering Department",
        )
        db_session.add(dept)
        await db_session.commit()
        await db_session.refresh(dept)

        assert dept.id is not None
        assert dept.name == "Engineering"
        assert dept.description == "Engineering Department"
        assert dept.created_at is not None

    async def test_department_unique_name(self, db_session: AsyncSession):
        """Test that duplicate department name raises an error."""
        dept1 = Department(
            id=uuid.uuid4(),
            name="Unique Dept",
        )
        db_session.add(dept1)
        await db_session.commit()

        dept2 = Department(
            id=uuid.uuid4(),
            name="Unique Dept",
        )
        db_session.add(dept2)
        with pytest.raises(Exception):
            await db_session.commit()


class TestUserSessionModel:
    """Test UserSession model."""

    async def test_create_session(self, db_session: AsyncSession, employee_user):
        """Test creating a user session."""
        jti = uuid.uuid4().hex
        session = UserSession(
            id=uuid.uuid4(),
            user_id=employee_user.id,
            access_token_jti=jti,
            refresh_token_hash=hash_token("refresh-token-value"),
            ip_address="192.168.1.1",
            user_agent="pytest-agent",
            is_active=True,
        )
        db_session.add(session)
        await db_session.commit()
        await db_session.refresh(session)

        assert session.id is not None
        assert session.user_id == employee_user.id
        assert session.access_token_jti == jti
        assert session.is_active is True
        assert session.logged_in_at is not None
        assert session.logged_out_at is None

    async def test_session_belongs_to_user(
        self, db_session: AsyncSession, employee_user
    ):
        """Test that session relationship to user works."""
        jti = uuid.uuid4().hex
        session = UserSession(
            id=uuid.uuid4(),
            user_id=employee_user.id,
            access_token_jti=jti,
            refresh_token_hash=hash_token("refresh-token"),
            is_active=True,
        )
        db_session.add(session)
        await db_session.commit()

        # Check relationship
        result = await db_session.execute(
            select(UserSession).where(UserSession.id == session.id)
        )
        found = result.scalar_one()
        assert found.user.id == employee_user.id
        assert found.user.email == employee_user.email


class TestProductivityRuleModel:
    """Test ProductivityRule model."""

    async def test_create_rule(self, db_session: AsyncSession):
        """Test creating a productivity rule."""
        rule = ProductivityRule(
            id=uuid.uuid4(),
            pattern_type="domain",
            pattern="github.com",
            category="productive",
            is_builtin=True,
        )
        db_session.add(rule)
        await db_session.commit()
        await db_session.refresh(rule)

        assert rule.id is not None
        assert rule.pattern == "github.com"
        assert rule.category == "productive"
        assert rule.is_builtin is True

    async def test_create_all_pattern_types(self, db_session: AsyncSession):
        """Test all pattern types."""
        rules = [
            ProductivityRule(
                id=uuid.uuid4(),
                pattern_type="app_name",
                pattern="VS Code",
                category="productive",
            ),
            ProductivityRule(
                id=uuid.uuid4(),
                pattern_type="domain",
                pattern="example.com",
                category="neutral",
            ),
            ProductivityRule(
                id=uuid.uuid4(),
                pattern_type="url_contains",
                pattern="/admin",
                category="non_productive",
            ),
        ]
        for rule in rules:
            db_session.add(rule)
        await db_session.commit()

        result = await db_session.execute(select(ProductivityRule))
        all_rules = result.scalars().all()
        assert len(all_rules) == 3


class TestSystemConfigModel:
    """Test SystemConfig model."""

    async def test_create_system_config(self, db_session: AsyncSession):
        """Test creating system config (singleton pattern)."""
        config = SystemConfig(
            id=1,
            screenshot_interval_seconds=300,
            idle_threshold_seconds=600,
            screenshot_retention_days=30,
        )
        db_session.add(config)
        await db_session.commit()
        await db_session.refresh(config)

        assert config.id == 1
        assert config.screenshot_interval_seconds == 300
        assert config.idle_threshold_seconds == 600
        assert config.max_sessions_per_user == 3  # default

    async def test_system_config_defaults(self, db_session: AsyncSession):
        """Test system config default values."""
        config = SystemConfig(id=1)
        db_session.add(config)
        await db_session.commit()

        assert config.screenshot_interval_seconds == 300
        assert config.idle_threshold_seconds == 300
        assert config.screenshot_retention_days == 30
        assert config.max_sessions_per_user == 3
        assert config.data_purge_enabled is True

    async def test_update_system_config(self, db_session: AsyncSession):
        """Test updating system config."""
        config = SystemConfig(id=1)
        db_session.add(config)
        await db_session.commit()

        config.screenshot_interval_seconds = 600
        config.max_sessions_per_user = 5
        await db_session.commit()
        await db_session.refresh(config)

        assert config.screenshot_interval_seconds == 600
        assert config.max_sessions_per_user == 5


class TestCascadeRelationships:
    """Test cascade delete relationships."""

    async def test_cascade_delete_user_sessions(
        self, db_session: AsyncSession, employee_user
    ):
        """Test that deleting a user also deletes their sessions."""
        jti = uuid.uuid4().hex
        session = UserSession(
            id=uuid.uuid4(),
            user_id=employee_user.id,
            access_token_jti=jti,
            refresh_token_hash=hash_token("refresh"),
            is_active=True,
        )
        db_session.add(session)
        await db_session.commit()

        # Delete user
        await db_session.delete(employee_user)
        await db_session.commit()

        # Sessions should be deleted
        result = await db_session.execute(
            select(UserSession).where(UserSession.id == session.id)
        )
        assert result.scalar_one_or_none() is None

    async def test_user_department_relationship(
        self, db_session: AsyncSession, default_department
    ):
        """Test user-department relationship."""
        user = User(
            id=uuid.uuid4(),
            email="deptuser@test.com",
            password_hash=hash_password("test123"),
            full_name="Dept User",
            role="employee",
            department_id=default_department.id,
        )
        db_session.add(user)
        await db_session.commit()

        # Check relationship
        result = await db_session.execute(select(User).where(User.id == user.id))
        found = result.scalar_one()
        assert found.department is not None
        assert found.department.name == "Test Department"
