from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError

from app.schemas.run import StepSampleIn
from app.services.run_validation import ChallengeRule, RejectionReason, validate_run

START = datetime(2026, 10, 1, tzinfo=UTC)
RULE = ChallengeRule(target_steps=1_000, starts_at=START, ends_at=START + timedelta(hours=2))


def sample(record_id: str, steps: int, offset_minutes: int = 0) -> StepSampleIn:
    start = START + timedelta(minutes=offset_minutes)
    return StepSampleIn(
        health_record_id=record_id,
        start_time=start,
        end_time=start + timedelta(minutes=10),
        steps=steps,
    )


def test_passes_when_target_reached() -> None:
    result = validate_run([sample("a", 600), sample("b", 400, offset_minutes=10)], RULE)

    assert result.passed
    assert result.counted_steps == 1_000
    assert result.rejected == []


def test_fails_below_target() -> None:
    result = validate_run([sample("a", 999)], RULE)

    assert not result.passed
    assert result.counted_steps == 999


def test_duplicate_in_same_sync_is_counted_once() -> None:
    result = validate_run([sample("a", 600), sample("a", 600)], RULE)

    assert result.counted_steps == 600
    assert [r.reason for r in result.rejected] == [RejectionReason.DUPLICATE]


def test_already_stored_record_is_rejected() -> None:
    result = validate_run([sample("a", 600)], RULE, known_record_ids={"a"})

    assert result.counted_steps == 0
    assert result.rejected[0].reason is RejectionReason.DUPLICATE


@pytest.mark.parametrize("offset_minutes", [-5, 115])
def test_samples_outside_window_are_rejected(offset_minutes: int) -> None:
    result = validate_run([sample("a", 2_000, offset_minutes=offset_minutes)], RULE)

    assert not result.passed
    assert result.rejected[0].reason is RejectionReason.OUTSIDE_WINDOW


def test_sample_rejects_end_before_start() -> None:
    with pytest.raises(ValidationError):
        StepSampleIn(health_record_id="a", start_time=START, end_time=START - timedelta(1), steps=1)


def test_sample_requires_timezone() -> None:
    with pytest.raises(ValidationError):
        StepSampleIn(
            health_record_id="a",
            start_time=datetime(2026, 10, 1),
            end_time=datetime(2026, 10, 1, 1),
            steps=1,
        )
