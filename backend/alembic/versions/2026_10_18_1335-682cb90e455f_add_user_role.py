"""add user role

Revision ID: 682cb90e455f
Revises: 75ce27cfe522
Create Date: 2026-10-18 13:35:31.136029
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "682cb90e455f"
down_revision: str | Sequence[str] | None = "75ce27cfe522"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema.

    Existing accounts become `user` through the column's server default. The check
    constraint is added by hand: autogenerate does not see it.
    """
    op.add_column(
        "users", sa.Column("role", sa.String(length=10), server_default="user", nullable=False)
    )
    op.create_check_constraint(op.f("ck_users_role_valid"), "users", "role IN ('user', 'admin')")


def downgrade() -> None:
    """Downgrade schema. Every account keeps working, but admins lose the role."""
    op.drop_constraint(op.f("ck_users_role_valid"), "users", type_="check")
    op.drop_column("users", "role")
