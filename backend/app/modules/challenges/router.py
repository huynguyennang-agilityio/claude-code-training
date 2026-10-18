from typing import Annotated, Any

from fastapi import APIRouter, File, Form, Path, Query, Response, UploadFile

from app.core.errors import ErrorResponse
from app.core.storage import ImageKind
from app.modules.auth.deps import AdminUserDep, CurrentUserDep
from app.modules.auth.models import UserRole
from app.modules.auth.service import ForbiddenError
from app.modules.challenges.deps import ChallengeServiceDep, ImageServiceDep
from app.modules.challenges.images import MAX_IMAGE_BYTES
from app.modules.challenges.models import ChallengeStatus
from app.modules.challenges.schemas import (
    ChallengeCreate,
    ChallengeDetail,
    ChallengeListQuery,
    ChallengePage,
    ChallengeRead,
    ChallengeSummary,
    ChallengeUpdate,
    QuestCreate,
    QuestSummary,
    UploadedImageRead,
)

# The auth dependency is declared first on every route: FastAPI resolves dependencies in
# order, so a request without a token is refused before a database session is opened.
challenges_router = APIRouter(prefix="/challenges", tags=["challenges"])
quests_router = APIRouter(prefix="/quests", tags=["quests"])
images_router = APIRouter(prefix="/images", tags=["images"])

router = APIRouter()
router.include_router(challenges_router)
router.include_router(quests_router)
router.include_router(images_router)

# A Postgres integer: a larger id can match nothing, and would only fail inside the driver.
ChallengeId = Annotated[int, Path(ge=1, le=2_147_483_647)]

Responses = dict[int | str, dict[str, Any]]
_UNAUTHENTICATED: Responses = {401: {"model": ErrorResponse}}
_ADMIN_ONLY: Responses = {**_UNAUTHENTICATED, 403: {"model": ErrorResponse}}
_NOT_FOUND: Responses = {404: {"model": ErrorResponse}}


@challenges_router.get(
    "",
    responses={**_UNAUTHENTICATED, 403: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
    summary="List the published challenges",
)
async def list_challenges(
    user: CurrentUserDep,
    query: Annotated[ChallengeListQuery, Query()],
    service: ChallengeServiceDep,
) -> ChallengePage:
    if query.status is ChallengeStatus.DRAFT and user.role != UserRole.ADMIN.value:
        raise ForbiddenError("Only an admin can list drafts.")
    listing = await service.page(
        status=query.status,
        challenge_type=query.type,
        search=query.q,
        limit=query.limit,
        cursor=query.cursor,
    )
    return ChallengePage(
        items=[
            ChallengeSummary.build(
                view.challenge, participant_count=view.participant_count, enrollment=None
            )
            for view in listing.items
        ],
        next_cursor=listing.next_cursor,
    )


@challenges_router.get(
    "/{challenge_id}",
    responses={**_UNAUTHENTICATED, **_NOT_FOUND},
    summary="Read one challenge",
)
async def get_challenge(
    user: CurrentUserDep, challenge_id: ChallengeId, service: ChallengeServiceDep
) -> ChallengeDetail:
    view = await service.view(challenge_id, include_drafts=user.role == UserRole.ADMIN.value)
    return ChallengeDetail.build(
        view.challenge,
        participant_count=view.participant_count,
        enrollment=None,
        blocked_by=None,
    )


@challenges_router.post(
    "",
    status_code=201,
    responses={**_ADMIN_ONLY, **_NOT_FOUND},
    summary="Create a draft challenge (admin)",
)
async def create_challenge(
    _: AdminUserDep, body: ChallengeCreate, service: ChallengeServiceDep
) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.create(body))


@challenges_router.patch(
    "/{challenge_id}",
    responses={**_ADMIN_ONLY, **_NOT_FOUND, 409: {"model": ErrorResponse}},
    summary="Edit a challenge (admin)",
)
async def update_challenge(
    _: AdminUserDep, challenge_id: ChallengeId, body: ChallengeUpdate, service: ChallengeServiceDep
) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.update(challenge_id, body))


@challenges_router.delete(
    "/{challenge_id}",
    status_code=204,
    responses={**_ADMIN_ONLY, **_NOT_FOUND, 409: {"model": ErrorResponse}},
    summary="Delete a draft challenge (admin)",
)
async def delete_challenge(
    _: AdminUserDep, challenge_id: ChallengeId, service: ChallengeServiceDep
) -> Response:
    await service.delete(challenge_id)
    return Response(status_code=204)


@challenges_router.post(
    "/{challenge_id}/publish",
    responses={**_ADMIN_ONLY, **_NOT_FOUND, 409: {"model": ErrorResponse}},
    summary="Publish a draft challenge (admin)",
)
async def publish_challenge(
    _: AdminUserDep, challenge_id: ChallengeId, service: ChallengeServiceDep
) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.publish(challenge_id))


@challenges_router.post(
    "/{challenge_id}/unpublish",
    responses={**_ADMIN_ONLY, **_NOT_FOUND},
    summary="Take a challenge back to draft (admin)",
)
async def unpublish_challenge(
    _: AdminUserDep, challenge_id: ChallengeId, service: ChallengeServiceDep
) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.unpublish(challenge_id))


@quests_router.post("", status_code=201, responses=_ADMIN_ONLY, summary="Create a quest (admin)")
async def create_quest(
    _: AdminUserDep, body: QuestCreate, service: ChallengeServiceDep
) -> QuestSummary:
    return QuestSummary.model_validate(await service.create_quest(body))


@quests_router.get("", responses=_UNAUTHENTICATED, summary="List the quests")
async def list_quests(_: CurrentUserDep, service: ChallengeServiceDep) -> list[QuestSummary]:
    return [QuestSummary.model_validate(quest) for quest in await service.list_quests()]


@images_router.post(
    "",
    status_code=201,
    responses={
        **_ADMIN_ONLY,
        413: {"model": ErrorResponse},
        415: {"model": ErrorResponse},
        502: {"model": ErrorResponse},
        503: {"model": ErrorResponse},
    },
    summary="Upload a cover or medal image (admin)",
)
async def upload_image(
    _: AdminUserDep,
    file: Annotated[UploadFile, File()],
    kind: Annotated[ImageKind, Form()],
    service: ImageServiceDep,
) -> UploadedImageRead:
    # Read one byte past the limit: enough to know it is too large, without holding the rest.
    data = await file.read(MAX_IMAGE_BYTES + 1)
    image = await service.upload(data, kind=kind)
    return UploadedImageRead(
        url=image.url,  # type: ignore[arg-type]
        public_id=image.public_id,
        width=image.width,
        height=image.height,
        size_bytes=image.size_bytes,
    )
