from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.security import (
    ExpiredTokenError,
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    hash_password_async,
    hash_refresh_token,
    new_refresh_token,
    verify_password,
    verify_password_async,
)

SECRET = "a-test-secret-that-is-long-enough-for-hs256"
NOW = datetime(2026, 10, 13, 9, 55, tzinfo=UTC)
USER_ID = "6f1c2b3a-8d4e-4f5a-9b6c-7d8e9f0a1b2c"


def test_password_hash_verifies_only_the_right_password() -> None:
    hashed = hash_password("run4medals")

    assert hashed != "run4medals"
    assert verify_password("run4medals", hashed)
    assert not verify_password("run4medal", hashed)


def test_password_hashes_are_salted() -> None:
    assert hash_password("run4medals") != hash_password("run4medals")


@pytest.mark.anyio
async def test_async_helpers_match_the_sync_ones() -> None:
    hashed = await hash_password_async("run4medals")

    assert verify_password("run4medals", hashed)
    assert await verify_password_async("run4medals", hashed)
    assert not await verify_password_async("wrong", hashed)


@pytest.mark.anyio
async def test_verifying_without_a_hash_fails() -> None:
    assert not await verify_password_async("run4medals", None)


def test_access_token_round_trips_the_user_id() -> None:
    token = create_access_token(USER_ID, SECRET, timedelta(minutes=15), NOW)

    assert decode_access_token(token, SECRET, NOW + timedelta(minutes=14)) == USER_ID


def test_access_token_carries_the_documented_claims() -> None:
    token = create_access_token(USER_ID, SECRET, timedelta(minutes=15), NOW)

    claims = jwt.decode(token, SECRET, algorithms=["HS256"], options={"verify_exp": False})
    assert claims == {
        "sub": USER_ID,
        "iat": int(NOW.timestamp()),
        "exp": int((NOW + timedelta(minutes=15)).timestamp()),
    }


def test_expired_access_token_is_reported_as_expired() -> None:
    token = create_access_token(USER_ID, SECRET, timedelta(minutes=15), NOW)

    with pytest.raises(ExpiredTokenError):
        decode_access_token(token, SECRET, NOW + timedelta(minutes=15))


def test_expiry_uses_the_real_clock_when_no_time_is_given() -> None:
    token = create_access_token(USER_ID, SECRET, timedelta(minutes=-1))

    with pytest.raises(ExpiredTokenError):
        decode_access_token(token, SECRET)


def test_token_signed_with_another_secret_is_invalid() -> None:
    token = create_access_token(
        USER_ID, "another-secret-of-similar-length-12345", timedelta(1), NOW
    )

    with pytest.raises(InvalidTokenError):
        decode_access_token(token, SECRET, NOW)


@pytest.mark.parametrize("token", ["", "not-a-jwt", "a.b.c", "eyJhbGciOiJIUzI1NiJ9.e30."])
def test_malformed_tokens_are_invalid(token: str) -> None:
    with pytest.raises(InvalidTokenError):
        decode_access_token(token, SECRET, NOW)


def test_token_with_another_algorithm_is_invalid() -> None:
    claims = {"sub": USER_ID, "exp": NOW + timedelta(minutes=5)}
    long_secret = SECRET * 2  # long enough for HS512, so only the algorithm differs
    other_algorithm = jwt.encode(claims, long_secret, algorithm="HS512")

    with pytest.raises(InvalidTokenError):
        decode_access_token(other_algorithm, long_secret, NOW)


def test_unsigned_token_is_invalid() -> None:
    unsigned = jwt.encode({"sub": USER_ID, "exp": NOW + timedelta(minutes=5)}, "", algorithm="none")

    with pytest.raises(InvalidTokenError):
        decode_access_token(unsigned, SECRET, NOW)


@pytest.mark.parametrize("missing", ["sub", "exp"])
def test_token_without_a_required_claim_is_invalid(missing: str) -> None:
    claims = {"sub": USER_ID, "exp": NOW + timedelta(minutes=5)}
    del claims[missing]
    token = jwt.encode(claims, SECRET, algorithm="HS256")

    with pytest.raises(InvalidTokenError):
        decode_access_token(token, SECRET, NOW)


def test_token_with_a_non_string_subject_is_invalid() -> None:
    token = jwt.encode({"sub": 42, "exp": NOW + timedelta(minutes=5)}, SECRET, algorithm="HS256")

    with pytest.raises(InvalidTokenError):
        decode_access_token(token, SECRET, NOW)


def test_refresh_tokens_are_random_and_long() -> None:
    first, second = new_refresh_token(), new_refresh_token()

    assert first != second
    assert len(first) >= 40


def test_refresh_token_hash_is_stable_and_hides_the_token() -> None:
    token = new_refresh_token()

    assert hash_refresh_token(token) == hash_refresh_token(token)
    assert len(hash_refresh_token(token)) == 64
    assert token not in hash_refresh_token(token)
    assert hash_refresh_token(token) != hash_refresh_token(new_refresh_token())
