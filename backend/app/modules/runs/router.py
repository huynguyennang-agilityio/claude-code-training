from typing import Any

from fastapi import APIRouter

from app.core.errors import ErrorResponse
from app.modules.auth.deps import CurrentUserDep
from app.modules.challenges.deps import ChallengeServiceDep
from app.modules.challenges.router import ChallengeId
from app.modules.challenges.schemas import ChallengeDetail
from app.modules.runs.deps import EnrollmentServiceDep

router = APIRouter(prefix="/challenges", tags=["enrollments"])

_ERRORS: dict[int | str, dict[str, Any]] = {
    401: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    409: {"model": ErrorResponse},
}


async def _detail(
    challenges: ChallengeServiceDep, challenge_id: int, user: CurrentUserDep
) -> ChallengeDetail:
    """The challenge as the caller now sees it, so the app can redraw from the answer."""
    view = await challenges.view(challenge_id, user.id)
    return ChallengeDetail.build(
        view.challenge,
        participant_count=view.participant_count,
        enrollment=view.enrollment,
        blocked_by=view.blocked_by,
    )


@router.post("/{challenge_id}/join", responses=_ERRORS, summary="Join a challenge")
async def join_challenge(
    user: CurrentUserDep,
    challenge_id: ChallengeId,
    enrollments: EnrollmentServiceDep,
    challenges: ChallengeServiceDep,
) -> ChallengeDetail:
    await enrollments.join(user.id, challenge_id)
    return await _detail(challenges, challenge_id, user)


@router.post("/{challenge_id}/pause", responses=_ERRORS, summary="Pause a challenge you joined")
async def pause_challenge(
    user: CurrentUserDep,
    challenge_id: ChallengeId,
    enrollments: EnrollmentServiceDep,
    challenges: ChallengeServiceDep,
) -> ChallengeDetail:
    await enrollments.pause(user.id, challenge_id)
    return await _detail(challenges, challenge_id, user)


@router.post("/{challenge_id}/resume", responses=_ERRORS, summary="Resume a paused challenge")
async def resume_challenge(
    user: CurrentUserDep,
    challenge_id: ChallengeId,
    enrollments: EnrollmentServiceDep,
    challenges: ChallengeServiceDep,
) -> ChallengeDetail:
    await enrollments.resume(user.id, challenge_id)
    return await _detail(challenges, challenge_id, user)


@router.post("/{challenge_id}/leave", responses=_ERRORS, summary="Leave a challenge")
async def leave_challenge(
    user: CurrentUserDep,
    challenge_id: ChallengeId,
    enrollments: EnrollmentServiceDep,
    challenges: ChallengeServiceDep,
) -> ChallengeDetail:
    await enrollments.leave(user.id, challenge_id)
    return await _detail(challenges, challenge_id, user)
