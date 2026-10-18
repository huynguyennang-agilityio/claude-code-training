from datetime import datetime, timedelta
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
    accepted: int = Field(ge=0, description="Samples that were counted.")
    ignored: int = Field(
        ge=0, description="Samples that were not (duplicate or outside the window)."
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
