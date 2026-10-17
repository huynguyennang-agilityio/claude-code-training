import re
import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StringConstraints, field_validator

Email = Annotated[EmailStr, Field(max_length=254)]
DisplayName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]


def _lowercase(email: str) -> str:
    return email.lower()


class SignUpRequest(BaseModel):
    email: Email
    password: str = Field(min_length=8, max_length=128)
    display_name: DisplayName

    @field_validator("email")
    @classmethod
    def email_is_lowercase(cls, value: str) -> str:
        return _lowercase(value)

    @field_validator("password")
    @classmethod
    def password_has_letter_and_digit(cls, value: str) -> str:
        if not re.search(r"[^\W\d_]", value):
            raise ValueError("Password must contain at least one letter.")
        if not re.search(r"\d", value):
            raise ValueError("Password must contain at least one digit.")
        return value


class SignInRequest(BaseModel):
    email: Email
    # Only presence is checked: sign in must not reveal the password rules.
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def email_is_lowercase(cls, value: str) -> str:
        return _lowercase(value)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=512)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str
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
