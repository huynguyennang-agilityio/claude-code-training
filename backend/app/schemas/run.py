from datetime import datetime

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator


class StepSampleIn(BaseModel):
    """A step sample synced from the device."""

    health_record_id: str = Field(min_length=1, max_length=128)
    start_time: AwareDatetime
    end_time: AwareDatetime
    steps: int = Field(ge=0)

    @model_validator(mode="after")
    def check_time_order(self) -> "StepSampleIn":
        if self.end_time < self.start_time:
            raise ValueError("end_time must not be before start_time")
        return self


class RunSyncRequest(BaseModel):
    samples: list[StepSampleIn] = Field(max_length=1000)


class RunRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    challenge_id: int
    started_at: datetime
    total_steps: int
    completed: bool
