from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.medal import Medal
    from app.models.quest import Quest
    from app.models.run import Run


class Challenge(Base):
    """A step target that must be reached inside a time window."""

    __tablename__ = "challenges"
    __table_args__ = (
        CheckConstraint("target_steps > 0", name="ck_challenges_target_steps_positive"),
        CheckConstraint("ends_at > starts_at", name="ck_challenges_window_valid"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    quest_id: Mapped[int] = mapped_column(ForeignKey("quests.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(120))
    target_steps: Mapped[int]
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    quest: Mapped["Quest"] = relationship(back_populates="challenges")
    medal: Mapped["Medal | None"] = relationship(
        back_populates="challenge", cascade="all, delete-orphan"
    )
    runs: Mapped[list["Run"]] = relationship(back_populates="challenge")
