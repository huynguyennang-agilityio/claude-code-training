"""add challenge catalog fields and medal tiers

Revision ID: d9d1c3513a62
Revises: 682cb90e455f
Create Date: 2026-10-18 13:40:39.041500
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d9d1c3513a62"
down_revision: str | Sequence[str] | None = "682cb90e455f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema.

    Existing challenges become `run` / `steps` / `solo` and keep working: they are
    `published`, and `target_steps` becomes `target_value`. A new challenge defaults
    to `draft`. Each existing medal becomes the `gold` medal of its challenge, earned
    at the challenge's target. Autogenerate sees none of the renames, check constraints
    or data changes below, so they are written by hand.
    """
    op.add_column(
        "challenges", sa.Column("type", sa.String(length=10), server_default="run", nullable=False)
    )
    op.add_column(
        "challenges",
        sa.Column("metric", sa.String(length=12), server_default="steps", nullable=False),
    )
    op.add_column(
        "challenges", sa.Column("mode", sa.String(length=10), server_default="solo", nullable=False)
    )
    op.add_column(
        "challenges", sa.Column("description_md", sa.Text(), server_default="", nullable=False)
    )
    op.add_column("challenges", sa.Column("terms_md", sa.Text(), server_default="", nullable=False))
    op.add_column("challenges", sa.Column("cover_image_url", sa.String(length=2048), nullable=True))
    op.add_column("challenges", sa.Column("city", sa.String(length=120), nullable=True))
    op.add_column("challenges", sa.Column("landmark", sa.String(length=120), nullable=True))
    # Existing challenges were live, so they start published; new ones default to draft.
    op.add_column(
        "challenges",
        sa.Column("status", sa.String(length=10), server_default="published", nullable=False),
    )
    op.alter_column("challenges", "status", server_default="draft")
    # Keep the values: rename the column and its check constraint.
    op.alter_column("challenges", "target_steps", new_column_name="target_value")
    op.drop_constraint(op.f("ck_challenges_target_steps_positive"), "challenges", type_="check")
    op.create_check_constraint(
        op.f("ck_challenges_target_value_positive"), "challenges", "target_value > 0"
    )
    op.create_check_constraint(
        op.f("ck_challenges_type_valid"), "challenges", "type IN ('run', 'swim', 'cycle')"
    )
    op.create_check_constraint(
        op.f("ck_challenges_metric_valid"), "challenges", "metric IN ('steps', 'distance_m')"
    )
    op.create_check_constraint(
        op.f("ck_challenges_metric_matches_type"),
        "challenges",
        "(type = 'run' AND metric = 'steps') "
        "OR (type IN ('swim', 'cycle') AND metric = 'distance_m')",
    )
    op.create_check_constraint(op.f("ck_challenges_mode_valid"), "challenges", "mode IN ('solo')")
    op.create_check_constraint(
        op.f("ck_challenges_status_valid"), "challenges", "status IN ('draft', 'published')"
    )

    op.add_column(
        "medals", sa.Column("tier", sa.String(length=10), server_default="gold", nullable=False)
    )
    op.alter_column("medals", "tier", server_default=None)
    op.add_column("medals", sa.Column("threshold_value", sa.Integer(), nullable=True))
    op.execute(
        "UPDATE medals SET threshold_value = challenges.target_value "
        "FROM challenges WHERE challenges.id = medals.challenge_id"
    )
    op.alter_column("medals", "threshold_value", nullable=False)
    op.drop_constraint(op.f("uq_medals_challenge_id"), "medals", type_="unique")
    op.create_unique_constraint(
        op.f("uq_medals_challenge_id_tier"), "medals", ["challenge_id", "tier"]
    )
    op.create_check_constraint(
        op.f("ck_medals_tier_valid"), "medals", "tier IN ('bronze', 'silver', 'gold')"
    )
    op.create_check_constraint(
        op.f("ck_medals_threshold_value_positive"), "medals", "threshold_value > 0"
    )


def downgrade() -> None:
    """Downgrade schema.

    **Loses data.** The old schema has one medal per challenge, so only the medal with
    the highest threshold of each challenge is kept. Everything the new columns hold
    (type, metric, mode, texts, cover, place, status) is dropped; a swim or a ride keeps
    its target as a `target_steps` number, which is wrong for it.
    """
    op.drop_constraint(op.f("ck_medals_threshold_value_positive"), "medals", type_="check")
    op.drop_constraint(op.f("ck_medals_tier_valid"), "medals", type_="check")
    op.drop_constraint(op.f("uq_medals_challenge_id_tier"), "medals", type_="unique")
    op.execute(
        "DELETE FROM medals WHERE id NOT IN ("
        "SELECT DISTINCT ON (challenge_id) id FROM medals "
        "ORDER BY challenge_id, threshold_value DESC, id DESC)"
    )
    op.create_unique_constraint(op.f("uq_medals_challenge_id"), "medals", ["challenge_id"])
    op.drop_column("medals", "threshold_value")
    op.drop_column("medals", "tier")

    op.drop_constraint(op.f("ck_challenges_status_valid"), "challenges", type_="check")
    op.drop_constraint(op.f("ck_challenges_mode_valid"), "challenges", type_="check")
    op.drop_constraint(op.f("ck_challenges_metric_matches_type"), "challenges", type_="check")
    op.drop_constraint(op.f("ck_challenges_metric_valid"), "challenges", type_="check")
    op.drop_constraint(op.f("ck_challenges_type_valid"), "challenges", type_="check")
    op.drop_constraint(op.f("ck_challenges_target_value_positive"), "challenges", type_="check")
    op.alter_column("challenges", "target_value", new_column_name="target_steps")
    op.create_check_constraint(
        op.f("ck_challenges_target_steps_positive"), "challenges", "target_steps > 0"
    )
    for column in (
        "status",
        "landmark",
        "city",
        "cover_image_url",
        "terms_md",
        "description_md",
        "mode",
        "metric",
        "type",
    ):
        op.drop_column("challenges", column)
