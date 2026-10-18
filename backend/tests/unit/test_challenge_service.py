from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.modules.challenges.models import Challenge, ChallengeStatus, ChallengeType, Quest
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.schemas import ChallengeCreate, ChallengeUpdate, QuestCreate
from app.modules.challenges.service import (
    DEFAULT_QUEST_TITLE,
    MAX_PAGE_SIZE,
    ChallengeInUseError,
    ChallengeInvalidError,
    ChallengeNotDraftError,
    ChallengeNotFoundError,
    ChallengeNotPublishableError,
    ChallengeService,
    QuestNotFoundError,
)
from app.modules.medals.models import Medal
from app.modules.medals.service import MedalService

NOW = datetime(2026, 10, 18, tzinfo=UTC)
IMAGE = "https://res.cloudinary.com/demo/image/upload/a.png"


def make_challenge(**changes: Any) -> Challenge:
    values: dict[str, Any] = {
        "id": 1,
        "quest_id": 1,
        "title": "Old Quarter 50K Steps",
        "type": "run",
        "metric": "steps",
        "target_value": 50_000,
        "description_md": "Walk or run.",
        "terms_md": "",
        "city": None,
        "landmark": None,
        "cover_image_url": IMAGE,
        "status": "draft",
        "starts_at": NOW - timedelta(days=1),
        "ends_at": NOW + timedelta(days=30),
        "medals": [Medal(tier="gold", threshold_value=50_000, name="Gold", image_url=IMAGE)],
    }
    values.update(changes)
    return Challenge(**values)


@pytest.fixture
def repository() -> AsyncMock:
    mock = AsyncMock(spec=ChallengeRepository)
    mock.get.return_value = make_challenge()
    mock.get_quest_by_title.return_value = Quest(id=7, title=DEFAULT_QUEST_TITLE, description="")

    async def add(challenge: Challenge) -> Challenge:
        challenge.id = 42
        return challenge

    mock.add.side_effect = add
    return mock


@pytest.fixture
def session() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def medals() -> AsyncMock:
    return AsyncMock(spec=MedalService)


@pytest.fixture
def participants() -> AsyncMock:
    return AsyncMock(return_value=0)


@pytest.fixture
def service(
    session: AsyncMock, repository: AsyncMock, medals: AsyncMock, participants: AsyncMock
) -> ChallengeService:
    return ChallengeService(session, repository, medals, participants=participants, now=lambda: NOW)


def create_request(**changes: Any) -> ChallengeCreate:
    body: dict[str, Any] = {
        "title": "Mỹ Khê Bay 20 km",
        "type": "swim",
        "target_value": 20_000,
        "starts_at": NOW,
        "ends_at": NOW + timedelta(days=30),
    }
    body.update(changes)
    return ChallengeCreate.model_validate(body)


