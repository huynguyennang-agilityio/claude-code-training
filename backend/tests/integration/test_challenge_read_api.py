"""The list and detail routes, against PostgreSQL and real tokens."""

from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.api_docs import load_example
from tests.integration.enrollment_helpers import add_user, join_directly
from tests.integration.query_counter import QueryCounter
from tests.integration.test_auth_api import PREFIX
from tests.integration.test_challenge_admin_api import (  # noqa: F401  (fixtures)
    _settings,
    admin,
    auth_settings,
    client,
    create,
    storage,
    user,
)

__all__ = ["_settings", "admin", "auth_settings", "client", "storage", "user"]

MAX_QUERIES_FOR_THE_LIST = 5  # user, challenges, medals, participant counts, enrollments
MAX_QUERIES_FOR_THE_DETAIL = 6  # user, challenge, medals, enrollment, participants, blocking


async def publish(client: AsyncClient, admin: dict[str, str], **changes: Any) -> dict[str, Any]:
    challenge = await create(client, admin, ends_at="2099-01-01T00:00:00Z", **changes)
    response = await client.post(f"{PREFIX}/challenges/{challenge['id']}/publish", headers=admin)
    assert response.status_code == 200, response.text
    return dict(response.json())


@pytest.mark.anyio
async def test_the_list_needs_a_token(client: AsyncClient) -> None:
    assert (await client.get(f"{PREFIX}/challenges")).status_code == 401


