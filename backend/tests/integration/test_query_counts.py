"""Endpoints send a fixed number of SQL statements, and nested responses don't add one per row.

The budgets are the current numbers: a new query in one of these paths fails here,
so it gets noticed and either justified (raise the budget) or removed.
"""

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.modules.challenges.models import Challenge, Quest
from app.modules.challenges.schemas import QuestRead
from app.modules.medals.models import Medal
from tests.integration.query_counter import QueryCounter
from tests.integration.test_auth_api import (  # noqa: F401  (autouse fixture)
    PREFIX,
    SIGNIN,
    SIGNUP,
    auth_settings,
    bearer,
    sign_up,
)

__all__ = ["auth_settings"]

MAX_QUERIES_FOR_CURRENT_USER = 1  # the user
MAX_QUERIES_FOR_SIGN_IN = 5  # attempts by email and by IP, user, clear attempts, refresh token
MAX_QUERIES_FOR_REFRESH = 2  # consume the old token, store the new one
MAX_QUERIES_FOR_QUEST_WITH_NESTED_ROWS = 3  # quests, challenges, medals


@pytest.fixture(autouse=True)
def _settings(auth_settings: None) -> None:  # noqa: PT004
    get_settings.cache_clear()


@pytest.mark.anyio
async def test_current_user_is_one_query(
    client: AsyncClient, session: AsyncSession, query_counter: QueryCounter
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.get(f"{PREFIX}/users/me", headers=bearer(token))

    assert response.status_code == 200
    assert len(queries) <= MAX_QUERIES_FOR_CURRENT_USER, queries.text()


@pytest.mark.anyio
async def test_sign_in_query_count_is_bounded(
    client: AsyncClient, session: AsyncSession, query_counter: QueryCounter
) -> None:
    await sign_up(client)
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.post(f"{PREFIX}/auth/signin", json=SIGNIN)

    assert response.status_code == 200
    assert len(queries) <= MAX_QUERIES_FOR_SIGN_IN, queries.text()


@pytest.mark.anyio
async def test_refresh_query_count_is_bounded(
    client: AsyncClient, session: AsyncSession, query_counter: QueryCounter
) -> None:
    refresh_token = (await sign_up(client))["tokens"]["refresh_token"]
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.post(
            f"{PREFIX}/auth/refresh", json={"refresh_token": refresh_token}
        )

    assert response.status_code == 200
    assert len(queries) <= MAX_QUERIES_FOR_REFRESH, queries.text()


async def add_quest(session: AsyncSession, challenges: int) -> int:
    """A quest with `challenges` challenges, each with a medal."""
    starts = datetime(2026, 1, 1, tzinfo=UTC)
    quest = Quest(
        title="Spring",
        description="",
        challenges=[
            Challenge(
                title=f"Challenge {number}",
                target_value=5000,
                starts_at=starts,
                ends_at=starts + timedelta(days=1),
                medals=[
                    Medal(
                        tier="gold",
                        threshold_value=5000,
                        name=f"Medal {number}",
                        image_url=f"https://cdn.test/{number}.png",
                    )
                ],
            )
            for number in range(challenges)
        ],
    )
    session.add(quest)
    await session.flush()
    quest_id = quest.id
    session.expunge_all()
    return quest_id


async def read_quest(session: AsyncSession, quest_id: int) -> dict[str, Any]:
    """The pattern of the `fastapi-module` skill: eager-load what the response nests."""
    quest = await session.scalar(
        select(Quest)
        .where(Quest.id == quest_id)
        .options(selectinload(Quest.challenges).selectinload(Challenge.medals))
    )
    assert quest is not None
    return QuestRead.model_validate(quest).model_dump()


@pytest.mark.anyio
@pytest.mark.parametrize("challenges", [1, 5, 25])
async def test_nested_response_uses_a_fixed_number_of_queries(
    session: AsyncSession, query_counter: QueryCounter, challenges: int
) -> None:
    quest_id = await add_quest(session, challenges)

    with query_counter.measure() as queries:
        quest = await read_quest(session, quest_id)

    assert len(quest["challenges"]) == challenges
    assert all(len(challenge["medals"]) == 1 for challenge in quest["challenges"])
    assert len(queries) <= MAX_QUERIES_FOR_QUEST_WITH_NESTED_ROWS, queries.text()


@pytest.mark.anyio
async def test_the_counter_sees_a_query_per_row(
    session: AsyncSession, query_counter: QueryCounter
) -> None:
    """The N+1 shape the budget above guards against: one extra query per challenge."""
    quest_id = await add_quest(session, 10)
    challenges = list(
        await session.scalars(select(Challenge).where(Challenge.quest_id == quest_id))
    )
    session.expunge_all()

    with query_counter.measure() as queries:
        for challenge in challenges:
            await session.scalar(select(Medal).where(Medal.challenge_id == challenge.id))

    assert len(queries) == 10


@pytest.mark.anyio
async def test_the_counter_ignores_savepoints(
    session: AsyncSession, query_counter: QueryCounter
) -> None:
    with query_counter.measure() as queries:
        async with session.begin_nested():
            await session.scalar(select(1))

    assert [sql for sql in queries if "SELECT" in sql] == ["SELECT 1"]
    assert not any(sql.upper().startswith(("SAVEPOINT", "RELEASE")) for sql in queries)
