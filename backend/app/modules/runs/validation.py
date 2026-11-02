"""Pure functions that decide whether a run completes a challenge.

Nothing here touches the database: callers pass in the samples, the ids
already stored and the challenge rule, and get a typed result back.
"""

from collections.abc import Iterable
from datetime import UTC, datetime, timedelta
from enum import StrEnum

from pydantic import BaseModel

from app.modules.runs.schemas import StepHourIn, StepSampleIn


class ChallengeRule(BaseModel):
    """What a sample must fit to count: the challenge window, the time the enrollment counts
    from (after a pause), and the latest end a sample may have (the server's now plus a margin)."""

    target_steps: int
    starts_at: datetime
    ends_at: datetime
    counting_from: datetime | None = None
    latest_end: datetime | None = None

    @property
    def earliest_start(self) -> datetime:
        return max(self.starts_at, self.counting_from or self.starts_at)

    @property
    def last_end(self) -> datetime:
        return min(self.ends_at, self.latest_end or self.ends_at)


class RejectionReason(StrEnum):
    DUPLICATE = "duplicate"
    OUTSIDE_WINDOW = "outside_window"


class RejectedSample(BaseModel):
    health_record_id: str
    reason: RejectionReason


class ValidationResult(BaseModel):
    passed: bool
    counted_steps: int
    accepted: list[StepSampleIn]
    rejected: list[RejectedSample]


def validate_run(
    samples: Iterable[StepSampleIn],
    rule: ChallengeRule,
    known_record_ids: Iterable[str] = (),
) -> ValidationResult:
    """Count the steps that are new and inside the challenge window and the counting period."""
    seen = set(known_record_ids)
    accepted: list[StepSampleIn] = []
    rejected: list[RejectedSample] = []

    for sample in samples:
        if sample.health_record_id in seen:
            reason = RejectionReason.DUPLICATE
        elif sample.start_time < rule.earliest_start or sample.end_time > rule.last_end:
            reason = RejectionReason.OUTSIDE_WINDOW
        else:
            seen.add(sample.health_record_id)
            accepted.append(sample)
            continue
        rejected.append(RejectedSample(health_record_id=sample.health_record_id, reason=reason))

    counted_steps = sum(sample.steps for sample in accepted)
    return ValidationResult(
        passed=counted_steps >= rule.target_steps,
        counted_steps=counted_steps,
        accepted=accepted,
        rejected=rejected,
    )


HOUR = timedelta(hours=1)
MAX_STEPS_PER_HOUR = 15_000


class HourRule(BaseModel):
    """What an hour of steps must fit to count for an enrollment: it starts at or after every
    `*_from` bound, ends within the challenge (rounded up to a whole hour) and not in the
    future, and holds a plausible number of steps."""

    starts_at: datetime
    ends_at: datetime
    counting_from: datetime
    hours_from: datetime
    session_started_at: datetime
    now: datetime

    @property
    def earliest_hour(self) -> datetime:
        return max(self.starts_at, self.counting_from, self.hours_from, self.session_started_at)

    @property
    def last_hour_end(self) -> datetime:
        """The challenge's end rounded up to a whole UTC hour (unchanged when it is one)."""
        end = self.ends_at.astimezone(UTC)
        floor = end.replace(minute=0, second=0, microsecond=0)
        return floor if floor == end else floor + HOUR


def hour_counts(hour: StepHourIn, rule: HourRule) -> bool:
    """Whether the hour counts for an enrollment that is active and tracks steps. The caller
    checks those two; an hour that fails any rule here is ignored, never an error."""
    return (
        # The future check comes first: `hour_start + HOUR` overflows for the last hour of 9999.
        hour.hour_start <= rule.now
        and hour.hour_start >= rule.earliest_hour
        and hour.hour_start + HOUR <= rule.last_hour_end
        and hour.steps <= MAX_STEPS_PER_HOUR
    )
