import uuid
from typing import Any

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.profile.models import UserProfile


class ProfileRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: uuid.UUID) -> UserProfile | None:
        return await self._session.get(UserProfile, user_id)

    async def upsert(self, user_id: uuid.UUID, values: dict[str, Any]) -> UserProfile:
        """Insert the row, or replace every column of the existing one. The service commits."""
        statement = (
            insert(UserProfile)
            .values(user_id=user_id, **values)
            .on_conflict_do_update(index_elements=[UserProfile.user_id], set_=values)
            .returning(UserProfile)
        )
        result = await self._session.execute(
            statement, execution_options={"populate_existing": True}
        )
        row = result.scalar_one()
        await self._session.flush()
        return row
