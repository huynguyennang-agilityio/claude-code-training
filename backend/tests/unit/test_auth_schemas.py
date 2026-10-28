import pytest
from pydantic import BaseModel, ValidationError

from app.modules.auth.schemas import (
    AuthResponse,
    RefreshTokenRequest,
    SignInRequest,
    SignUpRequest,
    TokenPair,
    UserRead,
)
from tests.api_docs import load_example


def messages(error: ValidationError) -> list[tuple[str, str]]:
    return [(str(item["loc"][0]), item["msg"]) for item in error.errors()]


def test_documented_requests_are_valid() -> None:
    signup = SignUpRequest.model_validate(load_example("auth/signup_request.json"))
    signin = SignInRequest.model_validate(load_example("auth/signin_request.json"))
    refresh = RefreshTokenRequest.model_validate(load_example("auth/refresh_token_request.json"))

    assert signup.email == "runner@example.com"
    assert signin.email == "runner@example.com"
    assert refresh.refresh_token


@pytest.mark.parametrize("name", ["token_pair", "user", "auth_response"])
def test_documented_responses_round_trip_through_the_schemas(name: str) -> None:
    example = load_example(f"auth/{name}.json")
    schemas: dict[str, type[BaseModel]] = {
        "token_pair": TokenPair,
        "user": UserRead,
        "auth_response": AuthResponse,
    }
    schema = schemas[name]

    assert schema.model_validate(example).model_dump(mode="json") == example


def test_signup_lowercases_the_email_and_trims_the_display_name() -> None:
    request = SignUpRequest(
        email="Runner@Example.COM", password="run4medals", display_name="  Lan Runner  "
    )

    assert request.email == "runner@example.com"
    assert request.display_name == "Lan Runner"


@pytest.mark.parametrize(
    ("password", "message"),
    [
        ("runnerrun", "Value error, Password must contain at least one digit."),
        ("12345678", "Value error, Password must contain at least one letter."),
        ("éàüö1234", "Value error, Password must contain at least one letter."),
        ("password١٢٣", "Value error, Password must contain at least one digit."),
        ("run4me", "String should have at least 8 characters"),
        ("a1" * 65, "String should have at most 128 characters"),
    ],
)
def test_signup_password_rules(password: str, message: str) -> None:
    with pytest.raises(ValidationError) as error:
        SignUpRequest(email="a@b.co", password=password, display_name="A")

    assert messages(error.value) == [("password", message)]


@pytest.mark.parametrize("display_name", ["Lan\x00", "Lan\nRunner", "\tLan", "Lan\x7f"])
def test_signup_rejects_control_characters_in_the_display_name(display_name: str) -> None:
    with pytest.raises(ValidationError) as error:
        SignUpRequest(email="a@b.co", password="run4medals", display_name=display_name)

    assert messages(error.value) == [
        ("display_name", "Value error, Display name must not contain control characters.")
    ]


@pytest.mark.parametrize("display_name", ["", "   ", "x" * 51])
def test_signup_rejects_a_bad_display_name(display_name: str) -> None:
    with pytest.raises(ValidationError) as error:
        SignUpRequest(email="a@b.co", password="run4medals", display_name=display_name)

    assert [field for field, _ in messages(error.value)] == ["display_name"]


@pytest.mark.parametrize("email", ["", "runner", "runner@", "@example.com", "a b@example.com"])
def test_email_must_be_valid(email: str) -> None:
    with pytest.raises(ValidationError):
        SignUpRequest(email=email, password="run4medals", display_name="A")
    with pytest.raises(ValidationError):
        SignInRequest(email=email, password="x")


@pytest.mark.parametrize("email", ["mk~@ye.test", "a@b.example", "runner+quest@sub.example.org"])
def test_email_with_a_reserved_but_well_formed_domain_is_accepted(email: str) -> None:
    assert SignInRequest(email=email, password="x").email == email


def test_email_is_at_most_254_characters() -> None:
    too_long = "a" * 64 + "@" + "b" * 63 + "." + "c" * 63 + "." + "d" * 63 + ".com"

    with pytest.raises(ValidationError):
        SignInRequest(email=too_long, password="x")


def test_signin_only_checks_that_a_password_is_present() -> None:
    assert SignInRequest(email="a@b.co", password="x").password == "x"
    with pytest.raises(ValidationError):
        SignInRequest(email="a@b.co", password="")


def test_token_type_is_always_bearer() -> None:
    assert TokenPair(access_token="a", refresh_token="r", expires_in=900).token_type == "bearer"
