"""Each integration test starts from a clean database.

The two tests run in file order: the first commits a row, the second checks it
is gone because the per-test transaction was rolled back.
"""

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.models import Quest


@pytest.mark.anyio
async def test_commits_a_row(session: AsyncSession) -> None:
    session.add(Quest(title="Isolation check", description=""))
    await session.commit()

    assert await session.scalar(select(func.count()).select_from(Quest)) == 1


@pytest.mark.anyio
async def test_row_from_previous_test_is_gone(session: AsyncSession) -> None:
    assert await session.scalar(select(func.count()).select_from(Quest)) == 0
