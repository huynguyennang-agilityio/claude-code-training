import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, call

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.modules.auth.models import RefreshToken, User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import SignInRequest, SignUpRequest
from app.modules.auth.service import (
    FAILED_SIGN_IN_WINDOW,
    MAX_FAILED_SIGN_INS_PER_EMAIL,
    MAX_FAILED_SIGN_INS_PER_IP,
    AccessTokenExpiredError,
    AuthService,
    AuthSettings,
    EmailTakenError,
    InvalidAccessTokenError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
    RateLimitedError,
)

SECRET = "a-test-secret-that-is-long-enough-for-hs256"
START = datetime(2026, 10, 13, 9, 55, tzinfo=UTC)
PASSWORD = "run4medals"
PASSWORD_HASH = hash_password(PASSWORD)
IP = "203.0.113.7"


class Clock:
    def __init__(self) -> None:
        self.current = START

    def __call__(self) -> datetime:
        return self.current

    def advance(self, delta: timedelta) -> None:
        self.current += delta


def make_user(email: str = "runner@example.com") -> User:
    return User(
        id=uuid.uuid4(),
        email=email,
        password_hash=PASSWORD_HASH,
        display_name="Lan Runner",
        created_at=START,
    )


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def session() -> AsyncMock:
    return AsyncMock(spec=AsyncSession)


@pytest.fixture
def repository() -> AsyncMock:
    repository = AsyncMock(spec=AuthRepository)
    repository.get_user_by_email.return_value = None
    repository.failed_attempts_by_email.return_value = []
    repository.failed_attempts_by_ip.return_value = []
    return repository


@pytest.fixture
def service(session: AsyncMock, repository: AsyncMock, clock: Clock) -> AuthService:
    settings = AuthSettings(
        jwt_secret=SECRET,
        access_token_ttl=timedelta(minutes=15),
        refresh_token_ttl=timedelta(days=30),
    )
    return AuthService(session, repository, settings, clock)


def sign_up_request() -> SignUpRequest:
    return SignUpRequest(email="runner@example.com", password=PASSWORD, display_name="Lan Runner")


def sign_in_request(password: str = PASSWORD) -> SignInRequest:
    return SignInRequest(email="runner@example.com", password=password)


def stored_refresh_token(repository: AsyncMock) -> RefreshToken:
    token = repository.add_refresh_token.await_args.args[0]
    assert isinstance(token, RefreshToken)
    return token


# sign up


