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


BEFORE_STEP_HOURS = "e5a9b3c7d1f2"  # the revision before step_hours


def test_hours_from_is_set_for_joined_enrollments_and_step_hours_can_be_dropped(
    database_url: str,
) -> None:
    """Down to the revision before `step_hours`, add an active, a paused and a left enrollment,
    up again: the active and the paused one count hourly steps from the next whole hour, the left
    one has none; the table is gone after a downgrade."""
    config = Config(str(ALEMBIC_INI))
    users = {status: uuid.uuid4() for status in ("active", "paused", "left")}

    async def run(sql: str, **params: object) -> list[Any]:
        engine = create_async_engine(database_url, poolclass=NullPool)
        try:
            async with engine.begin() as connection:
                result = await connection.execute(text(sql), params)
                return list(result.fetchall()) if result.returns_rows else []
        finally:
            await engine.dispose()

    quest_id = None
    command.downgrade(config, BEFORE_STEP_HOURS)
    try:
        tables = asyncio.run(run("SELECT to_regclass('public.step_hours')"))
        assert tables == [(None,)]
        ((quest_id,),) = asyncio.run(
            run("INSERT INTO quests (title, description) VALUES ('Q', 'q') RETURNING id")
        )
        ((challenge_id,),) = asyncio.run(
            run(
                "INSERT INTO challenges (quest_id, title, target_value, starts_at, ends_at) "
                "VALUES (:quest, 'C', 1000, now() - interval '5 days', now() + interval '5 days') "
                "RETURNING id",
                quest=quest_id,
            )
        )
        for status, user_id in users.items():
            asyncio.run(
                run(
                    "INSERT INTO users (id, email, password_hash, display_name, role, "
                    "created_at, session_started_at) "
                    "VALUES (:id, :email, 'x', 'M', 'user', now(), now())",
                    id=user_id,
                    email=f"{status}-migrate@example.com",
                )
            )
            asyncio.run(
                run(
                    "INSERT INTO runs (user_id, challenge_id, joined_at, total_steps, completed, "
                    "status, type, starts_at, ends_at) SELECT :user, id, now(), 0, false, "
                    ":status, 'run', starts_at, ends_at FROM challenges WHERE id = :challenge",
                    user=user_id,
                    status=status,
                    challenge=challenge_id,
                )
            )
        command.upgrade(config, "head")
        rows = asyncio.run(
            run(
                "SELECT r.status, r.hours_from, "
                "date_trunc('hour', now()) + interval '1 hour' FROM runs r "
                "WHERE r.user_id = ANY(:ids)",
                ids=list(users.values()),
            )
        )
        by_status = {status: (hours_from, next_hour) for status, hours_from, next_hour in rows}
        for status in ("active", "paused"):
            hours_from, next_hour = by_status[status]
            assert hours_from is not None
            assert hours_from.minute == hours_from.second == 0
            assert hours_from.tzinfo is not None
            assert abs(hours_from - next_hour).total_seconds() <= 3600  # across an hour change
            assert hours_from > datetime.now(UTC)
        assert by_status["left"][0] is None
        assert asyncio.run(run("SELECT to_regclass('public.step_hours')")) == [("step_hours",)]
    finally:
        command.upgrade(config, "head")
        asyncio.run(run("DELETE FROM users WHERE id = ANY(:ids)", ids=list(users.values())))
        if quest_id is not None:
            asyncio.run(run("DELETE FROM quests WHERE id = :id", id=quest_id))
