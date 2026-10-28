from datetime import datetime
from enum import StrEnum
from typing import Annotated, Any, Self

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

from app.core.text import NO_NUL_PATTERN, SINGLE_LINE_PATTERN
from app.modules.challenges.models import (
    ChallengeMetric,
    ChallengeMode,
    ChallengeStatus,
    ChallengeType,
)
from app.modules.challenges.paging import MAX_PAGE_SIZE
from app.modules.medals.models import TIER_ORDER, MedalTier
from app.modules.medals.schemas import MAX_THRESHOLD, MedalInput, MedalRead


def _date_text(value: object) -> object:
    """A date and time is sent as ISO 8601 text; Pydantic would also take a bare number."""
    if not isinstance(value, str | datetime):
        raise ValueError("Send an ISO 8601 date and time with a timezone.")
    return value


Place = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True, min_length=1, max_length=120, pattern=SINGLE_LINE_PATTERN
    ),
]


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


class EnrollmentStatus(StrEnum):
    ACTIVE = "active"
    PAUSED = "paused"


class EnrollmentRead(BaseModel):
    """The caller's own place in a challenge. A challenge they left is "not joined"."""

    status: EnrollmentStatus
    joined_at: AwareDatetime


class BlockedByRead(BaseModel):
    """The challenge the caller is in that overlaps this one and so stops them joining it."""

    id: int
    title: str


def _attributes(source: object, model: type[BaseModel]) -> dict[str, Any]:
    return {name: getattr(source, name) for name in model.model_fields if hasattr(source, name)}


class ChallengeSummary(BaseModel):
    """A challenge as a card in the list."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    type: ChallengeType
    metric: ChallengeMetric
    target_value: int = Field(gt=0)
    cover_image_url: HttpUrl | None
    city: str | None
    landmark: str | None
    status: ChallengeStatus
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    participant_count: int = Field(ge=0)
    enrollment: EnrollmentRead | None

    @classmethod
    def build(
        cls, challenge: object, *, participant_count: int, enrollment: EnrollmentRead | None
    ) -> Self:
        return cls.model_validate(
            {
                **_attributes(challenge, cls),
                "participant_count": participant_count,
                "enrollment": enrollment,
            }
        )


class ChallengeListQuery(BaseModel):
    """The query string of the list. An unknown parameter is refused, so a misspelt filter
    is a `422` and not a list that silently ignores it."""

    model_config = ConfigDict(extra="forbid")

    type: ChallengeType | None = Field(default=None, description="Only this type.")
    q: str | None = Field(
        default=None,
        max_length=100,
        pattern=SINGLE_LINE_PATTERN,
        description="Matches the title, city and landmark, ignoring case.",
    )
    status: ChallengeStatus = Field(
        default=ChallengeStatus.PUBLISHED, description="`draft` is for admins; others get 403."
    )
    cursor: str | None = Field(
        default=None,
        max_length=40,
        pattern=r"^[A-Za-z0-9_-]+$",
        description="The `next_cursor` of the previous page.",
    )
    limit: int = Field(default=20, ge=1, le=MAX_PAGE_SIZE)


class ChallengePage(BaseModel):
    items: list[ChallengeSummary]
    next_cursor: str | None = Field(description="Send it as `cursor` for the next page.")


class ChallengeDetail(ChallengeRead):
    """A challenge with its checkpoints, how many joined, and where the caller stands."""

    participant_count: int = Field(ge=0)
    enrollment: EnrollmentRead | None
    blocked_by: BlockedByRead | None

    @classmethod
    def build(
        cls,
        challenge: object,
        *,
        participant_count: int,
        enrollment: EnrollmentRead | None,
        blocked_by: BlockedByRead | None,
    ) -> Self:
        return cls.model_validate(
            {
                **_attributes(challenge, cls),
                "participant_count": participant_count,
                "enrollment": enrollment,
                "blocked_by": blocked_by,
            }
        )


class ChallengeCreate(BaseModel):
    """A new challenge, always created as a draft. The metric follows from the type:
    steps for a run, metres for a swim or a ride."""

    quest_id: int | None = Field(default=None, description="Defaults to the default quest.")
    title: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True, min_length=1, max_length=120, pattern=SINGLE_LINE_PATTERN
        ),
    ]
    type: ChallengeType
    target_value: int = Field(gt=0, le=MAX_THRESHOLD)
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    description_md: str = Field(default="", max_length=20_000, pattern=NO_NUL_PATTERN)
    terms_md: str = Field(default="", max_length=20_000, pattern=NO_NUL_PATTERN)
    cover_image_url: HttpUrl | None = None
    city: Place | None = None
    landmark: Place | None = None
    medals: list[MedalInput] = Field(default_factory=list, max_length=len(TIER_ORDER))

    _dates_are_text = field_validator("starts_at", "ends_at", mode="before")(_date_text)

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


class ChallengeUpdate(BaseModel):
    """The fields to change, all optional. A field that is sent replaces the stored value
    (`null` clears the cover, city and landmark); one that is left out stays. The service
    checks the result against the same rules as `ChallengeCreate`, since a rule such as the
    gold medal at the target depends on stored fields the request may not repeat."""

    # The fields that can't be cleared are typed without `None`, so the OpenAPI document does
    # not offer `null` for them. Their default is `None` only to tell "left out" apart; the
    # service reads what was sent from `model_fields_set`, never the default.
    quest_id: int = Field(default=None)  # type: ignore[assignment]
    title: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True, min_length=1, max_length=120, pattern=SINGLE_LINE_PATTERN
        ),
    ] = Field(default=None)  # type: ignore[assignment]
    type: ChallengeType = Field(default=None)  # type: ignore[assignment]
    target_value: int = Field(default=None, gt=0, le=MAX_THRESHOLD)  # type: ignore[assignment]
    starts_at: AwareDatetime = Field(default=None)  # type: ignore[assignment]
    ends_at: AwareDatetime = Field(default=None)  # type: ignore[assignment]
    description_md: str = Field(default=None, max_length=20_000, pattern=NO_NUL_PATTERN)  # type: ignore[assignment]
    terms_md: str = Field(default=None, max_length=20_000, pattern=NO_NUL_PATTERN)  # type: ignore[assignment]
    cover_image_url: HttpUrl | None = None
    city: Place | None = None
    landmark: Place | None = None
    medals: list[MedalInput] = Field(
        default=None,  # type: ignore[arg-type]
        max_length=len(TIER_ORDER),
    )

    _dates_are_text = field_validator("starts_at", "ends_at", mode="before")(_date_text)


class QuestCreate(BaseModel):
    title: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True, min_length=1, max_length=120, pattern=SINGLE_LINE_PATTERN
        ),
    ]
    description: str = Field(default="", max_length=2_000, pattern=NO_NUL_PATTERN)


class QuestSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str


class UploadedImageRead(BaseModel):
    url: HttpUrl
    public_id: str
    width: int
    height: int
    size_bytes: int
