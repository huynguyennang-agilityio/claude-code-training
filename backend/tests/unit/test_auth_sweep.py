"""Every route declares who may call it, in ROUTE_ACCESS: `public`, `user` or `admin`.

A route that is not declared fails `test_every_route_declares_its_access`, so a new
route can't be added without saying who may call it. Because the guard is on each
route and not on a whole `/admin` router, this is what stops a write route from being
forgotten.

The sweep calls each route that is not public without an `Authorization` header and expects
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

For each `admin` route the sweep also calls it as a signed-in user whose role is
`user` and expects `403 forbidden`: the route must use `require_admin`, not only
`get_current_user`.
"""

import re
import uuid
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime
from typing import Literal

import pytest
from fastapi import APIRouter, Depends, FastAPI, WebSocket
from fastapi.routing import APIRoute, iter_route_contexts
from fastapi.security import HTTPBearer
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel

from app.core.database import get_session
from app.main import create_app
from app.modules.auth.deps import get_current_user, require_admin
from app.modules.auth.models import User, UserRole

Access = Literal["public", "user", "admin"]

# (method, path) -> who may call it. `public` is `none` in the `Auth` column of a
# `docs/api/` endpoints table (the four auth routes, plus the health probe, which has
# no contract); `user` is any signed-in user; `admin` needs `role = admin`.
ROUTE_ACCESS: dict[tuple[str, str], Access] = {
    ("GET", "/api/v1/health"): "public",
    ("POST", "/api/v1/auth/signup"): "public",
    ("POST", "/api/v1/auth/signin"): "public",
    ("POST", "/api/v1/auth/refresh"): "public",
    ("POST", "/api/v1/auth/signout"): "public",
    ("GET", "/api/v1/users/me"): "user",
    ("GET", "/api/v1/challenges"): "user",
    ("GET", "/api/v1/challenges/{challenge_id}"): "user",
    ("POST", "/api/v1/challenges"): "admin",
    ("PATCH", "/api/v1/challenges/{challenge_id}"): "admin",
    ("DELETE", "/api/v1/challenges/{challenge_id}"): "admin",
    ("POST", "/api/v1/challenges/{challenge_id}/publish"): "admin",
    ("POST", "/api/v1/challenges/{challenge_id}/unpublish"): "admin",
    ("POST", "/api/v1/challenges/{challenge_id}/join"): "user",
    ("POST", "/api/v1/challenges/{challenge_id}/pause"): "user",
    ("POST", "/api/v1/challenges/{challenge_id}/resume"): "user",
    ("POST", "/api/v1/challenges/{challenge_id}/leave"): "user",
    ("POST", "/api/v1/quests"): "admin",
    ("GET", "/api/v1/quests"): "user",
    ("POST", "/api/v1/images"): "admin",
}


def routes_with(
    access: Access, table: dict[tuple[str, str], Access] = ROUTE_ACCESS
) -> frozenset[tuple[str, str]]:
    return frozenset(route for route, declared in table.items() if declared == access)


PUBLIC_ROUTES = routes_with("public")
ADMIN_ROUTES = routes_with("admin")

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


def undeclared_routes(
    app: FastAPI, access: dict[tuple[str, str], Access] = ROUTE_ACCESS
) -> list[str]:
    """`METHOD path` for each route that has no entry in ROUTE_ACCESS."""
    return [f"{method} {path}" for method, path in api_routes(app) if (method, path) not in access]


def stale_declared_routes(
    app: FastAPI, access: dict[tuple[str, str], Access] = ROUTE_ACCESS
) -> list[tuple[str, str]]:
    """ROUTE_ACCESS entries that no longer match a route."""
    return sorted(set(access) - set(api_routes(app)))


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


def _a_normal_user() -> User:
    return User(
        id=uuid.UUID("00000000-0000-0000-0000-0000000000aa"),
        email="runner@example.com",
        password_hash="x",
        display_name="Lan Runner",
        role=UserRole.USER.value,
        created_at=datetime(2026, 10, 18, tzinfo=UTC),
    )


async def admin_routes_open_to_users(
    app: FastAPI, admin: frozenset[tuple[str, str]] = ADMIN_ROUTES
) -> list[str]:
    """`METHOD path: status code` for each admin route that does not answer a signed-in
    user (role `user`) with `403 forbidden`."""
    overrides = app.dependency_overrides
    previous = {key: overrides.get(key) for key in (get_session, get_current_user)}
    overrides[get_session] = _no_database
    overrides[get_current_user] = _a_normal_user
    found = []
    try:
        transport = ASGITransport(app=app, raise_app_exceptions=False)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for method, path in api_routes(app):
                if (method, path) not in admin:
                    continue
                response = await client.request(method, _concrete(path))
                code = _error_code(response.json()) if response.content else None
                if response.status_code != 403 or code != "forbidden":
                    found.append(f"{method} {path}: {response.status_code} {code}")
    finally:
        for key, value in previous.items():
            if value is None:
                overrides.pop(key, None)
            else:
                overrides[key] = value
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


def test_every_route_declares_its_access() -> None:
    assert undeclared_routes(create_app()) == [], (
        "Add each route to ROUTE_ACCESS as public, user or admin, and put the same "
        "requirement in the Auth column of its contract."
    )


def test_declared_routes_all_exist() -> None:
    assert stale_declared_routes(create_app()) == [], "Remove these from ROUTE_ACCESS."


@pytest.mark.anyio
async def test_every_admin_route_refuses_a_normal_user() -> None:
    assert await admin_routes_open_to_users(create_app()) == [], (
        "Guard these routes with `AdminUserDep` (`require_admin`), not only with the "
        "current-user dependency."
    )


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


def test_sweep_reports_undeclared_and_stale_routes() -> None:
    app = create_app()
    access: dict[tuple[str, str], Access] = {**ROUTE_ACCESS, ("POST", "/api/v1/gone"): "admin"}
    del access[("GET", "/api/v1/users/me")]

    assert undeclared_routes(app, access) == ["GET /api/v1/users/me"]
    assert stale_declared_routes(app, access) == [("POST", "/api/v1/gone")]


def _app_with_admin_routes() -> FastAPI:
    app = create_app()

    @app.get("/test/admin-ok", dependencies=[Depends(require_admin)])
    async def admin_ok() -> None:
        return None

    @app.post("/test/admin-write/{item_id}", dependencies=[Depends(require_admin)])
    async def admin_write(item_id: int, body: _Body) -> _Body:
        return body

    @app.get("/test/admin-user-only", dependencies=[Depends(get_current_user)])
    async def admin_user_only() -> None:
        return None

    @app.get("/test/admin-open")
    async def admin_open() -> None:
        return None

    return app


@pytest.mark.anyio
async def test_admin_sweep_reports_a_route_that_lets_a_normal_user_in() -> None:
    app = _app_with_admin_routes()
    admin = frozenset(
        {
            ("GET", "/test/admin-ok"),
            ("POST", "/test/admin-write/{item_id}"),
            ("GET", "/test/admin-user-only"),
            ("GET", "/test/admin-open"),
        }
    )

    found = await admin_routes_open_to_users(app, admin)

    assert found == [
        "GET /test/admin-open: 200 None",
        "GET /test/admin-user-only: 200 None",
    ]
    assert get_current_user not in app.dependency_overrides
    assert get_session not in app.dependency_overrides
