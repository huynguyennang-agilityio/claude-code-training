"""The daily activity sync, against PostgreSQL and real tokens."""

from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import User
from app.modules.runs.models import DailyActivity
from tests.api_docs import load_example
from tests.integration.query_counter import QueryCounter
from tests.integration.test_auth_api import PREFIX, bearer, sign_up
from tests.integration.test_challenge_admin_api import (  # noqa: F401  (fixtures)
    _settings,
    auth_settings,
    client,
    storage,
    user,
)

__all__ = ["_settings", "auth_settings", "client", "storage", "user"]

MAX_QUERIES_FOR_A_SYNC = 3  # the user, the write, and room for one more


def today() -> date:
    return datetime.now(UTC).date()


def ago(days: int) -> str:
    """A day the server accepts: the example dates are in the future by now."""
    return (today() - timedelta(days=days)).isoformat()


async def put(client: AsyncClient, who: dict[str, str] | None, body: Any) -> Any:
    return await client.put(f"{PREFIX}/runs/daily-activity", json=body, headers=who or {})


async def rows(session: AsyncSession) -> list[DailyActivity]:
    session.expire_all()
    return list(await session.scalars(select(DailyActivity).order_by(DailyActivity.day)))


@pytest.mark.anyio
async def test_it_needs_a_token(client: AsyncClient) -> None:
    response = await put(client, None, {"days": [{"date": "2026-11-02"}]})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


@pytest.mark.anyio
async def test_days_are_stored_and_the_answer_lists_them(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    example = load_example("runs/daily_activity_request.json")
    example["days"][0]["date"], example["days"][1]["date"] = ago(1), ago(0)
    response = await put(client, user, example)

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == set(load_example("runs/daily_activity_result.json"))
    assert set(body["days"][0]) == set(load_example("runs/daily_activity_result.json")["days"][0])
    assert [day["date"] for day in body["days"]] == [ago(1), ago(0)]
    assert body["days"][1] == {
        "date": ago(0),
        "steps": 5490,
        "calories_kcal": None,
        "distance_m": None,
        "sleep_minutes": None,
        "updated_at": body["days"][1]["updated_at"],
    }
    stored = await rows(session)
    assert [(row.day.isoformat(), row.steps, row.sleep_minutes) for row in stored] == [
        (ago(1), 8412, 410),
        (ago(0), 5490, None),
    ]


@pytest.mark.anyio
async def test_a_day_is_replaced_not_added_to_and_a_missing_figure_goes_empty(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    await put(client, user, {"days": [{"date": ago(1), "steps": 100, "sleep_minutes": 400}]})

    again = await put(client, user, {"days": [{"date": ago(1), "steps": 250}]})

    assert again.status_code == 200
    (row,) = await rows(session)
    assert (row.steps, row.sleep_minutes) == (250, None)


@pytest.mark.anyio
async def test_each_user_has_their_own_rows(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])

    await put(client, user, {"days": [{"date": ago(1), "steps": 100}]})
    await put(client, other, {"days": [{"date": ago(1), "steps": 900}]})

    stored = await rows(session)
    assert sorted(row.steps or 0 for row in stored) == [100, 900]
    assert len({row.user_id for row in stored}) == 2


@pytest.mark.anyio
async def test_seven_days_are_one_write(
    client: AsyncClient, user: dict[str, str], session: AsyncSession, query_counter: QueryCounter
) -> None:
    start = today() - timedelta(days=6)
    body = {
        "days": [{"date": (start + timedelta(days=n)).isoformat(), "steps": n} for n in range(7)]
    }
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await put(client, user, body)

    assert response.status_code == 200
    assert len(response.json()["days"]) == 7
    assert len(queries) <= MAX_QUERIES_FOR_A_SYNC, queries.text()


@pytest.mark.anyio
async def test_tomorrow_is_accepted_and_the_day_after_is_not(
    client: AsyncClient, user: dict[str, str]
) -> None:
    tomorrow = (today() + timedelta(days=1)).isoformat()
    later = (today() + timedelta(days=2)).isoformat()

    assert (await put(client, user, {"days": [{"date": tomorrow, "steps": 1}]})).status_code == 200
    refused = await put(client, user, {"days": [{"date": later, "steps": 1}]})

    assert refused.status_code == 422
    error = refused.json()["error"]
    assert error["code"] == "validation_error"
    assert error["fields"][0]["field"] == "body.days.0.date"


@pytest.mark.anyio
@pytest.mark.parametrize(
    "body",
    [
        {},
        {"days": []},
        {"days": [{"date": "2026-11-02"}, {"date": "2026-11-02"}]},
        {"days": [{"date": "2026-11-02", "steps": -1}]},
        {"days": [{"date": "2026-11-02", "steps": 200001}]},
        {"days": [{"date": "2026-11-02", "sleep_minutes": 1441}]},
        {"days": [{"date": 20261102}]},
        {"days": [{"date": "2019-12-31"}]},
        {"days": "2026-11-02"},
    ],
)
async def test_a_bad_body_is_a_validation_error(
    client: AsyncClient, user: dict[str, str], body: Any
) -> None:
    response = await put(client, user, body)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.anyio
async def test_the_rows_go_with_the_user(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    await put(client, user, {"days": [{"date": ago(1), "steps": 100}]})
    assert len(await rows(session)) == 1

    await session.execute(delete(User))
    await session.flush()

    assert await rows(session) == []


@pytest.mark.anyio
async def test_the_table_refuses_a_negative_figure(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    await put(client, user, {"days": [{"date": ago(1), "steps": 100}]})
    (existing,) = await rows(session)

    session.add(
        DailyActivity(
            user_id=existing.user_id,
            day=today() - timedelta(days=9),
            steps=-1,
            updated_at=datetime.now(UTC),
        )
    )
    with pytest.raises(IntegrityError, match="ck_daily_activity_steps_non_negative"):
        await session.flush()
