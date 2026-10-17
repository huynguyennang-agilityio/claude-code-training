"""Every route must require authentication unless it is listed in PUBLIC_ROUTES.

The sweep calls each route without an `Authorization` header and expects
`401 not_authenticated`. It fills path parameters with a placeholder and sends
no body: FastAPI runs a raising security dependency before it reports path or
body validation errors, so a guarded route still answers 401
(`test_sweep_reports_unprotected_routes` checks this).
"""

import re
from collections.abc import AsyncIterator

import pytest
from fastapi import APIRouter, Depends, FastAPI
from fastapi.routing import APIRoute, iter_route_contexts
from fastapi.security import HTTPBearer
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel

from app.core.database import get_session
from app.main import create_app

# (method, path) pairs anyone may call. Add the auth routes (signup, signin,
# refresh, signout) here when the auth module lands; nothing else without review.
PUBLIC_ROUTES: frozenset[tuple[str, str]] = frozenset({("GET", "/api/v1/health")})

_PATH_PARAM = re.compile(r"\{[^}]+\}")


def api_routes(app: FastAPI) -> list[tuple[str, str]]:
    """Every (method, path) the app serves through an API route.

    `app.routes` keeps an included router as one wrapper entry, so walk the
    route contexts instead: they carry each route's full path and methods.
    """
    return sorted(
        (method, context.path)
        for context in iter_route_contexts(app.routes)
        if isinstance(context.original_route, APIRoute) and context.path is not None
        for method in context.methods or ()
    )


def stale_public_routes(
    app: FastAPI, public: frozenset[tuple[str, str]] = PUBLIC_ROUTES
) -> list[tuple[str, str]]:
    """Allowlist entries that no longer match a route."""
    return sorted(public - set(api_routes(app)))


async def _no_database() -> AsyncIterator[None]:
    raise RuntimeError("The auth sweep must not reach the database.")
    yield  # pragma: no cover


async def unprotected_routes(
    app: FastAPI, public: frozenset[tuple[str, str]] = PUBLIC_ROUTES
) -> list[str]:
    """`METHOD path: status code` for each non-public route that answers an
    unauthenticated call with anything but `401 not_authenticated`."""
    app.dependency_overrides[get_session] = _no_database
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    found = []
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        for method, path in api_routes(app):
            if (method, path) in public:
                continue
            response = await client.request(method, _PATH_PARAM.sub("1", path))
            code = _error_code(response.json()) if response.content else None
            if response.status_code != 401 or code != "not_authenticated":
                found.append(f"{method} {path}: {response.status_code} {code}")
    return found


def _error_code(body: object) -> object:
    if isinstance(body, dict) and isinstance(body.get("error"), dict):
        return body["error"].get("code")
    return None


@pytest.mark.anyio
async def test_every_non_public_route_requires_authentication() -> None:
    assert await unprotected_routes(create_app()) == [], (
        "Guard these routes with the auth dependency, or add them to PUBLIC_ROUTES "
        "if they are meant to be public."
    )


def test_public_routes_all_exist() -> None:
    assert stale_public_routes(create_app()) == [], "Remove these from PUBLIC_ROUTES."


class _Body(BaseModel):
    name: str


def _app_with_sweep_test_routes() -> FastAPI:
    app = create_app()
    bearer = [Depends(HTTPBearer())]

    @app.get("/test/open/{item_id}")
    async def open_read(item_id: int) -> int:
        return item_id

    @app.post("/test/open-write")
    async def open_write(body: _Body) -> _Body:
        return body

    @app.get("/test/guarded/{item_id}", dependencies=bearer)
    async def guarded_read(item_id: int) -> int:
        return item_id

    @app.post("/test/guarded-write/{item_id}", dependencies=bearer)
    async def guarded_write(item_id: int, body: _Body) -> _Body:
        return body

    # Module routers are included with a prefix; the sweep must see inside them.
    included = APIRouter(prefix="/api/v1/test")

    @included.get("/included-open")
    async def included_open() -> None:
        return None

    app.include_router(included)
    return app


@pytest.mark.anyio
async def test_sweep_reports_unprotected_routes() -> None:
    found = await unprotected_routes(_app_with_sweep_test_routes())

    assert found == [
        "GET /api/v1/test/included-open: 200 None",
        "GET /test/open/{item_id}: 200 None",
        "POST /test/open-write: 422 validation_error",
    ]


def test_sweep_reports_stale_public_routes() -> None:
    public = PUBLIC_ROUTES | {("POST", "/api/v1/gone")}

    assert stale_public_routes(create_app(), public) == [("POST", "/api/v1/gone")]
