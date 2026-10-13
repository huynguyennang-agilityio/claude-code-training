"""Pure functions that decide whether a run completes a challenge.

Nothing here touches the database: callers pass in the samples, the ids
already stored and the challenge rule, and get a typed result back.
"""

from collections.abc import Iterable
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel

from app.schemas.run import StepSampleIn


class ChallengeRule(BaseModel):
    target_steps: int
    starts_at: datetime
    ends_at: datetime


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
    """Count the steps that are new and inside the challenge window."""
    seen = set(known_record_ids)
    accepted: list[StepSampleIn] = []
    rejected: list[RejectedSample] = []

    for sample in samples:
        if sample.health_record_id in seen:
            reason = RejectionReason.DUPLICATE
        elif sample.start_time < rule.starts_at or sample.end_time > rule.ends_at:
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
