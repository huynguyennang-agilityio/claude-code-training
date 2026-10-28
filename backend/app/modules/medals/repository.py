from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.medals.models import Medal


class MedalRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_all(self, medals: list[Medal]) -> list[Medal]:
        self._session.add_all(medals)
        await self._session.flush()  # assigns the ids; the calling service commits
        return medals

    async def delete_for_challenge(self, challenge_id: int) -> None:
        await self._session.execute(delete(Medal).where(Medal.challenge_id == challenge_id))
