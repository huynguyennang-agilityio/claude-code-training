"""Requests that issue or revoke a user's refresh tokens wait for a password change of
that user, on real connections.

Each side runs on its own connection and commits, as two requests would. One connection
holds the per-user lock, as `change_password` does once the password is checked; the
request under test must still be waiting, then see the change once it commits.
"""

import asyncio
import uuid
from collections.abc import AsyncIterator, Iterator

import pytest
from sqlalchemy import delete, or_, select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.core.config import get_settings
from app.core.security import hash_password
from app.modules.auth.deps import get_auth_settings
from app.modules.auth.models import LoginAttempt, RefreshToken, User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import ChangePasswordRequest, SignInRequest, SignUpRequest, TokenPair
from app.modules.auth.service import (
    AuthService,
    IncorrectPasswordError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
)

SECRET = "an-integration-test-secret-that-is-long-enough"
PASSWORD = "run4medals"
OTHER_PASSWORD = "newrun5medals"
IP = "203.0.113.9"
# How long the waiting request may take to verify its password and reach the lock.
REACH_THE_LOCK_TIMEOUT = 10.0


@pytest.fixture(autouse=True)
def auth_settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("JWT_SECRET", SECRET)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _service(session: AsyncSession) -> AuthService:
    return AuthService(session, AuthRepository(session), get_auth_settings())


@pytest.fixture
async def signed_up(engine: AsyncEngine) -> AsyncIterator[tuple[User, TokenPair]]:
    """A committed user and its first token pair, deleted after the test."""
    async with AsyncSession(engine, expire_on_commit=False) as session:
        user, tokens = await _service(session).sign_up(
            SignUpRequest(
                email=f"lock-{uuid.uuid4().hex[:8]}@example.com",
                password=PASSWORD,
                display_name="Lock Runner",
            )
        )
    yield user, tokens
    async with AsyncSession(engine) as session:
        await session.execute(delete(User).where(User.id == user.id))
        # The refused sign-ins and changes record failed attempts, which have no foreign key
        # to the user and would count against this IP for the rest of the test session.
        await session.execute(
            delete(LoginAttempt).where(or_(LoginAttempt.email == user.email, LoginAttempt.ip == IP))
        )
        await session.commit()


async def _wait_until_a_session_waits_for_an_advisory_lock(
    engine: AsyncEngine, task: "asyncio.Future[str]"
) -> None:
    """Poll `pg_stat_activity` until another connection is blocked on an advisory lock, so
    the test exercises the wait and not a request that is still hashing. Each poll runs in a
    new transaction: PostgreSQL keeps one activity snapshot per transaction."""
    deadline = asyncio.get_running_loop().time() + REACH_THE_LOCK_TIMEOUT
    while True:
        assert not task.done(), "the request finished without waiting for the lock"
        async with engine.connect() as connection:
            waiting = await connection.scalar(
                text(
                    "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() "
                    "AND wait_event_type = 'Lock' AND wait_event = 'advisory'"
                )
            )
        if waiting:
            return
        assert asyncio.get_running_loop().time() < deadline, "no request reached the lock"
        await asyncio.sleep(0.05)


async def _change_password_while_holding_the_lock(
    engine: AsyncEngine, user: User, waiting: "asyncio.Future[str]"
) -> None:
    """Hold the user's lock, check `waiting` is blocked, then change the password, revoke
    every refresh token and commit, as `change_password` does."""
    async with AsyncSession(engine, expire_on_commit=False) as holder:
        repository = AuthRepository(holder)
        stored = await holder.get(User, user.id)
        assert stored is not None
        await repository.lock_user_refresh_tokens(user.id)
        task = asyncio.ensure_future(waiting)
        await _wait_until_a_session_waits_for_an_advisory_lock(engine, task)

        await repository.update_password_hash(stored, hash_password(OTHER_PASSWORD))
        await repository.revoke_all_refresh_tokens(user.id, user.created_at)
        await holder.commit()
    waiting_result = await asyncio.wait_for(task, timeout=10)
    assert waiting_result == "refused"


async def _live_tokens(engine: AsyncEngine, user_id: uuid.UUID) -> list[RefreshToken]:
    async with AsyncSession(engine) as session:
        live = await session.scalars(
            select(RefreshToken).where(
                RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None)
            )
        )
        return list(live.all())


async def _refresh(engine: AsyncEngine, refresh_token: str) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        try:
            await _service(session).refresh(refresh_token)
        except InvalidRefreshTokenError:
            return "refused"
        return "refreshed"


async def _sign_in(engine: AsyncEngine, email: str) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        try:
            await _service(session).sign_in(SignInRequest(email=email, password=PASSWORD), IP)
        except InvalidCredentialsError:
            return "refused"
        return "signed in"


async def _change_password(engine: AsyncEngine, user_id: uuid.UUID) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        user = await session.get(User, user_id)
        assert user is not None
        try:
            await _service(session).change_password(
                user,
                ChangePasswordRequest(current_password=PASSWORD, new_password="third6medals"),
                IP,
            )
        except IncorrectPasswordError:
            return "refused"
        return "changed"


@pytest.mark.anyio
async def test_a_refresh_waits_for_a_password_change_and_then_fails(
    engine: AsyncEngine, signed_up: tuple[User, TokenPair]
) -> None:
    user, tokens = signed_up

    await _change_password_while_holding_the_lock(
        engine, user, _refresh(engine, tokens.refresh_token)
    )

    assert await _live_tokens(engine, user.id) == []


@pytest.mark.anyio
async def test_a_sign_in_with_the_old_password_waits_for_a_password_change_and_then_fails(
    engine: AsyncEngine, signed_up: tuple[User, TokenPair]
) -> None:
    user, _ = signed_up

    await _change_password_while_holding_the_lock(engine, user, _sign_in(engine, user.email))

    assert await _live_tokens(engine, user.id) == []


@pytest.mark.anyio
async def test_a_second_password_change_with_the_old_password_waits_and_then_fails(
    engine: AsyncEngine, signed_up: tuple[User, TokenPair]
) -> None:
    user, _ = signed_up

    await _change_password_while_holding_the_lock(engine, user, _change_password(engine, user.id))

    assert await _live_tokens(engine, user.id) == []
    # The first change's password stands; the refused one changed nothing.
    async with AsyncSession(engine) as session:
        with pytest.raises(InvalidCredentialsError):
            await _service(session).sign_in(SignInRequest(email=user.email, password=PASSWORD), IP)
        _, pair = await _service(session).sign_in(
            SignInRequest(email=user.email, password=OTHER_PASSWORD), IP
        )
    assert pair.refresh_token
