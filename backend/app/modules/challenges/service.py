import base64
import binascii
from collections.abc import Awaitable, Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError, fields_from_validation_error
from app.modules.challenges.models import (
    METRIC_FOR_TYPE,
    Challenge,
    ChallengeStatus,
    ChallengeType,
    Quest,
)
from app.modules.challenges.paging import MAX_PAGE_SIZE
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.schemas import ChallengeCreate, ChallengeUpdate, QuestCreate
from app.modules.medals.service import MedalService

DEFAULT_QUEST_TITLE = "General"


# The codes below are listed in `docs/api/challenges.md`.
class ChallengeNotFoundError(DomainError):
    status_code = 404
    code = "challenge_not_found"


class QuestNotFoundError(DomainError):
    status_code = 404
    code = "quest_not_found"


class ChallengeNotPublishableError(DomainError):
    status_code = 409
    code = "challenge_not_publishable"


class ChallengeNotDraftError(DomainError):
    status_code = 409
    code = "challenge_not_draft"


class ChallengeInUseError(DomainError):
    status_code = 409
    code = "challenge_in_use"


class ChallengeInvalidError(DomainError):
    """An edit that breaks a rule once merged with the stored challenge."""

    status_code = 422
    code = "validation_error"


class InvalidCursorError(DomainError):
    status_code = 422
    code = "invalid_cursor"


@dataclass(frozen=True)
class ChallengeView:
    """A challenge with what the response adds to it for this caller."""

    challenge: Challenge
    participant_count: int


@dataclass(frozen=True)
class ChallengeListing:
    items: list[ChallengeView]
    next_cursor: str | None


def encode_cursor(challenge_id: int) -> str:
    return base64.urlsafe_b64encode(str(challenge_id).encode()).decode().rstrip("=")


def decode_cursor(cursor: str) -> int:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        value = int(base64.urlsafe_b64decode(padded.encode()).decode())
    except (binascii.Error, UnicodeDecodeError, ValueError) as error:
        raise InvalidCursorError("The cursor is not valid.") from error
    if value < 1:
        raise InvalidCursorError("The cursor is not valid.")
    return value


