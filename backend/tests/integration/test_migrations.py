import asyncio
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from sqlalchemy.pool import NullPool

from alembic import command

ALEMBIC_INI = Path(__file__).resolve().parents[2] / "alembic.ini"


def test_models_match_the_migrated_schema(database_url: str) -> None:
    """`alembic check` fails if a model change ships without its migration."""
    command.check(Config(str(ALEMBIC_INI)))


@pytest.mark.anyio
async def test_test_database_is_at_the_latest_revision(engine: AsyncEngine) -> None:
    async with engine.connect() as connection:
        version = await connection.scalar(text("SELECT version_num FROM alembic_version"))

    head = ScriptDirectory.from_config(Config(str(ALEMBIC_INI))).get_current_head()
    assert version == head


BEFORE_SESSION_STARTED_AT = "6fa1bc92a72b"  # the revision before session_started_at


def test_session_started_at_is_backfilled_from_created_at_and_can_be_dropped(
    database_url: str,
) -> None:
    """Down to the revision before the column, add a user the old schema accepts, up again:
    the new column holds the user's `created_at`, and the schema is back at head afterwards."""
    config = Config(str(ALEMBIC_INI))
    user_id = uuid.uuid4()
    created_at = datetime(2026, 10, 1, 8, 0, tzinfo=UTC)

    async def run(sql: str, **params: object) -> list[Any]:
        engine = create_async_engine(database_url, poolclass=NullPool)
        try:
            async with engine.begin() as connection:
                result = await connection.execute(text(sql), params)
                return list(result.fetchall()) if result.returns_rows else []
        finally:
            await engine.dispose()

    command.downgrade(config, BEFORE_SESSION_STARTED_AT)
    try:
        columns = asyncio.run(
            run("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
        )
        assert ("session_started_at",) not in columns
        asyncio.run(
            run(
                "INSERT INTO users (id, email, password_hash, display_name, role, created_at) "
                "VALUES (:id, 'migrate@example.com', 'x', 'M', 'user', :created_at)",
                id=user_id,
                created_at=created_at,
            )
        )
        command.upgrade(config, "head")
        rows = asyncio.run(run("SELECT session_started_at FROM users WHERE id = :id", id=user_id))
        assert rows == [(created_at,)]
    finally:
        command.upgrade(config, "head")
        asyncio.run(run("DELETE FROM users WHERE id = :id", id=user_id))
