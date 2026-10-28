"""The challenge catalog against PostgreSQL: the repository, the service and the
constraints that back the rules."""

from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.challenges.models import Challenge, ChallengeType, Quest
from app.modules.challenges.repository import ChallengeRepository
from app.modules.challenges.schemas import ChallengeCreate, ChallengeRead
from app.modules.challenges.service import (
    DEFAULT_QUEST_TITLE,
    ChallengeNotDraftError,
    ChallengeNotPublishableError,
    ChallengeService,
)
from app.modules.medals.models import Medal
from app.modules.medals.repository import MedalRepository
from app.modules.medals.service import MedalService
from app.modules.runs.repository import RunRepository
from app.modules.runs.service import RunService

NOW = datetime(2026, 10, 18, tzinfo=UTC)
IMAGE = "https://res.cloudinary.com/demo/image/upload/stridequest/a.png"


@pytest.fixture
async def service(session: AsyncSession) -> AsyncIterator[ChallengeService]:
    runs = RunService(RunRepository(session))
    yield ChallengeService(
        session,
        ChallengeRepository(session),
        MedalService(MedalRepository(session)),
        runs=runs,
        now=lambda: NOW,
    )


def request(**changes: Any) -> ChallengeCreate:
    body: dict[str, Any] = {
        "title": "Old Quarter 50K Steps",
        "type": "run",
        "target_value": 50_000,
        "starts_at": NOW,
        "ends_at": NOW + timedelta(days=30),
        "description_md": "Walk or run 50,000 steps.",
        "cover_image_url": IMAGE,
        "city": "Hà Nội",
        "landmark": "Hồ Hoàn Kiếm",
        "medals": [
            {"tier": "bronze", "name": "Bronze", "threshold_value": 20_000, "image_url": IMAGE},
            {"tier": "silver", "name": "Silver", "threshold_value": 35_000, "image_url": IMAGE},
            {"tier": "gold", "name": "Gold", "threshold_value": 50_000, "image_url": IMAGE},
        ],
    }
    body.update(changes)
    return ChallengeCreate.model_validate(body)


@pytest.mark.anyio
async def test_a_created_challenge_is_a_draft_with_its_medals_in_tier_order(
    service: ChallengeService,
) -> None:
    challenge = await service.create(request())

    read = ChallengeRead.model_validate(challenge)
    assert (read.status.value, read.type.value, read.metric.value) == ("draft", "run", "steps")
    assert (read.city, read.landmark, read.mode.value) == ("Hà Nội", "Hồ Hoàn Kiếm", "solo")
    assert [(m.tier.value, m.threshold_value) for m in read.medals] == [
        ("bronze", 20_000),
        ("silver", 35_000),
        ("gold", 50_000),
    ]
    assert str(read.cover_image_url) == IMAGE


@pytest.mark.anyio
async def test_every_challenge_without_a_quest_shares_the_default_quest(
    service: ChallengeService, session: AsyncSession
) -> None:
    first = await service.create(request(title="One"))
    second = await service.create(request(title="Two", type="swim", target_value=20_000, medals=[]))

    assert first.quest_id == second.quest_id
    quests = await session.scalars(select(Quest).where(Quest.title == DEFAULT_QUEST_TITLE))
    assert len(quests.all()) == 1


@pytest.mark.anyio
async def test_a_swim_counts_metres(service: ChallengeService) -> None:
    challenge = await service.create(request(type="swim", target_value=20_000, medals=[]))

    assert (challenge.type, challenge.metric) == ("swim", "distance_m")


@pytest.mark.anyio
async def test_publish_then_visible_to_users(service: ChallengeService) -> None:
    created = await service.create(request())

    published = await service.publish(created.id)

    assert published.status == "published"
    assert (await service.get(created.id)).id == created.id


@pytest.mark.anyio
async def test_an_incomplete_draft_does_not_publish(service: ChallengeService) -> None:
    created = await service.create(request(cover_image_url=None, medals=[]))

    with pytest.raises(ChallengeNotPublishableError, match="a cover image, at least one medal"):
        await service.publish(created.id)

    assert (await service.get(created.id, include_drafts=True)).status == "draft"


