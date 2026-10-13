from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import event, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import selectinload

from app.core.database import Base
from app.models import Challenge, Medal, Quest, Run, StepSample
from app.schemas.quest import QuestRead

START = datetime(2026, 10, 1, tzinfo=UTC)


@pytest.fixture
async def session() -> AsyncIterator[AsyncSession]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    event.listen(
        engine.sync_engine, "connect", lambda conn, _: conn.execute("PRAGMA foreign_keys=ON")
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as session:
        yield session
    await engine.dispose()


def make_quest() -> Quest:
    challenge = Challenge(
        title="10k steps",
        target_steps=10_000,
        starts_at=START,
        ends_at=START + timedelta(days=1),
        medal=Medal(name="First 10k", image_url="https://storage.example.com/medals/10k.png"),
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
        select(Quest).options(selectinload(Quest.challenges).selectinload(Challenge.medal))
    )

    assert quest is not None
    challenge = quest.challenges[0]
    assert challenge.medal is not None
    assert challenge.medal.image_url == "https://storage.example.com/medals/10k.png"
    assert QuestRead.model_validate(quest).challenges[0].medal is not None


@pytest.mark.anyio
async def test_run_keeps_its_samples(session: AsyncSession) -> None:
    quest = make_quest()
    run = Run(user_id="user-1", challenge=quest.challenges[0], started_at=START)
    run.samples = [make_sample("a"), make_sample("b", steps=250)]
    session.add(run)
    await session.commit()

    stored = await session.scalar(select(Run).options(selectinload(Run.samples)))

    assert stored is not None
    assert sorted(s.health_record_id for s in stored.samples) == ["a", "b"]


@pytest.mark.anyio
async def test_health_record_id_is_unique_per_run(session: AsyncSession) -> None:
    quest = make_quest()
    run = Run(user_id="user-1", challenge=quest.challenges[0], started_at=START)
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
    first = Run(user_id="user-1", challenge=challenge, started_at=START)
    second = Run(user_id="user-1", challenge=challenge, started_at=START)
    first.samples = [make_sample("shared")]
    second.samples = [make_sample("shared")]
    session.add_all([first, second])

    await session.commit()

    assert first.id != second.id
