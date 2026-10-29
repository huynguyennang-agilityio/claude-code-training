"""The auth endpoints of `docs/api/auth.md`, against PostgreSQL.

Every success body is compared with the files in `docs/api/examples/auth/`, and
every documented error code is produced by a real call. Generated values (ids,
tokens, timestamps) are compared by type.
"""

import asyncio
import re
import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient, Response
from sqlalchemy import delete, text
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.core.config import get_settings
from app.core.errors import ErrorResponse
from app.core.security import create_access_token, hash_password
from app.modules.auth.deps import get_auth_settings
from app.modules.auth.models import LoginAttempt, RefreshToken, User
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import DeleteAccountRequest
from app.modules.auth.service import (
    FAILED_SIGN_IN_WINDOW,
    MAX_FAILED_SIGN_INS_PER_EMAIL,
    MAX_FAILED_SIGN_INS_PER_IP,
    AuthService,
    IncorrectPasswordError,
    LastAdminError,
)
from app.modules.challenges.models import Challenge, Quest
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.service import ChallengeService
from app.modules.medals.repository import MedalRepository
from app.modules.medals.service import MedalService
from app.modules.runs.enrollments import EnrollmentService
from app.modules.runs.models import DailyActivity, StepSample
from app.modules.runs.repository import RunRepository
from app.modules.runs.service import RunService
from tests.api_docs import API_DOCS_DIR, AUTH_MODULE_ERROR_CODES, error_codes, load_example
from tests.integration.enrollment_helpers import make_run
from tests.integration.test_refresh_token_lock import (
    _wait_until_a_session_waits_for_an_advisory_lock,
)

SECRET = "an-integration-test-secret-that-is-long-enough"
PASSWORD = "run4medals"
SIGNUP = load_example("auth/signup_request.json")
SIGNIN = load_example("auth/signin_request.json")
PREFIX = "/api/v1"


@pytest.fixture(autouse=True)
def auth_settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """The app reads its settings from the environment; give it known ones."""
    monkeypatch.setenv("JWT_SECRET", SECRET)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def assert_same_shape(actual: Any, example: Any) -> None:
    """Same keys at each level and the same JSON type for each value."""
    if isinstance(example, dict):
        assert isinstance(actual, dict)
        assert set(actual) == set(example)
        for key, value in example.items():
            assert_same_shape(actual[key], value)
    elif isinstance(example, list):
        assert isinstance(actual, list)
    else:
        assert type(actual) is type(example)


def assert_error(response: Response, status: int, code: str) -> dict[str, Any]:
    assert response.status_code == status, response.text
    body = ErrorResponse.model_validate(response.json())
    assert body.error.code == code
    assert code in AUTH_MODULE_ERROR_CODES | {"validation_error", "not_authenticated"}
    return dict(response.json())


async def sign_up(client: AsyncClient, **changes: str) -> dict[str, Any]:
    response = await client.post(f"{PREFIX}/auth/signup", json={**SIGNUP, **changes})
    assert response.status_code == 201, response.text
    return dict(response.json())


async def sign_in(client: AsyncClient, **changes: str) -> Response:
    return await client.post(f"{PREFIX}/auth/signin", json={**SIGNIN, **changes})


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# sign up


@pytest.mark.anyio
async def test_sign_up_returns_the_documented_auth_response(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/auth/signup", json=SIGNUP)

    assert response.status_code == 201
    body = response.json()
    example = load_example("auth/auth_response.json")
    assert_same_shape(body, example)
    assert body["user"]["email"] == example["user"]["email"]
    assert body["user"]["display_name"] == example["user"]["display_name"]
    assert uuid.UUID(body["user"]["id"])
    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z", body["user"]["created_at"])
    assert body["tokens"]["token_type"] == "bearer"
    assert body["tokens"]["expires_in"] == 900
    assert "password" not in response.text


@pytest.mark.anyio
async def test_sign_up_stores_the_email_lowercase(client: AsyncClient) -> None:
    body = await sign_up(client, email="Runner@Example.COM")

    assert body["user"]["email"] == "runner@example.com"


@pytest.mark.anyio
async def test_sign_up_stores_a_hash_not_the_password(
    client: AsyncClient, session: AsyncSession
) -> None:
    await sign_up(client)

    stored = await session.scalar(
        text("SELECT password_hash FROM users WHERE email = 'runner@example.com'")
    )
    assert stored is not None
    assert stored.startswith("$argon2")
    assert PASSWORD not in stored


@pytest.mark.anyio
async def test_sign_up_with_a_taken_email_returns_email_taken(client: AsyncClient) -> None:
    await sign_up(client)

    again = await client.post(
        f"{PREFIX}/auth/signup", json={**SIGNUP, "email": "RUNNER@example.com"}
    )

    assert_error(again, 409, "email_taken")


@pytest.mark.anyio
async def test_sign_up_validation_error_matches_the_documented_example(
    client: AsyncClient,
) -> None:
    response = await client.post(f"{PREFIX}/auth/signup", json={**SIGNUP, "password": "runnerrun"})

    assert_error(response, 422, "validation_error")
    assert response.json() == load_example("auth/error_validation.json")


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("changes", "field"),
    [
        ({"email": "not-an-email"}, "email"),
        ({"password": "short1"}, "password"),
        ({"display_name": "   "}, "display_name"),
    ],
)
async def test_sign_up_names_the_invalid_field(
    client: AsyncClient, changes: dict[str, str], field: str
) -> None:
    response = await client.post(f"{PREFIX}/auth/signup", json={**SIGNUP, **changes})

    body = assert_error(response, 422, "validation_error")
    assert [item["field"] for item in body["error"]["fields"]] == [field]


