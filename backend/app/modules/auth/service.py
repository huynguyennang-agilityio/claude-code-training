import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from math import ceil

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NOT_AUTHENTICATED_CODE, DomainError
from app.core.security import (
    ExpiredTokenError,
    TokenError,
    create_access_token,
    decode_access_token,
    hash_password_async,
    hash_refresh_token,
    new_refresh_token,
    verify_password_async,
)
from app.modules.auth.models import RefreshToken, User, UserRole
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import SignInRequest, SignUpRequest, TokenPair

MAX_FAILED_SIGN_INS_PER_EMAIL = 5
MAX_FAILED_SIGN_INS_PER_IP = 20
FAILED_SIGN_IN_WINDOW = timedelta(minutes=15)

_BEARER = {"WWW-Authenticate": "Bearer"}


class EmailTakenError(DomainError):
    status_code = 409
    code = "email_taken"


class InvalidCredentialsError(DomainError):
    status_code = 401
    code = "invalid_credentials"


class InvalidRefreshTokenError(DomainError):
    status_code = 401
    code = "invalid_refresh_token"


class NotAuthenticatedError(DomainError):
    status_code = 401
    code = NOT_AUTHENTICATED_CODE


class ForbiddenError(DomainError):
    """The caller is signed in but their role does not allow the call."""

    status_code = 403
    code = "forbidden"


class UnknownUserError(Exception):
    """No account has the given email. Used by the command-line script, not by the API."""


class InvalidAccessTokenError(DomainError):
    status_code = 401
    code = "invalid_token"


class AccessTokenExpiredError(DomainError):
    status_code = 401
    code = "token_expired"


class RateLimitedError(DomainError):
    status_code = 429
    code = "rate_limited"


@dataclass(frozen=True)
class AuthSettings:
    jwt_secret: str
    access_token_ttl: timedelta
    refresh_token_ttl: timedelta


def _utcnow() -> datetime:
    return datetime.now(UTC)


class AuthService:
    def __init__(
        self,
        session: AsyncSession,
        repository: AuthRepository,
        settings: AuthSettings,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._settings = settings
        self._now = now

    async def sign_up(self, data: SignUpRequest) -> tuple[User, TokenPair]:
        if await self._repository.get_user_by_email(data.email) is not None:
            raise EmailTakenError("An account with this email already exists.")
        user = User(
            id=uuid.uuid4(),
            email=data.email,
            password_hash=await hash_password_async(data.password),
            display_name=data.display_name,
            created_at=self._now(),
        )
        try:
            await self._repository.add_user(user)
        except IntegrityError:
            # Another request took the email between the check and the insert.
            await self._session.rollback()
            if await self._repository.get_user_by_email(data.email) is not None:
                raise EmailTakenError("An account with this email already exists.") from None
            raise
        tokens = await self._issue_tokens(user.id)
        await self._session.commit()
        return user, tokens

    async def sign_in(self, data: SignInRequest, ip: str) -> tuple[User, TokenPair]:
        now = self._now()
        await self._enforce_rate_limit(data.email, ip, now)
        user = await self._repository.get_user_by_email(data.email)
        password_ok = await verify_password_async(
            data.password, user.password_hash if user else None
        )
        if user is None or not password_ok:
            await self._repository.add_login_attempt(data.email, ip, now)
            await self._session.commit()
            raise InvalidCredentialsError("Email or password is incorrect.")
        await self._repository.clear_login_attempts(data.email)
        tokens = await self._issue_tokens(user.id)
        await self._session.commit()
        return user, tokens

    async def refresh(self, refresh_token: str) -> TokenPair:
        user_id = await self._repository.consume_refresh_token(
            hash_refresh_token(refresh_token), self._now()
        )
        if user_id is None:
            raise InvalidRefreshTokenError("The refresh token is unknown, expired or used.")
        tokens = await self._issue_tokens(user_id)
        await self._session.commit()
        return tokens

    async def sign_out(self, refresh_token: str) -> None:
        """Revoke a refresh token. An unknown or already revoked one is not an error."""
        await self._repository.revoke_refresh_token(hash_refresh_token(refresh_token), self._now())
        await self._session.commit()

    async def authenticate(self, access_token: str) -> User:
        """The user an access token belongs to."""
        try:
            subject = decode_access_token(access_token, self._settings.jwt_secret, self._now())
        except ExpiredTokenError:
            raise AccessTokenExpiredError(
                "The access token has expired.", headers=_BEARER
            ) from None
        except TokenError:
            raise InvalidAccessTokenError("The access token is invalid.", headers=_BEARER) from None
        try:
            user_id = uuid.UUID(subject)
        except ValueError:
            raise InvalidAccessTokenError("The access token is invalid.", headers=_BEARER) from None
        user = await self._repository.get_user(user_id)
        if user is None:
            raise InvalidAccessTokenError("The account no longer exists.", headers=_BEARER)
        return user

    async def set_role(self, email: str, role: UserRole) -> User:
        """Give the account with `email` a role. The only way to make an admin.

        No API route calls this: a role must never be reachable by a request.
        """
        user = await self._repository.get_user_by_email(email.strip().lower())
        if user is None:
            raise UnknownUserError(email)
        user.role = role.value
        await self._session.commit()
        return user

    async def _issue_tokens(self, user_id: uuid.UUID) -> TokenPair:
        now = self._now()
        refresh_token = new_refresh_token()
        await self._repository.add_refresh_token(
            RefreshToken(
                user_id=user_id,
                token_hash=hash_refresh_token(refresh_token),
                expires_at=now + self._settings.refresh_token_ttl,
                created_at=now,
            )
        )
        return TokenPair(
            access_token=create_access_token(
                str(user_id), self._settings.jwt_secret, self._settings.access_token_ttl, now
            ),
            refresh_token=refresh_token,
            expires_in=int(self._settings.access_token_ttl.total_seconds()),
        )

    async def _enforce_rate_limit(self, email: str, ip: str, now: datetime) -> None:
        since = now - FAILED_SIGN_IN_WINDOW
        by_email = await self._repository.failed_attempts_by_email(
            email, since, MAX_FAILED_SIGN_INS_PER_EMAIL
        )
        by_ip = await self._repository.failed_attempts_by_ip(ip, since, MAX_FAILED_SIGN_INS_PER_IP)
        # Each list is newest first and holds at most the limit, so when it is full its
        # last entry is the one whose expiry brings the count back under the limit.
        blocking = []
        if len(by_email) >= MAX_FAILED_SIGN_INS_PER_EMAIL:
            blocking.append(by_email[-1])
        if len(by_ip) >= MAX_FAILED_SIGN_INS_PER_IP:
            blocking.append(by_ip[-1])
        if not blocking:
            return
        wait = max(attempt + FAILED_SIGN_IN_WINDOW - now for attempt in blocking)
        seconds = max(1, ceil(wait.total_seconds()))
        raise RateLimitedError(
            "Too many failed sign-ins. Try again later.", headers={"Retry-After": str(seconds)}
        )
