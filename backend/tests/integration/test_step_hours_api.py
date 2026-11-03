"""`PUT /runs/step-hours` against PostgreSQL and real tokens (`docs/api/runs.md`)."""

from datetime import UTC, datetime, timedelta, timezone
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import User
from app.modules.runs.models import Run, StepHour
from tests.api_docs import load_example
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
from tests.integration.test_runs_progress_api import DAY, HOUR, join_running, mine, sample, sync

__all__ = ["_settings", "admin", "auth_settings", "client", "storage", "user"]

LONG_AGO = datetime.now(UTC) - 3 * DAY


def _hour_now() -> datetime:
    return datetime.now(UTC).replace(minute=0, second=0, microsecond=0)


# The current hour, read once at the start of each test (`_read_the_current_hour`), so a request
# and its assertions use the same hours even when an hour boundary passes in between.
_current_hour = _hour_now()


@pytest.fixture(autouse=True)
def _read_the_current_hour() -> None:
    global _current_hour
    _current_hour = _hour_now()


def ago(hours: int) -> datetime:
    """The start of the UTC hour that began `hours` hours before the current one."""
    return _current_hour - hours * HOUR


def body(*hours: tuple[datetime, int]) -> dict[str, Any]:
    return {"hours": [{"hour_start": iso(start), "steps": steps} for start, steps in hours]}


async def put_hours(client: AsyncClient, who: dict[str, str], *hours: tuple[datetime, int]) -> Any:
    return await client.put(f"{PREFIX}/runs/step-hours", json=body(*hours), headers=who)


async def set_bounds(session: AsyncSession, **changes: datetime) -> None:
    """Move the bounds of the enrollment (and `session_started_at` of the user) in the past."""
    session_started_at = changes.pop("session_started_at", None)
    if changes:
        await session.execute(update(Run).values(**changes))
    if session_started_at is not None:
        await session.execute(update(User).values(session_started_at=session_started_at))
    await session.flush()
    session.expire_all()


async def join_hourly(
    client: AsyncClient,
    admin: dict[str, str],
    who: dict[str, str],
    session: AsyncSession,
    **bounds: datetime,
) -> dict[str, Any]:
    """Join a running challenge and let every bound start long ago, except those given."""
    challenge = await join_running(client, admin, who, session)
    values = {
        "hours_from": LONG_AGO,
        "counting_from": LONG_AGO,
        "session_started_at": LONG_AGO,
        **bounds,
    }
    await set_bounds(session, **values)
    return challenge


async def stored(session: AsyncSession) -> dict[datetime, int]:
    rows = await session.execute(select(StepHour.hour_start, StepHour.steps))
    return {hour_start: steps for hour_start, steps in rows}


async def total_steps(session: AsyncSession) -> int:
    return int(await session.scalar(select(func.sum(Run.total_steps))) or 0)


def current_value(response: Any) -> int:
    return int(response.json()["enrollments"][0]["progress"]["current_value"])


@pytest.mark.anyio
async def test_the_route_needs_a_token(client: AsyncClient) -> None:
    response = await client.put(f"{PREFIX}/runs/step-hours", json=body((ago(2), 5)))

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


@pytest.mark.anyio
async def test_hours_are_counted_and_the_answer_has_the_progress(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_hourly(client, admin, user, session)

    response = await put_hours(client, user, (ago(3), 4120), (ago(2), 980), (ago(1), 18_250))

    assert response.status_code == 200, response.text
    answer = response.json()
    assert set(answer) == set(load_example("runs/step_hours_result.json"))
    assert (answer["accepted"], answer["ignored"]) == (2, 1)
    assert answer["enrollments"] == [
        {
            "challenge_id": challenge["id"],
            "progress": {
                "current_value": 5100,
                "target_value": 50000,
                "percent": 10,
                "tracked": True,
                "started": True,
            },
        }
    ]
    assert await stored(session) == {ago(3): 4120, ago(2): 980}


@pytest.mark.anyio
async def test_the_documented_example_request_is_accepted(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)

    response = await client.put(
        f"{PREFIX}/runs/step-hours",
        json=load_example("runs/step_hours_request.json"),
        headers=user,
    )

    assert response.status_code == 200, response.text


@pytest.mark.anyio
async def test_the_same_hour_twice_counts_once(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(2), 1000))

    again = await put_hours(client, user, (ago(2), 1000))

    assert (again.json()["accepted"], again.json()["ignored"]) == (1, 0)
    assert current_value(again) == 1000
    assert await total_steps(session) == 1000
    assert await stored(session) == {ago(2): 1000}


@pytest.mark.anyio
async def test_a_higher_and_then_a_lower_value_replace_the_hour(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(2), 1000), (ago(3), 200))

    higher = await put_hours(client, user, (ago(2), 1800))
    assert current_value(higher) == 2000
    lower = await put_hours(client, user, (ago(2), 300))

    assert current_value(lower) == 500
    assert await stored(session) == {ago(2): 300, ago(3): 200}
    assert await total_steps(session) == 500


