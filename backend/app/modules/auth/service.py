import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from math import ceil

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NOT_AUTHENTICATED_CODE, VALIDATION_ERROR_CODE, DomainError, FieldError
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
from app.modules.auth.schemas import (
    ChangeEmailRequest,
    ChangePasswordRequest,
    DeleteAccountRequest,
    SignInRequest,
    SignUpRequest,
    TokenPair,
)
from app.modules.runs.service import RunService

MAX_FAILED_SIGN_INS_PER_EMAIL = 5
MAX_FAILED_SIGN_INS_PER_IP = 20
FAILED_SIGN_IN_WINDOW = timedelta(minutes=15)

_BEARER = {"WWW-Authenticate": "Bearer"}
_USERS_EMAIL_CONSTRAINT = "uq_users_email"


def _violated_constraint(error: IntegrityError) -> str | None:
    """The name of the constraint a PostgreSQL integrity error broke, when the driver says."""
    cause = getattr(error.orig, "__cause__", None)
    name = getattr(cause, "constraint_name", None) or getattr(error.orig, "constraint_name", None)
    return name if isinstance(name, str) else None


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


class IncorrectPasswordError(DomainError):
    status_code = 403
    code = "incorrect_password"


class SameEmailError(DomainError):
    status_code = 422
    code = VALIDATION_ERROR_CODE


class SamePasswordError(DomainError):
    status_code = 422
    code = VALIDATION_ERROR_CODE


class LastAdminError(DomainError):
    status_code = 409
    code = "last_admin"


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
        runs: RunService,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._settings = settings
        # The only way auth reaches the enrollments: for the lock in `delete_account`.
        self._runs = runs
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
        # Serialized with `change_password`: a password that changed while it was being
        # checked is wrong now, and must not get a refresh token the change never revoked.
        if password_ok and user is not None:
            password_ok = await self._password_unchanged_after_lock(user)
        if user is None or not password_ok:
            await self._repository.add_login_attempt(data.email, ip, now)
            await self._session.commit()
            raise InvalidCredentialsError("Email or password is incorrect.")
        await self._repository.clear_login_attempts(data.email)
        tokens = await self._issue_tokens(user.id)
        await self._session.commit()
        return user, tokens

    async def change_email(self, user: User, data: ChangeEmailRequest, ip: str) -> User:
        """Give `user` a new email. The order of checks is part of the contract: rate limit,
        current password, same email, email in use (see `docs/api/auth.md`)."""
        now = self._now()
        old_email = user.email
        await self._verify_current_password(user, data.current_password, ip, now)
        if data.new_email == old_email:
            raise SameEmailError(
                "The new email is the same as the current one.",
                fields=[
                    FieldError(
                        field="new_email", message="The new email must differ from the current one."
                    )
                ],
            )
        if await self._repository.get_user_by_email(data.new_email) is not None:
            raise EmailTakenError("An account with this email already exists.")
        try:
            await self._repository.update_email(user, data.new_email)
        except IntegrityError as error:
            # Another request took the email between the check and the update.
            constraint = _violated_constraint(error)
            await self._session.rollback()
            if constraint == _USERS_EMAIL_CONSTRAINT:
                raise EmailTakenError("An account with this email already exists.") from None
            raise
        await self._repository.clear_login_attempts(old_email)
        await self._session.commit()
        return user

    async def change_password(self, user: User, data: ChangePasswordRequest, ip: str) -> TokenPair:
        """Give `user` a new password and sign every device out. The order of checks is part
        of the contract: rate limit, current password, same password (see `docs/api/auth.md`).

        Returns a new token pair for the device that made the call.
        """
        now = self._now()
        await self._verify_current_password(user, data.current_password, ip, now)
        if data.new_password == data.current_password:
            raise SamePasswordError(
                "The new password is the same as the current one.",
                fields=[
                    FieldError(
                        field="new_password",
                        message="The new password must differ from the current one.",
                    )
                ],
            )
        password_hash = await hash_password_async(data.new_password)
        if not await self._password_unchanged_after_lock(user):
            # Another change committed after the check: the current password is wrong now.
            await self._repository.add_login_attempt(user.email, ip, now)
            await self._session.commit()
            raise IncorrectPasswordError("The current password is incorrect.")
        await self._repository.update_password_hash(user, password_hash)
        await self._repository.revoke_all_refresh_tokens(user.id, now)
        await self._repository.clear_login_attempts(user.email)
        tokens = await self._issue_tokens(user.id)
        await self._session.commit()
        return tokens

    async def delete_account(self, user: User, data: DeleteAccountRequest, ip: str) -> None:
        """Delete `user` and everything that belongs to them, for good. The order of checks is
        part of the contract: rate limit, current password, last admin (see `docs/api/auth.md`).

        The locks are taken in the order `join` and `resume` use (enrollments, then refresh
        tokens, then rows), so a delete running with them waits instead of deadlocking.
        """
        await self._verify_current_password(user, data.current_password, ip, self._now())
        await self._runs.lock_user_enrollments(user.id)
        await self._repository.lock_user_refresh_tokens(user.id)
        if (
            user.role == UserRole.ADMIN.value
            and await self._repository.lock_admins_and_count() <= 1
        ):
            raise LastAdminError(
                "You're the only admin. Make another account an admin before deleting yours."
            )
        await self._repository.delete_user(user.id)
        await self._repository.clear_login_attempts(user.email)
        await self._session.commit()

    async def refresh(self, refresh_token: str) -> TokenPair:
        token_hash = hash_refresh_token(refresh_token)
        # Serialized with `change_password`, so a password change revokes this pair too.
        await self._repository.lock_refresh_token_owner(token_hash)
        user_id = await self._repository.consume_refresh_token(token_hash, self._now())
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

    async def _password_unchanged_after_lock(self, user: User) -> bool:
        """Take the lock on `user`'s refresh tokens, then check that the stored password hash
        is still the one that was verified. The lock is held until the transaction ends."""
        await self._repository.lock_user_refresh_tokens(user.id)
        return await self._repository.stored_password_hash(user.id) == user.password_hash

    async def _verify_current_password(
        self, user: User, password: str, ip: str, now: datetime
    ) -> None:
        """Check the password of a signed-in user for a sensitive change.

        Shares the sign-in rate limit: a wrong password is recorded as a failed sign-in for
        the user's email and the IP, and a blocked caller gets `429` even with the right one.
        """
        await self._enforce_rate_limit(user.email, ip, now)
        if not await verify_password_async(password, user.password_hash):
            await self._repository.add_login_attempt(user.email, ip, now)
            await self._session.commit()
            raise IncorrectPasswordError("The current password is incorrect.")

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
