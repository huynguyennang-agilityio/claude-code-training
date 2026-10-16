"""Fixtures for tests that need PostgreSQL.

Start the database first with `docker compose up -d --wait db`. The tests use
the database named in `TEST_DATABASE_URL` (environment or `.env`): it is
created if missing, rebuilt from the Alembic migrations once per session, and
every test runs inside a transaction that is rolled back afterwards.
"""

import asyncio
from collections.abc import AsyncIterator, Iterator
from pathlib import Path

import asyncpg
import pytest
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from alembic import command
from app.core.config import get_settings
from app.core.database import get_session
from app.main import create_app

BACKEND_DIR = Path(__file__).resolve().parents[2]


class TestSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    test_database_url: str


def _test_database_url() -> URL:
    url = make_url(TestSettings().test_database_url)  # type: ignore[call-arg]
    # The session fixture drops every table, so refuse anything that isn't
    # clearly a throwaway test database (for example the dev database).
    if not (url.database or "").endswith("_test"):
        raise RuntimeError(
            f"TEST_DATABASE_URL must point to a database whose name ends in '_test', "
            f"got {url.database!r}."
        )
    return url


async def _create_database_if_missing(url: URL) -> None:
    conn = await asyncpg.connect(
        user=url.username,
        password=url.password,
        host=url.host,
        port=url.port,
        database="postgres",
    )
    try:
        exists = await conn.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", url.database)
        if not exists:
            await conn.execute(f'CREATE DATABASE "{url.database}"')
    finally:
        await conn.close()


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    """Build the test schema from the migrations, from scratch, once per session."""
    url = _test_database_url()
    asyncio.run(_create_database_if_missing(url))
    url_text = url.render_as_string(hide_password=False)

    with pytest.MonkeyPatch.context() as mp:
        # alembic/env.py reads the URL through app.core.config.Settings, which
        # also requires the S3 and JWT settings (#31 removes that need).
        mp.setenv("DATABASE_URL", url_text)
        mp.setenv("S3_ENDPOINT_URL", "http://localhost:8333")
        mp.setenv("S3_BUCKET", "medals-test")
        mp.setenv("JWT_SECRET", "test-only-secret")
        get_settings.cache_clear()
        config = Config(str(BACKEND_DIR / "alembic.ini"))
        command.downgrade(config, "base")
        command.upgrade(config, "head")
        yield url_text
    get_settings.cache_clear()


@pytest.fixture(scope="session")
async def engine(database_url: str) -> AsyncIterator[AsyncEngine]:
    engine = create_async_engine(database_url, poolclass=NullPool)
    yield engine
    await engine.dispose()


@pytest.fixture
async def session(engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    """A session whose commits only release savepoints; everything is rolled back."""
    async with engine.connect() as connection:
        transaction = await connection.begin()
        session = AsyncSession(
            bind=connection, join_transaction_mode="create_savepoint", expire_on_commit=False
        )
        try:
            yield session
        finally:
            await session.close()
            await transaction.rollback()


@pytest.fixture
async def client(session: AsyncSession) -> AsyncIterator[AsyncClient]:
    """An HTTP client whose requests use the test session."""
    app = create_app()

    async def override_get_session() -> AsyncIterator[AsyncSession]:
        yield session

    app.dependency_overrides[get_session] = override_get_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
