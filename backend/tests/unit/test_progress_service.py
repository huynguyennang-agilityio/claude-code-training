"""Counting synced steps toward enrollments, and listing them, with the database mocked.

Against a real database (the unique record per enrollment, the lock, the query count) these are
in `tests/integration/test_runs_progress_api.py`.
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.modules.challenges.models import Challenge
from app.modules.runs.models import Run
from app.modules.runs.progress import (
    CLOCK_MARGIN,
    InvalidRunCursorError,
    ProgressService,
    decode_cursor,
    encode_cursor,
    progress_of,
)
from app.modules.runs.repository import RunRepository
from app.modules.runs.schemas import StepHourIn, StepSampleIn
from app.modules.runs.service import RunService

NOW = datetime(2026, 11, 10, 12, 0, tzinfo=UTC)
USER = uuid.UUID("00000000-0000-0000-0000-000000000001")
HOUR = timedelta(hours=1)
# Step samples count only before `hours_from`, so by default it is past every sample the tests
# send, and each step-sync test fails only on the rule it names. Hour tests set it themselves.
SAMPLES_OPEN = NOW + HOUR


def make_run(**changes: Any) -> Run:
    challenge_id = changes.get("challenge_id", 3)
    challenge = Challenge(
        id=challenge_id,
        title="November",
        type="run",
        metric="steps",
        target_value=50_000,
        status="published",
        starts_at=NOW - 9 * 24 * HOUR,
        ends_at=NOW + 20 * 24 * HOUR,
    )
    values: dict[str, Any] = {
        "id": 11,
        "user_id": USER,
        "challenge_id": challenge_id,
        "challenge": challenge,
        "status": "active",
        "type": "run",
        "joined_at": NOW - 5 * 24 * HOUR,
        "counting_from": NOW - 5 * 24 * HOUR,
        "hours_from": SAMPLES_OPEN,
        "starts_at": NOW - 9 * 24 * HOUR,
        "ends_at": NOW + 20 * 24 * HOUR,
        "total_steps": 0,
    }
    values.update(changes)
    return Run(**values)


def sample(record_id: str, steps: int, *, ended: timedelta = timedelta(hours=-2)) -> StepSampleIn:
    end = NOW + ended
    return StepSampleIn(
        health_record_id=record_id, start_time=end - HOUR, end_time=end, steps=steps
    )


def service(runs: list[Run], known: set[str] | None = None) -> tuple[ProgressService, AsyncMock]:
    repository = MagicMock(spec=RunRepository)
    repository.active_with_challenge = AsyncMock(return_value=runs)
    repository.known_record_ids = AsyncMock(return_value=known or set())
    repository.add_samples = AsyncMock()
    session = AsyncMock()
    return (
        ProgressService(session, repository, RunService(repository), now=lambda: NOW),
        repository.add_samples,
    )


@pytest.mark.anyio
async def test_new_samples_in_the_window_are_counted_and_stored() -> None:
    run = make_run()
    progress, add_samples = service([run])

    result = await progress.sync_steps(USER, [sample("a", 4000), sample("b", 5000)])

    assert (result.accepted, result.ignored) == (2, 0)
    assert run.total_steps == 9000
    assert result.enrollments[0].progress.percent == 18
    assert len(add_samples.await_args.args[0]) == 2


@pytest.mark.anyio
async def test_a_record_already_stored_counts_once() -> None:
    run = make_run(total_steps=4000)
    progress, _ = service([run], known={"a"})

    result = await progress.sync_steps(USER, [sample("a", 4000), sample("b", 1000)])

    assert (result.accepted, result.ignored) == (1, 1)
    assert run.total_steps == 5000


@pytest.mark.anyio
async def test_the_same_record_twice_in_one_request_counts_once() -> None:
    run = make_run()
    progress, _ = service([run])

    result = await progress.sync_steps(USER, [sample("a", 100), sample("a", 100)])

    assert (result.accepted, result.ignored) == (1, 0)
    assert run.total_steps == 100


@pytest.mark.anyio
async def test_steps_before_the_enrollment_counts_from_are_ignored() -> None:
    run = make_run(counting_from=NOW - 3 * HOUR)
    progress, _ = service([run])

    result = await progress.sync_steps(
        USER, [sample("before", 700, ended=-2 * HOUR - HOUR), sample("after", 300, ended=-HOUR)]
    )

    assert (result.accepted, result.ignored) == (1, 1)
    assert run.total_steps == 300


@pytest.mark.anyio
async def test_steps_starting_at_or_after_hours_from_are_ignored() -> None:
    hours_from = NOW - 2 * HOUR
    run = make_run(hours_from=hours_from)
    progress, add_samples = service([run])
    before = StepSampleIn(
        health_record_id="before",
        start_time=hours_from - timedelta(minutes=1),
        end_time=hours_from + timedelta(minutes=29),
        steps=300,
    )
    at = StepSampleIn(
        health_record_id="at",
        start_time=hours_from,
        end_time=hours_from + HOUR,
        steps=700,
    )

    result = await progress.sync_steps(
        USER, [before, at, sample("after", 50, ended=-HOUR + timedelta(minutes=30))]
    )

    assert (result.accepted, result.ignored) == (1, 2)
    assert run.total_steps == 300
    assert [row.health_record_id for row in add_samples.await_args.args[0]] == ["before"]


@pytest.mark.anyio
async def test_a_null_hours_from_has_no_cutoff() -> None:
    run = make_run(hours_from=None)
    progress, _ = service([run])

    result = await progress.sync_steps(USER, [sample("a", 400, ended=-HOUR)])

    assert (result.accepted, result.ignored) == (1, 0)


@pytest.mark.anyio
async def test_a_null_counting_from_falls_back_to_the_join_time() -> None:
    run = make_run(counting_from=None, joined_at=NOW - 3 * HOUR)
    progress, _ = service([run])

    result = await progress.sync_steps(USER, [sample("old", 5, ended=-5 * HOUR)])

    assert result.accepted == 0


@pytest.mark.anyio
async def test_steps_before_the_challenge_starts_are_ignored() -> None:
    run = make_run(starts_at=NOW - HOUR, counting_from=NOW - 20 * HOUR)
    progress, _ = service([run])

    result = await progress.sync_steps(USER, [sample("early", 10, ended=-3 * HOUR)])

    assert result.accepted == 0


@pytest.mark.anyio
async def test_steps_from_the_future_are_ignored_but_a_small_clock_skew_is_not() -> None:
    run = make_run()
    progress, _ = service([run])

    result = await progress.sync_steps(
        USER,
        [
            sample("skew", 10, ended=CLOCK_MARGIN),
            sample("future", 10, ended=CLOCK_MARGIN + timedelta(minutes=1)),
        ],
    )

    assert (result.accepted, result.ignored) == (1, 1)


@pytest.mark.anyio
async def test_steps_after_the_challenge_ended_are_ignored() -> None:
    run = make_run(ends_at=NOW - HOUR, starts_at=NOW - 10 * HOUR)
    progress, _ = service([run])

    result = await progress.sync_steps(
        USER, [sample("late", 10, ended=-HOUR + timedelta(minutes=30))]
    )

    assert result.accepted == 0


@pytest.mark.anyio
async def test_a_swim_enrollment_counts_nothing_and_is_not_tracked() -> None:
    run = make_run(type="swim")
    run.challenge.type = "swim"
    run.challenge.target_value = 20_000
    progress, add_samples = service([run])

    result = await progress.sync_steps(USER, [sample("a", 500)])

    assert (result.accepted, result.ignored) == (0, 1)
    assert run.total_steps == 0
    assert result.enrollments[0].progress.tracked is False
    add_samples.assert_not_awaited()


@pytest.mark.anyio
async def test_no_active_enrollment_ignores_everything() -> None:
    progress, add_samples = service([])

    result = await progress.sync_steps(USER, [sample("a", 500)])

    assert (result.accepted, result.ignored, result.enrollments) == (0, 1, [])
    add_samples.assert_not_awaited()


def test_percent_never_exceeds_100_and_is_a_whole_number() -> None:
    assert progress_of(make_run(total_steps=60_000), NOW).percent == 100
    assert progress_of(make_run(total_steps=9_999), NOW).percent == 19
    assert progress_of(make_run(total_steps=0), NOW).percent == 0


def test_started_follows_the_start_date() -> None:
    assert progress_of(make_run(starts_at=NOW + HOUR), NOW).started is False
    assert progress_of(make_run(starts_at=NOW), NOW).started is True


def test_a_cursor_round_trips() -> None:
    starts_at = datetime(2026, 11, 1, 8, 30, 15, 123456, tzinfo=UTC)
    run = make_run(id=42, starts_at=starts_at)

    assert decode_cursor(encode_cursor(run)) == (starts_at, 42)


@pytest.mark.parametrize(
    "cursor", ["!!", "bm90LWEtY3Vyc29y", "MDow", "LTE6LTE", "OTk5OTk5OTk5OTk5OTk5OjE"]
)
def test_a_cursor_that_is_not_ours_is_refused(cursor: str) -> None:
    with pytest.raises(InvalidRunCursorError):
        decode_cursor(cursor)


@pytest.mark.anyio
async def test_the_list_has_a_next_cursor_only_when_more_follow() -> None:
    runs = [make_run(id=number, challenge_id=number) for number in (1, 2, 3)]
    repository = MagicMock(spec=RunRepository)
    repository.joined_page = AsyncMock(return_value=runs)
    repository.counts_for_challenges = AsyncMock(return_value={1: 5})
    progress = ProgressService(AsyncMock(), repository, RunService(repository), now=lambda: NOW)

    page = await progress.my_challenges(USER, limit=2, cursor=None)

    assert [item.challenge.id for item in page.items] == [1, 2]
    assert page.next_cursor is not None
    repository.joined_page.assert_awaited_once_with(USER, limit=3, after=None)


# hourly steps


def hour(offset_hours: int, steps: int) -> StepHourIn:
    """The hour that started `offset_hours` before NOW (NOW is on the hour)."""
    return StepHourIn(hour_start=NOW - offset_hours * HOUR, steps=steps)


def hours_service(
    runs: list[Run], stored: dict[datetime, int] | None = None
) -> tuple[ProgressService, MagicMock, AsyncMock]:
    repository = MagicMock(spec=RunRepository)
    repository.lock_user_enrollments = AsyncMock()
    repository.active_with_challenge = AsyncMock(return_value=runs)
    repository.stored_step_hours = AsyncMock(return_value=stored or {})
    repository.upsert_step_hours = AsyncMock()
    session = AsyncMock()
    return (
        ProgressService(session, repository, RunService(repository), now=lambda: NOW),
        repository,
        session.commit,
    )


SESSION_STARTED = NOW - 10 * 24 * HOUR


@pytest.mark.anyio
async def test_new_hours_are_stored_and_counted() -> None:
    run = make_run(hours_from=NOW - 5 * 24 * HOUR)
    progress, repository, commit = hours_service([run])

    result = await progress.sync_step_hours(USER, [hour(3, 4000), hour(2, 1000)], SESSION_STARTED)

    assert (result.accepted, result.ignored) == (2, 0)
    assert run.total_steps == 5000
    stored = repository.upsert_step_hours.await_args.args[1]
    assert stored == [(NOW - 3 * HOUR, 4000), (NOW - 2 * HOUR, 1000)]
    commit.assert_awaited_once()


@pytest.mark.anyio
async def test_the_user_lock_is_taken_before_the_row_locks() -> None:
    progress, repository, _ = hours_service([make_run(hours_from=NOW - 5 * 24 * HOUR)])
    order: list[str] = []
    repository.lock_user_enrollments.side_effect = lambda *_: order.append("user lock")
    repository.active_with_challenge.side_effect = lambda *_: (
        order.append("rows") or [make_run(hours_from=NOW - 5 * 24 * HOUR)]
    )

    await progress.sync_step_hours(USER, [hour(1, 10)], SESSION_STARTED)

    assert order == ["user lock", "rows"]


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("old", "new", "total"), [(1000, 1500, 5500), (1000, 400, 4400), (1000, 1000, 5000)]
)
async def test_an_hour_sent_again_changes_the_total_by_the_difference(
    old: int, new: int, total: int
) -> None:
    run = make_run(hours_from=NOW - 5 * 24 * HOUR, total_steps=5000)
    progress, _, _ = hours_service([run], stored={NOW - 2 * HOUR: old})

    result = await progress.sync_step_hours(USER, [hour(2, new)], SESSION_STARTED)

    assert run.total_steps == total
    assert (result.accepted, result.ignored) == (1, 0)  # repeating the value is accepted


@pytest.mark.anyio
async def test_ignored_hours_are_not_stored_and_not_counted() -> None:
    run = make_run(hours_from=NOW - 5 * 24 * HOUR, total_steps=7)
    progress, repository, _ = hours_service([run])

    result = await progress.sync_step_hours(
        USER,
        [
            hour(2, 20_000),  # too many steps
            StepHourIn(hour_start=NOW + HOUR, steps=5),  # in the future
            hour(24 * 11, 5),  # before the session began
        ],
        SESSION_STARTED,
    )

    assert (result.accepted, result.ignored) == (0, 3)
    assert run.total_steps == 7
    repository.upsert_step_hours.assert_not_awaited()


@pytest.mark.anyio
async def test_each_bound_of_the_enrollment_and_the_session_is_applied() -> None:
    run = make_run(
        starts_at=NOW - 20 * HOUR,
        counting_from=NOW - 8 * HOUR,
        hours_from=NOW - 6 * HOUR,
    )
    progress, _, _ = hours_service([run])

    result = await progress.sync_step_hours(
        USER,
        [hour(21, 1), hour(9, 1), hour(7, 1), hour(5, 1), hour(4, 1), hour(3, 1)],
        NOW - 4 * HOUR,
    )

    assert (result.accepted, result.ignored) == (2, 4)  # 4 and 3 hours ago
    assert run.total_steps == 2


@pytest.mark.anyio
async def test_an_enrollment_without_hours_from_counts_no_hours() -> None:
    """Step sync still counts such an enrollment, so counting hours too could count twice."""
    run = make_run(hours_from=None, counting_from=NOW - 5 * HOUR)
    progress, _, _ = hours_service([run])

    result = await progress.sync_step_hours(USER, [hour(3, 1), hour(2, 1)], SESSION_STARTED)

    assert (result.accepted, result.ignored) == (0, 2)
    assert run.total_steps == 0


@pytest.mark.anyio
async def test_a_hour_counts_for_one_enrollment_and_is_ignored_by_another() -> None:
    early = make_run(id=1, challenge_id=3, hours_from=NOW - 5 * HOUR)
    late = make_run(id=2, challenge_id=4, hours_from=NOW - HOUR)
    progress, repository, _ = hours_service([early, late])

    result = await progress.sync_step_hours(USER, [hour(3, 100)], SESSION_STARTED)

    assert (result.accepted, result.ignored) == (1, 0)
    assert (early.total_steps, late.total_steps) == (100, 0)
    assert repository.upsert_step_hours.await_count == 1


@pytest.mark.anyio
async def test_a_swim_enrollment_counts_no_hours_and_is_not_tracked() -> None:
    run = make_run(type="swim", hours_from=NOW - 5 * 24 * HOUR)
    run.challenge.type = "swim"
    progress, repository, _ = hours_service([run])

    result = await progress.sync_step_hours(USER, [hour(2, 500)], SESSION_STARTED)

    assert (result.accepted, result.ignored) == (0, 1)
    assert result.enrollments[0].progress.tracked is False
    repository.upsert_step_hours.assert_not_awaited()


@pytest.mark.anyio
async def test_no_active_enrollment_ignores_every_hour() -> None:
    progress, repository, commit = hours_service([])

    result = await progress.sync_step_hours(USER, [hour(2, 500)], SESSION_STARTED)

    assert (result.accepted, result.ignored, result.enrollments) == (0, 1, [])
    repository.upsert_step_hours.assert_not_awaited()
    commit.assert_awaited_once()
