"""Step sync and the list of my challenges, against PostgreSQL and real tokens."""

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.runs.models import Run
from tests.api_docs import load_example
from tests.integration.query_counter import QueryCounter
from tests.integration.test_auth_api import PREFIX, bearer, sign_up
from tests.integration.test_challenge_admin_api import (  # noqa: F401  (fixtures)
    _settings,
    admin,
    auth_settings,
    client,
    storage,
    user,
)
from tests.integration.test_enrollments_api import act, iso, publish

__all__ = ["_settings", "admin", "auth_settings", "client", "storage", "user"]

DAY = timedelta(days=1)
HOUR = timedelta(hours=1)
MAX_QUERIES_FOR_MY_CHALLENGES = 3  # the user, the enrollments with their challenges, the counts


def now() -> datetime:
    return datetime.now(UTC)


def sample(record_id: str, steps: int, *, ended_ago: timedelta = 2 * HOUR) -> dict[str, Any]:
    end = now() - ended_ago
    return {
        "health_record_id": record_id,
        "start_time": iso(end - HOUR),
        "end_time": iso(end),
        "steps": steps,
    }


async def sync(client: AsyncClient, who: dict[str, str], *samples: dict[str, Any]) -> Any:
    return await client.post(f"{PREFIX}/runs/steps", json={"samples": list(samples)}, headers=who)


async def mine(client: AsyncClient, who: dict[str, str], query: str = "") -> Any:
    return await client.get(f"{PREFIX}/runs{query}", headers=who)


async def count_from_long_ago(session: AsyncSession) -> None:
    """Joining counts from now, so move it back for samples that ended hours ago."""
    await session.execute(update(Run).values(counting_from=now() - 3 * DAY))
    await session.flush()
    session.expire_all()


async def join_running(
    client: AsyncClient,
    admin: dict[str, str],
    who: dict[str, str],
    session: AsyncSession,
    *,
    title: str = "November steps",
) -> dict[str, Any]:
    challenge = await publish(client, admin, start=-5 * DAY, end=25 * DAY, title=title)
    assert (await act(client, who, challenge, "join")).status_code == 200
    await count_from_long_ago(session)
    return challenge


# who may call


@pytest.mark.anyio
async def test_both_routes_need_a_token(client: AsyncClient) -> None:
    assert (await client.get(f"{PREFIX}/runs")).status_code == 401
    assert (await client.post(f"{PREFIX}/runs/steps", json={"samples": []})).status_code == 401


# step sync


