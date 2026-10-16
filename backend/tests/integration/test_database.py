"""The real `get_session` dependency, without the test override."""

from collections.abc import Iterator

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.database import get_engine, get_session, get_sessionmaker
from app.modules.models import Quest


@pytest.fixture
def fresh_database_factories(database_url: str) -> Iterator[None]:
    """Make get_engine/get_sessionmaker read the test DATABASE_URL, then forget it."""
    get_engine.cache_clear()
    get_sessionmaker.cache_clear()
    yield
    get_sessionmaker.cache_clear()
    get_engine.cache_clear()


@pytest.mark.anyio
@pytest.mark.usefixtures("fresh_database_factories")
async def test_get_session_uses_settings_and_discards_uncommitted_work(
    database_url: str, engine: AsyncEngine
) -> None:
    sessions = get_session()
    session = await anext(sessions)
    try:
        current = await session.scalar(text("SELECT current_database()"))
        assert current == make_url(database_url).database

        session.add(Quest(title="Never committed", description=""))
        await session.flush()
    finally:
        await sessions.aclose()
        await get_engine().dispose()

    async with engine.connect() as connection:
        count = await connection.scalar(select(func.count()).select_from(Quest))
    assert count == 0
