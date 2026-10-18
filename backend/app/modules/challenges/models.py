from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    # Type-only: SQLAlchemy resolves these relationships by class name at runtime.
    from app.modules.medals.models import Medal
    from app.modules.runs.models import Run


class ChallengeType(StrEnum):
    RUN = "run"
    SWIM = "swim"
    CYCLE = "cycle"


class ChallengeMetric(StrEnum):
    """What a challenge counts: steps for a run, metres for a swim or a ride."""

    STEPS = "steps"
    DISTANCE_M = "distance_m"


class ChallengeMode(StrEnum):
    """Solo is the only mode; team and rank are planned."""

    SOLO = "solo"


class ChallengeStatus(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"


# The metric a type counts. The database checks the same pairs.
METRIC_FOR_TYPE: dict[ChallengeType, ChallengeMetric] = {
    ChallengeType.RUN: ChallengeMetric.STEPS,
    ChallengeType.SWIM: ChallengeMetric.DISTANCE_M,
    ChallengeType.CYCLE: ChallengeMetric.DISTANCE_M,
}


def _one_of(column: str, values: type[StrEnum]) -> str:
    return f"{column} IN ({', '.join(repr(value.value) for value in values)})"


class Quest(Base):
    """A themed group of challenges. Hidden from the mobile app for now: every
    challenge belongs to one, and a default quest holds those created without one."""

    __tablename__ = "quests"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    challenges: Mapped[list["Challenge"]] = relationship(
        back_populates="quest", cascade="all, delete-orphan"
    )


class Challenge(Base):
    """A goal to reach inside a time window: steps for a run, metres for a swim or a ride.

    A new challenge is a `draft`; only a `published` one is shown to users.
    """

    __tablename__ = "challenges"
    __table_args__ = (
        CheckConstraint("target_value > 0", name="ck_challenges_target_value_positive"),
        CheckConstraint("ends_at > starts_at", name="ck_challenges_window_valid"),
        CheckConstraint(_one_of("type", ChallengeType), name="ck_challenges_type_valid"),
        CheckConstraint(_one_of("metric", ChallengeMetric), name="ck_challenges_metric_valid"),
        CheckConstraint(
            "(type = 'run' AND metric = 'steps') "
            "OR (type IN ('swim', 'cycle') AND metric = 'distance_m')",
            name="ck_challenges_metric_matches_type",
        ),
        CheckConstraint(_one_of("mode", ChallengeMode), name="ck_challenges_mode_valid"),
        CheckConstraint(_one_of("status", ChallengeStatus), name="ck_challenges_status_valid"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    quest_id: Mapped[int] = mapped_column(ForeignKey("quests.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(120))
    type: Mapped[str] = mapped_column(
        String(10), default=ChallengeType.RUN.value, server_default=ChallengeType.RUN.value
    )
    metric: Mapped[str] = mapped_column(
        String(12), default=ChallengeMetric.STEPS.value, server_default=ChallengeMetric.STEPS.value
    )
    target_value: Mapped[int]
    mode: Mapped[str] = mapped_column(
        String(10), default=ChallengeMode.SOLO.value, server_default=ChallengeMode.SOLO.value
    )
    description_md: Mapped[str] = mapped_column(Text, default="", server_default="")
    terms_md: Mapped[str] = mapped_column(Text, default="", server_default="")
    cover_image_url: Mapped[str | None] = mapped_column(String(2048), default=None)
    city: Mapped[str | None] = mapped_column(String(120), default=None)
    landmark: Mapped[str | None] = mapped_column(String(120), default=None)
    status: Mapped[str] = mapped_column(
        String(10), default=ChallengeStatus.DRAFT.value, server_default=ChallengeStatus.DRAFT.value
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    quest: Mapped[Quest] = relationship(back_populates="challenges")
    medals: Mapped[list["Medal"]] = relationship(
        back_populates="challenge",
        cascade="all, delete-orphan",
        order_by="Medal.threshold_value",
    )
    runs: Mapped[list["Run"]] = relationship(back_populates="challenge")