@pytest.mark.anyio
async def test_deleting_a_draft_removes_its_medals_too(
    service: ChallengeService, session: AsyncSession
) -> None:
    created = await service.create(request())

    await service.delete(created.id)

    assert await session.scalar(select(func.count()).select_from(Medal)) == 0
    assert await session.scalar(select(func.count()).select_from(Challenge)) == 0


@pytest.mark.anyio
async def test_a_published_challenge_is_not_deleted(service: ChallengeService) -> None:
    created = await service.create(request())
    await service.publish(created.id)

    with pytest.raises(ChallengeNotDraftError):
        await service.delete(created.id)


class TestList:
    @pytest.fixture
    async def catalog(self, service: ChallengeService) -> dict[str, int]:
        swim_medal = {"tier": "gold", "name": "Gold", "threshold_value": 20_000, "image_url": IMAGE}
        ids = {}
        for key, changes, publish in [
            ("old_quarter", {}, True),
            (
                "my_khe",
                {
                    "title": "Mỹ Khê Bay 20 km",
                    "type": "swim",
                    "target_value": 20_000,
                    "city": "Đà Nẵng",
                    "landmark": "Bãi biển Mỹ Khê",
                    "medals": [swim_medal],
                },
                True,
            ),
            ("draft", {"title": "Hidden draft"}, False),
            ("percent", {"title": "100% Club", "city": "Huế", "landmark": None}, True),
            (
                "underscore",
                {
                    "title": "A_B Ride",
                    "type": "cycle",
                    "target_value": 20_000,
                    "city": "Cần Thơ",
                    "landmark": None,
                    "medals": [swim_medal],
                },
                True,
            ),
        ]:
            challenge = await service.create(request(**changes))
            if publish:
                await service.publish(challenge.id)
            ids[key] = challenge.id
        return ids

    @pytest.mark.anyio
    async def test_users_see_only_published_challenges(
        self, service: ChallengeService, catalog: dict[str, int]
    ) -> None:
        listed = await service.list_challenges()

        assert catalog["draft"] not in [c.id for c in listed]
        assert [c.id for c in listed] == sorted(c.id for c in listed)
        assert len(listed) == 4

    @pytest.mark.anyio
    async def test_an_admin_can_see_drafts(
        self, service: ChallengeService, catalog: dict[str, int]
    ) -> None:
        listed = await service.list_challenges(include_drafts=True)

        assert catalog["draft"] in [c.id for c in listed]

    @pytest.mark.anyio
    async def test_filters_by_type(
        self, service: ChallengeService, catalog: dict[str, int]
    ) -> None:
        swims = await service.list_challenges(challenge_type=ChallengeType.SWIM)

        assert [c.id for c in swims] == [catalog["my_khe"]]

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("search", "key"),
        [
            ("old quarter", "old_quarter"),
            ("hoàn kiếm", "old_quarter"),
            ("ĐÀ NẴNG", "my_khe"),
            ("mỹ khê", "my_khe"),
        ],
    )
    async def test_search_matches_title_city_and_landmark_ignoring_case(
        self, service: ChallengeService, catalog: dict[str, int], search: str, key: str
    ) -> None:
        found = await service.list_challenges(search=search)

        assert [c.id for c in found] == [catalog[key]]

    @pytest.mark.anyio
    async def test_search_treats_wildcards_as_text(
        self, service: ChallengeService, catalog: dict[str, int]
    ) -> None:
        assert [c.id for c in await service.list_challenges(search="%")] == [catalog["percent"]]
        assert [c.id for c in await service.list_challenges(search="_")] == [catalog["underscore"]]

    @pytest.mark.anyio
    async def test_pages_by_id(self, service: ChallengeService, catalog: dict[str, int]) -> None:
        first = await service.list_challenges(limit=2)
        second = await service.list_challenges(limit=2, after_id=first[-1].id)

        assert len(first) == 2 and len(second) == 2
        assert {c.id for c in first}.isdisjoint(c.id for c in second)


