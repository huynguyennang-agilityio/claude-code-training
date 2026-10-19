"""Join, pause, resume and leave, against PostgreSQL and real tokens.

The overlap rule is checked three ways: through the API (the messages and status codes), on the
table itself (the exclusion constraint refuses what the service would), and with two joins at
once from separate connections (exactly one wins).
"""

import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.modules.auth.models import User
from app.modules.challenges.models import Challenge, Quest
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.service import ChallengeService
from app.modules.medals.repository import MedalRepository
from app.modules.medals.service import MedalService
from app.modules.runs.enrollments import EnrollmentService, OverlappingChallengeError
from app.modules.runs.models import Run
from app.modules.runs.repository import RunRepository
from app.modules.runs.service import RunService
from tests.api_docs import load_example
from tests.integration.enrollment_helpers import add_user, make_run
from tests.integration.test_auth_api import PREFIX, bearer, sign_up
from tests.integration.test_challenge_admin_api import (  # noqa: F401  (fixtures)
    _settings,
    admin,
    auth_settings,
    client,
    create,
    storage,
    user,
)

__all__ = ["_settings", "admin", "auth_settings", "client", "storage", "user"]

NOW = datetime.now(UTC)
DAY = timedelta(days=1)


def iso(moment: datetime) -> str:
    return moment.isoformat().replace("+00:00", "Z")


async def publish(
    client: AsyncClient,
    admin: dict[str, str],
    *,
    start: timedelta,
    end: timedelta,
    kind: str = "run",
    title: str = "Challenge",
) -> dict[str, Any]:
    """A published challenge whose window is `NOW + start` to `NOW + end`."""
    target = 1000 if kind != "run" else 50_000
    gold = {
        "tier": "gold",
        "name": "Gold",
        "threshold_value": target,
        "image_url": "https://res.cloudinary.com/demo/image/upload/g.png",
    }
    challenge = await create(
        client,
        admin,
        title=title,
        type=kind,
        target_value=target,
        starts_at=iso(NOW + start),
        ends_at=iso(NOW + end),
        medals=[gold],
    )
    response = await client.post(f"{PREFIX}/challenges/{challenge['id']}/publish", headers=admin)
    assert response.status_code == 200, response.text
    return dict(response.json())


async def act(
    client: AsyncClient, who: dict[str, str], challenge: dict[str, Any], action: str
) -> Any:
    return await client.post(f"{PREFIX}/challenges/{challenge['id']}/{action}", headers=who)


async def get_detail(client: AsyncClient, who: dict[str, str], challenge: dict[str, Any]) -> Any:
    return (await client.get(f"{PREFIX}/challenges/{challenge['id']}", headers=who)).json()


# the flow


@pytest.mark.anyio
async def test_join_pause_resume_and_leave_show_in_the_detail_and_the_list(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=-DAY, end=30 * DAY)

    joined = await act(client, user, challenge, "join")
    assert joined.status_code == 200, joined.text
    assert set(joined.json()) == set(load_example("challenges/challenge_detail.json"))
    assert joined.json()["enrollment"]["status"] == "active"
    assert joined.json()["participant_count"] == 1

    listed = (await client.get(f"{PREFIX}/challenges", headers=user)).json()["items"][0]
    assert listed["enrollment"]["status"] == "active"

    paused = await act(client, user, challenge, "pause")
    assert paused.json()["enrollment"]["status"] == "paused"
    assert paused.json()["participant_count"] == 1

    resumed = await act(client, user, challenge, "resume")
    assert resumed.json()["enrollment"]["status"] == "active"

    left = await act(client, user, challenge, "leave")
    assert left.json()["enrollment"] is None
    assert left.json()["participant_count"] == 0
    listed = (await client.get(f"{PREFIX}/challenges", headers=user)).json()["items"][0]
    assert listed["enrollment"] is None


