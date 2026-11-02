"""add users session_started_at

Revision ID: e5a9b3c7d1f2
Revises: 6fa1bc92a72b
Create Date: 2026-11-02 12:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e5a9b3c7d1f2"
down_revision: str | Sequence[str] | None = "6fa1bc92a72b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add `users.session_started_at`: when the account's current session began (sign up or
    the latest sign-in). Existing accounts get their `created_at`, so no row is left empty."""
    op.add_column("users", sa.Column("session_started_at", sa.DateTime(timezone=True)))
    op.execute("UPDATE users SET session_started_at = created_at")
    op.alter_column("users", "session_started_at", nullable=False)


def downgrade() -> None:
    """Drop `users.session_started_at`. Nothing else depends on it."""
    op.drop_column("users", "session_started_at")
