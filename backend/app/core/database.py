from collections.abc import AsyncIterator
from functools import lru_cache

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_database_settings


class Base(DeclarativeBase):
    """Base class for all database models."""


@lru_cache
def get_engine() -> AsyncEngine:
    return create_async_engine(get_database_settings().database_url)


@lru_cache
def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(get_engine(), expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency: one session per request.

    It does not commit. Services commit or roll back, as the layer rules in
    `docs/architecture.md` require; anything left uncommitted is discarded.
    """
    async with get_sessionmaker()() as session:
        yield session
