from pathlib import Path

import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from alembic import command

ALEMBIC_INI = Path(__file__).resolve().parents[2] / "alembic.ini"


def test_models_match_the_migrated_schema(database_url: str) -> None:
    """`alembic check` fails if a model change ships without its migration."""
    command.check(Config(str(ALEMBIC_INI)))


@pytest.mark.anyio
async def test_test_database_is_at_the_latest_revision(engine: AsyncEngine) -> None:
    async with engine.connect() as connection:
        version = await connection.scalar(text("SELECT version_num FROM alembic_version"))

    head = ScriptDirectory.from_config(Config(str(ALEMBIC_INI))).get_current_head()
    assert version == head
