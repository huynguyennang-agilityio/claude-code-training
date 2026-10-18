from typing import Annotated, Any

from fastapi import APIRouter, Query

from app.core.errors import ErrorResponse
from app.modules.auth.deps import CurrentUserDep
from app.modules.runs.deps import ProgressServiceDep
from app.modules.runs.schemas import (
    MyChallengePage,
    MyChallengeQuery,
    StepSyncRequest,
    StepSyncResult,
)

router = APIRouter(prefix="/runs", tags=["runs"])

_ERRORS: dict[int | str, dict[str, Any]] = {401: {"model": ErrorResponse}}


@router.post(
    "/steps",
    responses=_ERRORS,
    summary="Sync step samples",
    description="Counts the samples toward the caller's active run challenges and answers with "
    "their progress.",
)
async def sync_steps(
    body: StepSyncRequest, user: CurrentUserDep, progress: ProgressServiceDep
) -> StepSyncResult:
    return await progress.sync_steps(user.id, body.samples)


@router.get(
    "",
    responses={**_ERRORS, 422: {"model": ErrorResponse}},
    summary="Challenges I am in, with progress",
)
async def my_challenges(
    query: Annotated[MyChallengeQuery, Query()], user: CurrentUserDep, progress: ProgressServiceDep
) -> MyChallengePage:
    return await progress.my_challenges(user.id, limit=query.limit, cursor=query.cursor)
