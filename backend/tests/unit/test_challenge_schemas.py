from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from pydantic import ValidationError

from app.modules.challenges.models import ChallengeType
from app.modules.challenges.schemas import ChallengeCreate

START = datetime(2026, 10, 1, tzinfo=UTC)
IMAGE = "https://res.cloudinary.com/demo/image/upload/medal.png"


def medal(tier: str, threshold: int) -> dict[str, Any]:
    return {"tier": tier, "name": f"{tier} medal", "threshold_value": threshold, "image_url": IMAGE}


def valid(**changes: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "title": "Old Quarter 50K Steps",
        "type": "run",
        "target_value": 50_000,
        "starts_at": START,
        "ends_at": START + timedelta(days=30),
        "medals": [medal("bronze", 20_000), medal("silver", 35_000), medal("gold", 50_000)],
    }
    body.update(changes)
    return body


def errors(**changes: Any) -> list[str]:
    with pytest.raises(ValidationError) as raised:
        ChallengeCreate.model_validate(valid(**changes))
    return [f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in raised.value.errors()]


def test_a_complete_challenge_is_valid() -> None:
    challenge = ChallengeCreate.model_validate(valid())

    assert challenge.type is ChallengeType.RUN
    assert challenge.quest_id is None
    assert [m.threshold_value for m in challenge.medals] == [20_000, 35_000, 50_000]


def test_only_a_title_a_type_a_target_and_a_window_are_required() -> None:
    challenge = ChallengeCreate.model_validate(
        {
            "title": "  Hill climb  ",
            "type": "cycle",
            "target_value": 300,
            "starts_at": START,
            "ends_at": START + timedelta(days=1),
        }
    )

    assert challenge.title == "Hill climb"
    assert challenge.medals == []
    assert challenge.cover_image_url is None


@pytest.mark.parametrize(
    "changes",
    [
        {"title": ""},
        {"title": "   "},
        {"title": "x" * 121},
        {"type": "walk"},
        {"target_value": 0},
        {"target_value": -5},
        {"target_value": 10_000_001},
        {"starts_at": datetime(2026, 10, 1)},  # no timezone
        {"cover_image_url": "not a url"},
        {"city": " "},
        {"landmark": "x" * 121},
        {"description_md": "x" * 20_001},
        {"quest_id": "abc"},
    ],
)
def test_invalid_fields_are_refused(changes: dict[str, Any]) -> None:
    assert errors(**changes)


def test_the_window_must_end_after_it_starts() -> None:
    assert errors(ends_at=START) == ["ends_at: Value error, ends_at must be after starts_at."]
    assert errors(ends_at=START - timedelta(days=1))


def test_a_medal_cannot_have_a_bad_threshold_or_url() -> None:
    assert errors(medals=[medal("gold", 0)])
    assert errors(medals=[{**medal("gold", 50_000), "image_url": "nope"}])
    assert errors(medals=[{**medal("gold", 50_000), "name": ""}])
    assert errors(medals=[{**medal("platinum", 50_000)}])


def test_a_challenge_has_at_most_one_medal_per_tier() -> None:
    assert (
        "at most one medal per tier"
        in errors(medals=[medal("bronze", 10_000), medal("bronze", 20_000)])[0]
    )


def test_a_higher_tier_asks_for_more() -> None:
    assert (
        "more than the tier below"
        in errors(medals=[medal("bronze", 30_000), medal("silver", 30_000)])[0]
    )
    assert (
        "more than the tier below"
        in errors(medals=[medal("silver", 10_000), medal("bronze", 20_000)])[0]
    )


def test_the_order_of_the_list_does_not_matter() -> None:
    challenge = ChallengeCreate.model_validate(
        valid(medals=[medal("gold", 50_000), medal("bronze", 20_000)])
    )

    assert {m.tier.value for m in challenge.medals} == {"gold", "bronze"}


def test_a_medal_cannot_ask_for_more_than_the_target() -> None:
    assert "more than the target" in errors(medals=[medal("bronze", 50_001)])[0]


def test_the_gold_medal_is_earned_at_the_target() -> None:
    assert "gold medal is earned at the target" in errors(medals=[medal("gold", 40_000)])[0]
    # Without a gold medal, the lower tiers are free below the target.
    assert ChallengeCreate.model_validate(valid(medals=[medal("silver", 40_000)]))


def test_at_most_three_medals() -> None:
    assert errors(medals=[medal("bronze", 1)] * 4)