# What the participants are counting toward. Once anyone has joined, an edit can't change these.
FROZEN_WITH_PARTICIPANTS = ("type", "target_value", "starts_at", "ends_at", "medals")


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ChallengeService:
    def __init__(
        self,
        session: AsyncSession,
        repository: ChallengeRepository,
        medals: MedalService,
        participants: Callable[[int], Awaitable[int]],
        participant_counts: Callable[[Sequence[int]], Awaitable[dict[int, int]]],
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._medals = medals
        # How many users joined a challenge. The runs module owns it; the caller passes
        # `RunService.count_participants`, so this module never imports the runs one.
        self._participants = participants
        self._participant_counts = participant_counts
        self._now = now

    async def create(self, data: ChallengeCreate) -> Challenge:
        """Create a draft challenge with its medals."""
        quest = await self._quest_for(data.quest_id)
        challenge = await self._repository.add(
            Challenge(
                quest_id=quest.id,
                title=data.title,
                type=data.type.value,
                metric=METRIC_FOR_TYPE[data.type].value,
                target_value=data.target_value,
                description_md=data.description_md,
                terms_md=data.terms_md,
                cover_image_url=str(data.cover_image_url) if data.cover_image_url else None,
                city=data.city,
                landmark=data.landmark,
                status=ChallengeStatus.DRAFT.value,
                starts_at=data.starts_at,
                ends_at=data.ends_at,
            )
        )
        await self._medals.add_medals(challenge.id, data.medals)
        await self._session.commit()
        return await self._get_or_raise(challenge.id)

    async def update(self, challenge_id: int, data: ChallengeUpdate) -> Challenge:
        """Change a challenge.

        The result is validated as a whole, with the rules of `ChallengeCreate`. Once anyone
        has joined, `type`, `target_value`, the window and the medals are frozen: they are what
        the participants are counting toward. A published challenge must stay publishable.
        """
        challenge = await self._get_or_raise(challenge_id)
        changes = {name: getattr(data, name) for name in data.model_fields_set}
        if not changes:
            return challenge
        merged = self._merge(challenge, changes)
        if await self._participants(challenge.id):
            frozen = [
                name
                for name in FROZEN_WITH_PARTICIPANTS
                if name in changes and self._differs(challenge, name, merged)
            ]
            if frozen:
                raise ChallengeInUseError(
                    f"People have joined this challenge, so {', '.join(frozen)} cannot change."
                )
        if "quest_id" in changes and changes["quest_id"] != challenge.quest_id:
            await self._quest_for(merged.quest_id)
        if challenge.status == ChallengeStatus.PUBLISHED.value:
            missing = self._missing(
                merged.cover_image_url,
                merged.description_md,
                len(merged.medals),
                merged.ends_at,
            )
            if missing:
                raise ChallengeNotPublishableError(
                    f"A published challenge must keep {', '.join(missing)}."
                )
        self._apply(challenge, merged)
        if "medals" in changes:
            await self._medals.replace_medals(challenge.id, merged.medals)
        await self._session.commit()
        return await self._get_or_raise(challenge.id)

    def _merge(self, challenge: Challenge, changes: dict[str, Any]) -> ChallengeCreate:
        current: dict[str, Any] = {
            "quest_id": challenge.quest_id,
            "title": challenge.title,
            "type": challenge.type,
            "target_value": challenge.target_value,
            "starts_at": challenge.starts_at,
            "ends_at": challenge.ends_at,
            "description_md": challenge.description_md,
            "terms_md": challenge.terms_md,
            "cover_image_url": challenge.cover_image_url,
            "city": challenge.city,
            "landmark": challenge.landmark,
            "medals": [
                {
                    "tier": medal.tier,
                    "name": medal.name,
                    "threshold_value": medal.threshold_value,
                    "image_url": medal.image_url,
                }
                for medal in challenge.medals
            ],
        }
        try:
            return ChallengeCreate.model_validate({**current, **changes})
        except ValidationError as error:
            raise ChallengeInvalidError(
                "The challenge would break a rule.", fields=fields_from_validation_error(error)
            ) from error

    @staticmethod
    def _differs(challenge: Challenge, name: str, merged: ChallengeCreate) -> bool:
        if name == "medals":
            stored = [(m.tier, m.threshold_value, m.name, m.image_url) for m in challenge.medals]
            wanted = [
                (m.tier.value, m.threshold_value, m.name, str(m.image_url)) for m in merged.medals
            ]
            return sorted(stored) != sorted(wanted)
        new = getattr(merged, name)
        return bool(getattr(challenge, name) != (new.value if hasattr(new, "value") else new))

    @staticmethod
    def _apply(challenge: Challenge, merged: ChallengeCreate) -> None:
        challenge.quest_id = merged.quest_id if merged.quest_id is not None else challenge.quest_id
        challenge.title = merged.title
        challenge.type = merged.type.value
        challenge.metric = METRIC_FOR_TYPE[merged.type].value
        challenge.target_value = merged.target_value
        challenge.starts_at = merged.starts_at
        challenge.ends_at = merged.ends_at
        challenge.description_md = merged.description_md
        challenge.terms_md = merged.terms_md
        challenge.cover_image_url = str(merged.cover_image_url) if merged.cover_image_url else None
        challenge.city = merged.city
        challenge.landmark = merged.landmark

    async def create_quest(self, data: QuestCreate) -> Quest:
        quest = await self._repository.add_quest(
            Quest(title=data.title, description=data.description)
        )
        await self._session.commit()
        return quest

    async def list_quests(self) -> list[Quest]:
        return await self._repository.list_quests()

    async def get(self, challenge_id: int, *, include_drafts: bool = False) -> Challenge:
        """A draft is hidden unless `include_drafts`: it answers as if it did not exist."""
        challenge = await self._get_or_raise(challenge_id)
        if challenge.status == ChallengeStatus.DRAFT.value and not include_drafts:
            raise ChallengeNotFoundError("Challenge not found.")
        return challenge

    async def list_challenges(
        self,
        *,
        include_drafts: bool = False,
        challenge_type: ChallengeType | None = None,
        search: str | None = None,
        limit: int = 20,
        after_id: int | None = None,
    ) -> list[Challenge]:
        return await self._repository.list_challenges(
            include_drafts=include_drafts,
            status=None,
            challenge_type=challenge_type.value if challenge_type else None,
            search=search.strip() if search and search.strip() else None,
            limit=max(1, min(limit, MAX_PAGE_SIZE)),
            after_id=after_id,
        )

    async def view(self, challenge_id: int, *, include_drafts: bool = False) -> ChallengeView:
        challenge = await self.get(challenge_id, include_drafts=include_drafts)
        return ChallengeView(challenge, await self._participants(challenge.id))

    async def page(
        self,
        *,
        status: ChallengeStatus = ChallengeStatus.PUBLISHED,
        challenge_type: ChallengeType | None = None,
        search: str | None = None,
        limit: int = 20,
        cursor: str | None = None,
    ) -> ChallengeListing:
        """One page of the list, oldest first. `next_cursor` is set only when more follow."""
        size = max(1, min(limit, MAX_PAGE_SIZE))
        rows = await self._repository.list_challenges(
            include_drafts=status is ChallengeStatus.DRAFT,
            status=status.value,
            challenge_type=challenge_type.value if challenge_type else None,
            search=search.strip() if search and search.strip() else None,
            limit=size + 1,
            after_id=decode_cursor(cursor) if cursor else None,
        )
        shown = rows[:size]
        counts = await self._participant_counts([challenge.id for challenge in shown])
        return ChallengeListing(
            items=[ChallengeView(challenge, counts.get(challenge.id, 0)) for challenge in shown],
            next_cursor=encode_cursor(shown[-1].id) if len(rows) > size else None,
        )

    async def publish(self, challenge_id: int) -> Challenge:
        """Publish a draft that is complete: a cover, a description, at least one medal
        and an end date that has not passed. Publishing a published challenge changes nothing."""
        challenge = await self._get_or_raise(challenge_id)
        if challenge.status == ChallengeStatus.PUBLISHED.value:
            return challenge
        missing = self._missing_for_publishing(challenge)
        if missing:
            raise ChallengeNotPublishableError(f"The challenge is not ready: {', '.join(missing)}.")
        challenge.status = ChallengeStatus.PUBLISHED.value
        await self._session.commit()
        return challenge

    async def unpublish(self, challenge_id: int) -> Challenge:
        """Take a challenge back to draft. Unpublishing a draft changes nothing."""
        challenge = await self._get_or_raise(challenge_id)
        if challenge.status == ChallengeStatus.DRAFT.value:
            return challenge
        challenge.status = ChallengeStatus.DRAFT.value
        await self._session.commit()
        return challenge

    async def delete(self, challenge_id: int) -> None:
        """Delete a draft. A published challenge must be unpublished first."""
        challenge = await self._get_or_raise(challenge_id)
        if challenge.status != ChallengeStatus.DRAFT.value:
            raise ChallengeNotDraftError("Only a draft can be deleted.")
        await self._repository.delete(challenge)
        await self._session.commit()

    def _missing_for_publishing(self, challenge: Challenge) -> list[str]:
        return self._missing(
            challenge.cover_image_url,
            challenge.description_md,
            len(challenge.medals),
            challenge.ends_at,
        )

    def _missing(
        self,
        cover_image_url: object,
        description_md: str,
        medal_count: int,
        ends_at: datetime,
    ) -> list[str]:
        missing = []
        if not cover_image_url:
            missing.append("a cover image")
        if not description_md.strip():
            missing.append("a description")
        if not medal_count:
            missing.append("at least one medal")
        if ends_at <= self._now():
            missing.append("an end date in the future")
        return missing

    async def _get_or_raise(self, challenge_id: int) -> Challenge:
        challenge = await self._repository.get(challenge_id)
        if challenge is None:
            raise ChallengeNotFoundError("Challenge not found.")
        return challenge

    async def _quest_for(self, quest_id: int | None) -> Quest:
        if quest_id is not None:
            quest = await self._repository.get_quest(quest_id)
            if quest is None:
                raise QuestNotFoundError("Quest not found.")
            return quest
        quest = await self._repository.get_quest_by_title(DEFAULT_QUEST_TITLE)
        if quest is None:
            quest = await self._repository.add_quest(
                Quest(title=DEFAULT_QUEST_TITLE, description="Challenges without a quest.")
            )
        return quest
