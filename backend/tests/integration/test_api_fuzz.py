"""Fuzz every operation of the OpenAPI document and check the responses against it.

Schemathesis generates requests from `app.openapi()` and checks each response: no
server error, a documented status code, a documented content type and headers, and a
body that matches the documented schema. The requests go over real HTTP to the app
(uvicorn in a thread) on the test database: the app is async, so a shared test session
can't be used from a client's worker thread. Rows the fuzzer creates stay in the test
database, which is rebuilt at the start of every session.

The run is reproducible (`derandomize`) and bounded (`max_examples`). Skip it with
`pytest -m "not fuzz"`.
"""

import asyncio
import socket
import threading
import time
from collections.abc import AsyncIterator, Iterator
from typing import Any

import httpx
import pytest
import schemathesis
import uvicorn
from hypothesis import HealthCheck, settings
from schemathesis import Case
from schemathesis.schemas import BaseSchema
from schemathesis.specs.openapi.checks import positive_data_acceptance
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import get_settings
from app.core.database import Base, get_session
from app.core.storage import StorageNotConfiguredError, UploadedImage
from app.main import create_app
from app.modules.challenges.deps import get_storage

MAX_EXAMPLES = 30

pytestmark = pytest.mark.fuzz


class _NoStorage:
    """Stands in for Cloudinary: the fuzzer must never upload to the real account."""

    async def upload_image(self, *args: Any, **kwargs: Any) -> UploadedImage:
        raise StorageNotConfiguredError("Image storage is off in the fuzz run.")


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


async def _empty_all_tables(database_url: str) -> None:
    """The server's requests commit, so remove what the fuzzer created before other tests run.

    Without this its failed sign-ins would count toward the per-IP rate limit in the auth tests.
    """
    engine = create_async_engine(database_url, poolclass=NullPool)
    try:
        async with engine.begin() as connection:
            tables = ", ".join(f'"{table.name}"' for table in Base.metadata.sorted_tables)
            await connection.execute(text(f"TRUNCATE TABLE {tables} RESTART IDENTITY CASCADE"))
    finally:
        await engine.dispose()


@pytest.fixture(scope="module")
def live_server(database_url: str) -> Iterator[str]:
    """The app served on a local port, using the test database. Yields its API origin."""
    with pytest.MonkeyPatch.context() as env:
        env.setenv("JWT_SECRET", "a-fuzz-test-secret-that-is-long-enough-for-hs256")
        get_settings.cache_clear()

        # NullPool opens a connection per use, so the engine isn't tied to one event loop.
        engine = create_async_engine(database_url, poolclass=NullPool)
        sessions = async_sessionmaker(engine, expire_on_commit=False)

        async def session_for_request() -> AsyncIterator[AsyncSession]:
            async with sessions() as session:
                yield session

        app = create_app()
        app.dependency_overrides[get_session] = session_for_request
        app.dependency_overrides[get_storage] = _NoStorage
        port = _free_port()
        server = uvicorn.Server(
            uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning")
        )
        thread = threading.Thread(target=server.run, daemon=True)
        thread.start()
        deadline = time.monotonic() + 10
        while not server.started and time.monotonic() < deadline:
            time.sleep(0.05)
        assert server.started, "The test server did not start."
        try:
            yield f"http://127.0.0.1:{port}"
        finally:
            server.should_exit = True
            thread.join(timeout=10)
            asyncio.run(_empty_all_tables(database_url))
            get_settings.cache_clear()


@pytest.fixture(scope="module")
def api_schema(live_server: str) -> BaseSchema:
    return schemathesis.openapi.from_url(f"{live_server}/openapi.json")


schema = schemathesis.pytest.from_fixture("api_schema")


@schema.parametrize()
@settings(
    max_examples=MAX_EXAMPLES,
    derandomize=True,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture, HealthCheck.too_slow],
)
def test_responses_match_the_openapi_document(case: Case[Any]) -> None:
    case.call_and_validate()


@pytest.fixture(scope="module")
def admin_headers(live_server: str, database_url: str) -> dict[str, str]:
    """A signed-in admin, so the fuzzer gets past the guard of the admin routes."""
    body = {"email": "fuzz-admin@example.com", "password": "run4medals", "display_name": "Fuzz"}
    response = httpx.post(f"{live_server}/api/v1/auth/signup", json=body)
    assert response.status_code == 201, response.text

    async def make_admin() -> None:
        engine = create_async_engine(database_url, poolclass=NullPool)
        try:
            async with engine.begin() as connection:
                await connection.execute(text("UPDATE users SET role = 'admin'"))
        finally:
            await engine.dispose()

    asyncio.run(make_admin())
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


@schema.parametrize()
@settings(
    max_examples=MAX_EXAMPLES,
    derandomize=True,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture, HealthCheck.too_slow],
)
def test_responses_match_the_openapi_document_for_an_admin(
    case: Case[Any], admin_headers: dict[str, str]
) -> None:
    # Some rules compare two fields (`ends_at` after `starts_at`, the gold medal at the target)
    # or look inside a file; the schema can't say so, and the API rightly refuses such input.
    case.call_and_validate(headers=admin_headers, excluded_checks=[positive_data_acceptance])
