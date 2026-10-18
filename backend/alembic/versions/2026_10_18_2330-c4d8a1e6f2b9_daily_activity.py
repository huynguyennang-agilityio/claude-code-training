"""daily activity

Revision ID: c4d8a1e6f2b9
Revises: b7c2e41f90a3
Create Date: 2026-10-18 23:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c4d8a1e6f2b9"
down_revision: str | Sequence[str] | None = "b7c2e41f90a3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create `daily_activity`: one row per user and calendar day with the health figures the
    app synced. Nothing existing changes."""
    op.create_table(
        "daily_activity",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("steps", sa.Integer(), nullable=True),
        sa.Column("calories_kcal", sa.Integer(), nullable=True),
        sa.Column("distance_m", sa.Integer(), nullable=True),
        sa.Column("sleep_minutes", sa.Integer(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("steps >= 0", name="ck_daily_activity_steps_non_negative"),
        sa.CheckConstraint("calories_kcal >= 0", name="ck_daily_activity_calories_non_negative"),
        sa.CheckConstraint("distance_m >= 0", name="ck_daily_activity_distance_non_negative"),
        sa.CheckConstraint("sleep_minutes >= 0", name="ck_daily_activity_sleep_non_negative"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_daily_activity_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "day", name="pk_daily_activity"),
    )


def downgrade() -> None:
    """Drop `daily_activity` and the figures in it."""
    op.drop_table("daily_activity")
