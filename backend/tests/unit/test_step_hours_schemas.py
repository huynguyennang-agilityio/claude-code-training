"""The body rules of `PUT /runs/step-hours` (`docs/api/runs.md`)."""

from datetime import UTC, datetime
from typing import Any

import pytest
from pydantic import ValidationError

from app.core.errors import fields_from_validation_error
from app.modules.runs.schemas import StepHoursRequest
from tests.api_docs import load_example


def hours(*items: tuple[object, object]) -> dict[str, Any]:
    return {"hours": [{"hour_start": start, "steps": steps} for start, steps in items]}


def fails(data: dict[str, Any]) -> dict[str, str]:
    with pytest.raises(ValidationError) as error:
        StepHoursRequest.model_validate(data)
    return {field.field: field.message for field in fields_from_validation_error(error.value)}


def test_the_documented_example_is_valid() -> None:
    StepHoursRequest.model_validate(load_example("runs/step_hours_request.json"))


def test_an_hour_is_converted_to_utc() -> None:
    request = StepHoursRequest.model_validate(hours(("2026-11-02T13:00:00+07:00", 5)))

    assert request.hours[0].hour_start == datetime(2026, 11, 2, 6, tzinfo=UTC)
    assert request.hours[0].hour_start.utcoffset() == UTC.utcoffset(None)


def test_a_half_hour_offset_is_on_the_hour_only_in_utc() -> None:
    assert StepHoursRequest.model_validate(hours(("2026-11-02T11:30:00+05:30", 5)))
    assert "hours.0.hour_start" in fails(hours(("2026-11-02T11:00:00+05:30", 5)))


@pytest.mark.parametrize(
    "start",
    [
        "2026-11-02T06:30:00Z",
        "2026-11-02T06:00:01Z",
        "2026-11-02T06:00:00.5Z",
        "2026-11-02T06:00:00",  # no timezone
        "not a date",
        20261102,
        1.5,
        None,
        True,
        "0001-01-01T00:00:00+01:00",  # before year 1 once in UTC
        "9999-12-31T23:30:00-01:00",  # after year 9999 once in UTC
    ],
)
def test_hour_start_must_be_the_start_of_a_utc_hour_as_text(start: object) -> None:
    assert "hours.0.hour_start" in fails(hours((start, 5)))


@pytest.mark.parametrize("steps", [-1, 2_147_483_648, None, "many", 1.5, True, False])
def test_steps_is_a_whole_number_in_range(steps: object) -> None:
    assert "hours.0.steps" in fails(hours(("2026-11-02T06:00:00Z", steps)))


def test_steps_may_be_zero_or_the_largest_value_and_above_15000() -> None:
    request = StepHoursRequest.model_validate(
        hours(("2026-11-02T06:00:00Z", 0), ("2026-11-02T07:00:00Z", 2_147_483_647))
    )

    assert [item.steps for item in request.hours] == [0, 2_147_483_647]


def test_the_same_hour_twice_is_refused_even_in_two_timezones() -> None:
    data = hours(("2026-11-02T06:00:00Z", 1), ("2026-11-02T13:00:00+07:00", 2))

    assert fails(data) == {"body": "Send each hour once."}


def hour_list(count: int) -> dict[str, Any]:
    return {
        "hours": [
            {"hour_start": f"2026-01-{1 + n // 24:02d}T{n % 24:02d}:00:00Z", "steps": 1}
            for n in range(count)
        ]
    }


@pytest.mark.parametrize("count", [0, 745])
def test_fewer_than_one_or_more_than_744_hours_are_refused(count: int) -> None:
    assert "hours" in fails(hour_list(count))


def test_744_hours_are_accepted() -> None:
    assert len(StepHoursRequest.model_validate(hour_list(744)).hours) == 744
