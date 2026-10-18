from typing import Annotated

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    HttpUrl,
    StringConstraints,
    ValidationInfo,
    field_validator,
)

from app.modules.challenges.models import (
    ChallengeMetric,
    ChallengeMode,
    ChallengeStatus,
    ChallengeType,
)
from app.modules.medals.models import TIER_ORDER, MedalTier
from app.modules.medals.schemas import MAX_THRESHOLD, MedalInput, MedalRead

Place = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]


class ChallengeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    quest_id: int
    title: str
    type: ChallengeType
    metric: ChallengeMetric
    target_value: int = Field(gt=0)
    mode: ChallengeMode
    description_md: str
    terms_md: str
    cover_image_url: HttpUrl | None
    city: str | None
    landmark: str | None
    status: ChallengeStatus
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    medals: list[MedalRead]


class ChallengeCreate(BaseModel):
    """A new challenge, always created as a draft. The metric follows from the type:
    steps for a run, metres for a swim or a ride."""

    quest_id: int | None = Field(default=None, description="Defaults to the default quest.")
    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
    type: ChallengeType
    target_value: int = Field(gt=0, le=MAX_THRESHOLD)
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    description_md: str = Field(default="", max_length=20_000)
    terms_md: str = Field(default="", max_length=20_000)
    cover_image_url: HttpUrl | None = None
    city: Place | None = None
    landmark: Place | None = None
    medals: list[MedalInput] = Field(default_factory=list, max_length=len(TIER_ORDER))

    @field_validator("ends_at")
    @classmethod
    def ends_after_start(cls, ends_at: AwareDatetime, info: ValidationInfo) -> AwareDatetime:
        starts_at = info.data.get("starts_at")
        if starts_at is not None and ends_at <= starts_at:
            raise ValueError("ends_at must be after starts_at.")
        return ends_at

    @field_validator("medals")
    @classmethod
    def medals_fit_the_challenge(
        cls, medals: list[MedalInput], info: ValidationInfo
    ) -> list[MedalInput]:
        """One medal per tier; a higher tier asks for more; none asks for more than the
        target; and the gold medal, when there is one, is the target itself."""
        tiers = [medal.tier for medal in medals]
        if len(set(tiers)) != len(tiers):
            raise ValueError("A challenge has at most one medal per tier.")
        ordered = sorted(medals, key=lambda medal: TIER_ORDER.index(medal.tier))
        thresholds = [medal.threshold_value for medal in ordered]
        if any(low >= high for low, high in zip(thresholds, thresholds[1:], strict=False)):
            raise ValueError("Each tier must ask for more than the tier below it.")
        target = info.data.get("target_value")
        if target is not None:
            if any(threshold > target for threshold in thresholds):
                raise ValueError("A medal cannot ask for more than the target.")
            gold = next((medal for medal in medals if medal.tier is MedalTier.GOLD), None)
            if gold is not None and gold.threshold_value != target:
                raise ValueError("The gold medal is earned at the target.")
        return medals


class QuestRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str
    challenges: list[ChallengeRead]
