from collections.abc import AsyncIterator

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel, Field

from app.core.errors import DomainError
from app.main import create_app


class ChallengeClosedError(DomainError):
    status_code = 409
    code = "challenge_closed"


class SignupBody(BaseModel):
    email: str
    password: str = Field(min_length=8)


def app_with_test_routes() -> FastAPI:
    app = create_app()

    @app.post("/test/domain-error")
    async def raise_domain_error() -> None:
        raise ChallengeClosedError("The challenge window has ended.")

    @app.post("/test/validate")
    async def validate(body: SignupBody) -> SignupBody:
        return body

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


@pytest.mark.anyio
async def test_validation_error_lists_fields(client: AsyncClient) -> None:
    response = await client.post("/test/validate", json={"password": "short"})

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["message"] == "Request body is invalid."
    assert {f["field"] for f in error["fields"]} == {"email", "password"}
    assert all(f["message"] for f in error["fields"])
