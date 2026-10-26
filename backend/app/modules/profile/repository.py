import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.profile.models import UserProfile


class ProfileRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: uuid.UUID) -> UserProfile | None:
        return await self._session.get(UserProfile, user_id)
