"""Every constraint name follows `app.core.database.NAMING_CONVENTION`."""

import asyncio
from pathlib import Path

from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from alembic import command

ALEMBIC_INI = Path(__file__).resolve().parents[2] / "alembic.ini"
INITIAL_REVISION = "3afe18174cdf"

# Prefix by `pg_constraint.contype`.
PREFIXES = {"p": "pk_", "f": "fk_", "u": "uq_", "c": "ck_"}

CONVENTION_NAMES = {
    "pk_quests",
    "pk_challenges",
    "pk_medals",
    "pk_runs",
    "pk_step_samples",
    "pk_users",
    "pk_refresh_tokens",
    "pk_login_attempts",
    "fk_challenges_quest_id_quests",
    "fk_medals_challenge_id_challenges",
    "fk_runs_challenge_id_challenges",
    "fk_step_samples_run_id_runs",
    "fk_refresh_tokens_user_id_users",
    "uq_users_email",
    "uq_refresh_tokens_token_hash",
    "uq_medals_challenge_id",
    "uq_step_samples_run_record",
    "ck_challenges_target_steps_positive",
    "ck_challenges_window_valid",
    "ck_step_samples_steps_non_negative",
    "ck_step_samples_time_order",
}

POSTGRES_NAMES = {
    "quests_pkey",
    "challenges_pkey",
    "medals_pkey",
    "runs_pkey",
    "step_samples_pkey",
    "challenges_quest_id_fkey",
    "medals_challenge_id_fkey",
    "runs_challenge_id_fkey",
    "step_samples_run_id_fkey",
    "medals_challenge_id_key",
    "uq_step_samples_run_record",
    "ck_challenges_target_steps_positive",
    "ck_challenges_window_valid",
    "ck_step_samples_steps_non_negative",
    "ck_step_samples_time_order",
}


async def _constraints(database_url: str) -> dict[str, str]:
    """Map each constraint name in `public` to its `contype`, except Alembic's own table."""
    engine = create_async_engine(database_url, poolclass=NullPool)
    try:
        async with engine.connect() as connection:
            rows = await connection.execute(
                text(
                    "SELECT conname, contype::text FROM pg_constraint "
                    "WHERE connamespace = 'public'::regnamespace AND contype IN ('p','f','u','c') "
                    "AND conrelid <> 'alembic_version'::regclass"
                )
            )
            return {name: contype for name, contype in rows}
    finally:
        await engine.dispose()


def test_constraint_names_follow_the_convention(database_url: str) -> None:
    constraints = asyncio.run(_constraints(database_url))

    assert set(constraints) == CONVENTION_NAMES
    assert all(name.startswith(PREFIXES[kind]) for name, kind in constraints.items())


def test_downgrade_restores_postgres_names_and_upgrade_renames_again(database_url: str) -> None:
    # This changes the shared session database and puts it back in `finally`, so
    # it must not run in parallel with other integration tests.
    config = Config(str(ALEMBIC_INI))

    # Back to the initial tables, before the constraint-naming revision (later revisions
    # are undone on the way, so adding one doesn't change what this checks).
    command.downgrade(config, INITIAL_REVISION)
    try:
        assert set(asyncio.run(_constraints(database_url))) == POSTGRES_NAMES
    finally:
        command.upgrade(config, "head")

    assert set(asyncio.run(_constraints(database_url))) == CONVENTION_NAMES
