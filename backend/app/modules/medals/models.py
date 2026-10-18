from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    # Type-only: SQLAlchemy resolves this relationship by class name at runtime.
    from app.modules.challenges.models import Challenge


class MedalTier(StrEnum):
    BRONZE = "bronze"
    SILVER = "silver"
    GOLD = "gold"


# Lowest first. A challenge has at most one medal per tier, and a higher tier asks for more.
TIER_ORDER: tuple[MedalTier, ...] = (MedalTier.BRONZE, MedalTier.SILVER, MedalTier.GOLD)


class Medal(Base):
    """A checkpoint medal of a challenge: one per tier, earned at `threshold_value`
    (steps for a run, metres for a swim or a ride).

    The image itself lives in Cloudinary; only its delivery URL is stored here.
    """

    __tablename__ = "medals"
    __table_args__ = (
        UniqueConstraint("challenge_id", "tier", name="uq_medals_challenge_id_tier"),
        CheckConstraint("tier IN ('bronze', 'silver', 'gold')", name="ck_medals_tier_valid"),
        CheckConstraint("threshold_value > 0", name="ck_medals_threshold_value_positive"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    challenge_id: Mapped[int] = mapped_column(ForeignKey("challenges.id", ondelete="CASCADE"))
    tier: Mapped[str] = mapped_column(String(10))
    threshold_value: Mapped[int]
    name: Mapped[str] = mapped_column(String(120))
    image_url: Mapped[str] = mapped_column(String(2048))
    challenge: Mapped["Challenge"] = relationship(back_populates="medals")
