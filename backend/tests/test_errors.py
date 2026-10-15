from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import FastAPI, Query
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel, Field, field_validator

from app.core.errors import DomainError
from app.main import create_app


class ChallengeClosedError(DomainError):
    status_code = 409
    code = "challenge_closed"


class Item(BaseModel):
    n: int


class SignupBody(BaseModel):
    email: str
    password: str = Field(min_length=8)
    items: list[Item] = []

    @field_validator("password")
    @classmethod
    def password_has_digit(cls, value: str) -> str:
        if not any(char.isdigit() for char in value):
            raise ValueError("Password must contain at least one digit.")
        return value


def app_with_test_routes() -> FastAPI:
    app = create_app()

    @app.post("/test/domain-error")
    async def raise_domain_error() -> None:
        raise ChallengeClosedError("The challenge window has ended.")

    @app.post("/test/validate")
    async def validate(body: SignupBody) -> SignupBody:
        return body

    @app.get("/test/query")
    async def query(limit: int = Query(ge=1)) -> int:
        return limit

    return app


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app_with_test_routes())
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.mark.anyio
async def test_domain_error_uses_error_response_shape(client: AsyncClient) -> None:
    response = await client.post("/test/domain-error")

    assert response.status_code == 409
    assert response.json() == {
        "error": {
            "code": "challenge_closed",
            "message": "The challenge window has ended.",
            "fields": [],
        }
    }


def test_domain_error_subclass_must_set_code() -> None:
    with pytest.raises(TypeError, match="must set a string `code`"):

        class MissingCodeError(DomainError):
            pass


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("request_kwargs", "expected_fields"),
    [
        pytest.param({"json": {"password": "short"}}, {"email", "password"}, id="top-level"),
        pytest.param(
            {"json": {"email": "a@b.c", "password": "longpass1", "items": [{"n": "x"}]}},
            {"items.0.n"},
            id="nested",
        ),
        pytest.param({}, {"body"}, id="missing-body"),
        pytest.param(
            {"content": b"{bad", "headers": {"content-type": "application/json"}},
            {"body"},
            id="malformed-json",
        ),
    ],
)
async def test_body_validation_errors_name_their_fields(
    client: AsyncClient, request_kwargs: dict[str, Any], expected_fields: set[str]
) -> None:
    response = await client.post("/test/validate", **request_kwargs)

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["message"] == "Request is invalid."
    assert {f["field"] for f in error["fields"]} == expected_fields
    assert all(f["message"] for f in error["fields"])


@pytest.mark.anyio
async def test_query_validation_error_names_the_parameter(client: AsyncClient) -> None:
    response = await client.get("/test/query", params={"limit": 0})

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["message"] == "Request is invalid."
    assert [f["field"] for f in error["fields"]] == ["limit"]


@pytest.mark.anyio
async def test_custom_validator_message_has_no_pydantic_prefix(client: AsyncClient) -> None:
    response = await client.post(
        "/test/validate", json={"email": "a@b.c", "password": "no-digits-here"}
    )

    assert response.json()["error"]["fields"] == [
        {"field": "password", "message": "Password must contain at least one digit."}
    ]
