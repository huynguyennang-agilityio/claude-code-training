"""Saving the daily figures, with the database mocked.

Replacing a row, the cascade on user delete and the table's checks are in
`tests/integration/test_daily_activity_api.py`.
"""

import uuid
from datetime import UTC, date, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from pydantic import ValidationError

from app.modules.runs.activity import ActivityService, FutureDayError
from app.modules.runs.models import DailyActivity
from app.modules.runs.repository import RunRepository
from app.modules.runs.schemas import DailyActivityIn, DailyActivityRequest

NOW = datetime(2026, 11, 3, 22, 0, tzinfo=UTC)
USER = uuid.UUID("00000000-0000-0000-0000-000000000001")


def day(when: str, **figures: int) -> DailyActivityIn:
    return DailyActivityIn.model_validate({"date": when, **figures})


def row(when: date, **figures: int | None) -> DailyActivity:
    values: dict[str, int | None] = {
        "steps": None,
        "calories_kcal": None,
        "distance_m": None,
        "sleep_minutes": None,
    }
    values.update(figures)
    return DailyActivity(user_id=USER, day=when, updated_at=NOW, **values)


def service(rows: list[DailyActivity]) -> tuple[ActivityService, AsyncMock, AsyncMock]:
    repository = MagicMock(spec=RunRepository)
    repository.replace_daily_activity = AsyncMock(return_value=rows)
    session = AsyncMock()
    return (
        ActivityService(session, repository, now=lambda: NOW),
        repository.replace_daily_activity,
        session.commit,
    )


@pytest.mark.anyio
async def test_each_day_is_written_and_the_result_lists_what_is_stored() -> None:
    stored = [
        row(date(2026, 11, 2), steps=8412, sleep_minutes=410),
        row(date(2026, 11, 3), steps=5),
    ]
    activity, replace, commit = service(stored)

    result = await activity.save_days(
        USER, [day("2026-11-02", steps=8412, sleep_minutes=410), day("2026-11-03", steps=5)]
    )

    assert [item.date for item in result.days] == [date(2026, 11, 2), date(2026, 11, 3)]
    assert result.days[0].sleep_minutes == 410
    assert result.days[1].calories_kcal is None
    rows = replace.await_args.args[1]
    assert rows[0] == {
        "day": date(2026, 11, 2),
        "steps": 8412,
        "calories_kcal": None,
        "distance_m": None,
        "sleep_minutes": 410,
    }
    assert replace.await_args.kwargs == {"now": NOW}
    commit.assert_awaited_once()


@pytest.mark.anyio
async def test_tomorrow_is_accepted_for_a_device_ahead_of_the_server() -> None:
    activity, _, _ = service([row(date(2026, 11, 4), steps=1)])

    result = await activity.save_days(USER, [day("2026-11-04", steps=1)])

    assert len(result.days) == 1


@pytest.mark.anyio
async def test_a_day_after_tomorrow_is_refused_and_nothing_is_written() -> None:
    activity, replace, commit = service([])

    with pytest.raises(FutureDayError) as error:
        await activity.save_days(USER, [day("2026-11-03", steps=1), day("2026-11-05", steps=1)])

    assert [field.field for field in error.value.fields or []] == ["body.days.1.date"]
    replace.assert_not_awaited()
    commit.assert_not_awaited()


@pytest.mark.parametrize(
    "body",
    [
        {"days": []},
        {"days": [{"date": "2026-11-02"}] * 8},
        {"days": [{"date": "2026-11-02"}, {"date": "2026-11-02"}]},
        {"days": [{"date": "2019-12-31"}]},
        {"days": [{"date": "2026-13-01"}]},
        {"days": [{"date": 20261102}]},
        {"days": [{"date": 1762041600}]},
        {"days": [{"date": "2026-11-02T00:00:00Z"}]},
        {"days": [{"date": "2026-11-02", "steps": -1}]},
        {"days": [{"date": "2026-11-02", "steps": 200_001}]},
        {"days": [{"date": "2026-11-02", "calories_kcal": 50_001}]},
        {"days": [{"date": "2026-11-02", "distance_m": 500_001}]},
        {"days": [{"date": "2026-11-02", "sleep_minutes": 1_441}]},
        {"days": [{"date": "2026-11-02", "steps": "many"}]},
        {"days": [{"date": "2026-11-02", "steps": 1.5}]},
    ],
)
def test_a_request_that_breaks_a_rule_is_refused(body: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        DailyActivityRequest.model_validate(body)


def test_every_figure_is_optional_and_the_limits_are_allowed() -> None:
    request = DailyActivityRequest.model_validate(
        {
            "days": [
                {"date": "2026-11-02"},
                {
                    "date": "2026-11-03",
                    "steps": 200_000,
                    "calories_kcal": 50_000,
                    "distance_m": 500_000,
                    "sleep_minutes": 1_440,
                },
            ]
        }
    )

    assert request.days[0].steps is None