@pytest.mark.anyio
async def test_sign_up_creates_the_user_and_issues_tokens(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    user, tokens = await service.sign_up(sign_up_request())

    repository.add_user.assert_awaited_once_with(user)
    assert user.email == "runner@example.com"
    assert user.display_name == "Lan Runner"
    assert user.created_at == START
    assert user.password_hash != PASSWORD
    assert verify_password(PASSWORD, user.password_hash)
    assert decode_access_token(tokens.access_token, SECRET, START) == str(user.id)
    assert tokens.token_type == "bearer"
    assert tokens.expires_in == 900
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_sign_up_stores_only_the_hash_of_the_refresh_token(
    service: AuthService, repository: AsyncMock
) -> None:
    user, tokens = await service.sign_up(sign_up_request())

    stored = stored_refresh_token(repository)
    assert stored.user_id == user.id
    assert stored.token_hash == hash_refresh_token(tokens.refresh_token)
    assert tokens.refresh_token not in (stored.token_hash, str(stored.__dict__))
    assert stored.expires_at == START + timedelta(days=30)


@pytest.mark.anyio
async def test_sign_up_rejects_a_taken_email(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.get_user_by_email.return_value = make_user()

    with pytest.raises(EmailTakenError):
        await service.sign_up(sign_up_request())

    repository.add_user.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_sign_up_maps_a_lost_race_for_the_email_to_email_taken(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.get_user_by_email.side_effect = [None, make_user()]
    repository.add_user.side_effect = IntegrityError("insert", {}, Exception("duplicate"))

    with pytest.raises(EmailTakenError):
        await service.sign_up(sign_up_request())

    session.rollback.assert_awaited_once()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_sign_up_does_not_hide_other_integrity_errors(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.add_user.side_effect = IntegrityError("insert", {}, Exception("other"))

    with pytest.raises(IntegrityError):
        await service.sign_up(sign_up_request())

    session.rollback.assert_awaited_once()


# sign in


@pytest.mark.anyio
async def test_sign_in_with_the_right_password_issues_tokens(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    user = make_user()
    repository.get_user_by_email.return_value = user

    signed_in, tokens = await service.sign_in(sign_in_request(), IP)

    assert signed_in is user
    assert decode_access_token(tokens.access_token, SECRET, START) == str(user.id)
    repository.clear_login_attempts.assert_awaited_once_with("runner@example.com")
    repository.add_login_attempt.assert_not_awaited()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_sign_in_with_a_wrong_password_records_the_failure(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.get_user_by_email.return_value = make_user()

    with pytest.raises(InvalidCredentialsError):
        await service.sign_in(sign_in_request("wrong-pass1"), IP)

    repository.add_login_attempt.assert_awaited_once_with("runner@example.com", IP, START)
    repository.add_refresh_token.assert_not_awaited()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_sign_in_with_an_unknown_email_fails_the_same_way(
    service: AuthService, repository: AsyncMock
) -> None:
    with pytest.raises(InvalidCredentialsError) as unknown:
        await service.sign_in(sign_in_request(), IP)
    repository.get_user_by_email.return_value = make_user()
    with pytest.raises(InvalidCredentialsError) as wrong:
        await service.sign_in(sign_in_request("wrong-pass1"), IP)

    assert unknown.value.code == wrong.value.code == "invalid_credentials"
    assert unknown.value.message == wrong.value.message
    assert repository.add_login_attempt.await_count == 2


def full_window(count: int, oldest_age: timedelta) -> list[datetime]:
    """`count` failures, newest first, the oldest one `oldest_age` old."""
    return [START - oldest_age + timedelta(seconds=count - 1 - index) for index in range(count)]


@pytest.mark.anyio
async def test_sign_in_is_blocked_after_too_many_failures_for_the_email(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, timedelta(minutes=10)
    )
    repository.get_user_by_email.return_value = make_user()

    with pytest.raises(RateLimitedError) as blocked:
        await service.sign_in(sign_in_request(), IP)  # even with the right password

    assert blocked.value.headers == {"Retry-After": "300"}
    repository.get_user_by_email.assert_not_awaited()
    repository.add_login_attempt.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_sign_in_is_blocked_after_too_many_failures_for_the_ip(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.failed_attempts_by_ip.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_IP, timedelta(minutes=14, seconds=30)
    )

    with pytest.raises(RateLimitedError) as blocked:
        await service.sign_in(sign_in_request(), IP)

    assert blocked.value.headers == {"Retry-After": "30"}


@pytest.mark.anyio
async def test_retry_after_waits_for_the_longer_of_the_two_limits(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, timedelta(minutes=14)
    )
    repository.failed_attempts_by_ip.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_IP, timedelta(minutes=5)
    )

    with pytest.raises(RateLimitedError) as blocked:
        await service.sign_in(sign_in_request(), IP)

    assert blocked.value.headers == {"Retry-After": "600"}


@pytest.mark.anyio
async def test_retry_after_is_at_least_one_second(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, FAILED_SIGN_IN_WINDOW - timedelta(milliseconds=200)
    )

    with pytest.raises(RateLimitedError) as blocked:
        await service.sign_in(sign_in_request(), IP)

    assert blocked.value.headers == {"Retry-After": "1"}


@pytest.mark.anyio
async def test_sign_in_is_allowed_just_under_the_limits(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL - 1, timedelta(minutes=10)
    )
    repository.failed_attempts_by_ip.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_IP - 1, timedelta(minutes=10)
    )
    repository.get_user_by_email.return_value = make_user()

    await service.sign_in(sign_in_request(), IP)


@pytest.mark.anyio
async def test_the_failed_attempt_lookups_use_the_window_and_the_limits(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.get_user_by_email.return_value = make_user()

    await service.sign_in(sign_in_request(), IP)

    since = START - FAILED_SIGN_IN_WINDOW
    assert repository.failed_attempts_by_email.await_args == call(
        "runner@example.com", since, MAX_FAILED_SIGN_INS_PER_EMAIL
    )
    assert repository.failed_attempts_by_ip.await_args == call(
        IP, since, MAX_FAILED_SIGN_INS_PER_IP
    )


# refresh and sign out


@pytest.mark.anyio
async def test_refresh_rotates_the_token(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    user_id = uuid.uuid4()
    repository.consume_refresh_token.return_value = user_id

    tokens = await service.refresh("old-refresh-token")

    repository.consume_refresh_token.assert_awaited_once_with(
        hash_refresh_token("old-refresh-token"), START
    )
    assert decode_access_token(tokens.access_token, SECRET, START) == str(user_id)
    assert tokens.refresh_token != "old-refresh-token"
    assert stored_refresh_token(repository).user_id == user_id
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_refresh_rejects_an_unknown_expired_or_used_token(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.consume_refresh_token.return_value = None

    with pytest.raises(InvalidRefreshTokenError):
        await service.refresh("anything")

    repository.add_refresh_token.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_sign_out_revokes_the_token_and_commits(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    await service.sign_out("some-refresh-token")

    repository.revoke_refresh_token.assert_awaited_once_with(
        hash_refresh_token("some-refresh-token"), START
    )
    session.commit.assert_awaited_once()


# authenticate


@pytest.mark.anyio
async def test_authenticate_returns_the_tokens_user(
    service: AuthService, repository: AsyncMock
) -> None:
    user = make_user()
    repository.get_user.return_value = user
    _, tokens = await service.sign_up(sign_up_request())

    assert await service.authenticate(tokens.access_token) is user


@pytest.mark.anyio
async def test_authenticate_reports_an_expired_token(
    service: AuthService, repository: AsyncMock, clock: Clock
) -> None:
    repository.get_user.return_value = make_user()
    _, tokens = await service.sign_up(sign_up_request())
    clock.advance(timedelta(minutes=15))

    with pytest.raises(AccessTokenExpiredError) as expired:
        await service.authenticate(tokens.access_token)

    assert expired.value.headers == {"WWW-Authenticate": "Bearer"}


@pytest.mark.anyio
@pytest.mark.parametrize("token", ["", "garbage", "a.b.c"])
async def test_authenticate_rejects_a_malformed_token(service: AuthService, token: str) -> None:
    with pytest.raises(InvalidAccessTokenError) as invalid:
        await service.authenticate(token)

    assert invalid.value.headers == {"WWW-Authenticate": "Bearer"}


@pytest.mark.anyio
async def test_authenticate_rejects_a_subject_that_is_not_a_uuid(
    service: AuthService, clock: Clock
) -> None:
    token = create_access_token("not-a-uuid", SECRET, timedelta(minutes=15), clock())

    with pytest.raises(InvalidAccessTokenError):
        await service.authenticate(token)


@pytest.mark.anyio
async def test_authenticate_rejects_a_token_whose_user_is_gone(
    service: AuthService, repository: AsyncMock
) -> None:
    _, tokens = await service.sign_up(sign_up_request())
    repository.get_user.return_value = None

    with pytest.raises(InvalidAccessTokenError):
        await service.authenticate(tokens.access_token)
