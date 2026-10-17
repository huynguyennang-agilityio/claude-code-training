"""Password hashing, access tokens and refresh tokens.

Pure helpers with no database or settings access, so they are easy to test.
The auth service decides when to call them.
"""

import hashlib
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher
from starlette.concurrency import run_in_threadpool

_password_hash = PasswordHash((Argon2Hasher(),))
_ALGORITHM = "HS256"

# Verified when an email is unknown, so a failed sign-in takes about as long
# whether or not the account exists.
_DUMMY_HASH = _password_hash.hash("dummy-password-for-timing")


class TokenError(Exception):
    """An access token that can't be used."""


class ExpiredTokenError(TokenError):
    """A well-formed access token whose lifetime has ended."""


class InvalidTokenError(TokenError):
    """A malformed access token, or one with a bad signature or claims."""


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return _password_hash.verify(password, password_hash)


async def hash_password_async(password: str) -> str:
    """Argon2 is deliberately slow CPU work: keep it off the event loop."""
    return await run_in_threadpool(hash_password, password)


async def verify_password_async(password: str, password_hash: str | None) -> bool:
    """Check a password; with no hash (unknown account) spend the same time and fail."""
    if password_hash is None:
        await run_in_threadpool(verify_password, password, _DUMMY_HASH)
        return False
    return await run_in_threadpool(verify_password, password, password_hash)


def create_access_token(
    user_id: str, secret: str, ttl: timedelta, now: datetime | None = None
) -> str:
    issued_at = now or datetime.now(UTC)
    claims = {"sub": user_id, "iat": issued_at, "exp": issued_at + ttl}
    return jwt.encode(claims, secret, algorithm=_ALGORITHM)


def decode_access_token(token: str, secret: str, now: datetime | None = None) -> str:
    """The user id (`sub`) of a valid access token.

    Raises `ExpiredTokenError` for an expired one and `InvalidTokenError` for
    anything else wrong with it. Only HS256 is accepted, so a token signed with
    another algorithm, or with `none`, is rejected.
    """
    try:
        claims = jwt.decode(
            token,
            secret,
            algorithms=[_ALGORITHM],
            options={"require": ["exp", "sub"], "verify_exp": now is None, "verify_iat": False},
        )
    except jwt.ExpiredSignatureError as error:
        raise ExpiredTokenError("The access token has expired.") from error
    except jwt.InvalidTokenError as error:
        raise InvalidTokenError("The access token is invalid.") from error
    if now is not None and datetime.fromtimestamp(claims["exp"], UTC) <= now:
        raise ExpiredTokenError("The access token has expired.")
    subject = claims["sub"]
    if not isinstance(subject, str) or not subject:
        raise InvalidTokenError("The access token has no subject.")
    return subject


def new_refresh_token() -> str:
    """An opaque random token to hand to the client. Store only its hash."""
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
