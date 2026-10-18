"""runs become enrollments

Revision ID: a3f4c1d2e5b6
Revises: d9d1c3513a62
Create Date: 2026-10-18 20:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a3f4c1d2e5b6"
down_revision: str | Sequence[str] | None = "d9d1c3513a62"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

EXCLUSION = "ex_runs_no_overlapping_active_challenges"


def upgrade() -> None:
    """Upgrade schema.

    A run becomes the user's place in a challenge. Each existing row is `active`, takes the
    `type` and window of its challenge, and `started_at` becomes `joined_at`. `user_id` turns
    from text into a real foreign key to `users.id`: a row whose `user_id` is not the id of a
    user makes the migration fail, so nothing is deleted behind your back (the table held no
    real data when this was written). A user with two rows for one challenge, or two active
    overlapping rows, also fails it. Autogenerate sees none of this, so it is written by hand.
    """
    # The exclusion constraint compares plain columns with `=`, which needs this extension.
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    op.add_column(
        "runs", sa.Column("status", sa.String(length=10), server_default="active", nullable=False)
    )
    op.add_column("runs", sa.Column("type", sa.String(length=10), nullable=True))
    op.add_column("runs", sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("runs", sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True))
    op.execute(
        "UPDATE runs SET type = challenges.type, starts_at = challenges.starts_at, "
        "ends_at = challenges.ends_at FROM challenges WHERE challenges.id = runs.challenge_id"
    )
    op.alter_column("runs", "type", nullable=False)
    op.alter_column("runs", "starts_at", nullable=False)
    op.alter_column("runs", "ends_at", nullable=False)
    op.alter_column("runs", "started_at", new_column_name="joined_at")

    op.drop_index(op.f("ix_runs_user_id"), table_name="runs")
    op.alter_column(
        "runs",
        "user_id",
        existing_type=sa.String(length=64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="user_id::uuid",
        nullable=False,
    )
    op.create_foreign_key(
        op.f("fk_runs_user_id_users"), "runs", "users", ["user_id"], ["id"], ondelete="CASCADE"
    )
    op.create_unique_constraint(
        op.f("uq_runs_user_id_challenge_id"), "runs", ["user_id", "challenge_id"]
    )
    op.create_check_constraint(
        op.f("ck_runs_status_valid"), "runs", "status IN ('active', 'paused', 'left')"
    )
    op.create_check_constraint(
        op.f("ck_runs_type_valid"), "runs", "type IN ('run', 'swim', 'cycle')"
    )
    op.create_check_constraint(op.f("ck_runs_window_valid"), "runs", "ends_at > starts_at")
    op.execute(
        f"ALTER TABLE runs ADD CONSTRAINT {EXCLUSION} EXCLUDE USING gist "
        "(user_id WITH =, type WITH =, tstzrange(starts_at, ends_at) WITH &&) "
        "WHERE (status = 'active')"
    )


def downgrade() -> None:
    """Downgrade schema.

    **Loses data.** A paused or left enrollment becomes a plain row, and the status, the type
    and the window copy are dropped. `user_id` goes back to text. The `btree_gist` extension is
    left installed: other things may use it.
    """
    op.execute(f"ALTER TABLE runs DROP CONSTRAINT {EXCLUSION}")
    op.drop_constraint(op.f("ck_runs_window_valid"), "runs", type_="check")
    op.drop_constraint(op.f("ck_runs_type_valid"), "runs", type_="check")
    op.drop_constraint(op.f("ck_runs_status_valid"), "runs", type_="check")
    op.drop_constraint(op.f("uq_runs_user_id_challenge_id"), "runs", type_="unique")
    op.drop_constraint(op.f("fk_runs_user_id_users"), "runs", type_="foreignkey")
    op.alter_column(
        "runs",
        "user_id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(length=64),
        postgresql_using="user_id::text",
        nullable=False,
    )
    op.create_index(op.f("ix_runs_user_id"), "runs", ["user_id"], unique=False)
    op.alter_column("runs", "joined_at", new_column_name="started_at")
    op.drop_column("runs", "ends_at")
    op.drop_column("runs", "starts_at")
    op.drop_column("runs", "type")
    op.drop_column("runs", "status")
