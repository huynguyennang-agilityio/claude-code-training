import re
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Self

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

from app.core.text import NO_NUL_PATTERN
from app.modules.challenges.models import ChallengeType
from app.modules.challenges.schemas import ChallengeSummary

MAX_SAMPLES_PER_SYNC = 500
MAX_STEPS_PER_SAMPLE = 100_000
MAX_SAMPLE_LENGTH = timedelta(hours=24)

RecordId = Annotated[str, StringConstraints(min_length=1, max_length=128, pattern=NO_NUL_PATTERN)]


class StepSampleIn(BaseModel):
    """A step sample synced from the device."""

    health_record_id: RecordId
    start_time: AwareDatetime
    end_time: AwareDatetime
    steps: int = Field(ge=1, le=MAX_STEPS_PER_SAMPLE)

    @field_validator("start_time", "end_time", mode="before")
    @classmethod
    def _date_is_text(cls, value: object) -> object:
        """A date and time is sent as ISO 8601 text; Pydantic would also take a bare number."""
        if not isinstance(value, str | datetime):
            raise ValueError("Send an ISO 8601 date and time with a timezone.")
        return value

    @model_validator(mode="after")
    def check_time_order(self) -> Self:
        if self.end_time < self.start_time:
            raise ValueError("end_time must not be before start_time")
        if self.end_time - self.start_time > MAX_SAMPLE_LENGTH:
            raise ValueError("A sample can cover at most 24 hours.")
        return self


class StepSyncRequest(BaseModel):
    samples: list[StepSampleIn] = Field(min_length=1, max_length=MAX_SAMPLES_PER_SYNC)


MAX_HOURS_PER_SYNC = 744  # 31 days
MAX_STEPS_VALUE = 2_147_483_647  # what the `steps` column holds


class StepHourIn(BaseModel):
    """The steps of one UTC hour, as the health data reports them. `hour_start` is converted to
    UTC, so two spellings of one hour are equal."""

    hour_start: AwareDatetime
    steps: int = Field(ge=0, le=MAX_STEPS_VALUE)

    @field_validator("hour_start", mode="before")
    @classmethod
    def _date_is_text(cls, value: object) -> object:
        """A date and time is sent as ISO 8601 text; Pydantic would also take a bare number."""
        if not isinstance(value, str | datetime):
            raise ValueError("Send an ISO 8601 date and time with a timezone.")
        return value

    @field_validator("steps", mode="before")
    @classmethod
    def _steps_is_not_a_boolean(cls, value: object) -> object:
        """Pydantic would read `true` as 1."""
        if isinstance(value, bool):
            raise ValueError("steps must be a whole number.")
        return value

    @field_validator("hour_start", mode="after")
    @classmethod
    def _on_the_hour(cls, value: datetime) -> datetime:
        try:
            value = value.astimezone(UTC)
        except OverflowError:
            # A year-1 or year-9999 time can fall outside the datetime range once in UTC; a
            # validator raises ValueError only, or the request would answer 500.
            raise ValueError("hour_start is out of range.") from None
        if value.minute or value.second or value.microsecond:
            raise ValueError("hour_start must be the start of a UTC hour.")
        return value


class StepHoursRequest(BaseModel):
    hours: list[StepHourIn] = Field(min_length=1, max_length=MAX_HOURS_PER_SYNC)

    @model_validator(mode="after")
    def hours_are_different(self) -> Self:
        starts = [item.hour_start for item in self.hours]
        if len(set(starts)) != len(starts):
            raise ValueError("Send each hour once.")
        return self


class ProgressRead(BaseModel):
    """How far the caller is in a challenge. `tracked` is false for a type whose progress the
    app does not count yet (swim and cycle): its `current_value` stays 0."""

    current_value: int = Field(ge=0)
    target_value: int = Field(gt=0)
    percent: int = Field(ge=0, le=100)
    tracked: bool
    started: bool


class EnrollmentProgress(BaseModel):
    challenge_id: int
    progress: ProgressRead


class StepSyncResult(BaseModel):
    accepted: int = Field(ge=0, description="Samples (or hours) that were counted.")
    ignored: int = Field(
        ge=0,
        description="Samples (or hours) that were not: a duplicate or outside the rules.",
    )
    enrollments: list[EnrollmentProgress]


class MyChallengeItem(BaseModel):
    """A challenge the caller is in, as a card, with their progress."""

    challenge: ChallengeSummary
    progress: ProgressRead


class MyChallengePage(BaseModel):
    items: list[MyChallengeItem]
    next_cursor: str | None = Field(description="Send it as `cursor` for the next page.")


class MyChallengeQuery(BaseModel):
    """The query string of the caller's challenges. An unknown parameter is refused."""

    model_config = ConfigDict(extra="forbid")

    cursor: str | None = Field(
        default=None,
        max_length=80,
        pattern=r"^[A-Za-z0-9_-]+$",
        description="The `next_cursor` of the previous page.",
    )
    limit: int = Field(default=20, ge=1, le=50)


TRACKED_TYPES = (ChallengeType.RUN.value,)


MAX_DAYS_PER_SYNC = 7
Day = date  # a field named `date` would hide the type inside its own class
EARLIEST_DAY = Day(2020, 1, 1)
_DAY_TEXT = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class DailyActivityIn(BaseModel):
    """What the health data said for one calendar day on the device. A figure the user did not
    allow, or the device has none of, is left out."""

    date: Day = Field(ge=EARLIEST_DAY, description="The calendar day on the device.")
    steps: int | None = Field(default=None, ge=0, le=200_000)
    calories_kcal: int | None = Field(default=None, ge=0, le=50_000)
    distance_m: int | None = Field(default=None, ge=0, le=500_000)
    sleep_minutes: int | None = Field(
        default=None, ge=0, le=1_440, description="Time asleep in the night that ends on this day."
    )

    @field_validator("date", mode="before")
    @classmethod
    def _date_is_text(cls, value: object) -> object:
        """A day is sent as `YYYY-MM-DD` text; Pydantic would also take a number or a time."""
        if not isinstance(value, str) or not _DAY_TEXT.match(value):
            raise ValueError("Send the day as YYYY-MM-DD.")
        return value


class DailyActivityRequest(BaseModel):
    days: list[DailyActivityIn] = Field(min_length=1, max_length=MAX_DAYS_PER_SYNC)

    @model_validator(mode="after")
    def days_are_different(self) -> Self:
        days = [item.date for item in self.days]
        if len(set(days)) != len(days):
            raise ValueError("Send each day once.")
        return self


class DailyActivityRead(BaseModel):
    """A day as it is stored."""

    date: Day
    steps: int | None
    calories_kcal: int | None
    distance_m: int | None
    sleep_minutes: int | None
    updated_at: AwareDatetime


class DailyActivityResult(BaseModel):
    days: list[DailyActivityRead]
