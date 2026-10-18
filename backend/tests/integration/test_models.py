from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.challenges.schemas import QuestRead
from app.modules.models import Challenge, Medal, Quest, Run, StepSample
from tests.integration.enrollment_helpers import add_user, make_run

START = datetime(2026, 10, 1, tzinfo=UTC)


def make_quest() -> Quest:
    challenge = Challenge(
        title="10k steps",
        type="run",
        metric="steps",
        target_value=10_000,
        starts_at=START,
        ends_at=START + timedelta(days=1),
        medals=[
            Medal(
                tier="gold",
                threshold_value=10_000,
                name="First 10k",
                image_url="https://res.cloudinary.com/demo/image/upload/medals/10k.png",
            )
        ],
    )
    return Quest(title="October quest", description="Walk every day", challenges=[challenge])


def make_sample(record_id: str, steps: int = 100) -> StepSample:
    return StepSample(
        health_record_id=record_id,
        start_time=START,
        end_time=START + timedelta(minutes=5),
        steps=steps,
    )


@pytest.mark.anyio
async def test_quest_challenge_medal_relationships(session: AsyncSession) -> None:
    session.add(make_quest())
    await session.commit()

    quest = await session.scalar(
        select(Quest).options(selectinload(Quest.challenges).selectinload(Challenge.medals))
    )

    assert quest is not None
    challenge = quest.challenges[0]
    assert [medal.tier for medal in challenge.medals] == ["gold"]
    assert (
        challenge.medals[0].image_url
        == "https://res.cloudinary.com/demo/image/upload/medals/10k.png"
    )
    assert len(QuestRead.model_validate(quest).challenges[0].medals) == 1


@pytest.mark.anyio
async def test_run_keeps_its_samples(session: AsyncSession) -> None:
    quest = make_quest()
    run = make_run(await add_user(session), quest.challenges[0])
    run.samples = [make_sample("a"), make_sample("b", steps=250)]
    session.add(run)
    await session.commit()

    stored = await session.scalar(select(Run).options(selectinload(Run.samples)))

    assert stored is not None
    assert sorted(s.health_record_id for s in stored.samples) == ["a", "b"]


@pytest.mark.anyio
async def test_health_record_id_is_unique_per_run(session: AsyncSession) -> None:
    quest = make_quest()
    run = make_run(await add_user(session), quest.challenges[0])
    run.samples = [make_sample("same"), make_sample("same")]
    session.add(run)

    with pytest.raises(IntegrityError):
        await session.commit()


@pytest.mark.anyio
async def test_challenge_rejects_inverted_window(session: AsyncSession) -> None:
    quest = make_quest()
    quest.challenges[0].ends_at = START - timedelta(hours=1)
    session.add(quest)

    with pytest.raises(IntegrityError):
        await session.commit()


@pytest.mark.anyio
async def test_same_record_can_count_for_two_runs(session: AsyncSession) -> None:
    quest = make_quest()
    challenge = quest.challenges[0]
    first = make_run(await add_user(session), challenge)
    second = make_run(await add_user(session), challenge)
    first.samples = [make_sample("shared")]
    second.samples = [make_sample("shared")]
    session.add_all([first, second])

    await session.commit()

    assert first.id != second.id
