from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class MedalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    image_url: HttpUrl


class ChallengeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    target_steps: int = Field(gt=0)
    starts_at: datetime
    ends_at: datetime
    medal: MedalRead | None


class QuestRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str
    challenges: list[ChallengeRead]
