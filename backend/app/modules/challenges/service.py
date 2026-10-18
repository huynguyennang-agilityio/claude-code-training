from collections.abc import Callable
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DomainError
from app.modules.challenges.models import (
    METRIC_FOR_TYPE,
    Challenge,
    ChallengeStatus,
    ChallengeType,
    Quest,
)
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.schemas import ChallengeCreate
from app.modules.medals.service import MedalService

DEFAULT_QUEST_TITLE = "General"
MAX_PAGE_SIZE = 50


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


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ChallengeService:
    def __init__(
        self,
        session: AsyncSession,
        repository: ChallengeRepository,
        medals: MedalService,
        now: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._session = session
        self._repository = repository
        self._medals = medals
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
        return await self._repository.list(
            include_drafts=include_drafts,
            challenge_type=challenge_type.value if challenge_type else None,
            search=search.strip() if search and search.strip() else None,
            limit=max(1, min(limit, MAX_PAGE_SIZE)),
            after_id=after_id,
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
        missing = []
        if not challenge.cover_image_url:
            missing.append("a cover image")
        if not challenge.description_md.strip():
            missing.append("a description")
        if not challenge.medals:
            missing.append("at least one medal")
        if challenge.ends_at <= self._now():
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
