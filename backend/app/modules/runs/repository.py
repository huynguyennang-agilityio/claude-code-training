import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.modules.runs.models import Run, RunStatus

# A user "is in" a challenge while the enrollment is active or paused.
_JOINED = (RunStatus.ACTIVE.value, RunStatus.PAUSED.value)


class RunRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def count_for_challenge(self, challenge_id: int) -> int:
        """How many users are in the challenge (active or paused)."""
        count = await self._session.scalar(
            select(func.count())
            .select_from(Run)
            .where(Run.challenge_id == challenge_id, Run.status.in_(_JOINED))
        )
        return count or 0

    async def counts_for_challenges(self, challenge_ids: Sequence[int]) -> dict[int, int]:
        """`count_for_challenge` for several challenges in one query; ids with none are left out."""
        if not challenge_ids:
            return {}
        rows = await self._session.execute(
            select(Run.challenge_id, func.count())
            .where(Run.challenge_id.in_(challenge_ids), Run.status.in_(_JOINED))
            .group_by(Run.challenge_id)
        )
        return {challenge_id: count for challenge_id, count in rows}

    async def get_for_user(
        self, user_id: uuid.UUID, challenge_id: int, *, lock: bool = False
    ) -> Run | None:
        """The user's row for the challenge, whatever its status. `lock` holds it until the
        transaction ends, so two requests of one user can't change it at once."""
        query = select(Run).where(Run.user_id == user_id, Run.challenge_id == challenge_id)
        if lock:
            query = query.with_for_update()
        return await self._session.scalar(query.execution_options(populate_existing=True))

    async def joined_by_user(self, user_id: uuid.UUID, challenge_ids: Sequence[int]) -> list[Run]:
        """The user's active and paused enrollments among these challenges."""
        if not challenge_ids:
            return []
        result = await self._session.scalars(
            select(Run).where(
                Run.user_id == user_id,
                Run.challenge_id.in_(challenge_ids),
                Run.status.in_(_JOINED),
            )
        )
        return list(result)

    async def find_active_overlap(
        self,
        user_id: uuid.UUID,
        *,
        challenge_type: str,
        starts_at: datetime,
        ends_at: datetime,
        except_challenge_id: int,
    ) -> Run | None:
        """An active enrollment of the user, in another challenge of the same type, whose
        window `[starts_at, ends_at)` overlaps the given one. Its challenge is loaded."""
        return await self._session.scalar(
            select(Run)
            .where(
                Run.user_id == user_id,
                Run.status == RunStatus.ACTIVE.value,
                Run.type == challenge_type,
                Run.challenge_id != except_challenge_id,
                Run.starts_at < ends_at,
                starts_at < Run.ends_at,
            )
            .options(joinedload(Run.challenge))
            .order_by(Run.joined_at)
            .limit(1)
        )

    async def add(self, run: Run) -> Run:
        self._session.add(run)
        await self._session.flush()
        return run
