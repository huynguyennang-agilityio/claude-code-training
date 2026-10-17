"""Every route must require authentication unless it is listed in PUBLIC_ROUTES.

The sweep calls each route without an `Authorization` header and expects
`401 not_authenticated`. It fills path parameters with a placeholder that fits
their converter and sends no body: FastAPI runs a raising security dependency
before it reports path or body validation errors, so a guarded route still
answers 401 (`test_sweep_reports_unprotected_routes` checks this).

FastAPI resolves dependencies in declaration order. Declare the auth dependency
before anything that needs a database session: the sweep replaces the session
with one that raises, so a route that asks for a session first answers 500.

The sweep only calls HTTP API routes. Any other route (a websocket, a mounted
app, a plain Starlette route) fails `test_every_route_is_an_api_route` until it
gets its own auth test and is excluded on purpose.
"""

import re
from collections.abc import AsyncIterator, Callable

import pytest
from fastapi import APIRouter, Depends, FastAPI, WebSocket
from fastapi.routing import APIRoute, iter_route_contexts
from fastapi.security import HTTPBearer
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel

from app.core.database import get_session
from app.main import create_app

# (method, path) pairs anyone may call: routes marked `none` in the Auth column of
# a `docs/api/` endpoints table (the four auth routes), plus the health probe, which has
# no contract.
PUBLIC_ROUTES: frozenset[tuple[str, str]] = frozenset(
    {
        ("GET", "/api/v1/health"),
        ("POST", "/api/v1/auth/signup"),
        ("POST", "/api/v1/auth/signin"),
        ("POST", "/api/v1/auth/refresh"),
        ("POST", "/api/v1/auth/signout"),
    }
)

_PATH_PARAM = re.compile(r"\{\w+(?::(\w+))?\}")
_PLACEHOLDERS = {"uuid": "00000000-0000-0000-0000-000000000001", "float": "1.0"}


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


def unswept_routes(app: FastAPI) -> list[str]:
    """`Type path` for each route the sweep can't call, except FastAPI's docs pages."""
    docs = {app.openapi_url, app.docs_url, app.swagger_ui_oauth2_redirect_url, app.redoc_url}
    found = []
    for context in iter_route_contexts(app.routes):
        route = context.original_route
        path = context.path or getattr(route, "path", "?")
        if not isinstance(route, APIRoute) and path not in docs:
            found.append(f"{type(route).__name__} {path}")
    return sorted(found)


def stale_public_routes(
    app: FastAPI, public: frozenset[tuple[str, str]] = PUBLIC_ROUTES
) -> list[tuple[str, str]]:
    """Allowlist entries that no longer match a route."""
    return sorted(public - set(api_routes(app)))


async def _no_database() -> AsyncIterator[None]:
    raise RuntimeError("The auth sweep must not reach the database.")
    yield  # pragma: no cover


def _concrete(path: str) -> str:
    return _PATH_PARAM.sub(lambda m: _PLACEHOLDERS.get(m[1] or "", "1"), path)


async def unprotected_routes(
    app: FastAPI, public: frozenset[tuple[str, str]] = PUBLIC_ROUTES
) -> list[str]:
    """`METHOD path: status code` for each non-public route that answers an
    unauthenticated call with anything but `401 not_authenticated`."""
    overrides = app.dependency_overrides
    previous: Callable[..., object] | None = overrides.get(get_session)
    overrides[get_session] = _no_database
    found = []
    try:
        transport = ASGITransport(app=app, raise_app_exceptions=False)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for method, path in api_routes(app):
                if (method, path) in public:
                    continue
                response = await client.request(method, _concrete(path))
                code = _error_code(response.json()) if response.content else None
                if response.status_code != 401 or code != "not_authenticated":
                    found.append(f"{method} {path}: {response.status_code} {code}")
    finally:
        if previous is None:
            overrides.pop(get_session, None)
        else:
            overrides[get_session] = previous
    return found


def _error_code(body: object) -> object:
    if isinstance(body, dict) and isinstance(body.get("error"), dict):
        return body["error"].get("code")
    return None


@pytest.mark.anyio
async def test_every_non_public_route_requires_authentication() -> None:
    assert await unprotected_routes(create_app()) == [], (
        "Guard these routes with the auth dependency, or add them to PUBLIC_ROUTES "
        "if the contract marks them public. A 500 means the route asked for a "
        "database session before authentication: declare the auth dependency first."
    )


def test_every_route_is_an_api_route() -> None:
    assert unswept_routes(create_app()) == [], (
        "The auth sweep can't call these routes. Give each one its own auth test "
        "and exclude it here on purpose."
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

    @app.get("/test/guarded-uuid/{medal_id:uuid}", dependencies=bearer)
    async def guarded_uuid(medal_id: str) -> str:
        return medal_id

    @app.get("/test/session-first", dependencies=[Depends(get_session), *bearer])
    async def session_first() -> None:
        return None

    # Module routers are included with a prefix; the sweep must see inside them.
    included = APIRouter(prefix="/api/v1/test")

    @included.get("/included-open")
    async def included_open() -> None:
        return None

    @included.websocket("/live")
    async def live(websocket: WebSocket) -> None:
        await websocket.close()

    app.include_router(included)
    app.mount("/test/sub", FastAPI())
    return app


@pytest.mark.anyio
async def test_sweep_reports_unprotected_routes() -> None:
    app = _app_with_sweep_test_routes()

    found = await unprotected_routes(app)

    assert found == [
        "GET /api/v1/test/included-open: 200 None",
        "GET /test/open/{item_id}: 200 None",
        "GET /test/session-first: 500 internal_error",
        "POST /test/open-write: 422 validation_error",
    ]
    assert get_session not in app.dependency_overrides


def test_sweep_reports_routes_it_cannot_call() -> None:
    assert unswept_routes(_app_with_sweep_test_routes()) == [
        "APIWebSocketRoute /api/v1/test/live",
        "Mount /test/sub",
    ]


@pytest.mark.anyio
async def test_sweep_restores_an_existing_session_override() -> None:
    app = _app_with_sweep_test_routes()

    async def test_session() -> AsyncIterator[None]:
        yield None

    app.dependency_overrides[get_session] = test_session

    await unprotected_routes(app)

    assert app.dependency_overrides[get_session] is test_session


def test_sweep_reports_stale_public_routes() -> None:
    public = PUBLIC_ROUTES | {("POST", "/api/v1/gone")}

    assert stale_public_routes(create_app(), public) == [("POST", "/api/v1/gone")]
