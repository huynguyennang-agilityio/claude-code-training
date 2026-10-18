"""Counting synced steps toward the challenges a user is in, and listing those challenges.

Only run challenges count (steps). A swim or cycle challenge counts distance from workouts, which
a later plan adds, so it reports `tracked: false` and no progress.
"""

import base64
import binascii
import uuid
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError
from app.modules.challenges.schemas import ChallengeSummary, EnrollmentRead
from app.modules.runs.models import Run, StepSample
from app.modules.runs.repository import RunRepository
from app.modules.runs.schemas import (
    TRACKED_TYPES,
    EnrollmentProgress,
    MyChallengeItem,
    MyChallengePage,
    ProgressRead,
    StepSampleIn,
    StepSyncResult,
)
from app.modules.runs.service import RunService
from app.modules.runs.validation import ChallengeRule, validate_run

# A device clock may be a little ahead; a sample that ends later than this is from the future.
CLOCK_MARGIN = timedelta(minutes=5)


class InvalidRunCursorError(DomainError):
    status_code = 422
    code = "invalid_cursor"


def encode_cursor(run: Run) -> str:
    """Where the next page starts: the start time (to the microsecond, so no row repeats) and
    the id."""
    raw = f"{run.starts_at.isoformat()}|{run.id}"
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, int]:
    padded = cursor + "=" * (-len(cursor) % 4)
    try:
        starts_at, run_id = base64.urlsafe_b64decode(padded.encode()).decode().split("|")
        value = (datetime.fromisoformat(starts_at), int(run_id))
    except (binascii.Error, UnicodeDecodeError, ValueError, OverflowError) as error:
        raise InvalidRunCursorError("The cursor is not valid.") from error
    if value[0].tzinfo is None or value[1] < 1:
        raise InvalidRunCursorError("The cursor is not valid.")
    return value


def progress_of(run: Run, now: datetime) -> ProgressRead:
    """Where the enrollment stands. Percent never exceeds 100."""
    target = run.challenge.target_value
    tracked = run.type in TRACKED_TYPES
    current = run.total_steps if tracked else 0
    return ProgressRead(
        current_value=current,
        target_value=target,
        percent=min(100, current * 100 // target),
        tracked=tracked,
        started=now >= run.starts_at,
    )


@dataclass(frozen=True)
class Listing:
    items: list[tuple[Run, int]]
    next_cursor: str | None


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ProgressService:
    def __init__(
        self,
        session: AsyncSession,
        repository: RunRepository,
        runs: RunService,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._runs = runs
        self._now = now

    async def sync_steps(
        self, user_id: uuid.UUID, samples: Sequence[StepSampleIn]
    ) -> StepSyncResult:
        """Count the samples toward each active run enrollment of the user. A sample is stored
        once per enrollment; one that is a duplicate or does not fit the enrollment's window and
        counting period is ignored."""
        now = self._now()
        enrollments = await self._repository.active_with_challenge(user_id)
        accepted: set[str] = set()
        for run in enrollments:
            if run.type not in TRACKED_TYPES:
                continue
            rule = ChallengeRule(
                target_steps=run.challenge.target_value,
                starts_at=run.starts_at,
                ends_at=run.ends_at,
                counting_from=run.counting_from or run.joined_at,
                latest_end=now + CLOCK_MARGIN,
            )
            known = await self._repository.known_record_ids(
                run.id, [sample.health_record_id for sample in samples]
            )
            result = validate_run(samples, rule, known)
            await self._repository.add_samples(
                [
                    StepSample(
                        run_id=run.id,
                        health_record_id=sample.health_record_id,
                        start_time=sample.start_time,
                        end_time=sample.end_time,
                        steps=sample.steps,
                    )
                    for sample in result.accepted
                ]
            )
            run.total_steps += result.counted_steps
            accepted.update(sample.health_record_id for sample in result.accepted)
        await self._session.commit()
        return StepSyncResult(
            accepted=len(accepted),
            ignored=len({sample.health_record_id for sample in samples}) - len(accepted),
            enrollments=[
                EnrollmentProgress(challenge_id=run.challenge_id, progress=progress_of(run, now))
                for run in enrollments
            ],
        )

    async def my_challenges(
        self, user_id: uuid.UUID, *, limit: int, cursor: str | None
    ) -> MyChallengePage:
        """The challenges the user is in (active or paused), the soonest start first."""
        rows = await self._repository.joined_page(
            user_id, limit=limit + 1, after=decode_cursor(cursor) if cursor else None
        )
        shown = rows[:limit]
        counts = await self._runs.count_participants_for([run.challenge_id for run in shown])
        now = self._now()
        return MyChallengePage(
            items=[
                MyChallengeItem(
                    challenge=ChallengeSummary.build(
                        run.challenge,
                        participant_count=counts.get(run.challenge_id, 0),
                        enrollment=EnrollmentRead(
                            status=run.status,  # type: ignore[arg-type]
                            joined_at=run.joined_at,
                        ),
                    ),
                    progress=progress_of(run, now),
                )
                for run in shown
            ],
            next_cursor=encode_cursor(shown[-1]) if len(rows) > limit else None,
        )
