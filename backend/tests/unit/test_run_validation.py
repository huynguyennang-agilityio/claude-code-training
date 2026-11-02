from datetime import UTC, datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app.modules.runs.schemas import StepHourIn, StepSampleIn
from app.modules.runs.validation import (
    MAX_STEPS_PER_HOUR,
    ChallengeRule,
    HourRule,
    RejectionReason,
    hour_counts,
    validate_run,
)

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


def test_a_sample_starting_before_hours_from_counts() -> None:
    rule = RULE.model_copy(update={"hours_from": START + timedelta(minutes=30)})

    result = validate_run([sample("a", 600, offset_minutes=29)], rule)

    assert result.counted_steps == 600


@pytest.mark.parametrize("offset_minutes", [30, 31])
def test_a_sample_starting_at_or_after_hours_from_is_ignored(offset_minutes: int) -> None:
    rule = RULE.model_copy(update={"hours_from": START + timedelta(minutes=30)})

    result = validate_run([sample("a", 600, offset_minutes=offset_minutes)], rule)

    assert result.counted_steps == 0
    assert [r.reason for r in result.rejected] == [RejectionReason.OUTSIDE_WINDOW]


def test_no_hours_from_means_no_cutoff() -> None:
    assert RULE.hours_from is None
    assert validate_run([sample("a", 600, offset_minutes=100)], RULE).counted_steps == 600


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


# hourly steps

NOON = datetime(2026, 11, 10, 12, 0, tzinfo=UTC)
HOUR = timedelta(hours=1)
HOUR_RULE = HourRule(
    starts_at=NOON - timedelta(days=9),
    ends_at=NOON + timedelta(days=20),
    counting_from=NOON - timedelta(days=5),
    hours_from=NOON - timedelta(days=4),
    session_started_at=NOON - timedelta(days=3),
    now=NOON,
)


def hour(start: datetime, steps: int = 100) -> StepHourIn:
    return StepHourIn(hour_start=start, steps=steps)


def test_an_hour_inside_every_bound_counts() -> None:
    assert hour_counts(hour(NOON - timedelta(hours=5)), HOUR_RULE)


@pytest.mark.parametrize(
    "field", ["starts_at", "counting_from", "hours_from", "session_started_at"]
)
def test_an_hour_before_any_lower_bound_is_ignored_and_the_bound_itself_counts(
    field: str,
) -> None:
    """The latest of the four bounds rules: move one of them past the others."""
    bound = NOON - timedelta(hours=2)
    rule = HOUR_RULE.model_copy(update={field: bound})
    if field == "starts_at":
        rule = rule.model_copy(update={"ends_at": NOON + timedelta(days=1)})

    assert not hour_counts(hour(bound - HOUR), rule)
    assert hour_counts(hour(bound), rule)


def test_the_last_representable_hour_is_in_the_future_not_an_error() -> None:
    last = datetime(9999, 12, 31, 23, tzinfo=UTC)
    assert not hour_counts(hour(last), HOUR_RULE)


def test_the_last_hour_is_the_ends_at_rounded_up_to_a_whole_hour() -> None:
    day_end = datetime(2026, 11, 20, 23, 59, 59, tzinfo=UTC)
    midnight = datetime(2026, 11, 21, tzinfo=UTC)
    now = datetime(2026, 12, 1, tzinfo=UTC)
    for ends_at in (day_end, midnight):
        rule = HOUR_RULE.model_copy(update={"ends_at": ends_at, "now": now})
        assert hour_counts(hour(datetime(2026, 11, 20, 23, tzinfo=UTC)), rule)
        assert not hour_counts(hour(midnight), rule)


def test_an_end_on_the_hour_is_not_rounded_further() -> None:
    ends_at = datetime(2026, 11, 20, 23, tzinfo=UTC)
    rule = HOUR_RULE.model_copy(update={"ends_at": ends_at, "now": ends_at + HOUR})

    assert hour_counts(hour(ends_at - HOUR), rule)
    assert not hour_counts(hour(ends_at), rule)


def test_an_end_in_another_timezone_is_rounded_in_utc() -> None:
    ends_at = datetime(2026, 11, 21, 6, 59, 59, tzinfo=timezone(timedelta(hours=7)))
    rule = HOUR_RULE.model_copy(
        update={"ends_at": ends_at, "now": datetime(2026, 12, 1, tzinfo=UTC)}
    )

    assert hour_counts(hour(datetime(2026, 11, 20, 23, tzinfo=UTC)), rule)
    assert not hour_counts(hour(datetime(2026, 11, 21, tzinfo=UTC)), rule)


def test_the_current_hour_counts_and_a_later_one_does_not() -> None:
    assert hour_counts(hour(NOON), HOUR_RULE)
    assert not hour_counts(hour(NOON + HOUR), HOUR_RULE)


def test_more_than_15000_steps_in_an_hour_are_ignored() -> None:
    start = NOON - timedelta(hours=1)

    assert hour_counts(hour(start, MAX_STEPS_PER_HOUR), HOUR_RULE)
    assert not hour_counts(hour(start, MAX_STEPS_PER_HOUR + 1), HOUR_RULE)
    assert hour_counts(hour(start, 0), HOUR_RULE)
