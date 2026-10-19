"""Joining a challenge, and pausing, resuming and leaving it.

The rule that a user can't be in two challenges of one type at the same time is kept by the
database (an exclusion constraint on `runs`); the service checks it first to give a message
that names the other challenge, and turns the constraint's error into the same answer when two
requests race.
"""

import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError
from app.modules.challenges.models import Challenge
from app.modules.runs.models import Run, RunStatus
from app.modules.runs.repository import RunRepository

EXCLUSION = "ex_runs_no_overlapping_active_challenges"
UNIQUE_ENROLLMENT = "uq_runs_user_id_challenge_id"


# The codes below are listed in `docs/api/challenges.md`.
class ChallengeEndedError(DomainError):
    status_code = 409
    code = "challenge_ended"


class AlreadyJoinedError(DomainError):
    status_code = 409
    code = "already_joined"


class OverlappingChallengeError(DomainError):
    status_code = 409
    code = "overlapping_challenge"


class EnrollmentNotFoundError(DomainError):
    status_code = 404
    code = "enrollment_not_found"


class NotActiveError(DomainError):
    status_code = 409
    code = "not_active"


class ChallengeNotStartedError(DomainError):
    status_code = 409
    code = "challenge_not_started"


class NotPausedError(DomainError):
    status_code = 409
    code = "not_paused"


def _utcnow() -> datetime:
    return datetime.now(UTC)


class EnrollmentService:
    def __init__(
        self,
        session: AsyncSession,
        repository: RunRepository,
        get_challenge: Callable[[int], Awaitable[Challenge]],
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        # `ChallengeService.get`: a draft or unknown challenge raises `challenge_not_found`.
        self._get_challenge = get_challenge
        self._now = now

    async def join(self, user_id: uuid.UUID, challenge_id: int) -> None:
        """Join a published challenge until it ends, also before it starts. Someone who left
        can join again; that reuses their row."""
        challenge = await self._get_challenge(challenge_id)
        now = self._now()
        if now >= challenge.ends_at:
            raise ChallengeEndedError("This challenge has ended.")
        await self._repository.lock_user_enrollments(user_id)
        run = await self._repository.get_for_user(user_id, challenge_id, lock=True)
        if run is not None and run.status != RunStatus.LEFT.value:
            raise AlreadyJoinedError("You have already joined this challenge.")
        await self._refuse_overlap(
            user_id, challenge.id, challenge.type, challenge.starts_at, challenge.ends_at
        )
        if run is None:
            run = Run(user_id=user_id, challenge_id=challenge.id)
        # The copy of the type and window is what the database checks overlap against.
        run.status = RunStatus.ACTIVE.value
        run.joined_at = now
        run.counting_from = now
        run.type = challenge.type
        run.starts_at = challenge.starts_at
        run.ends_at = challenge.ends_at
        await self._save(run)

    async def pause(self, user_id: uuid.UUID, challenge_id: int) -> None:
        """Pause: the slot is free for another challenge of the type until the user resumes.
        Before the start there is nothing to pause (leave instead)."""
        run = await self._own_run(user_id, challenge_id)
        if run.status != RunStatus.ACTIVE.value:
            raise NotActiveError("Only an active challenge can be paused.")
        if self._now() < run.starts_at:
            raise ChallengeNotStartedError("A challenge that has not started cannot be paused.")
        run.status = RunStatus.PAUSED.value
        await self._session.commit()

    async def resume(self, user_id: uuid.UUID, challenge_id: int) -> None:
        await self._repository.lock_user_enrollments(user_id)
        run = await self._own_run(user_id, challenge_id)
        if run.status != RunStatus.PAUSED.value:
            raise NotPausedError("Only a paused challenge can be resumed.")
        if self._now() >= run.ends_at:
            raise ChallengeEndedError("This challenge has ended.")
        await self._refuse_overlap(user_id, run.challenge_id, run.type, run.starts_at, run.ends_at)
        run.status = RunStatus.ACTIVE.value
        run.counting_from = self._now()
        await self._save(run)

    async def leave(self, user_id: uuid.UUID, challenge_id: int) -> None:
        """Leave an active or paused challenge. The user can join again while it is open."""
        run = await self._own_run(user_id, challenge_id)
        run.status = RunStatus.LEFT.value
        await self._session.commit()

    async def _own_run(self, user_id: uuid.UUID, challenge_id: int) -> Run:
        run = await self._repository.get_for_user(user_id, challenge_id, lock=True)
        if run is None or run.status == RunStatus.LEFT.value:
            raise EnrollmentNotFoundError("You are not in this challenge.")
        return run

    async def _refuse_overlap(
        self,
        user_id: uuid.UUID,
        challenge_id: int,
        challenge_type: str,
        starts_at: datetime,
        ends_at: datetime,
    ) -> None:
        other = await self._repository.find_active_overlap(
            user_id,
            challenge_type=challenge_type,
            starts_at=starts_at,
            ends_at=ends_at,
            except_challenge_id=challenge_id,
        )
        if other is not None:
            raise OverlappingChallengeError(_overlap_message(other.challenge.title))

    async def _save(self, run: Run) -> None:
        """Write the row and commit. A savepoint keeps the transaction usable if the database
        refuses, so the other challenge can still be looked up for the message."""
        try:
            async with self._session.begin_nested():
                await self._repository.add(run)
        except IntegrityError as error:
            raise await self._explain(error, run) from error
        await self._session.commit()

    async def _explain(self, error: IntegrityError, run: Run) -> Exception:
        """The domain error for a constraint the database enforced when two requests raced."""
        reason = str(error.orig)
        if EXCLUSION in reason:
            other = await self._repository.find_active_overlap(
                run.user_id,
                challenge_type=run.type,
                starts_at=run.starts_at,
                ends_at=run.ends_at,
                except_challenge_id=run.challenge_id,
            )
            return OverlappingChallengeError(
                _overlap_message(other.challenge.title) if other else _overlap_message(None)
            )
        if UNIQUE_ENROLLMENT in reason:
            return AlreadyJoinedError("You have already joined this challenge.")
        return error


def _overlap_message(title: str | None) -> str:
    other = f"“{title}”" if title else "another challenge of this type"
    return (
        f"You are already in {other}, which runs at the same time as this challenge. "
        "Finish, pause or leave it to join this one."
    )
