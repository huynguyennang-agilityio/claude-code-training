import re
import uuid
from datetime import datetime
from typing import Annotated, Any, Literal

from email_validator import EmailNotValidError, validate_email
from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
)


def _valid_email(value: str) -> str:
    """Check the address is well formed, without asking whether it is deliverable.

    `test_environment` accepts reserved names such as `.test`: an address with a valid
    shape is not rejected here, and sign in is just a lookup. The OpenAPI document says
    `format: email`, which allows them too.
    """
    try:
        return validate_email(value, check_deliverability=False, test_environment=True).normalized
    except EmailNotValidError as error:
        raise ValueError(str(error)) from None


Email = Annotated[
    str,
    AfterValidator(_valid_email),
    Field(max_length=254, json_schema_extra={"format": "email"}),
]
_CONTROL_CHARACTERS = re.compile(r"[\x00-\x1f\x7f]")

DisplayName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]


def _lowercase(email: str) -> str:
    return email.lower()


def _check_password_rule(value: str) -> str:
    """The contract's password rule beyond its length: a letter and a digit."""
    if not re.search(r"[A-Za-z]", value):
        raise ValueError("Password must contain at least one letter.")
    if not re.search(r"[0-9]", value):
        raise ValueError("Password must contain at least one digit.")
    return value


def _new_password_field() -> Any:
    return Field(
        min_length=8,
        max_length=128,
        # The validator enforces this and gives the messages; the schema states it
        # so the OpenAPI document describes what the API accepts. ASCII ranges, because
        # `\w` and `\d` mean different things in Python and in JSON Schema's ECMA-262
        # regular expressions, and the schema must mean the same to every reader.
        json_schema_extra={"allOf": [{"pattern": "[A-Za-z]"}, {"pattern": "[0-9]"}]},
    )


class SignUpRequest(BaseModel):
    email: Email
    password: str = _new_password_field()
    display_name: DisplayName = Field(json_schema_extra={"pattern": r"^[^\x00-\x1f\x7f]*$"})

    @field_validator("display_name", mode="before")
    @classmethod
    def display_name_has_no_control_characters(cls, value: object) -> object:
        """Reject control characters before whitespace is trimmed.

        PostgreSQL can't store NUL in text, and a name with line breaks or tabs in it is
        never wanted. The OpenAPI schema states the same rule as a `pattern`.
        """
        if isinstance(value, str) and _CONTROL_CHARACTERS.search(value):
            raise ValueError("Display name must not contain control characters.")
        return value

    @field_validator("email")
    @classmethod
    def email_is_lowercase(cls, value: str) -> str:
        return _lowercase(value)

    @field_validator("password")
    @classmethod
    def password_has_letter_and_digit(cls, value: str) -> str:
        return _check_password_rule(value)


class SignInRequest(BaseModel):
    email: Email
    # Only presence is checked: sign in must not reveal the password rules.
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def email_is_lowercase(cls, value: str) -> str:
        return _lowercase(value)


class ChangeEmailRequest(BaseModel):
    new_email: Email
    # Only presence is checked: the password rules are not repeated here.
    current_password: str = Field(min_length=1, max_length=128)

    @field_validator("new_email")
    @classmethod
    def new_email_is_lowercase(cls, value: str) -> str:
        return _lowercase(value)


class ChangePasswordRequest(BaseModel):
    # Only presence is checked: the password rules are not repeated here.
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = _new_password_field()

    @field_validator("new_password")
    @classmethod
    def new_password_has_letter_and_digit(cls, value: str) -> str:
        return _check_password_rule(value)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=512)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str
    role: Literal["user", "admin"]
    created_at: datetime


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"  # noqa: S105  (a scheme name, not a password)
    # Access token lifetime in seconds.
    expires_in: int


class AuthResponse(BaseModel):
    user: UserRead
    tokens: TokenPair
