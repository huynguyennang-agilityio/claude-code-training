"""The rules of joining, pausing, resuming and leaving, with the database mocked.

The overlap rule against a real database, and a race between two joins, are in
`tests/integration/test_enrollments_api.py`.
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.exc import IntegrityError

from app.modules.challenges.models import Challenge
from app.modules.challenges.service import ChallengeNotFoundError
from app.modules.runs.enrollments import (
    EXCLUSION,
    UNIQUE_ENROLLMENT,
    AlreadyJoinedError,
    ChallengeEndedError,
    EnrollmentNotFoundError,
    EnrollmentService,
    NotActiveError,
    NotPausedError,
    OverlappingChallengeError,
)
from app.modules.runs.models import Run, RunStatus
from app.modules.runs.repository import RunRepository

NOW = datetime(2026, 10, 9, tzinfo=UTC)
USER = uuid.UUID("00000000-0000-0000-0000-000000000001")


def make_challenge(**changes: Any) -> Challenge:
    values: dict[str, Any] = {
        "id": 3,
        "title": "October run",
        "type": "run",
        "starts_at": NOW + timedelta(days=22),
        "ends_at": NOW + timedelta(days=52),
    }
    values.update(changes)
    return Challenge(**values)


def make_run(status: str = "active", **changes: Any) -> Run:
    values: dict[str, Any] = {
        "id": 1,
        "user_id": USER,
        "challenge_id": 3,
        "status": status,
        "type": "run",
        "joined_at": NOW - timedelta(days=1),
        "starts_at": NOW + timedelta(days=22),
        "ends_at": NOW + timedelta(days=52),
    }
    values.update(changes)
    return Run(**values)


def blocker(title: str = "September run") -> Run:
    other = make_run(challenge_id=2)
    other.challenge = make_challenge(id=2, title=title)
    return other


@pytest.fixture
def repository() -> AsyncMock:
    mock = AsyncMock(spec=RunRepository)
    mock.get_for_user.return_value = None
    mock.find_active_overlap.return_value = None
    return mock


@pytest.fixture
def session() -> MagicMock:
    mock = MagicMock()
    mock.commit = AsyncMock()
    nested = MagicMock()
    nested.__aenter__ = AsyncMock(return_value=None)
    nested.__aexit__ = AsyncMock(return_value=False)
    mock.begin_nested.return_value = nested
    return mock


@pytest.fixture
def get_challenge() -> AsyncMock:
    return AsyncMock(return_value=make_challenge())


@pytest.fixture
def service(
    session: MagicMock, repository: AsyncMock, get_challenge: AsyncMock
) -> EnrollmentService:
    return EnrollmentService(session, repository, get_challenge, now=lambda: NOW)


def integrity_error(constraint: str) -> IntegrityError:
    return IntegrityError("INSERT", {}, Exception(f'violates constraint "{constraint}"'))


class TestJoin:
    @pytest.mark.anyio
    async def test_joins_with_a_copy_of_the_type_and_window(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock
    ) -> None:
        challenge = make_challenge()

        await service.join(USER, 3)

        run: Run = repository.add.await_args.args[0]
        assert (run.user_id, run.challenge_id, run.status) == (USER, 3, "active")
        assert (run.type, run.starts_at, run.ends_at) == (
            "run",
            challenge.starts_at,
            challenge.ends_at,
        )
        assert run.joined_at == NOW
        assert run.counting_from == NOW
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_a_draft_or_unknown_challenge_is_not_found(
        self, service: EnrollmentService, get_challenge: AsyncMock, repository: AsyncMock
    ) -> None:
        get_challenge.side_effect = ChallengeNotFoundError("nope")

        with pytest.raises(ChallengeNotFoundError):
            await service.join(USER, 3)

        repository.add.assert_not_awaited()

    @pytest.mark.anyio
    @pytest.mark.parametrize("offset", [timedelta(0), timedelta(seconds=-1)])
    async def test_an_ended_challenge_cannot_be_joined(
        self, service: EnrollmentService, get_challenge: AsyncMock, offset: timedelta
    ) -> None:
        get_challenge.return_value = make_challenge(ends_at=NOW + offset)

        with pytest.raises(ChallengeEndedError):
            await service.join(USER, 3)

    @pytest.mark.anyio
    async def test_a_challenge_that_has_not_started_can_be_joined(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        await service.join(USER, 3)

        repository.add.assert_awaited_once()

    @pytest.mark.anyio
    @pytest.mark.parametrize("status", ["active", "paused"])
    async def test_joining_twice_is_refused(
        self, service: EnrollmentService, repository: AsyncMock, status: str
    ) -> None:
        repository.get_for_user.return_value = make_run(status)

        with pytest.raises(AlreadyJoinedError):
            await service.join(USER, 3)

    @pytest.mark.anyio
    async def test_someone_who_left_joins_again_on_the_same_row(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        left = make_run("left", joined_at=NOW - timedelta(days=5))
        repository.get_for_user.return_value = left

        await service.join(USER, 3)

        assert repository.add.await_args.args[0] is left
        assert (left.status, left.joined_at) == ("active", NOW)

    @pytest.mark.anyio
    async def test_an_overlapping_challenge_names_the_other_one(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock
    ) -> None:
        repository.find_active_overlap.return_value = blocker("September run")

        with pytest.raises(OverlappingChallengeError, match="September run"):
            await service.join(USER, 3)

        repository.add.assert_not_awaited()
        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_the_overlap_is_checked_against_the_type_and_window_of_the_challenge(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        challenge = make_challenge()

        await service.join(USER, 3)

        assert repository.find_active_overlap.await_args.kwargs == {
            "challenge_type": "run",
            "starts_at": challenge.starts_at,
            "ends_at": challenge.ends_at,
            "except_challenge_id": 3,
        }

    @pytest.mark.anyio
    async def test_losing_a_race_for_the_slot_is_an_overlap_error(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock
    ) -> None:
        repository.add.side_effect = integrity_error(EXCLUSION)
        repository.find_active_overlap.side_effect = [None, blocker("Winner")]

        with pytest.raises(OverlappingChallengeError, match="Winner"):
            await service.join(USER, 3)

        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_losing_a_race_with_yourself_is_already_joined(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        repository.add.side_effect = integrity_error(UNIQUE_ENROLLMENT)

        with pytest.raises(AlreadyJoinedError):
            await service.join(USER, 3)

    @pytest.mark.anyio
    async def test_another_database_error_is_not_hidden(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        repository.add.side_effect = integrity_error("something_else")

        with pytest.raises(IntegrityError):
            await service.join(USER, 3)


class TestPause:
    @pytest.mark.anyio
    async def test_pauses_an_active_enrollment(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock
    ) -> None:
        run = make_run("active")
        repository.get_for_user.return_value = run

        await service.pause(USER, 3)

        assert run.status == RunStatus.PAUSED.value
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_a_paused_one_cannot_be_paused_again(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        repository.get_for_user.return_value = make_run("paused")

        with pytest.raises(NotActiveError):
            await service.pause(USER, 3)

    @pytest.mark.anyio
    @pytest.mark.parametrize("run", [None, make_run("left")])
    @pytest.mark.parametrize("action", ["pause", "resume", "leave"])
    async def test_someone_not_in_the_challenge_is_not_found(
        self, service: EnrollmentService, repository: AsyncMock, run: Run | None, action: str
    ) -> None:
        repository.get_for_user.return_value = run

        with pytest.raises(EnrollmentNotFoundError):
            await getattr(service, action)(USER, 3)


class TestResume:
    @pytest.mark.anyio
    async def test_resumes_a_paused_enrollment(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock
    ) -> None:
        run = make_run("paused")
        repository.get_for_user.return_value = run

        await service.resume(USER, 3)

        assert run.status == RunStatus.ACTIVE.value
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_resuming_restarts_the_counting_time(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        run = make_run("paused", counting_from=NOW - timedelta(days=1))
        repository.get_for_user.return_value = run

        await service.resume(USER, 3)

        assert run.counting_from == NOW

    @pytest.mark.anyio
    async def test_pausing_keeps_the_counting_time(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        before = NOW - timedelta(days=1)
        run = make_run("active", counting_from=before)
        repository.get_for_user.return_value = run

        await service.pause(USER, 3)

        assert run.counting_from == before

    @pytest.mark.anyio
    async def test_an_active_one_is_not_paused(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        repository.get_for_user.return_value = make_run("active")

        with pytest.raises(NotPausedError):
            await service.resume(USER, 3)

    @pytest.mark.anyio
    async def test_resume_is_refused_while_another_challenge_overlaps(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        run = make_run("paused")
        repository.get_for_user.return_value = run
        repository.find_active_overlap.return_value = blocker("Busy")

        with pytest.raises(OverlappingChallengeError, match="Busy"):
            await service.resume(USER, 3)

        assert run.status == "paused"

    @pytest.mark.anyio
    async def test_resume_is_refused_once_the_challenge_has_ended(
        self, service: EnrollmentService, repository: AsyncMock
    ) -> None:
        repository.get_for_user.return_value = make_run("paused", ends_at=NOW)

        with pytest.raises(ChallengeEndedError):
            await service.resume(USER, 3)


class TestLeave:
    @pytest.mark.anyio
    @pytest.mark.parametrize("status", ["active", "paused"])
    async def test_leaves(
        self, service: EnrollmentService, repository: AsyncMock, session: MagicMock, status: str
    ) -> None:
        run = make_run(status)
        repository.get_for_user.return_value = run

        await service.leave(USER, 3)

        assert run.status == RunStatus.LEFT.value
        session.commit.assert_awaited_once()
