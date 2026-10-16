"""Fixtures for tests that need PostgreSQL.

Start the database first with `docker compose up -d --wait db`. The tests use
the database named in `TEST_DATABASE_URL` (environment or `.env`). Once per
session it is created if missing, its `public` schema is dropped and recreated,
and `alembic upgrade head` builds the schema. Every test then runs inside a
transaction that is rolled back afterwards.
"""

import asyncio
import re
from collections.abc import AsyncIterator, Iterator
from pathlib import Path

import asyncpg
import pytest
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from alembic import command
from app.core.config import get_settings
from app.core.database import get_session
from app.main import create_app

BACKEND_DIR = Path(__file__).resolve().parents[2]

# The session fixture wipes this database, so only accept names that are
# plainly throwaway test databases, and only simple identifiers.
_TEST_DATABASE_NAME = re.compile(r"^[A-Za-z0-9_]+_test$")


class _TestDatabaseSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    test_database_url: str


def _test_database_url() -> URL:
    try:
        raw_url = _TestDatabaseSettings().test_database_url  # type: ignore[call-arg]
    except ValidationError:
        pytest.fail(
            "TEST_DATABASE_URL is not set. Copy it from .env.example into .env, "
            "or set it in the environment.",
            pytrace=False,
        )
    url = make_url(raw_url)
    if not _TEST_DATABASE_NAME.fullmatch(url.database or ""):
        pytest.fail(
            "TEST_DATABASE_URL must name a database made of letters, digits and "
            f"underscores and ending in '_test' (the tests wipe it); got {url.database!r}.",
            pytrace=False,
        )
    if url.query:
        pytest.fail(
            "TEST_DATABASE_URL must not have query options; the test setup connects "
            "with host, port, user and password only.",
            pytrace=False,
        )
    return url


async def _connect(url: URL, database: str) -> asyncpg.Connection:
    try:
        return await asyncpg.connect(
            user=url.username,
            password=url.password,
            host=url.host,
            port=url.port,
            database=database,
        )
    except (OSError, asyncpg.PostgresError) as exc:
        pytest.fail(
            f"Cannot connect to PostgreSQL at {url.host}:{url.port} ({exc}). "
            "Start it with `docker compose up -d --wait db` and check TEST_DATABASE_URL.",
            pytrace=False,
        )


async def _reset_database(url: URL) -> None:
    """Create the test database if needed and leave it with an empty `public` schema."""
    server = await _connect(url, "postgres")
    try:
        exists = await server.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", url.database)
        if not exists:
            # Safe to interpolate: the name was checked against _TEST_DATABASE_NAME.
            await server.execute(f'CREATE DATABASE "{url.database}"')
    finally:
        await server.close()

    # Drop everything instead of running `alembic downgrade base`: a downgrade
    # fails when the database is stamped with a revision this branch doesn't have.
    database = await _connect(url, url.database or "")
    try:
        await database.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    finally:
        await database.close()


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    """Rebuild the test schema from the migrations, from scratch, once per session."""
    url = _test_database_url()
    asyncio.run(_reset_database(url))
    url_text = url.render_as_string(hide_password=False)

    with pytest.MonkeyPatch.context() as mp:
        # alembic/env.py reads the URL through app.core.config.Settings, which
        # also requires the S3 and JWT settings (#31 removes that need).
        mp.setenv("DATABASE_URL", url_text)
        mp.setenv("S3_ENDPOINT_URL", "http://localhost:8333")
        mp.setenv("S3_BUCKET", "medals-test")
        mp.setenv("JWT_SECRET", "test-only-secret")
        get_settings.cache_clear()
        command.upgrade(Config(str(BACKEND_DIR / "alembic.ini")), "head")
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
