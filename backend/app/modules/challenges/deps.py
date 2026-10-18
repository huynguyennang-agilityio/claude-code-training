from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session
from app.core.storage import CloudinaryStorage
from app.modules.challenges.images import ImageService
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.service import ChallengeService
from app.modules.medals.repository import MedalRepository
from app.modules.medals.service import MedalService
from app.modules.runs.repository import RunRepository
from app.modules.runs.service import RunService


def get_challenge_service(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ChallengeService:
    runs = RunService(RunRepository(session))
    return ChallengeService(
        session,
        ChallengeRepository(session),
        MedalService(MedalRepository(session)),
        participants=runs.count_participants,
    )


def get_storage() -> CloudinaryStorage:
    return CloudinaryStorage.from_settings(get_settings())


def get_image_service(storage: Annotated[CloudinaryStorage, Depends(get_storage)]) -> ImageService:
    return ImageService(storage)


ChallengeServiceDep = Annotated[ChallengeService, Depends(get_challenge_service)]
ImageServiceDep = Annotated[ImageService, Depends(get_image_service)]
