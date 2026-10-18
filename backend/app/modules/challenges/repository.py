from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.challenges.models import Challenge, ChallengeStatus, Quest


def _escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


class ChallengeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, challenge_id: int) -> Challenge | None:
        # Medals are loaded to nest them, read-only, in `ChallengeRead` (ADR 0002).
        return await self._session.scalar(
            select(Challenge)
            .where(Challenge.id == challenge_id)
            .options(selectinload(Challenge.medals))
            .execution_options(populate_existing=True)
        )

    async def list_challenges(
        self,
        *,
        include_drafts: bool,
        challenge_type: str | None,
        search: str | None,
        limit: int,
        after_id: int | None,
    ) -> list[Challenge]:
        query = select(Challenge).options(selectinload(Challenge.medals))
        if not include_drafts:
            query = query.where(Challenge.status == ChallengeStatus.PUBLISHED.value)
        if challenge_type is not None:
            query = query.where(Challenge.type == challenge_type)
        if search:
            pattern = f"%{_escape_like(search)}%"
            query = query.where(
                Challenge.title.ilike(pattern, escape="\\")
                | Challenge.city.ilike(pattern, escape="\\")
                | Challenge.landmark.ilike(pattern, escape="\\")
            )
        if after_id is not None:
            query = query.where(Challenge.id > after_id)
        result = await self._session.scalars(query.order_by(Challenge.id).limit(limit))
        return list(result)

    async def add(self, challenge: Challenge) -> Challenge:
        self._session.add(challenge)
        await self._session.flush()  # assigns challenge.id; the service commits
        return challenge

    async def delete(self, challenge: Challenge) -> None:
        await self._session.delete(challenge)
        await self._session.flush()

    async def get_quest(self, quest_id: int) -> Quest | None:
        return await self._session.get(Quest, quest_id)

    async def get_quest_by_title(self, title: str) -> Quest | None:
        return await self._session.scalar(select(Quest).where(Quest.title == title))

    async def list_quests(self) -> list[Quest]:
        return list(await self._session.scalars(select(Quest).order_by(Quest.id)))

    async def add_quest(self, quest: Quest) -> Quest:
        self._session.add(quest)
        await self._session.flush()
        return quest
