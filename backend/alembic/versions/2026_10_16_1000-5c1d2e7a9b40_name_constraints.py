"""name constraints after the naming convention

Revision ID: 5c1d2e7a9b40
Revises: 3afe18174cdf
Create Date: 2026-10-16 10:00:00.000000
"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "5c1d2e7a9b40"
down_revision: str | Sequence[str] | None = "3afe18174cdf"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# (table, name PostgreSQL chose, name from the naming convention)
RENAMES = [
    ("quests", "quests_pkey", "pk_quests"),
    ("challenges", "challenges_pkey", "pk_challenges"),
    ("medals", "medals_pkey", "pk_medals"),
    ("runs", "runs_pkey", "pk_runs"),
    ("step_samples", "step_samples_pkey", "pk_step_samples"),
    ("challenges", "challenges_quest_id_fkey", "fk_challenges_quest_id_quests"),
    ("medals", "medals_challenge_id_fkey", "fk_medals_challenge_id_challenges"),
    ("runs", "runs_challenge_id_fkey", "fk_runs_challenge_id_challenges"),
    ("step_samples", "step_samples_run_id_fkey", "fk_step_samples_run_id_runs"),
    ("medals", "medals_challenge_id_key", "uq_medals_challenge_id"),
]


def _rename(table: str, old: str, new: str) -> None:
    op.execute(f'ALTER TABLE "{table}" RENAME CONSTRAINT "{old}" TO "{new}"')


def upgrade() -> None:
    """Rename the constraints PostgreSQL named to their convention names."""
    for table, old, new in RENAMES:
        _rename(table, old, new)


def downgrade() -> None:
    """Restore the names PostgreSQL chose."""
    for table, old, new in reversed(RENAMES):
        _rename(table, new, old)
