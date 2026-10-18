from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.runs.models import Run


class RunRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def count_for_challenge(self, challenge_id: int) -> int:
        """How many attempts exist for the challenge. Joining arrives with the join routes;
        until then every attempt counts."""
        count = await self._session.scalar(
            select(func.count()).select_from(Run).where(Run.challenge_id == challenge_id)
        )
        return count or 0