@pytest.mark.anyio
async def test_the_list_holds_published_challenges_only(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    published = await publish(client, admin, title="Visible")
    await create(client, admin, title="Hidden draft")

    page = (await client.get(f"{PREFIX}/challenges", headers=user)).json()

    assert [item["id"] for item in page["items"]] == [published["id"]]
    assert page["next_cursor"] is None


@pytest.mark.anyio
async def test_a_card_has_the_documented_fields(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    await publish(client, admin)

    card = (await client.get(f"{PREFIX}/challenges", headers=user)).json()["items"][0]

    expected = load_example("challenges/challenge_page.json")["items"][0]
    assert set(card) == set(expected)
    assert (card["participant_count"], card["enrollment"]) == (0, None)


@pytest.mark.anyio
async def test_the_list_filters_by_type_and_searches(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    run = await publish(client, admin, title="Lake loop", city="Hà Nội", landmark=None)
    swim = await publish(
        client,
        admin,
        title="Bay swim",
        type="swim",
        target_value=1000,
        city="Đà Nẵng",
        landmark=None,
        medals=[
            {
                "tier": "gold",
                "name": "Gold",
                "threshold_value": 1000,
                "image_url": "https://res.cloudinary.com/demo/image/upload/g.png",
            }
        ],
    )

    async def ids(**params: str) -> list[int]:
        response = await client.get(f"{PREFIX}/challenges", params=params, headers=user)
        assert response.status_code == 200, response.text
        return [item["id"] for item in response.json()["items"]]

    assert await ids(type="swim") == [swim["id"]]
    assert await ids(q="LAKE") == [run["id"]]
    assert await ids(q="đà nẵng") == [swim["id"]]
    assert await ids(q="%") == []
    assert await ids(type="run", q="bay") == []


@pytest.mark.anyio
async def test_the_list_pages_with_a_cursor(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    made = [(await publish(client, admin, title=f"Challenge {n}"))["id"] for n in range(5)]

    seen: list[int] = []
    cursor: str | None = None
    pages = 0
    while True:
        params: dict[str, Any] = {"limit": 2, **({"cursor": cursor} if cursor else {})}
        page = (await client.get(f"{PREFIX}/challenges", params=params, headers=user)).json()
        seen += [item["id"] for item in page["items"]]
        pages += 1
        cursor = page["next_cursor"]
        if cursor is None:
            break

    assert seen == made
    assert pages == 3


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("params", "code"),
    [
        ({"cursor": "not-a-cursor"}, "invalid_cursor"),
        ({"cursor": "MA"}, "invalid_cursor"),
        ({"cursor": "a b"}, "validation_error"),
        ({"limit": 0}, "validation_error"),
        ({"limit": 51}, "validation_error"),
        ({"type": "walk"}, "validation_error"),
        ({"q": "x" * 101}, "validation_error"),
        ({"status": "archived"}, "validation_error"),
        ({"colour": "red"}, "validation_error"),
    ],
)
async def test_bad_query_values_are_validation_errors(
    client: AsyncClient, user: dict[str, str], params: dict[str, Any], code: str
) -> None:
    response = await client.get(f"{PREFIX}/challenges", params=params, headers=user)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == code


@pytest.mark.anyio
async def test_only_an_admin_lists_drafts(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    draft = await create(client, admin, title="Draft")
    await publish(client, admin, title="Live")

    forbidden = await client.get(f"{PREFIX}/challenges", params={"status": "draft"}, headers=user)
    drafts = await client.get(f"{PREFIX}/challenges", params={"status": "draft"}, headers=admin)

    assert (forbidden.status_code, forbidden.json()["error"]["code"]) == (403, "forbidden")
    assert [item["id"] for item in drafts.json()["items"]] == [draft["id"]]


@pytest.mark.anyio
async def test_the_detail_has_the_documented_fields_and_the_checkpoints(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    challenge = await publish(client, admin)

    response = await client.get(f"{PREFIX}/challenges/{challenge['id']}", headers=user)

    assert response.status_code == 200
    detail = response.json()
    assert set(detail) == set(load_example("challenges/challenge_detail.json"))
    assert [m["tier"] for m in detail["medals"]] == ["bronze", "gold"]
    assert (detail["enrollment"], detail["blocked_by"]) == (None, None)


@pytest.mark.anyio
async def test_a_draft_is_not_found_for_a_user_but_open_to_an_admin(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    draft = await create(client, admin)
    url = f"{PREFIX}/challenges/{draft['id']}"

    hidden = await client.get(url, headers=user)
    seen = await client.get(url, headers=admin)

    assert (hidden.status_code, hidden.json()["error"]["code"]) == (404, "challenge_not_found")
    assert seen.status_code == 200


@pytest.mark.anyio
@pytest.mark.parametrize("challenge_id", [9999, 0, 2**31])
async def test_an_unknown_or_impossible_id_is_not_a_server_error(
    client: AsyncClient, user: dict[str, str], challenge_id: int
) -> None:
    response = await client.get(f"{PREFIX}/challenges/{challenge_id}", headers=user)

    assert response.status_code in (404, 422)


@pytest.mark.anyio
async def test_participants_are_counted(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str], session: AsyncSession
) -> None:
    challenge = await publish(client, admin)
    for number in range(3):
        await join_directly(session, challenge["id"], await add_user(session, f"u{number}"))
    await join_directly(session, challenge["id"], await add_user(session, "gone"), status="left")

    detail = (await client.get(f"{PREFIX}/challenges/{challenge['id']}", headers=user)).json()
    card = (await client.get(f"{PREFIX}/challenges", headers=user)).json()["items"][0]

    assert detail["participant_count"] == 3
    assert card["participant_count"] == 3


@pytest.mark.anyio
@pytest.mark.parametrize("rows", [1, 6])
async def test_the_list_costs_a_fixed_number_of_queries(
    client: AsyncClient,
    admin: dict[str, str],
    user: dict[str, str],
    session: AsyncSession,
    query_counter: QueryCounter,
    rows: int,
) -> None:
    for number in range(rows):
        await publish(client, admin, title=f"Challenge {number}")
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.get(f"{PREFIX}/challenges", headers=user)

    assert len(response.json()["items"]) == rows
    assert len(queries) <= MAX_QUERIES_FOR_THE_LIST, queries.text()


@pytest.mark.anyio
async def test_the_detail_costs_a_fixed_number_of_queries(
    client: AsyncClient,
    admin: dict[str, str],
    user: dict[str, str],
    session: AsyncSession,
    query_counter: QueryCounter,
) -> None:
    challenge = await publish(client, admin)
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.get(f"{PREFIX}/challenges/{challenge['id']}", headers=user)

    assert response.status_code == 200
    assert len(queries) <= MAX_QUERIES_FOR_THE_DETAIL, queries.text()