@pytest.mark.anyio
async def test_samples_are_counted_and_the_answer_has_the_progress(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_running(client, admin, user, session)

    response = await sync(client, user, sample("a", 4120), sample("b", 4880))

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == set(load_example("runs/step_sync_result.json"))
    assert (body["accepted"], body["ignored"]) == (2, 0)
    assert body["enrollments"] == [
        {
            "challenge_id": challenge["id"],
            "progress": {
                "current_value": 9000,
                "target_value": 50000,
                "percent": 18,
                "tracked": True,
                "started": True,
            },
        }
    ]


@pytest.mark.anyio
async def test_syncing_the_same_samples_again_changes_nothing(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_running(client, admin, user, session)
    first = sample("a", 1000)
    await sync(client, user, first)

    again = (await sync(client, user, first, sample("b", 500))).json()

    assert (again["accepted"], again["ignored"]) == (1, 1)
    assert again["enrollments"][0]["progress"]["current_value"] == 1500


@pytest.mark.anyio
async def test_steps_from_the_future_are_ignored(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_running(client, admin, user, session)

    body = (await sync(client, user, sample("future", 900, ended_ago=-HOUR))).json()

    assert (body["accepted"], body["ignored"]) == (0, 1)
    assert body["enrollments"][0]["progress"]["current_value"] == 0


@pytest.mark.anyio
async def test_steps_before_joining_are_ignored(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=-5 * DAY, end=25 * DAY)
    await act(client, user, challenge, "join")

    body = (await sync(client, user, sample("before-join", 900))).json()

    assert body["accepted"] == 0


@pytest.mark.anyio
async def test_steps_taken_while_paused_never_count(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_running(client, admin, user, session)
    await act(client, user, challenge, "pause")

    paused = (await sync(client, user, sample("while-paused", 400))).json()
    assert (paused["accepted"], paused["enrollments"]) == (0, [])

    await act(client, user, challenge, "resume")
    resumed = (await sync(client, user, sample("while-paused", 400))).json()
    assert resumed["accepted"] == 0
    assert resumed["enrollments"][0]["progress"]["current_value"] == 0


@pytest.mark.anyio
async def test_a_swim_challenge_is_not_tracked(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    swim = await publish(client, admin, start=-5 * DAY, end=25 * DAY, kind="swim")
    await act(client, user, swim, "join")
    await count_from_long_ago(session)

    body = (await sync(client, user, sample("a", 100))).json()

    assert body["accepted"] == 0
    assert body["enrollments"][0]["progress"]["tracked"] is False


@pytest.mark.anyio
async def test_another_users_steps_do_not_count_for_me(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_running(client, admin, user, session)
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])
    await act(client, other, challenge, "join")

    await sync(client, other, sample("theirs", 700))

    mine_now = (await mine(client, user)).json()["items"][0]["progress"]
    assert mine_now["current_value"] == 0


@pytest.mark.anyio
@pytest.mark.parametrize(
    "samples",
    [
        [],
        [
            {
                "health_record_id": "",
                "start_time": "2026-11-02T06:30:00Z",
                "end_time": "2026-11-02T07:00:00Z",
                "steps": 5,
            }
        ],
        [
            {
                "health_record_id": "a",
                "start_time": "2026-11-02T06:30:00Z",
                "end_time": "2026-11-02T07:00:00Z",
                "steps": 0,
            }
        ],
        [
            {
                "health_record_id": "a",
                "start_time": "2026-11-02T06:30:00Z",
                "end_time": "2026-11-02T07:00:00Z",
                "steps": 100001,
            }
        ],
        [
            {
                "health_record_id": "a",
                "start_time": "2026-11-02T07:00:00Z",
                "end_time": "2026-11-02T06:30:00Z",
                "steps": 5,
            }
        ],
        [
            {
                "health_record_id": "a",
                "start_time": "2026-11-01T06:30:00Z",
                "end_time": "2026-11-03T06:31:00Z",
                "steps": 5,
            }
        ],
        [
            {
                "health_record_id": "a",
                "start_time": "2026-11-02T06:30:00",
                "end_time": "2026-11-02T07:00:00",
                "steps": 5,
            }
        ],
        [{"health_record_id": "a", "start_time": 1, "end_time": 2, "steps": 5}],
        [
            {
                "health_record_id": "a\u0000",
                "start_time": "2026-11-02T06:30:00Z",
                "end_time": "2026-11-02T07:00:00Z",
                "steps": 5,
            }
        ],
    ],
)
async def test_a_bad_body_is_a_validation_error(
    client: AsyncClient, user: dict[str, str], samples: list[dict[str, Any]]
) -> None:
    response = await client.post(f"{PREFIX}/runs/steps", json={"samples": samples}, headers=user)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.anyio
async def test_more_than_500_samples_are_refused(client: AsyncClient, user: dict[str, str]) -> None:
    many = [sample(f"r{number}", 1) for number in range(501)]

    response = await sync(client, user, *many)

    assert response.status_code == 422


# the list


@pytest.mark.anyio
async def test_the_list_shows_active_and_paused_with_progress_and_hides_left(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    running = await join_running(client, admin, user, session)
    swim = await publish(client, admin, start=3 * DAY, end=20 * DAY, kind="swim", title="Swim")
    cycle = await publish(client, admin, start=4 * DAY, end=20 * DAY, kind="cycle", title="Ride")
    await act(client, user, swim, "join")
    await act(client, user, swim, "pause")
    await act(client, user, cycle, "join")
    await act(client, user, cycle, "leave")
    await sync(client, user, sample("a", 25_000))

    response = await mine(client, user)

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == set(load_example("runs/my_challenge_page.json"))
    assert [item["challenge"]["id"] for item in body["items"]] == [running["id"], swim["id"]]
    first, second = body["items"]
    assert first["challenge"]["enrollment"]["status"] == "active"
    assert first["progress"] == {
        "current_value": 25_000,
        "target_value": 50_000,
        "percent": 50,
        "tracked": True,
        "started": True,
    }
    assert second["challenge"]["enrollment"]["status"] == "paused"
    assert second["progress"]["started"] is False
    assert second["progress"]["tracked"] is False
    assert body["next_cursor"] is None


@pytest.mark.anyio
async def test_an_empty_list_is_an_empty_page(client: AsyncClient, user: dict[str, str]) -> None:
    response = await mine(client, user)

    assert response.json() == {"items": [], "next_cursor": None}


@pytest.mark.anyio
async def test_the_list_pages_with_a_cursor(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    ids = []
    for number, start in enumerate((2, 4, 6), 1):
        challenge = await publish(
            client, admin, start=start * DAY, end=40 * DAY, kind="swim", title=f"Swim {number}"
        )
        await act(client, user, challenge, "join")
        await act(client, user, challenge, "pause")
        ids.append(challenge["id"])

    first = (await mine(client, user, "?limit=2")).json()
    second = (await mine(client, user, f"?limit=2&cursor={first['next_cursor']}")).json()

    assert [item["challenge"]["id"] for item in first["items"]] == ids[:2]
    assert first["next_cursor"] is not None
    assert [item["challenge"]["id"] for item in second["items"]] == ids[2:]
    assert second["next_cursor"] is None


@pytest.mark.anyio
@pytest.mark.parametrize("query", ["?cursor=!!", "?cursor=bm90LWEtY3Vyc29y", "?cursor=MDow"])
async def test_a_bad_cursor_is_refused(
    client: AsyncClient, user: dict[str, str], query: str
) -> None:
    response = await mine(client, user, query)

    assert response.status_code == 422
    assert response.json()["error"]["code"] in {"invalid_cursor", "validation_error"}


@pytest.mark.anyio
@pytest.mark.parametrize("query", ["?limit=0", "?limit=51", "?status=paused"])
async def test_a_bad_query_is_a_validation_error(
    client: AsyncClient, user: dict[str, str], query: str
) -> None:
    response = await mine(client, user, query)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.anyio
async def test_someone_elses_enrollment_never_shows_in_my_list(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])
    await act(client, other, challenge, "join")

    assert (await mine(client, user)).json()["items"] == []
    assert len((await mine(client, other)).json()["items"]) == 1


@pytest.mark.anyio
async def test_the_list_sends_a_fixed_number_of_queries(
    client: AsyncClient,
    admin: dict[str, str],
    user: dict[str, str],
    session: AsyncSession,
    query_counter: QueryCounter,
) -> None:
    for number in range(4):
        challenge = await publish(
            client, admin, start=(number + 1) * DAY, end=60 * DAY, kind="swim", title=f"S{number}"
        )
        await act(client, user, challenge, "join")
        await act(client, user, challenge, "pause")
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await mine(client, user)

    assert len(response.json()["items"]) == 4
    assert len(queries) <= MAX_QUERIES_FOR_MY_CHALLENGES, queries.text()


@pytest.mark.anyio
async def test_resuming_restarts_the_counting_time(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_running(client, admin, user, session)
    await act(client, user, challenge, "pause")
    before = now()

    await act(client, user, challenge, "resume")

    session.expire_all()
    run = (await session.scalars(__import__("sqlalchemy").select(Run))).one()
    assert run.counting_from is not None and run.counting_from >= before
