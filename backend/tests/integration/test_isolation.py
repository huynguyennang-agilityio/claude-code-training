"""Each integration test starts from a clean database.

Both tests check the table is empty before they act, so the clean-state rule
is checked whatever order the tests run in. Run in file order, the second also
proves that the row the first one committed was rolled back.
"""

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.models import Quest


async def _quest_count(session: AsyncSession) -> int | None:
    return await session.scalar(select(func.count()).select_from(Quest))


@pytest.mark.anyio
async def test_commits_a_row(session: AsyncSession) -> None:
    assert await _quest_count(session) == 0

    session.add(Quest(title="Isolation check", description=""))
    await session.commit()

    assert await _quest_count(session) == 1


@pytest.mark.anyio
async def test_row_from_previous_test_is_gone(session: AsyncSession) -> None:
    assert await _quest_count(session) == 0
