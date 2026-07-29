"""
Tests for authentication module:
- Password hashing & verification
- JWT creation & verification
- Login/logout flow
- Authentication middleware
"""

import time
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import jwt
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import UserSession
from app.services.auth_service import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_jti,
    hash_password,
    verify_password,
)


# ─── Password Hashing Tests ─────────────────────────────────────────────────


class TestPasswordHashing:
    def test_hash_password_returns_string(self):
        hashed = hash_password("test_password")
        assert isinstance(hashed, str)
        assert len(hashed) > 0

    def test_hash_password_differs_from_plaintext(self):
        password = "test_password"
        hashed = hash_password(password)
        assert hashed != password

    def test_verify_password_correct(self):
        password = "test_password"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_verify_password_incorrect(self):
        hashed = hash_password("correct_password")
        assert verify_password("wrong_password", hashed) is False

    def test_hash_different_salts(self):
        password = "test_password"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        # Different salts should produce different hashes
        assert hash1 != hash2
        # But both should verify correctly
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True


# ─── JWT Token Tests ───────────────────────────────────────────────────────


class TestJWTToken:
    def test_create_access_token(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        token = create_access_token(user_id, "admin", jti)

        assert isinstance(token, str)
        assert len(token.split(".")) == 3  # JWT has 3 parts

    def test_create_refresh_token(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        token = create_refresh_token(user_id, jti)

        assert isinstance(token, str)
        assert len(token.split(".")) == 3

    def test_decode_valid_access_token(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        token = create_access_token(user_id, "admin", jti)

        payload = decode_token(token)
        assert payload["sub"] == str(user_id)
        assert payload["role"] == "admin"
        assert payload["jti"] == jti
        assert payload["type"] == "access"
        assert "exp" in payload
        assert "iat" in payload

    def test_decode_valid_refresh_token(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        token = create_refresh_token(user_id, jti)

        payload = decode_token(token)
        assert payload["sub"] == str(user_id)
        assert payload["jti"] == jti
        assert payload["type"] == "refresh"
        assert "exp" in payload

    def test_decode_expired_token(self):
        user_id = uuid.uuid4()
        jti = generate_jti()

        # Create a token that expired in the past
        now = datetime.now(timezone.utc)
        expired_payload = {
            "sub": str(user_id),
            "role": "admin",
            "jti": jti,
            "type": "access",
            "iat": now - timedelta(hours=1),
            "exp": now - timedelta(minutes=1),
        }
        token = jwt.encode(
            expired_payload,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )

        with pytest.raises(jwt.ExpiredSignatureError):
            decode_token(token)

    def test_decode_invalid_token(self):
        with pytest.raises(jwt.InvalidTokenError):
            decode_token("invalid.token.here")

    def test_decode_token_wrong_secret(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        payload = {
            "sub": str(user_id),
            "role": "admin",
            "jti": jti,
            "type": "access",
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        }
        token = jwt.encode(payload, "wrong-secret", algorithm="HS256")

        with pytest.raises(jwt.InvalidTokenError):
            decode_token(token)

    def test_generate_jti(self):
        jti1 = generate_jti()
        jti2 = generate_jti()
        assert jti1 != jti2
        assert len(jti1) == 32  # UUID4 hex is 32 chars
        assert isinstance(jti1, str)

    def test_access_token_has_correct_expiry(self):
        user_id = uuid.uuid4()
        jti = generate_jti()
        token = create_access_token(user_id, "employee", jti)

        payload = decode_token(token)
        exp_time = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        iat_time = datetime.fromtimestamp(payload["iat"], tz=timezone.utc)

        # Expiry should be ACCESS_TOKEN_EXPIRE_MINUTES from iat
        expected_diff = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        actual_diff = exp_time - iat_time
        # Allow 1 second tolerance
        assert abs(actual_diff - expected_diff) < timedelta(seconds=1)


# ─── Auth API Tests ────────────────────────────────────────────────────────


class TestLoginAPI:
    async def test_login_success(self, client: AsyncClient, employee_user):
        """Test successful login returns tokens."""
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "employee@test.com", "password": "emp123"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] == settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60

    async def test_login_invalid_email(self, client: AsyncClient):
        """Test login with non-existent email returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "nonexistent@test.com", "password": "test123"},
        )
        assert response.status_code == 401
        assert "Invalid email or password" in response.text

    async def test_login_wrong_password(self, client: AsyncClient, employee_user):
        """Test login with wrong password returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "employee@test.com", "password": "wrongpass"},
        )
        assert response.status_code == 401
        assert "Invalid email or password" in response.text

    async def test_login_deactivated_user(self, client: AsyncClient, deactivated_user):
        """Test login as deactivated user returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "deactivated@test.com",
                "password": "deact123",
            },
        )
        assert response.status_code == 401
        assert "Account is deactivated" in response.text or "Invalid" in response.text

    async def test_login_max_sessions(
        self, client: AsyncClient, employee_user, db_session: AsyncSession
    ):
        """Test that max sessions limit is enforced."""
        # Login multiple times up to the limit
        for i in range(settings.MAX_SESSIONS_PER_USER):
            response = await client.post(
                "/api/v1/auth/login",
                json={"email": "employee@test.com", "password": "emp123"},
            )
            assert response.status_code == 200

        # Next login should fail with 429
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "employee@test.com", "password": "emp123"},
        )
        assert response.status_code == 429
        assert "Maximum sessions reached" in response.text

    async def test_login_empty_credentials(self, client: AsyncClient):
        """Test login with empty credentials returns 422."""
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "", "password": ""},
        )
        assert response.status_code in (422, 422)  # Accepts both constants


class TestRefreshTokenAPI:
    async def test_refresh_success(self, client: AsyncClient, employee_user):
        """Test successful token refresh."""
        # Login first
        login_resp = await client.post(
            "/api/v1/auth/login",
            json={"email": "employee@test.com", "password": "emp123"},
        )
        assert login_resp.status_code == 200
        login_data = login_resp.json()

        # Refresh token
        refresh_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": login_data["refresh_token"]},
        )
        assert refresh_resp.status_code == 200
        data = refresh_resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["access_token"] != login_data["access_token"]

    async def test_refresh_with_invalid_token(self, client: AsyncClient):
        """Test refresh with invalid token returns 401."""
        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid-token"},
        )
        assert response.status_code == 401

    async def test_refresh_with_expired_token(self, client: AsyncClient):
        """Test refresh with expired token returns 401."""
        # Create an expired refresh token
        user_id = uuid.uuid4()
        # This is just for the test
        expired_payload = {
            "sub": str(user_id),
            "jti": "test-jti-expired",
            "type": "refresh",
            "exp": datetime.now(timezone.utc) - timedelta(days=1),
        }
        expired_token = jwt.encode(
            expired_payload,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )

        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": expired_token},
        )
        assert response.status_code == 401


class TestLogoutAPI:
    async def test_logout_success(
        self, client: AsyncClient, employee_user, auth_headers
    ):
        """Test successful logout."""
        response = await client.post(
            "/api/v1/auth/logout",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert "Logged out successfully" in response.text

    async def test_logout_without_token(self, client: AsyncClient):
        """Test logout without token returns 401."""
        response = await client.post("/api/v1/auth/logout")
        assert response.status_code == 401

    async def test_logout_revokes_session(
        self, client: AsyncClient, employee_user, auth_headers, db_session: AsyncSession
    ):
        """Test that after logout, the session is revoked."""
        await client.post("/api/v1/auth/logout", headers=auth_headers)

        # Check session is no longer active
        result = await db_session.execute(
            select(UserSession).where(UserSession.user_id == employee_user.id)
        )
        sessions = result.scalars().all()
        for session in sessions:
            assert session.is_active is False
            assert session.logged_out_at is not None


class TestMeAPI:
    async def test_me_success(self, client: AsyncClient, employee_user, auth_headers):
        """Test getting current user profile."""
        response = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "employee@test.com"
        assert data["full_name"] == "Test Employee"
        assert data["role"] == "employee"

    async def test_me_without_token(self, client: AsyncClient):
        """Test /me without token returns 401."""
        response = await client.get("/api/v1/auth/me")
        assert response.status_code == 401

    async def test_me_with_expired_token(self, client: AsyncClient, employee_user):
        """Test /me with expired token returns 401."""
        # Create an expired token
        user_id = employee_user.id
        expired_payload = {
            "sub": str(user_id),
            "role": "employee",
            "jti": "expired-jti",
            "type": "access",
            "exp": datetime.now(timezone.utc) - timedelta(hours=1),
        }
        expired_token = jwt.encode(
            expired_payload,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )

        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {expired_token}"},
        )
        assert response.status_code == 401
        assert "Token has expired" in response.text
