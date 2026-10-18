import uuid
from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.dialects.postgresql import ExcludeConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    # Type-only: SQLAlchemy resolves this relationship by class name at runtime.
    from app.modules.challenges.models import Challenge


class RunStatus(StrEnum):
    ACTIVE = "active"
    PAUSED = "paused"
    LEFT = "left"


class Run(Base):
    """A user's place in a challenge (an enrollment), and later the attempt built from step samples.

    The row keeps a copy of the challenge's `type` and window so the database itself can refuse
    two `active` enrollments of one user, in challenges of the same type, whose windows overlap
    (`[starts_at, ends_at)`, so one that starts when the other ends is fine). That is why a
    challenge's type and window cannot change once anyone has joined. A user has one row per
    challenge: leaving sets `left`, and joining again reuses the row.
    """

    __tablename__ = "runs"
    __table_args__ = (
        UniqueConstraint("user_id", "challenge_id", name="uq_runs_user_id_challenge_id"),
        CheckConstraint("status IN ('active', 'paused', 'left')", name="ck_runs_status_valid"),
        CheckConstraint("type IN ('run', 'swim', 'cycle')", name="ck_runs_type_valid"),
        CheckConstraint("ends_at > starts_at", name="ck_runs_window_valid"),
        ExcludeConstraint(
            ("user_id", "="),
            ("type", "="),
            (text("tstzrange(starts_at, ends_at)"), "&&"),
            where=text("status = 'active'"),
            using="gist",
            name="ex_runs_no_overlapping_active_challenges",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    challenge_id: Mapped[int] = mapped_column(ForeignKey("challenges.id", ondelete="CASCADE"))
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(
        String(10), default=RunStatus.ACTIVE.value, server_default=RunStatus.ACTIVE.value
    )
    type: Mapped[str] = mapped_column(String(10))
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
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
