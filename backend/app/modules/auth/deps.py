from datetime import timedelta
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session
from app.modules.auth.models import User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.service import AuthService, AuthSettings, NotAuthenticatedError

# auto_error is off so a missing header raises our own `not_authenticated`.
_bearer = HTTPBearer(auto_error=False)


def get_auth_settings() -> AuthSettings:
    settings = get_settings()
    return AuthSettings(
        jwt_secret=settings.jwt_secret.get_secret_value(),
        access_token_ttl=timedelta(minutes=settings.access_token_ttl_minutes),
        refresh_token_ttl=timedelta(days=settings.refresh_token_ttl_days),
    )


def get_auth_repository(session: Annotated[AsyncSession, Depends(get_session)]) -> AuthRepository:
    return AuthRepository(session)


def get_auth_service(
    session: Annotated[AsyncSession, Depends(get_session)],
    repository: Annotated[AuthRepository, Depends(get_auth_repository)],
    settings: Annotated[AuthSettings, Depends(get_auth_settings)],
) -> AuthService:
    return AuthService(session, repository, settings)


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]


def get_access_token(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> str:
    if credentials is None:
        raise NotAuthenticatedError(
            "Authentication is required.", headers={"WWW-Authenticate": "Bearer"}
        )
    return credentials.credentials


async def get_current_user(
    # The token comes first: FastAPI resolves dependencies in order, so a request
    # without one is rejected before a database session is opened.
    token: Annotated[str, Depends(get_access_token)],
    service: AuthServiceDep,
) -> User:
    return await service.authenticate(token)


CurrentUserDep = Annotated[User, Depends(get_current_user)]
