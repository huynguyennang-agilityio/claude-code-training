import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, call

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.modules.auth.models import RefreshToken, User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import (
    ChangeEmailRequest,
    ChangePasswordRequest,
    SignInRequest,
    SignUpRequest,
)
from app.modules.auth.service import (
    FAILED_SIGN_IN_WINDOW,
    MAX_FAILED_SIGN_INS_PER_EMAIL,
    MAX_FAILED_SIGN_INS_PER_IP,
    AccessTokenExpiredError,
    AuthService,
    AuthSettings,
    EmailTakenError,
    IncorrectPasswordError,
    InvalidAccessTokenError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
    RateLimitedError,
    SameEmailError,
    SamePasswordError,
    _utcnow,
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

    repository.get_user_by_email.assert_awaited_once_with("runner@example.com")
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
    assert stored.created_at == START


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
    assert repository.get_user_by_email.await_args_list == [
        call("runner@example.com"),
        call("runner@example.com"),
    ]


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
    repository.get_user_by_email.assert_awaited_once_with("runner@example.com")
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


# change email


def change_email_request(
    new_email: str = "new@example.com", password: str = PASSWORD
) -> ChangeEmailRequest:
    return ChangeEmailRequest(new_email=new_email, current_password=password)


@pytest.mark.anyio
async def test_change_email_updates_clears_the_failures_and_commits(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    user = make_user()

    updated = await service.change_email(user, change_email_request("New@Example.com"), IP)

    assert updated is user
    repository.get_user_by_email.assert_awaited_once_with("new@example.com")
    repository.update_email.assert_awaited_once_with(user, "new@example.com")
    repository.clear_login_attempts.assert_awaited_once_with("runner@example.com")
    repository.add_login_attempt.assert_not_awaited()
    repository.add_refresh_token.assert_not_awaited()
    repository.revoke_refresh_token.assert_not_awaited()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_change_email_with_a_wrong_password_records_the_failure(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    with pytest.raises(IncorrectPasswordError) as error:
        await service.change_email(make_user(), change_email_request(password="wrong-pass1"), IP)

    assert error.value.code == "incorrect_password"
    assert error.value.status_code == 403
    repository.add_login_attempt.assert_awaited_once_with("runner@example.com", IP, START)
    repository.update_email.assert_not_awaited()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
@pytest.mark.parametrize("password", [PASSWORD, "wrong-pass1"])
async def test_change_email_is_blocked_after_too_many_failures(
    service: AuthService, repository: AsyncMock, session: AsyncMock, password: str
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, timedelta(minutes=10)
    )

    with pytest.raises(RateLimitedError) as error:
        await service.change_email(make_user(), change_email_request(password=password), IP)

    assert error.value.headers is not None
    assert int(error.value.headers["Retry-After"]) >= 1
    repository.add_login_attempt.assert_not_awaited()
    repository.update_email.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
@pytest.mark.parametrize("new_email", ["runner@example.com", "Runner@Example.com"])
async def test_change_email_to_the_same_email_names_new_email(
    service: AuthService, repository: AsyncMock, new_email: str
) -> None:
    with pytest.raises(SameEmailError) as error:
        await service.change_email(make_user(), change_email_request(new_email), IP)

    assert error.value.code == "validation_error"
    assert error.value.status_code == 422
    assert [field.field for field in error.value.fields] == ["new_email"]
    repository.get_user_by_email.assert_not_awaited()
    repository.update_email.assert_not_awaited()


@pytest.mark.anyio
async def test_change_email_to_an_email_in_use_is_email_taken(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.get_user_by_email.return_value = make_user("new@example.com")

    with pytest.raises(EmailTakenError):
        await service.change_email(make_user(), change_email_request(), IP)

    repository.update_email.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_change_email_checks_the_password_before_the_email_in_use(
    service: AuthService, repository: AsyncMock
) -> None:
    repository.get_user_by_email.return_value = make_user("new@example.com")

    with pytest.raises(IncorrectPasswordError):
        await service.change_email(make_user(), change_email_request(password="wrong-pass1"), IP)

    repository.get_user_by_email.assert_not_awaited()


@pytest.mark.anyio
async def test_change_email_maps_a_lost_race_on_the_email_constraint(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    class Orig(Exception):
        constraint_name = "uq_users_email"

    repository.update_email.side_effect = IntegrityError("update", {}, Orig("duplicate"))

    with pytest.raises(EmailTakenError):
        await service.change_email(make_user(), change_email_request(), IP)

    session.rollback.assert_awaited_once()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_change_email_does_not_hide_other_integrity_errors(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    repository.update_email.side_effect = IntegrityError("update", {}, Exception("other"))

    with pytest.raises(IntegrityError):
        await service.change_email(make_user(), change_email_request(), IP)

    session.rollback.assert_awaited_once()


# refresh and sign out


# change password

NEW_PASSWORD = "newrun5medals"


def change_password_request(
    new_password: str = NEW_PASSWORD, password: str = PASSWORD
) -> ChangePasswordRequest:
    return ChangePasswordRequest(current_password=password, new_password=new_password)


@pytest.mark.anyio
async def test_change_password_rehashes_revokes_everything_and_issues_a_pair(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    user = make_user()

    tokens = await service.change_password(user, change_password_request(), IP)

    repository.update_password_hash.assert_awaited_once()
    new_hash = repository.update_password_hash.await_args.args[1]
    assert new_hash != PASSWORD_HASH
    assert verify_password(NEW_PASSWORD, new_hash)
    repository.revoke_all_refresh_tokens.assert_awaited_once_with(user.id, START)
    repository.clear_login_attempts.assert_awaited_once_with("runner@example.com")
    assert stored_refresh_token(repository).user_id == user.id
    assert tokens.token_type == "bearer"
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_change_password_revokes_before_issuing_the_new_token(
    service: AuthService, repository: AsyncMock
) -> None:
    await service.change_password(make_user(), change_password_request(), IP)

    names = [c[0] for c in repository.method_calls]
    assert names.index("revoke_all_refresh_tokens") < names.index("add_refresh_token")


@pytest.mark.anyio
async def test_change_password_with_a_wrong_password_records_the_failure(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    with pytest.raises(IncorrectPasswordError) as error:
        await service.change_password(
            make_user(), change_password_request(password="wrong-pass1"), IP
        )

    assert error.value.status_code == 403
    repository.add_login_attempt.assert_awaited_once_with("runner@example.com", IP, START)
    repository.update_password_hash.assert_not_awaited()
    repository.revoke_all_refresh_tokens.assert_not_awaited()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
@pytest.mark.parametrize("password", [PASSWORD, "wrong-pass1"])
async def test_change_password_is_blocked_after_too_many_failures(
    service: AuthService, repository: AsyncMock, session: AsyncMock, password: str
) -> None:
    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, timedelta(minutes=10)
    )

    with pytest.raises(RateLimitedError) as error:
        await service.change_password(make_user(), change_password_request(password=password), IP)

    assert error.value.headers is not None
    assert int(error.value.headers["Retry-After"]) >= 1
    repository.update_password_hash.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_change_password_to_the_same_password_names_new_password(
    service: AuthService, repository: AsyncMock, session: AsyncMock
) -> None:
    with pytest.raises(SamePasswordError) as error:
        await service.change_password(make_user(), change_password_request(PASSWORD), IP)

    assert error.value.code == "validation_error"
    assert error.value.status_code == 422
    assert [field.field for field in error.value.fields] == ["new_password"]
    repository.update_password_hash.assert_not_awaited()
    repository.revoke_all_refresh_tokens.assert_not_awaited()
    session.commit.assert_not_awaited()


@pytest.mark.anyio
async def test_change_password_checks_the_password_before_the_same_password(
    service: AuthService,
) -> None:
    with pytest.raises(IncorrectPasswordError):
        await service.change_password(
            make_user(), change_password_request("wrong-pass1", "wrong-pass1"), IP
        )


def test_change_password_rejects_a_new_password_that_breaks_the_rule() -> None:
    for bad in ["short1", "onlyletters", "12345678", "a1" * 65]:
        with pytest.raises(ValueError, match="new_password"):
            change_password_request(bad)


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
    signed_up, tokens = await service.sign_up(sign_up_request())

    assert await service.authenticate(tokens.access_token) is user
    repository.get_user.assert_awaited_once_with(signed_up.id)


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

    with pytest.raises(InvalidAccessTokenError) as invalid:
        await service.authenticate(token)

    assert invalid.value.headers == {"WWW-Authenticate": "Bearer"}


@pytest.mark.anyio
async def test_authenticate_rejects_a_token_whose_user_is_gone(
    service: AuthService, repository: AsyncMock
) -> None:
    _, tokens = await service.sign_up(sign_up_request())
    repository.get_user.return_value = None

    with pytest.raises(InvalidAccessTokenError) as invalid:
        await service.authenticate(tokens.access_token)

    assert invalid.value.headers == {"WWW-Authenticate": "Bearer"}


# Every error is rendered into an `ErrorResponse` whose `message` must be a string, so a
# service must never raise one without a readable message. The wording is free: clients
# branch on `code`.


async def raised(call: object) -> DomainError:
    with pytest.raises(DomainError) as error:
        await call  # type: ignore[misc]
    return error.value


@pytest.mark.anyio
async def test_every_error_the_service_raises_has_a_message(
    service: AuthService, repository: AsyncMock, clock: Clock
) -> None:
    errors: list[DomainError] = []

    repository.get_user_by_email.return_value = make_user()
    errors.append(await raised(service.sign_up(sign_up_request())))  # email taken
    errors.append(await raised(service.sign_in(sign_in_request("wrong-pass1"), IP)))

    repository.get_user_by_email.side_effect = [None, make_user()]
    repository.add_user.side_effect = IntegrityError("insert", {}, Exception("duplicate"))
    errors.append(await raised(service.sign_up(sign_up_request())))  # lost race
    repository.get_user_by_email.side_effect = None
    repository.add_user.side_effect = None

    repository.failed_attempts_by_email.return_value = full_window(
        MAX_FAILED_SIGN_INS_PER_EMAIL, timedelta(minutes=10)
    )
    errors.append(await raised(service.sign_in(sign_in_request(), IP)))  # rate limited
    repository.failed_attempts_by_email.return_value = []

    repository.consume_refresh_token.return_value = None
    errors.append(await raised(service.refresh("unknown")))

    errors.append(await raised(service.authenticate("garbage")))
    not_a_uuid = create_access_token("not-a-uuid", SECRET, timedelta(minutes=15), clock())
    errors.append(await raised(service.authenticate(not_a_uuid)))
    token = create_access_token(str(uuid.uuid4()), SECRET, timedelta(minutes=15), clock())
    repository.get_user.return_value = None
    errors.append(await raised(service.authenticate(token)))  # user gone
    expired = create_access_token(str(uuid.uuid4()), SECRET, timedelta(minutes=15), clock())
    clock.advance(timedelta(minutes=15))
    errors.append(await raised(service.authenticate(expired)))  # expired

    errors.append(
        await raised(
            service.change_email(make_user(), change_email_request(password="wrong-pass1"), IP)
        )
    )
    errors.append(
        await raised(
            service.change_email(make_user(), change_email_request("runner@example.com"), IP)
        )
    )

    errors.append(
        await raised(service.change_password(make_user(), change_password_request(PASSWORD), IP))
    )

    assert len(errors) == 12
    for error in errors:
        assert isinstance(error.message, str), type(error).__name__
        assert error.message.strip(), type(error).__name__


def test_utcnow_is_timezone_aware_and_current() -> None:
    now = _utcnow()

    assert now.tzinfo is not None
    assert abs(datetime.now(UTC) - now) < timedelta(seconds=5)
