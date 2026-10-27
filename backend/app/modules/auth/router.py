from fastapi import APIRouter, Request

from app.core.errors import ErrorResponse
from app.modules.auth.deps import AuthServiceDep, CurrentUserDep
from app.modules.auth.schemas import (
    AuthResponse,
    ChangeEmailRequest,
    RefreshTokenRequest,
    SignInRequest,
    SignUpRequest,
    TokenPair,
    UserRead,
)

auth_router = APIRouter(prefix="/auth", tags=["auth"])
users_router = APIRouter(prefix="/users", tags=["users"])

router = APIRouter()
router.include_router(auth_router)
router.include_router(users_router)


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@auth_router.post("/signup", status_code=201, responses={409: {"model": ErrorResponse}})
async def sign_up(body: SignUpRequest, service: AuthServiceDep) -> AuthResponse:
    user, tokens = await service.sign_up(body)
    return AuthResponse(user=UserRead.model_validate(user), tokens=tokens)


@auth_router.post(
    "/signin",
    responses={401: {"model": ErrorResponse}, 429: {"model": ErrorResponse}},
)
async def sign_in(body: SignInRequest, request: Request, service: AuthServiceDep) -> AuthResponse:
    user, tokens = await service.sign_in(body, _client_ip(request))
    return AuthResponse(user=UserRead.model_validate(user), tokens=tokens)


@auth_router.post("/refresh", responses={401: {"model": ErrorResponse}})
async def refresh(body: RefreshTokenRequest, service: AuthServiceDep) -> TokenPair:
    return await service.refresh(body.refresh_token)


@auth_router.post("/signout", status_code=204)
async def sign_out(body: RefreshTokenRequest, service: AuthServiceDep) -> None:
    await service.sign_out(body.refresh_token)


@users_router.get("/me", responses={401: {"model": ErrorResponse}})
async def read_me(user: CurrentUserDep) -> UserRead:
    return UserRead.model_validate(user)


@users_router.put(
    "/me/email",
    responses={
        401: {"model": ErrorResponse},
        403: {"model": ErrorResponse},
        409: {"model": ErrorResponse},
        429: {"model": ErrorResponse},
    },
)
async def change_email(
    body: ChangeEmailRequest, request: Request, user: CurrentUserDep, service: AuthServiceDep
) -> UserRead:
    updated = await service.change_email(user, body, _client_ip(request))
    return UserRead.model_validate(updated)
