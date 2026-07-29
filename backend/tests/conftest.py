"""
Pytest configuration and fixtures for Monitoring App tests.

Uses SQLite in-memory database for test isolation.
"""

import asyncio
import uuid
from typing import AsyncGenerator, Generator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.database import Base, get_db
from app.main import app
from app.models import Department, SystemConfig, User
from app.services.auth_service import hash_password, hash_token

# Use SQLite in-memory for testing (avoids file-level contention)
TEST_DATABASE_URL = "sqlite+aiosqlite://"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
)

test_async_session_factory = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def setup_database():
    """Create tables before each test and drop them after."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
    """Override FastAPI dependency to use test database."""
    async with test_async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Override the database dependency
app.dependency_overrides[get_db] = override_get_db


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide a test database session."""
    async with test_async_session_factory() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Provide an HTTP test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def admin_user(db_session: AsyncSession) -> User:
    """Create and return an admin user."""
    user = User(
        id=uuid.uuid4(),
        email="admin@test.com",
        password_hash=hash_password("admin123"),
        full_name="Test Admin",
        role="admin",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def supervisor_user(db_session: AsyncSession) -> User:
    """Create and return a supervisor user."""
    user = User(
        id=uuid.uuid4(),
        email="supervisor@test.com",
        password_hash=hash_password("super123"),
        full_name="Test Supervisor",
        role="supervisor",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def employee_user(db_session: AsyncSession) -> User:
    """Create and return an employee user."""
    user = User(
        id=uuid.uuid4(),
        email="employee@test.com",
        password_hash=hash_password("emp123"),
        full_name="Test Employee",
        role="employee",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def deactivated_user(db_session: AsyncSession) -> User:
    """Create and return a deactivated user."""
    user = User(
        id=uuid.uuid4(),
        email="deactivated@test.com",
        password_hash=hash_password("deact123"),
        full_name="Deactivated User",
        role="employee",
        is_active=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def default_department(db_session: AsyncSession) -> Department:
    """Create and return a default department."""
    dept = Department(
        id=uuid.uuid4(),
        name="Test Department",
        description="A test department",
    )
    db_session.add(dept)
    await db_session.commit()
    await db_session.refresh(dept)
    return dept


@pytest_asyncio.fixture
async def auth_headers(
    client: AsyncClient,
    employee_user: User,
) -> dict:
    """Login as employee and return authorization headers."""
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "employee@test.com", "password": "emp123"},
    )
    data = response.json()
    return {"Authorization": f"Bearer {data['access_token']}"}


@pytest_asyncio.fixture
async def admin_auth_headers(
    client: AsyncClient,
    admin_user: User,
) -> dict:
    """Login as admin and return authorization headers."""
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "admin123"},
    )
    data = response.json()
    return {"Authorization": f"Bearer {data['access_token']}"}
