"""add user profiles

Revision ID: 6fa1bc92a72b
Revises: c4d8a1e6f2b9
Create Date: 2026-10-26 22:16:49.018470
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "6fa1bc92a72b"
down_revision: str | Sequence[str] | None = "c4d8a1e6f2b9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create `user_profiles`: the optional personal details, one row per user. Nothing existing
    changes."""
    op.create_table(
        "user_profiles",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("first_name", sa.String(length=50), nullable=True),
        sa.Column("last_name", sa.String(length=50), nullable=True),
        sa.Column("birthday", sa.Date(), nullable=True),
        sa.Column("country", sa.String(length=2), nullable=True),
        sa.Column("state", sa.String(length=100), nullable=True),
        sa.Column("gender", sa.String(length=20), nullable=True),
        sa.Column("unit_system", sa.String(length=10), server_default="metric", nullable=False),
        sa.Column("height_cm", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("weight_kg", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "gender IN ('female', 'male', 'non_binary', 'prefer_not_to_say')",
            name=op.f("ck_user_profiles_gender_valid"),
        ),
        sa.CheckConstraint(
            "unit_system IN ('imperial', 'metric')", name=op.f("ck_user_profiles_unit_system_valid")
        ),
        sa.CheckConstraint(
            "height_cm BETWEEN 50.0 AND 272.0", name=op.f("ck_user_profiles_height_cm_in_range")
        ),
        sa.CheckConstraint(
            "weight_kg BETWEEN 20.0 AND 400.0", name=op.f("ck_user_profiles_weight_kg_in_range")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_user_profiles_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_user_profiles")),
    )


def downgrade() -> None:
    """Drop `user_profiles` and the details in it."""
    op.drop_table("user_profiles")
