import uuid

from app.modules.profile.repository import ProfileRepository
from app.modules.profile.schemas import ProfileRead


class ProfileService:
    def __init__(self, repository: ProfileRepository) -> None:
        self._repository = repository

    async def get(self, user_id: uuid.UUID) -> ProfileRead:
        """The user's profile, or the empty one when they never saved it (not a 404)."""
        row = await self._repository.get(user_id)
        if row is None:
            return ProfileRead()
        return ProfileRead.model_validate(row)
