import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserRole(StrEnum):
    USER = "user"
    ADMIN = "admin"


class User(Base):
    """An account. `email` is stored lowercase, so it is unique case-insensitively.

    `role` is `user` for everyone at sign up. An admin is also a normal user in the
    app; the role only opens the routes that change shared data. It is never set by
    an API route: `python -m app.scripts.create_admin` is the way to make an admin.
    """

    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('user', 'admin')", name="ck_users_role_valid"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    email: Mapped[str] = mapped_column(String(254), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(50))
    role: Mapped[str] = mapped_column(
        String(10), default=UserRole.USER.value, server_default=UserRole.USER.value
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class RefreshToken(Base):
    """A refresh token the client holds. Only its SHA-256 is stored.

    A token works once: using it sets `revoked_at` and issues a new one.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class LoginAttempt(Base):
    """A failed sign-in, kept to rate limit by email and by client IP."""

    __tablename__ = "login_attempts"
    __table_args__ = (
        Index("ix_login_attempts_email_attempted_at", "email", "attempted_at"),
        Index("ix_login_attempts_ip_attempted_at", "ip", "attempted_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(254))
    ip: Mapped[str] = mapped_column(String(45))
    attempted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
