"""A refresh waits for a password change of the same user, on real connections.

Each side runs on its own connection and commits, as two requests would. Without the
per-user lock, a refresh that commits while a password change is running keeps a token
the change never revoked.
"""

import asyncio
import uuid
from collections.abc import Iterator

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.core.config import get_settings
from app.modules.auth.deps import get_auth_settings
from app.modules.auth.models import RefreshToken, User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import SignUpRequest
from app.modules.auth.service import AuthService, InvalidRefreshTokenError

SECRET = "an-integration-test-secret-that-is-long-enough"


@pytest.fixture(autouse=True)
def auth_settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("JWT_SECRET", SECRET)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _service(session: AsyncSession) -> AuthService:
    return AuthService(session, AuthRepository(session), get_auth_settings())


async def _refresh(engine: AsyncEngine, refresh_token: str) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        try:
            await _service(session).refresh(refresh_token)
        except InvalidRefreshTokenError:
            return "refused"
        return "refreshed"


@pytest.mark.anyio
async def test_a_refresh_waits_for_the_users_token_lock_and_then_fails(
    engine: AsyncEngine,
) -> None:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        user, tokens = await _service(session).sign_up(
            SignUpRequest(
                email=f"lock-{uuid.uuid4().hex[:8]}@example.com",
                password="run4medals",
                display_name="Lock Runner",
            )
        )
    try:
        async with AsyncSession(engine, expire_on_commit=False) as holder:
            repository = AuthRepository(holder)
            # What `change_password` does once the password is checked.
            await repository.lock_user_refresh_tokens(user.id)
            refresh = asyncio.ensure_future(_refresh(engine, tokens.refresh_token))
            await asyncio.sleep(0.5)

            assert not refresh.done()

            await repository.revoke_all_refresh_tokens(user.id, user.created_at)
            await holder.commit()

        assert await asyncio.wait_for(refresh, timeout=5) == "refused"
        async with AsyncSession(engine) as session:
            live = await session.scalars(
                select(RefreshToken).where(
                    RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None)
                )
            )
            assert live.all() == []
    finally:
        async with AsyncSession(engine) as session:
            await session.execute(delete(User).where(User.id == user.id))
            await session.commit()
