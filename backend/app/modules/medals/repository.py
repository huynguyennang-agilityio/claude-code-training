from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.medals.models import Medal


class MedalRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_all(self, medals: list[Medal]) -> list[Medal]:
        self._session.add_all(medals)
        await self._session.flush()  # assigns the ids; the calling service commits
        return medals