@pytest.mark.anyio
async def test_sign_up_with_a_missing_body_is_a_validation_error(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/auth/signup", json={})

    body = assert_error(response, 422, "validation_error")
    assert {item["field"] for item in body["error"]["fields"]} == {
        "email",
        "password",
        "display_name",
    }


# sign in


@pytest.mark.anyio
async def test_sign_in_returns_the_documented_auth_response(client: AsyncClient) -> None:
    signed_up = await sign_up(client)

    response = await sign_in(client)

    assert response.status_code == 200
    body = response.json()
    assert_same_shape(body, load_example("auth/auth_response.json"))
    assert body["user"] == signed_up["user"]


@pytest.mark.anyio
async def test_sign_in_ignores_the_case_of_the_email(client: AsyncClient) -> None:
    await sign_up(client)

    assert (await sign_in(client, email="RUNNER@EXAMPLE.COM")).status_code == 200


@pytest.mark.anyio
async def test_sign_in_with_a_wrong_password_matches_the_documented_example(
    client: AsyncClient,
) -> None:
    await sign_up(client)

    response = await sign_in(client, password="wrong-pass1")

    assert_error(response, 401, "invalid_credentials")
    assert response.json() == load_example("auth/error_invalid_credentials.json")


@pytest.mark.anyio
async def test_sign_in_with_an_unknown_email_looks_the_same_as_a_wrong_password(
    client: AsyncClient,
) -> None:
    await sign_up(client)

    unknown = await sign_in(client, email="nobody@example.com")
    wrong = await sign_in(client, password="wrong-pass1")

    assert_error(unknown, 401, "invalid_credentials")
    assert unknown.json() == wrong.json()


@pytest.mark.anyio
async def test_sign_in_with_an_empty_password_is_a_validation_error(client: AsyncClient) -> None:
    response = await sign_in(client, password="")

    assert_error(response, 422, "validation_error")


# rate limit


@pytest.mark.anyio
async def test_sign_in_is_blocked_after_five_failures_for_the_email(client: AsyncClient) -> None:
    await sign_up(client)
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        assert_error(await sign_in(client, password="wrong-pass1"), 401, "invalid_credentials")

    blocked = await sign_in(client)  # the right password

    assert_error(blocked, 429, "rate_limited")
    retry_after = int(blocked.headers["retry-after"])
    assert 1 <= retry_after <= int(FAILED_SIGN_IN_WINDOW.total_seconds())


@pytest.mark.anyio
async def test_a_blocked_attempt_does_not_extend_the_block(client: AsyncClient) -> None:
    await sign_up(client)
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        await sign_in(client, password="wrong-pass1")
    first = await sign_in(client)

    second = await sign_in(client)

    assert int(second.headers["retry-after"]) <= int(first.headers["retry-after"])


@pytest.mark.anyio
async def test_a_successful_sign_in_clears_the_failures_for_that_email(
    client: AsyncClient,
) -> None:
    await sign_up(client)
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL - 1):
        await sign_in(client, password="wrong-pass1")
    assert (await sign_in(client)).status_code == 200

    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL - 1):
        assert_error(await sign_in(client, password="wrong-pass1"), 401, "invalid_credentials")

    assert (await sign_in(client)).status_code == 200


@pytest.mark.anyio
async def test_failures_for_one_email_do_not_block_another(client: AsyncClient) -> None:
    await sign_up(client)
    await sign_up(client, email="other@example.com")
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        await sign_in(client, password="wrong-pass1")

    assert (await sign_in(client, email="other@example.com")).status_code == 200


@pytest.mark.anyio
async def test_sign_in_is_blocked_after_twenty_failures_from_one_ip(client: AsyncClient) -> None:
    for number in range(MAX_FAILED_SIGN_INS_PER_IP):
        failed = await sign_in(client, email=f"nobody{number}@example.com")
        assert_error(failed, 401, "invalid_credentials")

    blocked = await sign_in(client, email="another-new-address@example.com")

    assert_error(blocked, 429, "rate_limited")


@pytest.mark.anyio
async def test_old_failures_stop_counting(client: AsyncClient, session: AsyncSession) -> None:
    await sign_up(client)
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        await sign_in(client, password="wrong-pass1")
    assert_error(await sign_in(client), 429, "rate_limited")

    await session.execute(
        text("UPDATE login_attempts SET attempted_at = :at"),
        {"at": datetime.now(UTC) - FAILED_SIGN_IN_WINDOW - timedelta(seconds=1)},
    )

    assert (await sign_in(client)).status_code == 200


# refresh and sign out


