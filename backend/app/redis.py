import json
from typing import Any, AsyncGenerator, Optional

from redis.asyncio import Redis, ConnectionPool

from app.config import settings

# Redis connection pool
redis_pool = ConnectionPool.from_url(
    settings.REDIS_URL,
    max_connections=20,
    decode_responses=True,
)


async def get_redis() -> AsyncGenerator[Redis, None]:
    """FastAPI dependency that provides a Redis client."""
    redis_client = Redis(connection_pool=redis_pool)
    try:
        yield redis_client
    finally:
        await redis_client.close()


# ─── Session Cache Operations ────────────────────────────────────────────────


async def cache_set_session(
    redis_client: Redis,
    jti: str,
    user_id: str,
    ttl_seconds: int = 900,
) -> None:
    """Store session JTI in Redis for fast lookup."""
    key = f"session:{jti}"
    await redis_client.setex(key, ttl_seconds, user_id)


async def cache_get_session(
    redis_client: Redis,
    jti: str,
) -> Optional[str]:
    """Get user_id from session JTI cache."""
    key = f"session:{jti}"
    value = await redis_client.get(key)
    if value is None:
        return None
    return str(value)


async def cache_delete_session(
    redis_client: Redis,
    jti: str,
) -> None:
    """Delete session JTI from cache."""
    key = f"session:{jti}"
    await redis_client.delete(key)


# ─── Rate Limiting Counter ───────────────────────────────────────────────────


async def rate_limit_check(
    redis_client: Redis,
    key: str,
    max_requests: int = 5,
    window_seconds: int = 60,
) -> tuple[bool, int]:
    """
    Check if a rate limit has been exceeded.
    Returns (is_allowed, current_count).
    Uses sliding window counter approach.
    """
    current = await redis_client.get(key)
    if current is None:
        await redis_client.setex(key, window_seconds, 1)
        return True, 1

    count = int(current)
    if count >= max_requests:
        return False, count

    await redis_client.incr(key)
    return True, count + 1


# ─── Generic Cache ───────────────────────────────────────────────────────────


async def cache_get(key: str) -> Optional[Any]:
    """Get a value from Redis cache."""
    async with Redis(connection_pool=redis_pool) as r:
        value = await r.get(key)
        if value is None:
            return None
        try:
            return json.loads(value)
        except (json.JSONDecodeError, TypeError):
            return value


async def cache_set(
    key: str,
    value: Any,
    ttl_seconds: int = 300,
) -> None:
    """Set a value in Redis cache."""
    async with Redis(connection_pool=redis_pool) as r:
        if isinstance(value, (dict, list, tuple)):
            value = json.dumps(value)
        await r.setex(key, ttl_seconds, value)


async def cache_delete(key: str) -> None:
    """Delete a key from Redis cache."""
    async with Redis(connection_pool=redis_pool) as r:
        await r.delete(key)