@pytest.mark.anyio
async def test_an_hour_in_another_timezone_is_the_same_hour(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(2), 700))
    local = ago(2).astimezone(timezone(timedelta(hours=7)))

    response = await client.put(
        f"{PREFIX}/runs/step-hours",
        json={"hours": [{"hour_start": local.isoformat(), "steps": 900}]},
        headers=user,
    )

    assert current_value(response) == 900
    assert await stored(session) == {ago(2): 900}


@pytest.mark.anyio
async def test_total_steps_is_the_sum_of_the_hours_plus_the_samples_before(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session, hours_from=ago(7))
    before = sample("before-hours", 2500, ended_ago=8 * HOUR)  # starts before `hours_from`
    assert (await sync(client, user, before)).json()["accepted"] == 1
    requests = [
        [(ago(5), 100), (ago(4), 200)],
        [(ago(4), 50), (ago(3), 20_000), (ago(6), 7)],
        [(ago(5), 0), (ago(2), 15_000), (ago(1), 15_001)],
        [(ago(2), 14_000), (ago(4), 50)],
    ]

    for hours in requests:
        assert (await put_hours(client, user, *hours)).status_code == 200

    hours_sum = sum((await stored(session)).values())
    assert await stored(session) == {ago(6): 7, ago(5): 0, ago(4): 50, ago(2): 14_000}
    assert hours_sum == 14_057
    assert await total_steps(session) == 2500 + hours_sum
    listed = (await mine(client, user)).json()["items"][0]["progress"]
    assert listed["current_value"] == 2500 + hours_sum


# the hours that are ignored


@pytest.mark.anyio
@pytest.mark.parametrize("bound", ["session_started_at", "hours_from", "counting_from"])
async def test_an_hour_before_the_latest_bound_is_ignored(
    bound: str,
    client: AsyncClient,
    admin: dict[str, str],
    user: dict[str, str],
    session: AsyncSession,
) -> None:
    await join_hourly(client, admin, user, session, **{bound: ago(5) + timedelta(minutes=20)})

    response = await put_hours(client, user, (ago(5), 100), (ago(4), 200))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)
    assert await stored(session) == {ago(4): 200}
    assert current_value(response) == 200


@pytest.mark.anyio
async def test_an_hour_that_starts_exactly_at_a_bound_counts(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session, hours_from=ago(5), session_started_at=ago(5))

    response = await put_hours(client, user, (ago(5), 100), (ago(6), 100))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)


@pytest.mark.anyio
async def test_an_hour_before_the_challenge_starts_is_ignored(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await set_bounds(session, starts_at=ago(5))

    response = await put_hours(client, user, (ago(6), 100), (ago(5), 300))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)
    assert await stored(session) == {ago(5): 300}


@pytest.mark.anyio
@pytest.mark.parametrize(
    "ends_at",
    [ago(3) + timedelta(minutes=59, seconds=59), ago(2), ago(2) - timedelta(seconds=1)],
    ids=["end-of-hour", "on-the-hour", "just-before-the-hour"],
)
async def test_the_last_hour_is_the_end_rounded_up_to_a_whole_hour(
    ends_at: datetime,
    client: AsyncClient,
    admin: dict[str, str],
    user: dict[str, str],
    session: AsyncSession,
) -> None:
    await join_hourly(client, admin, user, session)
    await set_bounds(session, ends_at=ends_at)
    last_start = ago(3)

    response = await put_hours(client, user, (last_start, 10), (last_start + HOUR, 20))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)
    assert await stored(session) == {last_start: 10}


@pytest.mark.anyio
async def test_the_current_hour_counts_and_replaces_as_it_grows_but_the_next_does_not(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(0), 100))

    response = await put_hours(client, user, (ago(0), 250), (ago(-1), 999))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)
    assert await stored(session) == {ago(0): 250}
    assert current_value(response) == 250


@pytest.mark.anyio
async def test_more_than_15000_steps_in_an_hour_is_ignored_and_keeps_the_stored_value(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(2), 15_000))

    response = await put_hours(client, user, (ago(2), 15_001), (ago(3), 0))

    assert (response.json()["accepted"], response.json()["ignored"]) == (1, 1)
    assert await stored(session) == {ago(2): 15_000, ago(3): 0}
    assert current_value(response) == 15_000


@pytest.mark.anyio
async def test_the_hour_of_joining_does_not_count(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=-5 * DAY, end=25 * DAY)
    await act(client, user, challenge, "join")

    response = await put_hours(client, user, (ago(0), 300))

    assert (response.json()["accepted"], response.json()["ignored"]) == (0, 1)