@pytest.mark.anyio
async def test_someone_who_left_can_join_again(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")
    await act(client, user, challenge, "leave")

    again = await act(client, user, challenge, "join")

    assert again.status_code == 200
    assert again.json()["enrollment"]["status"] == "active"
    rows = (await session.scalars(select(Run).where(Run.challenge_id == challenge["id"]))).all()
    assert len(rows) == 1


@pytest.mark.anyio
async def test_joining_twice_is_already_joined(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")

    response = await act(client, user, challenge, "join")

    assert (response.status_code, response.json()["error"]["code"]) == (409, "already_joined")


@pytest.mark.anyio
async def test_a_challenge_that_has_started_can_still_be_joined_until_it_ends(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    running = await publish(client, admin, start=-DAY, end=30 * DAY)
    ended = await publish(client, admin, start=DAY, end=30 * DAY, title="Soon over")
    # It ended while published: only the stored window says so, the API can't make one.
    stored = await session.get(Challenge, ended["id"])
    assert stored is not None
    stored.starts_at = NOW - 3 * DAY
    stored.ends_at = NOW - DAY
    await session.flush()

    assert (await act(client, user, running, "join")).status_code == 200
    refused = await act(client, user, ended, "join")
    assert (refused.status_code, refused.json()["error"]["code"]) == (409, "challenge_ended")


@pytest.mark.anyio
async def test_a_draft_cannot_be_joined(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    draft = await create(client, admin)

    response = await act(client, user, draft, "join")

    assert (response.status_code, response.json()["error"]["code"]) == (404, "challenge_not_found")


@pytest.mark.anyio
@pytest.mark.parametrize("action", ["pause", "resume", "leave"])
async def test_someone_not_in_the_challenge_gets_not_found(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], action: str
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)

    response = await act(client, user, challenge, action)

    assert (response.status_code, response.json()["error"]["code"]) == (
        404,
        "enrollment_not_found",
    )


@pytest.mark.anyio
async def test_another_users_enrollment_is_not_reachable(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])

    for action in ("pause", "resume", "leave"):
        response = await act(client, other, challenge, action)
        assert (response.status_code, response.json()["error"]["code"]) == (
            404,
            "enrollment_not_found",
        )
    assert (await get_detail(client, user, challenge))["enrollment"]["status"] == "active"
    assert (await get_detail(client, other, challenge))["enrollment"] is None


@pytest.mark.anyio
async def test_pause_and_resume_in_the_wrong_state_are_conflicts(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=-DAY, end=30 * DAY)
    await act(client, user, challenge, "join")

    not_paused = await act(client, user, challenge, "resume")
    await act(client, user, challenge, "pause")
    not_active = await act(client, user, challenge, "pause")

    assert (not_paused.status_code, not_paused.json()["error"]["code"]) == (409, "not_paused")
    assert (not_active.status_code, not_active.json()["error"]["code"]) == (409, "not_active")


@pytest.mark.anyio
async def test_a_challenge_that_has_not_started_cannot_be_paused(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")

    refused = await act(client, user, challenge, "pause")

    assert (refused.status_code, refused.json()["error"]["code"]) == (409, "challenge_not_started")
    assert (await get_detail(client, user, challenge))["enrollment"]["status"] == "active"
    assert (await act(client, user, challenge, "leave")).status_code == 200


@pytest.mark.anyio
@pytest.mark.parametrize("action", ["join", "pause", "resume", "leave"])
async def test_the_routes_need_a_token(client: AsyncClient, action: str) -> None:
    assert (await client.post(f"{PREFIX}/challenges/1/{action}")).status_code == 401


# the overlap rule, through the API


@pytest.mark.anyio
async def test_a_challenge_that_starts_after_the_other_ends_can_be_joined(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    """Today is the 9th, the user is in a run ending on the 30th: October's run is fine."""
    september = await publish(client, admin, start=-8 * DAY, end=21 * DAY, title="September")
    october = await publish(client, admin, start=22 * DAY, end=52 * DAY, title="October")
    await act(client, user, september, "join")

    response = await act(client, user, october, "join")

    assert response.status_code == 200
    assert (await get_detail(client, user, october))["blocked_by"] is None


@pytest.mark.anyio
async def test_an_overlapping_challenge_of_the_same_type_is_blocked_and_named(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    first = await publish(client, admin, start=-DAY, end=20 * DAY, title="First run")
    second = await publish(client, admin, start=10 * DAY, end=40 * DAY, title="Second run")
    await act(client, user, first, "join")

    detail = await get_detail(client, user, second)
    refused = await act(client, user, second, "join")

    assert detail["blocked_by"] == {"id": first["id"], "title": "First run"}
    assert (refused.status_code, refused.json()["error"]["code"]) == (409, "overlapping_challenge")
    assert "First run" in refused.json()["error"]["message"]
    assert (await get_detail(client, user, first))["blocked_by"] is None


@pytest.mark.anyio
async def test_a_challenge_of_another_type_at_the_same_time_is_fine(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    run = await publish(client, admin, start=DAY, end=30 * DAY)
    swim = await publish(client, admin, start=DAY, end=30 * DAY, kind="swim")
    await act(client, user, run, "join")

    assert (await act(client, user, swim, "join")).status_code == 200


@pytest.mark.anyio
async def test_windows_that_only_touch_do_not_overlap(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    first = await publish(client, admin, start=DAY, end=10 * DAY)
    second = await publish(client, admin, start=10 * DAY, end=20 * DAY)
    await act(client, user, first, "join")

    assert (await act(client, user, second, "join")).status_code == 200


@pytest.mark.anyio
async def test_a_paused_challenge_frees_the_slot_and_resume_waits_for_it(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    first = await publish(client, admin, start=-DAY, end=30 * DAY, title="First")
    second = await publish(client, admin, start=5 * DAY, end=35 * DAY, title="Second")
    await act(client, user, first, "join")
    await act(client, user, first, "pause")

    assert (await act(client, user, second, "join")).status_code == 200
    blocked = await get_detail(client, user, first)
    resume = await act(client, user, first, "resume")

    assert blocked["blocked_by"] == {"id": second["id"], "title": "Second"}
    assert (resume.status_code, resume.json()["error"]["code"]) == (409, "overlapping_challenge")
    assert (await get_detail(client, user, first))["enrollment"]["status"] == "paused"

    await act(client, user, second, "leave")
    assert (await act(client, user, first, "resume")).status_code == 200


@pytest.mark.anyio
async def test_leaving_frees_the_slot(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    first = await publish(client, admin, start=DAY, end=30 * DAY)
    second = await publish(client, admin, start=5 * DAY, end=35 * DAY)
    await act(client, user, first, "join")
    await act(client, user, first, "leave")

    assert (await act(client, user, second, "join")).status_code == 200


@pytest.mark.anyio
async def test_two_users_can_be_in_overlapping_challenges(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    other = bearer((await sign_up(client, email="other@example.com"))["tokens"]["access_token"])

    assert (await act(client, user, challenge, "join")).status_code == 200
    joined = await act(client, other, challenge, "join")

    assert joined.json()["participant_count"] == 2


# a challenge people joined


@pytest.mark.anyio
async def test_a_draft_with_participants_cannot_be_deleted_and_the_counted_fields_are_frozen(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")
    await client.post(f"{PREFIX}/challenges/{challenge['id']}/unpublish", headers=admin)

    deleted = await client.delete(f"{PREFIX}/challenges/{challenge['id']}", headers=admin)
    changed = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}",
        json={"ends_at": iso(NOW + 99 * DAY)},
        headers=admin,
    )

    assert (deleted.status_code, deleted.json()["error"]["code"]) == (409, "challenge_in_use")
    assert (changed.status_code, changed.json()["error"]["code"]) == (409, "challenge_in_use")


@pytest.mark.anyio
async def test_a_draft_that_only_people_who_left_had_joined_can_be_deleted(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await publish(client, admin, start=DAY, end=30 * DAY)
    await act(client, user, challenge, "join")
    await act(client, user, challenge, "leave")
    await client.post(f"{PREFIX}/challenges/{challenge['id']}/unpublish", headers=admin)

    deleted = await client.delete(f"{PREFIX}/challenges/{challenge['id']}", headers=admin)

    assert deleted.status_code == 204
    session.expunge_all()
    assert (
        await session.scalars(select(Run).where(Run.challenge_id == challenge["id"]))
    ).all() == []


# the database refuses what the service would


@pytest.mark.anyio
async def test_the_table_refuses_two_overlapping_active_enrollments(session: AsyncSession) -> None:
    quest = Quest(title="Q", description="")
    first = _challenge(quest, "A", NOW, NOW + 10 * DAY)
    second = _challenge(quest, "B", NOW + 5 * DAY, NOW + 15 * DAY)
    session.add(quest)
    await session.flush()
    user_id = await add_user(session)
    session.add(make_run(user_id, first))
    await session.flush()

    with pytest.raises(IntegrityError, match="ex_runs_no_overlapping_active_challenges"):
        async with session.begin_nested():
            session.add(make_run(user_id, second))
            await session.flush()


@pytest.mark.anyio
@pytest.mark.parametrize("status", ["paused", "left"])
async def test_the_table_lets_a_paused_or_left_enrollment_overlap(
    session: AsyncSession, status: str
) -> None:
    quest = Quest(title="Q", description="")
    first = _challenge(quest, "A", NOW, NOW + 10 * DAY)
    second = _challenge(quest, "B", NOW + 5 * DAY, NOW + 15 * DAY)
    session.add(quest)
    await session.flush()
    user_id = await add_user(session)
    session.add_all([make_run(user_id, first, status=status), make_run(user_id, second)])

    await session.flush()


@pytest.mark.anyio
async def test_the_table_has_one_row_per_user_and_challenge(session: AsyncSession) -> None:
    quest = Quest(title="Q", description="")
    challenge = _challenge(quest, "A", NOW, NOW + 10 * DAY)
    session.add(quest)
    await session.flush()
    user_id = await add_user(session)
    session.add(make_run(user_id, challenge))
    await session.flush()

    with pytest.raises(IntegrityError, match="uq_runs_user_id_challenge_id"):
        async with session.begin_nested():
            session.add(make_run(user_id, challenge, status="left"))
            await session.flush()


def _challenge(quest: Quest, title: str, starts_at: datetime, ends_at: datetime) -> Challenge:
    challenge = Challenge(
        title=title,
        type="run",
        metric="steps",
        target_value=1000,
        starts_at=starts_at,
        ends_at=ends_at,
        status="published",
    )
    quest.challenges.append(challenge)
    return challenge


# two joins at once


async def _act(engine: AsyncEngine, user_id: uuid.UUID, action: str, challenge_id: int) -> str:
    """One `join` or `resume` on its own connection, committed, as a request would be."""
    async with AsyncSession(engine, expire_on_commit=False) as session:
        runs = RunService(RunRepository(session))
        challenges = ChallengeService(
            session,
            ChallengeRepository(session),
            MedalService(MedalRepository(session)),
            runs=runs,
        )
        enrollments = EnrollmentService(session, RunRepository(session), challenges.get)
        try:
            await getattr(enrollments, action)(user_id, challenge_id)
        except OverlappingChallengeError:
            return "overlap"
        return "joined"


async def _active_count(engine: AsyncEngine, user_id: uuid.UUID) -> int:
    async with AsyncSession(engine) as session:
        active = await session.scalars(
            select(Run).where(Run.user_id == user_id, Run.status == "active")
        )
        return len(active.all())


@pytest.mark.anyio
async def test_two_overlapping_joins_at_once_let_exactly_one_win(engine: AsyncEngine) -> None:
    """Each join runs on its own connection and commits, as two requests would."""
    user_id, first_id, second_id, quest_id = await _seed_two_overlapping_challenges(engine)
    try:
        results = await asyncio.gather(
            _act(engine, user_id, "join", first_id), _act(engine, user_id, "join", second_id)
        )

        assert sorted(results) == ["joined", "overlap"]
        assert await _active_count(engine, user_id) == 1
    finally:
        await _clean_up(engine, user_id, quest_id)


@pytest.mark.anyio
async def test_a_join_and_a_resume_at_once_let_exactly_one_win(engine: AsyncEngine) -> None:
    user_id, first_id, second_id, quest_id = await _seed_two_overlapping_challenges(engine)
    try:
        async with AsyncSession(engine, expire_on_commit=False) as session:
            first = await session.get(Challenge, first_id)
            assert first is not None
            session.add(make_run(user_id, first, status="paused", counting_from=NOW))
            await session.commit()

        results = await asyncio.gather(
            _act(engine, user_id, "resume", first_id), _act(engine, user_id, "join", second_id)
        )

        assert sorted(results) == ["joined", "overlap"]
        assert await _active_count(engine, user_id) == 1
    finally:
        await _clean_up(engine, user_id, quest_id)


@pytest.mark.anyio
async def test_a_join_waits_while_another_request_of_the_user_holds_the_lock(
    engine: AsyncEngine,
) -> None:
    """Deterministic: without the per-user lock the join would finish at once."""
    user_id, first_id, _, quest_id = await _seed_two_overlapping_challenges(engine)
    try:
        async with AsyncSession(engine) as holder:
            await RunRepository(holder).lock_user_enrollments(user_id)
            join = asyncio.create_task(_act(engine, user_id, "join", first_id))
            done, _ = await asyncio.wait({join}, timeout=0.5)
            assert not done, "join did not wait for the user's lock"
            await holder.rollback()

        assert await asyncio.wait_for(join, timeout=5) == "joined"
    finally:
        await _clean_up(engine, user_id, quest_id)


async def _seed_two_overlapping_challenges(engine: AsyncEngine) -> tuple[uuid.UUID, int, int, int]:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        quest = Quest(title="Race", description="")
        first = _challenge(quest, "Race A", NOW + DAY, NOW + 20 * DAY)
        second = _challenge(quest, "Race B", NOW + 5 * DAY, NOW + 25 * DAY)
        session.add(quest)
        user_id = await add_user(session, "racer")
        await session.commit()
        return user_id, first.id, second.id, quest.id


async def _clean_up(engine: AsyncEngine, user_id: uuid.UUID, quest_id: int) -> None:
    async with AsyncSession(engine) as session:
        await session.execute(delete(Quest).where(Quest.id == quest_id))
        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()
        left = await session.scalar(text("SELECT count(*) FROM runs"))
        assert left == 0
