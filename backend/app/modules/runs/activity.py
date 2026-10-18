"""Saving the daily health figures the app syncs (steps, calories, distance, sleep)."""

import uuid
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError, FieldError
from app.modules.runs.repository import RunRepository
from app.modules.runs.schemas import DailyActivityIn, DailyActivityRead, DailyActivityResult


class FutureDayError(DomainError):
    status_code = 422
    code = "validation_error"


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ActivityService:
    def __init__(
        self,
        session: AsyncSession,
        repository: RunRepository,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._now = now

    async def save_days(
        self, user_id: uuid.UUID, days: list[DailyActivityIn]
    ) -> DailyActivityResult:
        """Replace the user's figures for each day. A day is the date on the device, which may
        be a day ahead of the server's, so tomorrow is accepted and nothing later."""
        now = self._now()
        latest: date = now.date() + timedelta(days=1)
        too_late = [
            FieldError(field=f"body.days.{index}.date", message="The day is in the future.")
            for index, day in enumerate(days)
            if day.date > latest
        ]
        if too_late:
            raise FutureDayError("A day is in the future.", fields=too_late)
        rows = await self._repository.replace_daily_activity(
            user_id,
            [
                {
                    "day": day.date,
                    "steps": day.steps,
                    "calories_kcal": day.calories_kcal,
                    "distance_m": day.distance_m,
                    "sleep_minutes": day.sleep_minutes,
                }
                for day in days
            ],
            now=now,
        )
        await self._session.commit()
        return DailyActivityResult(
            days=[
                DailyActivityRead(
                    date=row.day,
                    steps=row.steps,
                    calories_kcal=row.calories_kcal,
                    distance_m=row.distance_m,
                    sleep_minutes=row.sleep_minutes,
                    updated_at=row.updated_at,
                )
                for row in rows
            ]
        )
