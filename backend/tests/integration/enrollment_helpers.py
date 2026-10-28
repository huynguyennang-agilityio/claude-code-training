"""Rows for tests that need users and enrollments."""

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import User
from app.modules.challenges.models import Challenge
from app.modules.runs.models import Run

JOINED = datetime(2026, 10, 1, tzinfo=UTC)


async def add_user(session: AsyncSession, name: str = "runner") -> uuid.UUID:
    user = User(
        id=uuid.uuid4(),
        email=f"{name}-{uuid.uuid4().hex[:8]}@example.com",
        password_hash="not-a-real-hash",
        display_name=name,
        created_at=JOINED,
    )
    session.add(user)
    await session.flush()
    return user.id


def make_run(user_id: uuid.UUID, challenge: Challenge, **changes: Any) -> Run:
    """An enrollment that copies the type and window of the challenge, as joining does."""
    values: dict[str, Any] = {
        "user_id": user_id,
        "challenge": challenge,
        "joined_at": JOINED,
        "type": challenge.type or "run",
        "starts_at": challenge.starts_at,
        "ends_at": challenge.ends_at,
    }
    values.update(changes)
    return Run(**values)


async def join_directly(
    session: AsyncSession, challenge_id: int, user_id: uuid.UUID, status: str = "active"
) -> None:
    """Enroll a user without the service, copying the window from the stored challenge."""
    challenge = await session.get(Challenge, challenge_id)
    assert challenge is not None
    session.add(make_run(user_id, challenge, status=status))
    await session.flush()