@pytest.mark.anyio
async def test_refresh_returns_a_new_token_pair(client: AsyncClient) -> None:
    tokens = (await sign_up(client))["tokens"]

    response = await client.post(
        f"{PREFIX}/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert response.status_code == 200
    new = response.json()
    assert_same_shape(new, load_example("auth/token_pair.json"))
    assert new["refresh_token"] != tokens["refresh_token"]
    me = await client.get(f"{PREFIX}/users/me", headers=bearer(new["access_token"]))
    assert me.status_code == 200


@pytest.mark.anyio
async def test_a_refresh_token_works_once(client: AsyncClient) -> None:
    old = (await sign_up(client))["tokens"]["refresh_token"]
    new = (await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": old})).json()

    reused = await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": old})

    assert_error(reused, 401, "invalid_refresh_token")
    again = await client.post(
        f"{PREFIX}/auth/refresh", json={"refresh_token": new["refresh_token"]}
    )
    assert again.status_code == 200


@pytest.mark.anyio
async def test_refresh_with_an_unknown_token_is_rejected(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": "made-up"})

    assert_error(response, 401, "invalid_refresh_token")


@pytest.mark.anyio
async def test_refresh_with_an_expired_token_is_rejected(
    client: AsyncClient, session: AsyncSession
) -> None:
    token = (await sign_up(client))["tokens"]["refresh_token"]
    await session.execute(
        text("UPDATE refresh_tokens SET expires_at = :at"),
        {"at": datetime.now(UTC) - timedelta(seconds=1)},
    )

    response = await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": token})

    assert_error(response, 401, "invalid_refresh_token")


@pytest.mark.anyio
async def test_refresh_without_a_token_is_a_validation_error(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/auth/refresh", json={})

    assert_error(response, 422, "validation_error")


@pytest.mark.anyio
async def test_sign_out_revokes_the_refresh_token(client: AsyncClient) -> None:
    token = (await sign_up(client))["tokens"]["refresh_token"]

    signed_out = await client.post(f"{PREFIX}/auth/signout", json={"refresh_token": token})

    assert signed_out.status_code == 204
    assert signed_out.content == b""
    refreshed = await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": token})
    assert_error(refreshed, 401, "invalid_refresh_token")


@pytest.mark.anyio
async def test_sign_out_twice_or_with_an_unknown_token_is_still_204(client: AsyncClient) -> None:
    token = (await sign_up(client))["tokens"]["refresh_token"]

    for refresh_token in (token, token, "made-up"):
        response = await client.post(
            f"{PREFIX}/auth/signout", json={"refresh_token": refresh_token}
        )
        assert response.status_code == 204


@pytest.mark.anyio
async def test_sign_out_without_a_token_is_a_validation_error(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/auth/signout", json={})

    assert_error(response, 422, "validation_error")


# current user


@pytest.mark.anyio
async def test_users_me_returns_the_signed_in_user(client: AsyncClient) -> None:
    body = await sign_up(client)

    response = await client.get(
        f"{PREFIX}/users/me", headers=bearer(body["tokens"]["access_token"])
    )

    assert response.status_code == 200
    assert response.json() == body["user"]
    assert_same_shape(response.json(), load_example("auth/user.json"))


@pytest.mark.anyio
async def test_users_me_without_a_token_returns_not_authenticated(client: AsyncClient) -> None:
    response = await client.get(f"{PREFIX}/users/me")

    assert_error(response, 401, "not_authenticated")
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.anyio
@pytest.mark.parametrize("header", ["Basic abc", "Bearer", "token-without-scheme"])
async def test_users_me_without_a_bearer_token_returns_not_authenticated(
    client: AsyncClient, header: str
) -> None:
    response = await client.get(f"{PREFIX}/users/me", headers={"Authorization": header})

    assert_error(response, 401, "not_authenticated")


@pytest.mark.anyio
async def test_users_me_with_a_garbage_token_returns_invalid_token(client: AsyncClient) -> None:
    response = await client.get(f"{PREFIX}/users/me", headers=bearer("not.a.jwt"))

    assert_error(response, 401, "invalid_token")
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.anyio
async def test_users_me_with_a_token_signed_by_someone_else_returns_invalid_token(
    client: AsyncClient,
) -> None:
    user_id = (await sign_up(client))["user"]["id"]
    forged = create_access_token(user_id, "another-secret-of-similar-length-12345", timedelta(1))

    response = await client.get(f"{PREFIX}/users/me", headers=bearer(forged))

    assert_error(response, 401, "invalid_token")


@pytest.mark.anyio
async def test_users_me_with_an_expired_token_returns_token_expired(client: AsyncClient) -> None:
    user_id = (await sign_up(client))["user"]["id"]
    expired = create_access_token(user_id, SECRET, timedelta(seconds=-1))

    response = await client.get(f"{PREFIX}/users/me", headers=bearer(expired))

    assert_error(response, 401, "token_expired")
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.anyio
async def test_users_me_for_a_deleted_user_returns_invalid_token(
    client: AsyncClient, session: AsyncSession
) -> None:
    body = await sign_up(client)
    await session.execute(text("DELETE FROM users"))

    response = await client.get(
        f"{PREFIX}/users/me", headers=bearer(body["tokens"]["access_token"])
    )

    assert_error(response, 401, "invalid_token")


# change email

CHANGE_EMAIL = load_example("auth/change_email_request.json")
NEW_EMAIL = "new.runner@example.com"


async def change_email(client: AsyncClient, token: str, **changes: str) -> Response:
    return await client.put(
        f"{PREFIX}/users/me/email", json={**CHANGE_EMAIL, **changes}, headers=bearer(token)
    )


@pytest.mark.anyio
async def test_change_email_then_sign_in_with_the_new_email_only(client: AsyncClient) -> None:
    body = await sign_up(client)
    token = body["tokens"]["access_token"]

    response = await change_email(client, token, new_email="New.Runner@Example.com")

    assert response.status_code == 200, response.text
    assert response.json() == {**body["user"], "email": NEW_EMAIL}
    assert_same_shape(response.json(), load_example("auth/user.json"))
    assert (await sign_in(client, email=NEW_EMAIL)).status_code == 200
    assert_error(await sign_in(client), 401, "invalid_credentials")
    # Sessions are not revoked: the token in use and the refresh token still work.
    assert (await client.get(f"{PREFIX}/users/me", headers=bearer(token))).json()["email"] == (
        NEW_EMAIL
    )
    refreshed = await client.post(
        f"{PREFIX}/auth/refresh", json={"refresh_token": body["tokens"]["refresh_token"]}
    )
    assert refreshed.status_code == 200


@pytest.mark.anyio
async def test_change_email_with_a_wrong_password_matches_the_example(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    response = await change_email(client, token, current_password="wrong-pass1")

    body = assert_error(response, 403, "incorrect_password")
    assert body == load_example("auth/error_incorrect_password.json")


@pytest.mark.anyio
async def test_wrong_passwords_on_change_email_count_toward_the_sign_in_limit(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        assert_error(
            await change_email(client, token, current_password="wrong-pass1"),
            403,
            "incorrect_password",
        )

    blocked = await change_email(client, token)  # the right password

    assert_error(blocked, 429, "rate_limited")
    assert int(blocked.headers["retry-after"]) >= 1
    assert_error(await sign_in(client), 429, "rate_limited")


@pytest.mark.anyio
async def test_a_successful_change_email_clears_the_failures_for_the_old_email(
    client: AsyncClient, session: AsyncSession
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL - 1):
        await change_email(client, token, current_password="wrong-pass1")

    assert (await change_email(client, token)).status_code == 200

    count = await session.scalar(
        text("SELECT count(*) FROM login_attempts WHERE email = :e"), {"e": SIGNUP["email"]}
    )
    assert count == 0


@pytest.mark.anyio
async def test_change_email_to_the_same_email_names_new_email(client: AsyncClient) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    response = await change_email(client, token, new_email=SIGNUP["email"].upper())

    body = assert_error(response, 422, "validation_error")
    assert body["error"]["fields"][0]["field"] == "new_email"


@pytest.mark.anyio
async def test_change_email_with_an_invalid_email_is_a_validation_error(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    body = assert_error(
        await change_email(client, token, new_email="nope"), 422, "validation_error"
    )

    assert body["error"]["fields"][0]["field"] == "new_email"


@pytest.mark.anyio
async def test_change_email_to_an_email_in_use_is_email_taken(client: AsyncClient) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    other = await sign_up(client, email="other@example.com")

    assert_error(
        await change_email(client, token, new_email="Other@example.com"), 409, "email_taken"
    )

    # Nothing changed for either account.
    assert (await client.get(f"{PREFIX}/users/me", headers=bearer(token))).json()["email"] == (
        SIGNUP["email"]
    )
    me = await client.get(f"{PREFIX}/users/me", headers=bearer(other["tokens"]["access_token"]))
    assert me.json()["email"] == "other@example.com"


@pytest.mark.anyio
async def test_change_email_loses_a_race_for_the_email_with_email_taken(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    await sign_up(client, email="other@example.com")
    original = AuthRepository.get_user_by_email

    async def not_seen_yet(self: AuthRepository, email: str) -> User | None:
        # The email check misses the other account, so the unique constraint decides.
        return None if email == "other@example.com" else await original(self, email)

    monkeypatch.setattr(AuthRepository, "get_user_by_email", not_seen_yet)

    response = await change_email(client, token, new_email="other@example.com")

    assert_error(response, 409, "email_taken")
    monkeypatch.undo()
    assert (await sign_in(client)).status_code == 200


@pytest.mark.anyio
async def test_change_email_checks_the_password_before_the_email_in_use(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    await sign_up(client, email="other@example.com")

    response = await change_email(
        client, token, new_email="other@example.com", current_password="wrong-pass1"
    )

    assert_error(response, 403, "incorrect_password")


@pytest.mark.anyio
async def test_change_email_without_a_token_returns_not_authenticated(
    client: AsyncClient,
) -> None:
    response = await client.put(f"{PREFIX}/users/me/email", json=CHANGE_EMAIL)

    assert_error(response, 401, "not_authenticated")


# change password

CHANGE_PASSWORD = load_example("auth/change_password_request.json")
NEW_PASSWORD = CHANGE_PASSWORD["new_password"]


async def change_password(client: AsyncClient, token: str, **changes: str) -> Response:
    return await client.put(
        f"{PREFIX}/users/me/password", json={**CHANGE_PASSWORD, **changes}, headers=bearer(token)
    )


async def refresh(client: AsyncClient, refresh_token: str) -> Response:
    return await client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": refresh_token})


@pytest.mark.anyio
async def test_change_password_returns_a_token_pair_and_revokes_every_session(
    client: AsyncClient,
) -> None:
    first = (await sign_up(client))["tokens"]
    second = (await sign_in(client)).json()["tokens"]  # another device

    response = await change_password(client, first["access_token"])

    assert response.status_code == 200, response.text
    assert_same_shape(response.json(), load_example("auth/token_pair.json"))
    new = response.json()
    assert_error(await refresh(client, first["refresh_token"]), 401, "invalid_refresh_token")
    assert_error(await refresh(client, second["refresh_token"]), 401, "invalid_refresh_token")
    me = await client.get(f"{PREFIX}/users/me", headers=bearer(new["access_token"]))
    assert me.status_code == 200
    assert (await refresh(client, new["refresh_token"])).status_code == 200


@pytest.mark.anyio
async def test_after_changing_the_password_only_the_new_one_signs_in(client: AsyncClient) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    assert (await change_password(client, token)).status_code == 200

    assert (await sign_in(client, password=NEW_PASSWORD)).status_code == 200
    assert_error(await sign_in(client), 401, "invalid_credentials")


@pytest.mark.anyio
async def test_change_password_with_a_wrong_password_matches_the_example(
    client: AsyncClient,
) -> None:
    body = await sign_up(client)

    response = await change_password(
        client, body["tokens"]["access_token"], current_password="wrong-pass1"
    )

    assert assert_error(response, 403, "incorrect_password") == load_example(
        "auth/error_incorrect_password.json"
    )
    # Nothing changed: the old password and the refresh token still work.
    assert (await sign_in(client)).status_code == 200
    assert (await refresh(client, body["tokens"]["refresh_token"])).status_code == 200


@pytest.mark.anyio
async def test_wrong_passwords_on_change_password_are_blocked_with_429(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        assert_error(
            await change_password(client, token, current_password="wrong-pass1"),
            403,
            "incorrect_password",
        )

    blocked = await change_password(client, token)  # the right password

    assert_error(blocked, 429, "rate_limited")
    assert int(blocked.headers["retry-after"]) >= 1
    assert_error(await sign_in(client), 429, "rate_limited")


@pytest.mark.anyio
async def test_a_successful_change_password_clears_the_failures(
    client: AsyncClient, session: AsyncSession
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL - 1):
        await change_password(client, token, current_password="wrong-pass1")

    assert (await change_password(client, token)).status_code == 200

    count = await session.scalar(
        text("SELECT count(*) FROM login_attempts WHERE email = :e"), {"e": SIGNUP["email"]}
    )
    assert count == 0


@pytest.mark.anyio
async def test_change_password_to_the_same_password_names_new_password(
    client: AsyncClient,
) -> None:
    body = await sign_up(client)

    response = await change_password(client, body["tokens"]["access_token"], new_password=PASSWORD)

    error = assert_error(response, 422, "validation_error")
    assert error["error"]["fields"][0]["field"] == "new_password"
    assert (await refresh(client, body["tokens"]["refresh_token"])).status_code == 200


@pytest.mark.anyio
async def test_change_password_checks_the_current_password_before_the_same_password(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    response = await change_password(
        client, token, current_password="wrong-pass1", new_password="wrong-pass1"
    )

    assert_error(response, 403, "incorrect_password")


@pytest.mark.anyio
@pytest.mark.parametrize("new_password", ["short1", "onlyletters", "12345678"])
async def test_change_password_with_a_new_password_that_breaks_the_rule(
    client: AsyncClient, new_password: str
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    response = await change_password(client, token, new_password=new_password)

    error = assert_error(response, 422, "validation_error")
    assert error["error"]["fields"][0]["field"] == "new_password"


@pytest.mark.anyio
async def test_change_password_without_a_token_returns_not_authenticated(
    client: AsyncClient,
) -> None:
    response = await client.put(f"{PREFIX}/users/me/password", json=CHANGE_PASSWORD)

    assert_error(response, 401, "not_authenticated")


# delete account

DELETE_ACCOUNT = load_example("auth/delete_account_request.json")
USER_TABLES = ("users", "user_profiles", "refresh_tokens", "runs", "step_samples", "daily_activity")


async def delete_account(client: AsyncClient, token: str, **changes: str) -> Response:
    return await client.post(
        f"{PREFIX}/users/me/delete", json={**DELETE_ACCOUNT, **changes}, headers=bearer(token)
    )


async def seed_account_data(
    client: AsyncClient, session: AsyncSession, email: str, quest_title: str
) -> dict[str, Any]:
    """Sign up `email` and give the account a row in each table that references it."""
    body = await sign_up(client, email=email)
    token = body["tokens"]["access_token"]
    user_id = uuid.UUID(body["user"]["id"])
    saved = await client.put(
        f"{PREFIX}/users/me/profile",
        json=load_example("profile/profile_put_request.json"),
        headers=bearer(token),
    )
    assert saved.status_code == 200, saved.text
    now = datetime.now(UTC)
    quest = Quest(title=quest_title, description="")
    challenge = Challenge(
        title=quest_title,
        type="run",
        metric="steps",
        target_value=1000,
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=5),
        status="published",
    )
    quest.challenges.append(challenge)
    session.add(quest)
    run = make_run(user_id, challenge)
    run.samples.append(
        StepSample(
            health_record_id=f"record-{email}",
            start_time=now - timedelta(minutes=30),
            end_time=now - timedelta(minutes=20),
            steps=100,
        )
    )
    session.add(run)
    session.add(DailyActivity(user_id=user_id, day=now.date(), steps=1000, updated_at=now))
    await session.flush()
    return {"user_id": user_id, "tokens": body["tokens"]}


async def row_counts(session: AsyncSession, user_id: uuid.UUID) -> dict[str, int]:
    counts: dict[str, int] = {}
    queries = {
        "users": "SELECT count(*) FROM users WHERE id = :u",
        "user_profiles": "SELECT count(*) FROM user_profiles WHERE user_id = :u",
        "refresh_tokens": "SELECT count(*) FROM refresh_tokens WHERE user_id = :u",
        "runs": "SELECT count(*) FROM runs WHERE user_id = :u",
        "step_samples": (
            "SELECT count(*) FROM step_samples s JOIN runs r ON r.id = s.run_id "
            "WHERE r.user_id = :u"
        ),
        "daily_activity": "SELECT count(*) FROM daily_activity WHERE user_id = :u",
    }
    for table in USER_TABLES:
        counts[table] = (await session.scalar(text(queries[table]), {"u": user_id})) or 0
    return counts


@pytest.mark.anyio
async def test_delete_account_removes_every_row_of_the_user_and_only_theirs(
    client: AsyncClient, session: AsyncSession
) -> None:
    mine = await seed_account_data(client, session, SIGNUP["email"], "Mine")
    other = await seed_account_data(client, session, "other.runner@example.com", "Other")
    before_mine = await row_counts(session, mine["user_id"])
    before_other = await row_counts(session, other["user_id"])
    assert all(count >= 1 for count in before_mine.values())

    response = await delete_account(client, mine["tokens"]["access_token"])

    assert response.status_code == 204
    assert response.content == b""
    assert await row_counts(session, mine["user_id"]) == dict.fromkeys(USER_TABLES, 0)
    assert await row_counts(session, other["user_id"]) == before_other


@pytest.mark.anyio
async def test_after_delete_account_the_old_tokens_are_refused(client: AsyncClient) -> None:
    body = await sign_up(client)
    tokens = body["tokens"]
    assert (await delete_account(client, tokens["access_token"])).status_code == 204

    me = await client.get(f"{PREFIX}/users/me", headers=bearer(tokens["access_token"]))

    assert_error(me, 401, "invalid_token")
    assert_error(await refresh(client, tokens["refresh_token"]), 401, "invalid_refresh_token")
    assert_error(await sign_in(client), 401, "invalid_credentials")


@pytest.mark.anyio
async def test_delete_account_with_a_wrong_password_matches_the_example_and_deletes_nothing(
    client: AsyncClient, session: AsyncSession
) -> None:
    body = await sign_up(client)
    token = body["tokens"]["access_token"]

    response = await delete_account(client, token, current_password="wrong-pass1")

    assert assert_error(response, 403, "incorrect_password") == load_example(
        "auth/error_incorrect_password.json"
    )
    assert (await row_counts(session, uuid.UUID(body["user"]["id"])))["users"] == 1
    assert (await client.get(f"{PREFIX}/users/me", headers=bearer(token))).status_code == 200


@pytest.mark.anyio
async def test_wrong_passwords_on_delete_account_count_toward_the_sign_in_limit(
    client: AsyncClient, session: AsyncSession
) -> None:
    body = await sign_up(client)
    token = body["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL):
        assert_error(
            await delete_account(client, token, current_password="wrong-pass1"),
            403,
            "incorrect_password",
        )

    blocked = await delete_account(client, token)  # the right password

    assert_error(blocked, 429, "rate_limited")
    assert int(blocked.headers["retry-after"]) >= 1
    assert (await row_counts(session, uuid.UUID(body["user"]["id"])))["users"] == 1
    assert_error(await sign_in(client), 429, "rate_limited")


@pytest.mark.anyio
async def test_a_successful_delete_account_clears_the_failures_for_the_email(
    client: AsyncClient, session: AsyncSession
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]
    for _ in range(MAX_FAILED_SIGN_INS_PER_EMAIL - 1):
        await delete_account(client, token, current_password="wrong-pass1")

    assert (await delete_account(client, token)).status_code == 204

    count = await session.scalar(
        text("SELECT count(*) FROM login_attempts WHERE email = :e"), {"e": SIGNUP["email"]}
    )
    assert count == 0


@pytest.mark.anyio
async def test_delete_account_with_an_empty_password_is_a_validation_error(
    client: AsyncClient,
) -> None:
    token = (await sign_up(client))["tokens"]["access_token"]

    response = await delete_account(client, token, current_password="")

    body = assert_error(response, 422, "validation_error")
    assert body["error"]["fields"][0]["field"] == "current_password"


@pytest.mark.anyio
async def test_delete_account_without_a_token_returns_not_authenticated(
    client: AsyncClient,
) -> None:
    response = await client.post(f"{PREFIX}/users/me/delete", json=DELETE_ACCOUNT)

    assert_error(response, 401, "not_authenticated")


async def make_admin(session: AsyncSession, email: str) -> None:
    await session.execute(text("UPDATE users SET role = 'admin' WHERE email = :e"), {"e": email})


@pytest.mark.anyio
async def test_the_only_admin_cannot_delete_the_account(
    client: AsyncClient, session: AsyncSession
) -> None:
    body = await sign_up(client)
    await make_admin(session, SIGNUP["email"])

    response = await delete_account(client, body["tokens"]["access_token"])

    assert assert_error(response, 409, "last_admin") == load_example("auth/error_last_admin.json")
    assert (await row_counts(session, uuid.UUID(body["user"]["id"])))["users"] == 1


@pytest.mark.anyio
async def test_with_two_admins_one_can_delete_the_account(
    client: AsyncClient, session: AsyncSession
) -> None:
    first = await sign_up(client)
    await sign_up(client, email="second.admin@example.com")
    await make_admin(session, SIGNUP["email"])
    await make_admin(session, "second.admin@example.com")

    response = await delete_account(client, first["tokens"]["access_token"])

    assert response.status_code == 204
    admins = await session.scalar(text("SELECT count(*) FROM users WHERE role = 'admin'"))
    assert admins == 1


# delete account at the same time as a join


async def _seed_user(engine: AsyncEngine, role: str = "user") -> uuid.UUID:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        user = User(
            id=uuid.uuid4(),
            email=f"seed-{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password(PASSWORD),
            display_name="Seed",
            role=role,
            created_at=datetime.now(UTC),
        )
        session.add(user)
        await session.commit()
        return user.id


async def _seed_account_and_challenge(engine: AsyncEngine) -> tuple[uuid.UUID, int, int]:
    """Commit a user who knows their password and a published challenge; return their ids."""
    now = datetime.now(UTC)
    async with AsyncSession(engine, expire_on_commit=False) as session:
        quest = Quest(title="Delete race", description="")
        challenge = Challenge(
            title="Delete race",
            type="run",
            metric="steps",
            target_value=1000,
            starts_at=now + timedelta(days=1),
            ends_at=now + timedelta(days=20),
            status="published",
        )
        quest.challenges.append(challenge)
        session.add(quest)
        user = User(
            id=uuid.uuid4(),
            email=f"race-{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password(PASSWORD),
            display_name="Racer",
            created_at=now,
        )
        session.add(user)
        await session.commit()
        return user.id, challenge.id, quest.id


async def _delete_in_own_session(engine: AsyncEngine, user_id: uuid.UUID) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        runs = RunService(RunRepository(session))
        service = AuthService(session, AuthRepository(session), get_auth_settings(), runs)
        user = await session.get(User, user_id)
        assert user is not None
        try:
            await service.delete_account(
                user, DeleteAccountRequest(current_password=PASSWORD), "203.0.113.99"
            )
        except (LastAdminError, IncorrectPasswordError) as error:
            return error.code
        return "deleted"


async def _join_in_own_session(engine: AsyncEngine, user_id: uuid.UUID, challenge_id: int) -> str:
    async with AsyncSession(engine, expire_on_commit=False) as session:
        runs = RunService(RunRepository(session))
        challenges = ChallengeService(
            session,
            ChallengeRepository(session),
            MedalService(MedalRepository(session)),
            runs=runs,
        )
        enrollments = EnrollmentService(session, RunRepository(session), challenges.get)
        try:
            await enrollments.join(user_id, challenge_id)
        except IntegrityError:
            # The delete committed first, so the user the row points to is gone.
            return "user_gone"
        return "joined"


async def _clean_up_race(engine: AsyncEngine, user_id: uuid.UUID, quest_id: int) -> None:
    async with AsyncSession(engine) as session:
        await session.execute(delete(Quest).where(Quest.id == quest_id))
        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()


@pytest.mark.anyio
async def test_a_delete_and_a_join_of_the_same_user_at_once_do_not_deadlock(
    engine: AsyncEngine,
) -> None:
    user_id, challenge_id, quest_id = await _seed_account_and_challenge(engine)
    try:
        results = await asyncio.wait_for(
            asyncio.gather(
                _delete_in_own_session(engine, user_id),
                _join_in_own_session(engine, user_id, challenge_id),
                return_exceptions=True,
            ),
            timeout=15,
        )

        assert not any(isinstance(result, DBAPIError) for result in results), results
        assert results[0] == "deleted"
        assert results[1] in ("joined", "user_gone")
        async with AsyncSession(engine) as session:
            assert await session.get(User, user_id) is None
            runs = await session.scalar(
                text("SELECT count(*) FROM runs WHERE user_id = :u"), {"u": user_id}
            )
            assert runs == 0
    finally:
        await _clean_up_race(engine, user_id, quest_id)


@pytest.mark.anyio
async def test_a_delete_waits_while_another_request_of_the_user_holds_the_enrollment_lock(
    engine: AsyncEngine,
) -> None:
    """Deterministic: without the lock the delete would finish at once."""
    user_id, _, quest_id = await _seed_account_and_challenge(engine)
    try:
        async with AsyncSession(engine) as holder:
            await RunRepository(holder).lock_user_enrollments(user_id)
            delete_task = asyncio.create_task(_delete_in_own_session(engine, user_id))
            done, _ = await asyncio.wait({delete_task}, timeout=0.5)
            assert not done, "delete did not wait for the user's enrollment lock"
            await holder.rollback()

        assert await asyncio.wait_for(delete_task, timeout=5) == "deleted"
    finally:
        await _clean_up_race(engine, user_id, quest_id)


@pytest.mark.anyio
async def test_a_delete_with_the_old_password_is_refused_after_a_password_change(
    engine: AsyncEngine,
) -> None:
    """The delete checked the password, then waits for the refresh token lock while a change
    commits: the password it sent is wrong by then, so nothing is deleted."""
    user_id, _, quest_id = await _seed_account_and_challenge(engine)
    try:
        async with AsyncSession(engine, expire_on_commit=False) as holder:
            repository = AuthRepository(holder)
            stored = await holder.get(User, user_id)
            assert stored is not None
            await repository.lock_user_refresh_tokens(user_id)
            task = asyncio.ensure_future(_delete_in_own_session(engine, user_id))
            await _wait_until_a_session_waits_for_an_advisory_lock(engine, task)

            await repository.update_password_hash(stored, hash_password("newrun5medals"))
            await holder.commit()

        assert await asyncio.wait_for(task, timeout=10) == "incorrect_password"
        async with AsyncSession(engine) as session:
            assert await session.get(User, user_id) is not None
    finally:
        await _clean_up_race(engine, user_id, quest_id)
        async with AsyncSession(engine) as session:
            await session.execute(delete(LoginAttempt).where(LoginAttempt.ip == "203.0.113.99"))
            await session.commit()


@pytest.mark.anyio
async def test_the_last_two_admins_deleting_at_once_leave_one(engine: AsyncEngine) -> None:
    first = await _seed_user(engine, "admin")
    second = await _seed_user(engine, "admin")
    try:
        async with AsyncSession(engine) as holder:
            # Both deletes queue on the admin rows, so they really run one after the other.
            await AuthRepository(holder).lock_admins_and_count()
            tasks = asyncio.gather(
                _delete_in_own_session(engine, first),
                _delete_in_own_session(engine, second),
                return_exceptions=True,
            )
            await asyncio.sleep(1)
            await holder.rollback()
        results = await asyncio.wait_for(tasks, timeout=15)

        assert sorted(str(result) for result in results) == ["deleted", "last_admin"], results
        async with AsyncSession(engine) as session:
            admins = await session.scalar(
                text("SELECT count(*) FROM users WHERE id IN (:a, :b)"), {"a": first, "b": second}
            )
        assert admins == 1
    finally:
        async with AsyncSession(engine) as session:
            await session.execute(delete(User).where(User.id.in_([first, second])))
            await session.execute(delete(LoginAttempt).where(LoginAttempt.ip == "203.0.113.99"))
            await session.commit()


# the contract


def test_the_error_codes_this_file_produces_are_the_documented_ones() -> None:
    documented = set(error_codes(API_DOCS_DIR / "auth.md"))

    assert documented >= AUTH_MODULE_ERROR_CODES
    produced = {
        "email_taken",  # test_sign_up_with_a_taken_email_returns_email_taken
        "incorrect_password",  # test_change_email_with_a_wrong_password_matches_the_example
        "invalid_credentials",  # test_sign_in_with_a_wrong_password_matches_the_documented_example
        "invalid_refresh_token",  # test_refresh_with_an_unknown_token_is_rejected
        "invalid_token",  # test_users_me_with_a_garbage_token_returns_invalid_token
        "token_expired",  # test_users_me_with_an_expired_token_returns_token_expired
        "rate_limited",  # test_sign_in_is_blocked_after_five_failures_for_the_email
        "last_admin",  # test_the_only_admin_cannot_delete_the_account
    }
    assert produced == AUTH_MODULE_ERROR_CODES


@pytest.mark.anyio
async def test_consuming_a_refresh_token_twice_gives_it_to_one_caller(
    session: AsyncSession,
) -> None:
    now = datetime.now(UTC)
    user = User(
        id=uuid.uuid4(),
        email="atomic@example.com",
        password_hash="x",
        display_name="A",
        created_at=now,
    )
    repository = AuthRepository(session)
    await repository.add_user(user)
    await repository.add_refresh_token(
        RefreshToken(
            user_id=user.id,
            token_hash="a" * 64,
            expires_at=now + timedelta(days=1),
            created_at=now,
        )
    )

    first = await repository.consume_refresh_token("a" * 64, now)
    second = await repository.consume_refresh_token("a" * 64, now)

    assert first == user.id
    assert second is None
