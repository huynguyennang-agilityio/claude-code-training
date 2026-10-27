import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import ColumnElement, String, Uuid, cast, delete, func, literal, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import SQLCoreOperations

from app.modules.auth.models import LoginAttempt, RefreshToken, User

# Salts the advisory lock key, so it can't equal a key another feature derives from the id.
_REFRESH_TOKENS_LOCK_SALT = 7_301_224


def _refresh_tokens_lock(user_id: SQLCoreOperations[uuid.UUID]) -> ColumnElement[Any]:
    """Take the advisory lock on one user's refresh tokens. The key is computed in SQL, so a
    refresh can find the token's owner and take the lock in one query."""
    return func.pg_advisory_xact_lock(
        func.hashtextextended(cast(user_id, String), _REFRESH_TOKENS_LOCK_SALT)
    )


class AuthRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_user(self, user_id: uuid.UUID) -> User | None:
        return await self._session.get(User, user_id)

    async def get_user_by_email(self, email: str) -> User | None:
        return await self._session.scalar(select(User).where(User.email == email))

    async def add_user(self, user: User) -> User:
        self._session.add(user)
        await self._session.flush()
        return user

    async def update_email(self, user: User, email: str) -> None:
        user.email = email
        await self._session.flush()

    async def add_refresh_token(self, token: RefreshToken) -> None:
        self._session.add(token)
        await self._session.flush()

    async def consume_refresh_token(self, token_hash: str, now: datetime) -> uuid.UUID | None:
        """Revoke an unused, unexpired refresh token and return its user's id.

        One `UPDATE … RETURNING`, so two requests with the same token can't both
        succeed. Returns None when the token is unknown, used or expired.
        """
        return await self._session.scalar(
            update(RefreshToken)
            .where(
                RefreshToken.token_hash == token_hash,
                RefreshToken.revoked_at.is_(None),
                RefreshToken.expires_at > now,
            )
            .values(revoked_at=now)
            .returning(RefreshToken.user_id)
        )

    async def revoke_refresh_token(self, token_hash: str, now: datetime) -> None:
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.token_hash == token_hash, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )

    async def lock_user_refresh_tokens(self, user_id: uuid.UUID) -> None:
        """Wait for any other transaction that is issuing or revoking this user's refresh
        tokens, then hold the lock until this transaction ends. Without it a refresh that
        commits during a password change keeps a token the change never saw."""
        await self._session.execute(select(_refresh_tokens_lock(literal(user_id, Uuid))))

    async def stored_password_hash(self, user_id: uuid.UUID) -> str | None:
        """The password hash as committed now, read with a new query: not the copy of the
        `User` loaded earlier in this session. Call it after `lock_user_refresh_tokens`, in a
        statement of its own, so it sees a password change that committed while waiting."""
        return await self._session.scalar(select(User.password_hash).where(User.id == user_id))

    async def lock_refresh_token_owner(self, token_hash: str) -> None:
        """`lock_user_refresh_tokens` for the owner of `token_hash`, found in the same query.
        An unknown token takes no lock."""
        await self._session.execute(
            select(_refresh_tokens_lock(RefreshToken.user_id)).where(
                RefreshToken.token_hash == token_hash
            )
        )

    async def revoke_all_refresh_tokens(self, user_id: uuid.UUID, now: datetime) -> None:
        """Revoke every refresh token of `user_id` that is not revoked yet."""
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await self._session.flush()

    async def update_password_hash(self, user: User, password_hash: str) -> None:
        user.password_hash = password_hash
        await self._session.flush()

    async def add_login_attempt(self, email: str, ip: str, attempted_at: datetime) -> None:
        self._session.add(LoginAttempt(email=email, ip=ip, attempted_at=attempted_at))
        await self._session.flush()

    async def failed_attempts_by_email(
        self, email: str, since: datetime, limit: int
    ) -> list[datetime]:
        """The newest `limit` failed sign-in times for `email` since `since`, newest first."""
        return await self._attempt_times(LoginAttempt.email == email, since, limit)

    async def failed_attempts_by_ip(self, ip: str, since: datetime, limit: int) -> list[datetime]:
        return await self._attempt_times(LoginAttempt.ip == ip, since, limit)

    async def clear_login_attempts(self, email: str) -> None:
        await self._session.execute(delete(LoginAttempt).where(LoginAttempt.email == email))

    async def _attempt_times(
        self, match: ColumnElement[bool], since: datetime, limit: int
    ) -> list[datetime]:
        rows = await self._session.scalars(
            select(LoginAttempt.attempted_at)
            .where(match, LoginAttempt.attempted_at > since)
            .order_by(LoginAttempt.attempted_at.desc())
            .limit(limit)
        )
        return list(rows)
