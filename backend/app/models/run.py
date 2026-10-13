from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.challenge import Challenge


class Run(Base):
    """One attempt by a user at a challenge, built from synced step samples."""

    __tablename__ = "runs"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[str] = mapped_column(String(64), index=True)
    challenge_id: Mapped[int] = mapped_column(ForeignKey("challenges.id", ondelete="CASCADE"))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    total_steps: Mapped[int] = mapped_column(default=0)
    completed: Mapped[bool] = mapped_column(default=False)

    challenge: Mapped["Challenge"] = relationship(back_populates="runs")
    samples: Mapped[list["StepSample"]] = relationship(
        back_populates="run", cascade="all, delete-orphan"
    )


class StepSample(Base):
    """A step count read from Apple Health or Health Connect.

    `health_record_id` is the record's id on the device. It is unique per run,
    so a sample synced twice is never counted twice in the same run, while the
    same steps can still count toward two challenges running at the same time.
    """

    __tablename__ = "step_samples"
    __table_args__ = (
        CheckConstraint("steps >= 0", name="ck_step_samples_steps_non_negative"),
        CheckConstraint("end_time >= start_time", name="ck_step_samples_time_order"),
        UniqueConstraint("run_id", "health_record_id", name="uq_step_samples_run_record"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("runs.id", ondelete="CASCADE"))
    health_record_id: Mapped[str] = mapped_column(String(128))
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    steps: Mapped[int]

    run: Mapped[Run] = relationship(back_populates="samples")
