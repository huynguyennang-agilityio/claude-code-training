from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.modules.profile.repository import ProfileRepository
from app.modules.profile.service import ProfileService


def get_profile_service(session: Annotated[AsyncSession, Depends(get_session)]) -> ProfileService:
    return ProfileService(ProfileRepository(session))


ProfileServiceDep = Annotated[ProfileService, Depends(get_profile_service)]
