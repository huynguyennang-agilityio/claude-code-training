"""Each implemented row of the "Error codes" table in `docs/api/auth.md` is served.

The table drives the test: a new row must be added to `IMPLEMENTED` here (with a way to
trigger it without a database) or to `AUTH_MODULE_ERROR_CODES`, whose codes
`tests/integration/test_auth_api.py` triggers through the real endpoints, so a documented
code can't be forgotten.
"""

from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import HTTPBearer
from httpx import ASGITransport, AsyncClient, Response
from pydantic import BaseModel, Field, field_validator

from app.core.errors import ErrorResponse
from app.main import create_app
from app.modules.auth.service import ForbiddenError
from tests.api_docs import API_DOCS_DIR, AUTH_MODULE_ERROR_CODES, error_codes, load_example

# code -> (method, path, status). The routes under /test are added by `app_under_test`.
IMPLEMENTED: dict[str, tuple[str, str, int]] = {
    "validation_error": ("POST", "/test/validate", 422),
    "not_authenticated": ("GET", "/test/protected", 401),
    "forbidden": ("GET", "/test/forbidden", 403),
    "not_found": ("GET", "/api/v1/nope", 404),
    "method_not_allowed": ("POST", "/api/v1/health", 405),
    "http_error": ("GET", "/test/teapot", 418),
    "internal_error": ("GET", "/test/boom", 500),
}


class _SignupBody(BaseModel):
    email: str
    password: str = Field(min_length=8)

    @field_validator("password")
    @classmethod
    def password_has_digit(cls, value: str) -> str:
        if not any(char.isdigit() for char in value):
            raise ValueError("Password must contain at least one digit.")
        return value


def app_under_test() -> FastAPI:
    app = create_app()

    @app.post("/test/validate")
    async def validate(body: _SignupBody) -> _SignupBody:
        return body

    @app.get("/test/protected", dependencies=[Depends(HTTPBearer())])
    async def protected() -> None:
        return None

    @app.get("/test/forbidden")
    async def forbidden() -> None:
        raise ForbiddenError("This action needs an admin.")

    @app.get("/test/teapot")
    async def teapot() -> None:
        raise HTTPException(status_code=418, detail="I'm a teapot.")

    @app.get("/test/boom")
    async def boom() -> None:
        raise RuntimeError("secret database password")

    return app


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app_under_test(), raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


async def trigger(client: AsyncClient, code: str) -> Response:
    method, path, _ = IMPLEMENTED[code]
    body = {"email": "runner@example.com", "password": "runnerrun"} if method == "POST" else None
    return await client.request(method, path, json=body if path == "/test/validate" else None)


def test_every_documented_code_is_tested_here_or_in_the_auth_api_tests() -> None:
    documented = error_codes(API_DOCS_DIR / "auth.md")

    assert sorted(documented) == sorted(set(IMPLEMENTED) | AUTH_MODULE_ERROR_CODES)
    assert not set(IMPLEMENTED) & AUTH_MODULE_ERROR_CODES


@pytest.mark.anyio
@pytest.mark.parametrize("code", sorted(IMPLEMENTED))
async def test_error_has_the_documented_status_code_and_shape(
    client: AsyncClient, code: str
) -> None:
    response = await trigger(client, code)

    assert response.status_code == IMPLEMENTED[code][2]
    body = ErrorResponse.model_validate(response.json())
    assert body.error.code == code
    assert_same_shape(response.json(), load_example("auth/error_invalid_credentials.json"))


@pytest.mark.anyio
async def test_validation_error_matches_the_documented_example(client: AsyncClient) -> None:
    response = await trigger(client, "validation_error")

    assert response.json() == load_example("auth/error_validation.json")


def assert_same_shape(actual: Any, example: Any) -> None:
    """Same keys at each level and the same JSON type for each value; `fields` items
    are compared by key only, because an empty example list holds no items."""
    assert set(actual) == set(example) == {"error"}
    error, expected = actual["error"], example["error"]
    assert set(error) == set(expected) == {"code", "message", "fields"}
    assert isinstance(error["code"], str)
    assert isinstance(error["message"], str)
    assert isinstance(error["fields"], list)
    for item in error["fields"]:
        assert set(item) == {"field", "message"}