@pytest.mark.anyio
async def test_joining_sets_hours_from_to_the_join_time_also_when_joining_again(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await publish(client, admin, start=-5 * DAY, end=25 * DAY)
    await act(client, user, challenge, "join")
    await act(client, user, challenge, "leave")
    await set_bounds(session, hours_from=LONG_AGO)

    await act(client, user, challenge, "join")

    run = (await session.scalars(select(Run).execution_options(populate_existing=True))).one()
    assert run.hours_from is not None
    assert run.hours_from == run.joined_at == run.counting_from
    assert run.hours_from > LONG_AGO


@pytest.mark.anyio
async def test_a_paused_enrollment_counts_nothing_and_an_hour_stored_before_stays(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_hourly(client, admin, user, session)
    await put_hours(client, user, (ago(5), 400))
    await act(client, user, challenge, "pause")

    paused = await put_hours(client, user, (ago(5), 9000), (ago(4), 100))

    assert (paused.json()["accepted"], paused.json()["ignored"]) == (0, 2)
    assert paused.json()["enrollments"] == []
    await act(client, user, challenge, "resume")
    resumed = await put_hours(client, user, (ago(5), 9000), (ago(4), 100))
    assert (resumed.json()["accepted"], resumed.json()["ignored"]) == (0, 2)
    assert await stored(session) == {ago(5): 400}
    assert current_value(resumed) == 400


@pytest.mark.anyio
async def test_a_left_enrollment_counts_nothing(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_hourly(client, admin, user, session)
    await act(client, user, challenge, "leave")

    response = await put_hours(client, user, (ago(2), 100))

    assert (response.json()["accepted"], response.json()["ignored"]) == (0, 1)
    assert await stored(session) == {}


@pytest.mark.anyio
async def test_a_swim_challenge_is_not_tracked(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    swim = await publish(client, admin, start=-5 * DAY, end=25 * DAY, kind="swim")
    await act(client, user, swim, "join")
    await set_bounds(
        session, hours_from=LONG_AGO, counting_from=LONG_AGO, session_started_at=LONG_AGO
    )

    response = await put_hours(client, user, (ago(2), 100))

    assert (response.json()["accepted"], response.json()["ignored"]) == (0, 1)
    assert response.json()["enrollments"][0]["progress"]["tracked"] is False
    assert await stored(session) == {}


@pytest.mark.anyio
async def test_another_users_hours_do_not_count_for_me(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await join_hourly(client, admin, user, session)
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])
    await act(client, other, challenge, "join")
    await set_bounds(session, hours_from=LONG_AGO, counting_from=LONG_AGO)
    await set_bounds(session, session_started_at=LONG_AGO)

    await put_hours(client, other, (ago(2), 700))

    assert current_value(await put_hours(client, user, (ago(3), 5))) == 5
    mine_now = (await mine(client, user)).json()["items"][0]["progress"]
    assert mine_now["current_value"] == 5


# a bad body


@pytest.mark.anyio
@pytest.mark.parametrize(
    "payload",
    [
        {"hours": []},
        {"hours": [{"hour_start": "2026-11-02T06:00:00Z", "steps": 1}] * 2},
        {"hours": [{"hour_start": "2026-11-02T06:30:00Z", "steps": 1}]},
        {"hours": [{"hour_start": "2026-11-02T06:00:00", "steps": 1}]},
        {"hours": [{"hour_start": 1762063200, "steps": 1}]},
        {"hours": [{"hour_start": "2026-11-02T06:00:00Z", "steps": -1}]},
        {"hours": [{"hour_start": "2026-11-02T06:00:00Z", "steps": 2_147_483_648}]},
        {"hours": [{"hour_start": "2026-11-02T06:00:00Z"}]},
        {},
    ],
    ids=[
        "empty",
        "duplicate",
        "not-on-the-hour",
        "no-timezone",
        "number",
        "negative",
        "too-large",
        "no-steps",
        "no-hours",
    ],
)
async def test_a_bad_body_is_a_validation_error(
    payload: dict[str, Any], client: AsyncClient, user: dict[str, str]
) -> None:
    response = await client.put(f"{PREFIX}/runs/step-hours", json=payload, headers=user)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert response.json()["error"]["fields"]


@pytest.mark.anyio
async def test_745_hours_are_refused_and_744_are_accepted(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    month_ago = ago(0) - 40 * DAY
    await join_hourly(
        client,
        admin,
        user,
        session,
        hours_from=month_ago,
        counting_from=month_ago,
        session_started_at=month_ago,
    )
    await set_bounds(session, starts_at=month_ago)

    too_many = await put_hours(client, user, *[(ago(n), 1) for n in range(745)])
    all_of_them = await put_hours(client, user, *[(ago(n), 1) for n in range(744)])

    assert too_many.status_code == 422
    assert too_many.json()["error"]["code"] == "validation_error"
    assert all_of_them.status_code == 200, all_of_them.text
    assert all_of_them.json()["accepted"] == 744
    assert await total_steps(session) == 744


@pytest.mark.anyio
async def test_the_same_hour_in_two_timezones_is_refused(
    client: AsyncClient, user: dict[str, str]
) -> None:
    payload = {
        "hours": [
            {"hour_start": "2026-11-02T06:00:00Z", "steps": 1},
            {"hour_start": "2026-11-02T13:00:00+07:00", "steps": 2},
        ]
    }

    response = await client.put(f"{PREFIX}/runs/step-hours", json=payload, headers=user)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
