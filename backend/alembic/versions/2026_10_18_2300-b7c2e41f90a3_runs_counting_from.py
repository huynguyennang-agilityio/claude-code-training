"""runs counting_from

Revision ID: b7c2e41f90a3
Revises: a3f4c1d2e5b6
Create Date: 2026-10-18 23:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7c2e41f90a3"
down_revision: str | Sequence[str] | None = "a3f4c1d2e5b6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add `runs.counting_from`: steps count toward an enrollment only from this time.

    Existing rows take their `joined_at`, which is what the rule would have been had it existed.
    The column stays nullable so a row can still be written without it; the service reads a null
    as `joined_at`. No data is lost.
    """
    op.add_column("runs", sa.Column("counting_from", sa.DateTime(timezone=True), nullable=True))
    op.execute("UPDATE runs SET counting_from = joined_at")


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("runs", "counting_from")
