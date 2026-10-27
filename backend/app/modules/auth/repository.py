import uuid
from datetime import datetime

from sqlalchemy import ColumnElement, delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import LoginAttempt, RefreshToken, User


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
