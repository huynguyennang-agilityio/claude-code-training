from typing import Any

from fastapi import APIRouter

from app.core.errors import ErrorResponse
from app.modules.auth.deps import CurrentUserDep
from app.modules.profile.deps import ProfileServiceDep
from app.modules.profile.schemas import ProfileRead

router = APIRouter(prefix="/users/me", tags=["profile"])

_ERRORS: dict[int | str, dict[str, Any]] = {401: {"model": ErrorResponse}}


@router.get("/profile", responses=_ERRORS, summary="Read the caller's profile")
async def get_profile(user: CurrentUserDep, profiles: ProfileServiceDep) -> ProfileRead:
    return await profiles.get(user.id)