class TestConstraints:
    async def insert(self, session: AsyncSession, **changes: Any) -> None:
        values = {
            "quest_id": await self.quest_id(session),
            "title": "x",
            "type": "run",
            "metric": "steps",
            "target_value": 10,
            "mode": "solo",
            "status": "draft",
            "starts_at": NOW,
            "ends_at": NOW + timedelta(days=1),
            **changes,
        }
        session.add(Challenge(**values))
        await session.flush()

    async def quest_id(self, session: AsyncSession) -> int:
        quest = Quest(title="q", description="")
        session.add(quest)
        await session.flush()
        return quest.id

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("changes", "constraint"),
        [
            # Two constraints fail for an unknown type or metric; PostgreSQL names one.
            ({"type": "walk"}, "ck_challenges_(type_valid|metric_matches_type)"),
            ({"metric": "calories"}, "ck_challenges_(metric_valid|metric_matches_type)"),
            ({"type": "run", "metric": "distance_m"}, "ck_challenges_metric_matches_type"),
            ({"type": "swim", "metric": "steps"}, "ck_challenges_metric_matches_type"),
            ({"mode": "team"}, "ck_challenges_mode_valid"),
            ({"status": "archived"}, "ck_challenges_status_valid"),
            ({"target_value": 0}, "ck_challenges_target_value_positive"),
            ({"ends_at": NOW}, "ck_challenges_window_valid"),
        ],
    )
    async def test_the_database_refuses_an_invalid_challenge(
        self, session: AsyncSession, changes: dict[str, Any], constraint: str
    ) -> None:
        with pytest.raises(IntegrityError, match=constraint):
            await self.insert(session, **changes)

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("kind", "metric"), [("run", "steps"), ("swim", "distance_m"), ("cycle", "distance_m")]
    )
    async def test_each_type_pairs_with_its_metric(
        self, session: AsyncSession, kind: str, metric: str
    ) -> None:
        await self.insert(session, type=kind, metric=metric)

    @pytest.mark.anyio
    async def test_a_medal_tier_is_unique_per_challenge_and_valid(
        self, session: AsyncSession
    ) -> None:
        await self.insert(session)
        challenge_id = await session.scalar(select(Challenge.id))

        def medal(tier: str, threshold: int = 5) -> Medal:
            return Medal(
                challenge_id=challenge_id,
                tier=tier,
                threshold_value=threshold,
                name="m",
                image_url=IMAGE,
            )

        session.add(medal("gold"))
        await session.flush()
        session.add(medal("gold", 6))
        with pytest.raises(IntegrityError, match="uq_medals_challenge_id_tier"):
            await session.flush()

    @pytest.mark.anyio
    @pytest.mark.parametrize(
        ("tier", "threshold", "constraint"),
        [
            ("platinum", 5, "ck_medals_tier_valid"),
            ("gold", 0, "ck_medals_threshold_value_positive"),
        ],
    )
    async def test_the_database_refuses_an_invalid_medal(
        self, session: AsyncSession, tier: str, threshold: int, constraint: str
    ) -> None:
        await self.insert(session)
        challenge_id = await session.scalar(select(Challenge.id))
        session.add(
            Medal(
                challenge_id=challenge_id,
                tier=tier,
                threshold_value=threshold,
                name="m",
                image_url=IMAGE,
            )
        )

        with pytest.raises(IntegrityError, match=constraint):
            await session.flush()

    @pytest.mark.anyio
    async def test_new_rows_default_to_draft_run_steps_solo(self, session: AsyncSession) -> None:
        quest_id = await self.quest_id(session)
        await session.execute(
            text(
                "INSERT INTO challenges (quest_id, title, target_value, starts_at, ends_at) "
                "VALUES (:q, 'x', 5, :s, :e)"
            ),
            {"q": quest_id, "s": NOW, "e": NOW + timedelta(days=1)},
        )

        row = (
            await session.execute(text("SELECT type, metric, mode, status FROM challenges"))
        ).one()

        assert tuple(row) == ("run", "steps", "solo", "draft")
