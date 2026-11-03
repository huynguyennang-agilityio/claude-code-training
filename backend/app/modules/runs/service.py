import uuid
from collections.abc import Sequence
from datetime import datetime

from app.modules.challenges.schemas import BlockedByRead, EnrollmentRead
from app.modules.runs.models import RunStatus
from app.modules.runs.repository import RunRepository


class RunService:
    """What the other modules ask about the enrollments (the reads). Changing them is
    `EnrollmentService`."""

    def __init__(self, repository: RunRepository) -> None:
        self._repository = repository

    async def count_participants(self, challenge_id: int) -> int:
        """How many users are in the challenge. A challenge with participants can't
        change what they are counting toward (see `ChallengeService.update`)."""
        return await self._repository.count_for_challenge(challenge_id)

    async def count_participants_for(self, challenge_ids: Sequence[int]) -> dict[int, int]:
        """Participants of each of the challenges, with 0 for those nobody joined."""
        counts = await self._repository.counts_for_challenges(challenge_ids)
        return {challenge_id: counts.get(challenge_id, 0) for challenge_id in challenge_ids}

    async def enrollments_for(
        self, user_id: uuid.UUID, challenge_ids: Sequence[int]
    ) -> dict[int, EnrollmentRead]:
        """The user's own place in each challenge they are in. A challenge they have not
        joined, or have left, is not in the result."""
        runs = await self._repository.joined_by_user(user_id, challenge_ids)
        return {
            run.challenge_id: EnrollmentRead(status=run.status, joined_at=run.joined_at)  # type: ignore[arg-type]
            for run in runs
        }

    async def blocked_by(
        self,
        user_id: uuid.UUID,
        *,
        challenge_id: int,
        challenge_type: str,
        starts_at: datetime,
        ends_at: datetime,
        enrollment: EnrollmentRead | None,
    ) -> BlockedByRead | None:
        """The challenge that stops the user joining (or resuming) this one, if any. Someone
        already active in it is not blocked."""
        if enrollment is not None and enrollment.status == RunStatus.ACTIVE.value:
            return None
        other = await self._repository.find_active_overlap(
            user_id,
            challenge_type=challenge_type,
            starts_at=starts_at,
            ends_at=ends_at,
            except_challenge_id=challenge_id,
        )
        if other is None:
            return None
        return BlockedByRead(id=other.challenge_id, title=other.challenge.title)

    async def lock_user_enrollments(self, user_id: uuid.UUID) -> None:
        """Take the lock that serializes the changes to one user's enrollments, and hold it
        until the transaction ends. Another module that must not run at the same time as a
        join or resume of the user (deleting the account) takes it first, before any other
        lock, to keep the lock order of `EnrollmentService`."""
        await self._repository.lock_user_enrollments(user_id)