class TestCreate:
    @pytest.mark.anyio
    async def test_makes_a_draft_whose_metric_follows_the_type(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        await service.create(create_request())

        created: Challenge = repository.add.await_args.args[0]
        assert (created.type, created.metric, created.status) == ("swim", "distance_m", "draft")
        assert created.quest_id == 7
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("kind", "metric"), [("run", "steps"), ("swim", "distance_m"), ("cycle", "distance_m")]
    )
    async def test_each_type_counts_its_own_metric(
        self, service: ChallengeService, repository: AsyncMock, kind: str, metric: str
    ) -> None:
        await service.create(create_request(type=kind))

        assert repository.add.await_args.args[0].metric == metric

    @pytest.mark.anyio
    async def test_the_medals_are_added_by_the_medals_service_in_one_transaction(
        self, service: ChallengeService, medals: AsyncMock, session: AsyncMock
    ) -> None:
        request = create_request(
            target_value=20_000,
            medals=[
                {"tier": "gold", "name": "Gold", "threshold_value": 20_000, "image_url": IMAGE}
            ],
        )

        await service.create(request)

        medals.add_medals.assert_awaited_once_with(42, request.medals)
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_creates_the_default_quest_when_there_is_none(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get_quest_by_title.return_value = None
        repository.add_quest.side_effect = lambda quest: setattr(quest, "id", 9) or quest

        await service.create(create_request())

        repository.add_quest.assert_awaited_once()
        assert repository.add.await_args.args[0].quest_id == 9

    @pytest.mark.anyio
    async def test_uses_the_quest_it_is_given(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get_quest.return_value = Quest(id=3, title="Autumn", description="")

        await service.create(create_request(quest_id=3))

        assert repository.add.await_args.args[0].quest_id == 3
        repository.get_quest_by_title.assert_not_awaited()

    @pytest.mark.anyio
    async def test_an_unknown_quest_is_refused_before_anything_is_written(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        repository.get_quest.return_value = None

        with pytest.raises(QuestNotFoundError) as raised:
            await service.create(create_request(quest_id=99))

        assert (raised.value.status_code, raised.value.code) == (404, "quest_not_found")
        repository.add.assert_not_awaited()
        session.commit.assert_not_awaited()


class TestGet:
    @pytest.mark.anyio
    async def test_a_draft_is_hidden_from_users(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        with pytest.raises(ChallengeNotFoundError):
            await service.get(1)

        assert (await service.get(1, include_drafts=True)).id == 1

    @pytest.mark.anyio
    async def test_a_published_challenge_is_visible(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(status="published")

        assert (await service.get(1)).status == "published"

    @pytest.mark.anyio
    async def test_an_unknown_id_is_not_found(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = None

        with pytest.raises(ChallengeNotFoundError) as raised:
            await service.get(404, include_drafts=True)

        assert (raised.value.status_code, raised.value.code) == (404, "challenge_not_found")


class TestList:
    @pytest.mark.anyio
    async def test_passes_the_filters_and_clamps_the_page_size(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.list_challenges.return_value = []

        await service.list_challenges(
            challenge_type=ChallengeType.SWIM, search="  Hà Nội ", limit=10_000, after_id=5
        )

        repository.list_challenges.assert_awaited_once_with(
            include_drafts=False,
            challenge_type="swim",
            search="Hà Nội",
            limit=MAX_PAGE_SIZE,
            after_id=5,
        )

    @pytest.mark.anyio
    @pytest.mark.parametrize(("asked", "used"), [(0, 1), (-3, 1), (20, 20)])
    async def test_a_page_has_at_least_one_row(
        self, service: ChallengeService, repository: AsyncMock, asked: int, used: int
    ) -> None:
        repository.list_challenges.return_value = []

        await service.list_challenges(limit=asked, search="   ")

        kwargs = repository.list_challenges.await_args.kwargs
        assert kwargs["limit"] == used
        assert kwargs["search"] is None


class TestPublish:
    @pytest.mark.anyio
    async def test_publishes_a_complete_draft(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        challenge = await service.publish(1)

        assert challenge.status == ChallengeStatus.PUBLISHED.value
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("changes", "missing"),
        [
            ({"cover_image_url": None}, "a cover image"),
            ({"description_md": "  \n"}, "a description"),
            ({"medals": []}, "at least one medal"),
            ({"ends_at": NOW - timedelta(seconds=1)}, "an end date in the future"),
            ({"ends_at": NOW}, "an end date in the future"),
        ],
    )
    async def test_refuses_an_incomplete_draft(
        self,
        service: ChallengeService,
        repository: AsyncMock,
        session: AsyncMock,
        changes: dict[str, Any],
        missing: str,
    ) -> None:
        repository.get.return_value = make_challenge(**changes)

        with pytest.raises(ChallengeNotPublishableError, match=missing) as raised:
            await service.publish(1)

        assert (raised.value.status_code, raised.value.code) == (409, "challenge_not_publishable")
        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_lists_everything_that_is_missing(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(
            cover_image_url=None, description_md="", medals=[]
        )

        with pytest.raises(ChallengeNotPublishableError) as raised:
            await service.publish(1)

        message = str(raised.value)
        assert "a cover image, a description, at least one medal" in message

    @pytest.mark.anyio
    async def test_publishing_a_published_challenge_changes_nothing(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(status="published", cover_image_url=None)

        challenge = await service.publish(1)

        assert challenge.status == "published"
        session.commit.assert_not_awaited()


class TestUnpublishAndDelete:
    @pytest.mark.anyio
    async def test_unpublish_takes_a_challenge_back_to_draft(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(status="published")

        assert (await service.unpublish(1)).status == "draft"
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_unpublishing_a_draft_changes_nothing(
        self, service: ChallengeService, session: AsyncMock
    ) -> None:
        assert (await service.unpublish(1)).status == "draft"
        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_a_draft_can_be_deleted(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        await service.delete(1)

        repository.delete.assert_awaited_once()
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_a_published_challenge_cannot_be_deleted(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(status="published")

        with pytest.raises(ChallengeNotDraftError) as raised:
            await service.delete(1)

        assert (raised.value.status_code, raised.value.code) == (409, "challenge_not_draft")
        repository.delete.assert_not_awaited()


def update_request(**changes: Any) -> ChallengeUpdate:
    return ChallengeUpdate.model_validate(changes)


class TestUpdate:
    @pytest.mark.anyio
    async def test_changes_only_what_is_sent(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        challenge = repository.get.return_value

        await service.update(1, update_request(title="New title", city="Hà Nội"))

        assert (challenge.title, challenge.city) == ("New title", "Hà Nội")
        assert challenge.target_value == 50_000
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_a_null_clears_an_optional_field(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(city="Hà Nội")

        await service.update(1, update_request(city=None))

        assert repository.get.return_value.city is None

    @pytest.mark.anyio
    async def test_an_empty_patch_writes_nothing(
        self, service: ChallengeService, session: AsyncMock
    ) -> None:
        await service.update(1, update_request())

        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_the_merged_challenge_must_still_follow_the_rules(
        self, service: ChallengeService, session: AsyncMock
    ) -> None:
        with pytest.raises(ChallengeInvalidError) as raised:
            await service.update(1, update_request(target_value=60_000))

        assert raised.value.fields
        session.commit.assert_not_awaited()

    @pytest.mark.anyio
    async def test_the_type_changes_the_metric(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        await service.update(1, update_request(type="swim"))

        assert repository.get.return_value.metric == "distance_m"

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        "changes",
        [
            {"type": "swim"},
            {"target_value": 40_000, "medals": []},
            {"ends_at": NOW + timedelta(days=60)},
            {"starts_at": NOW - timedelta(days=2)},
        ],
    )
    async def test_the_counted_fields_are_frozen_once_someone_joined(
        self, service: ChallengeService, participants: AsyncMock, changes: dict[str, Any]
    ) -> None:
        participants.return_value = 3

        with pytest.raises(ChallengeInUseError):
            await service.update(1, update_request(**changes))

    @pytest.mark.anyio
    async def test_the_same_value_is_not_a_change(
        self, service: ChallengeService, participants: AsyncMock
    ) -> None:
        participants.return_value = 3

        await service.update(1, update_request(type="run", target_value=50_000, title="Renamed"))

    @pytest.mark.anyio
    async def test_other_fields_stay_editable_once_someone_joined(
        self, service: ChallengeService, participants: AsyncMock, repository: AsyncMock
    ) -> None:
        participants.return_value = 3

        await service.update(1, update_request(description_md="New text."))

        assert repository.get.return_value.description_md == "New text."

    @pytest.mark.anyio
    async def test_replaces_the_medals_in_the_same_transaction(
        self, service: ChallengeService, medals: AsyncMock, session: AsyncMock
    ) -> None:
        gold = {"tier": "gold", "name": "G", "threshold_value": 50_000, "image_url": IMAGE}

        await service.update(1, update_request(medals=[gold]))

        medals.replace_medals.assert_awaited_once()
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_a_published_challenge_cannot_lose_what_publishing_needs(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = make_challenge(status="published")

        with pytest.raises(ChallengeNotPublishableError, match="a cover image"):
            await service.update(1, update_request(cover_image_url=None))

    @pytest.mark.anyio
    async def test_an_unknown_quest_is_refused(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get_quest.return_value = None

        with pytest.raises(QuestNotFoundError):
            await service.update(1, update_request(quest_id=99))

    @pytest.mark.anyio
    async def test_an_unknown_challenge_is_not_found(
        self, service: ChallengeService, repository: AsyncMock
    ) -> None:
        repository.get.return_value = None

        with pytest.raises(ChallengeNotFoundError):
            await service.update(1, update_request(title="x"))


class TestQuests:
    @pytest.mark.anyio
    async def test_creates_a_quest_and_commits_it(
        self, service: ChallengeService, repository: AsyncMock, session: AsyncMock
    ) -> None:
        repository.add_quest.side_effect = lambda quest: quest

        quest = await service.create_quest(QuestCreate(title="Hanoi", description="Walks"))

        assert (quest.title, quest.description) == ("Hanoi", "Walks")
        session.commit.assert_awaited_once()

    @pytest.mark.anyio
    async def test_lists_the_quests(self, service: ChallengeService, repository: AsyncMock) -> None:
        repository.list_quests.return_value = [Quest(id=1, title="A", description="")]

        assert [q.id for q in await service.list_quests()] == [1]


class TestMedalService:
    @pytest.mark.anyio
    async def test_builds_one_row_per_input_without_committing(self) -> None:
        from app.modules.medals.repository import MedalRepository
        from app.modules.medals.schemas import MedalInput

        repository = MagicMock(spec=MedalRepository)
        repository.add_all = AsyncMock(side_effect=lambda medals: medals)
        service = MedalService(repository)

        medals = await service.add_medals(
            5,
            [
                MedalInput.model_validate(
                    {"tier": "bronze", "name": "B", "threshold_value": 1, "image_url": IMAGE}
                )
            ],
        )

        assert [(m.challenge_id, m.tier, m.threshold_value, m.image_url) for m in medals] == [
            (5, "bronze", 1, IMAGE)
        ]
