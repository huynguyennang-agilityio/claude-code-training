"""step hours

Revision ID: f1b6c2d8a4e3
Revises: e5a9b3c7d1f2
Create Date: 2026-11-02 13:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f1b6c2d8a4e3"
down_revision: str | Sequence[str] | None = "e5a9b3c7d1f2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create `step_hours` (the steps of each hour of an enrollment) and add `runs.hours_from`
    (hourly steps count only from there).

    An enrollment that is active or paused when this runs gets `hours_from` at the next whole
    hour (UTC): from then on its steps come as hours, and the step samples stored before keep
    counting in `total_steps`. A left enrollment stays null; joining again sets it.
    """
    op.create_table(
        "step_hours",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("run_id", sa.Integer(), nullable=False),
        sa.Column("hour_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("steps", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("steps >= 0", name="ck_step_hours_steps_non_negative"),
        sa.ForeignKeyConstraint(
            ["run_id"], ["runs.id"], name="fk_step_hours_run_id_runs", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_step_hours"),
        sa.UniqueConstraint("run_id", "hour_start", name="uq_step_hours_run_hour"),
    )
    op.add_column("runs", sa.Column("hours_from", sa.DateTime(timezone=True), nullable=True))
    op.execute(
        "UPDATE runs SET hours_from = date_trunc('hour', now() AT TIME ZONE 'UTC') "
        "AT TIME ZONE 'UTC' + interval '1 hour' WHERE status IN ('active', 'paused')"
    )


def downgrade() -> None:
    """Drop `runs.hours_from` and `step_hours`, and the hourly steps in it. `total_steps` keeps
    the value it had."""
    op.drop_column("runs", "hours_from")
    op.drop_table("step_hours")
