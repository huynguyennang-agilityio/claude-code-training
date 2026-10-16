from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.security import HTTPBearer
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

    @app.get("/test/teapot")
    async def teapot() -> None:
        raise HTTPException(status_code=418, detail="I'm a teapot.")

    @app.get("/test/protected", dependencies=[Depends(HTTPBearer())])
    async def protected() -> None:
        return None

    @app.get("/test/boom")
    async def boom() -> None:
        raise RuntimeError("secret database password")

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


def error_of(response: Any) -> dict[str, Any]:
    return response.json()["error"]


@pytest.mark.anyio
async def test_unknown_route_returns_not_found(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 404
    assert error_of(response) == {
        "code": "not_found",
        "message": "Resource not found.",
        "fields": [],
    }


@pytest.mark.anyio
async def test_wrong_method_returns_method_not_allowed_with_allow_header(
    client: AsyncClient,
) -> None:
    response = await client.post("/api/v1/health")

    assert response.status_code == 405
    assert error_of(response)["code"] == "method_not_allowed"
    assert "GET" in response.headers["allow"]


@pytest.mark.anyio
async def test_other_http_exception_keeps_status_and_uses_http_error(
    client: AsyncClient,
) -> None:
    response = await client.get("/test/teapot")

    assert response.status_code == 418
    assert error_of(response)["code"] == "http_error"
    assert error_of(response)["message"] == "I'm a teapot."


@pytest.mark.anyio
async def test_missing_authorization_header_returns_not_authenticated(
    client: AsyncClient,
) -> None:
    response = await client.get("/test/protected")

    assert response.status_code == 401
    assert error_of(response)["code"] == "not_authenticated"
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.anyio
async def test_unexpected_exception_returns_internal_error_without_its_text(
    caplog: pytest.LogCaptureFixture,
) -> None:
    transport = ASGITransport(app=app_with_test_routes(), raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/test/boom")

    assert response.status_code == 500
    assert error_of(response)["code"] == "internal_error"
    assert "secret database password" not in response.text
    assert "secret database password" in caplog.text
