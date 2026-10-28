import uuid
from collections.abc import Callable
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.profile.repository import ProfileRepository
from app.modules.profile.schemas import ProfileRead, ProfileWrite


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ProfileService:
    def __init__(
        self,
        session: AsyncSession,
        repository: ProfileRepository,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._now = now

    async def get(self, user_id: uuid.UUID) -> ProfileRead:
        """The user's profile, or the empty one when they never saved it (not a 404)."""
        row = await self._repository.get(user_id)
        if row is None:
            return ProfileRead()
        return ProfileRead.model_validate(row)

    async def replace(self, user_id: uuid.UUID, data: ProfileWrite) -> ProfileRead:
        """Replace the whole profile; the first save creates it. A `null` clears a value."""
        values = {**data.model_dump(mode="python"), "updated_at": self._now()}
        row = await self._repository.upsert(user_id, values)
        saved = ProfileRead.model_validate(row)  # before the commit expires the row
        await self._session.commit()
        return saved
