from pydantic import BaseModel, ConfigDict, Field, HttpUrl

from app.modules.medals.models import MedalTier

# The most a challenge can ask for: 10 million steps, or 10,000 km in metres.
MAX_THRESHOLD = 10_000_000


class MedalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    tier: MedalTier
    name: str
    threshold_value: int
    image_url: HttpUrl


class MedalInput(BaseModel):
    """A medal of a new challenge. The challenge's own rules (the tier order and the
    thresholds against its target) are checked by `ChallengeCreate`."""

    tier: MedalTier
    name: str = Field(min_length=1, max_length=120)
    threshold_value: int = Field(gt=0, le=MAX_THRESHOLD)
    image_url: HttpUrl
