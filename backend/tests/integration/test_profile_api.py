"""`GET /users/me/profile`, against PostgreSQL and real tokens."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import User
from app.modules.profile.models import UserProfile
from tests.api_docs import load_example
from tests.integration.test_auth_api import PREFIX, bearer, sign_up
from tests.integration.test_challenge_admin_api import (  # noqa: F401  (fixtures)
    _settings,
    auth_settings,
    client,
    storage,
    user,
)

__all__ = ["_settings", "auth_settings", "client", "storage", "user"]

URL = f"{PREFIX}/users/me/profile"


def profile_row(user_id: uuid.UUID, **changes: object) -> UserProfile:
    values: dict[str, object] = {
        "first_name": "Max",
        "last_name": "Darsonval",
        "birthday": date(1991, 6, 24),
        "country": "US",
        "state": "California",
        "gender": "male",
        "unit_system": "imperial",
        "height_cm": Decimal("180.3"),
        "weight_kg": Decimal("84.4"),
        "updated_at": datetime.now(UTC),
    }
    values.update(changes)
    return UserProfile(user_id=user_id, **values)


@pytest.mark.anyio
async def test_it_needs_a_token(client: AsyncClient) -> None:
    response = await client.get(URL)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


@pytest.mark.anyio
async def test_a_user_without_a_row_gets_the_empty_profile(
    client: AsyncClient, user: dict[str, str]
) -> None:
    response = await client.get(URL, headers=user)

    assert response.status_code == 200
    assert response.json() == load_example("profile/profile_empty.json")


@pytest.mark.anyio
async def test_the_own_profile_is_returned_with_numbers_as_json_numbers(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    me = (await client.get(f"{PREFIX}/users/me", headers=user)).json()["id"]
    session.add(profile_row(uuid.UUID(me)))
    await session.flush()

    response = await client.get(URL, headers=user)

    assert response.status_code == 200
    assert response.json() == load_example("profile/profile.json")
    assert isinstance(response.json()["height_cm"], float)


@pytest.mark.anyio
async def test_another_users_row_never_appears(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    other = await sign_up(client, email="other@example.com")
    session.add(profile_row(uuid.UUID(other["user"]["id"])))
    await session.flush()

    mine = await client.get(URL, headers=user)
    theirs = await client.get(URL, headers=bearer(other["tokens"]["access_token"]))

    assert mine.json() == load_example("profile/profile_empty.json")
    assert theirs.json() == load_example("profile/profile.json")


@pytest.mark.anyio
async def test_the_row_is_deleted_with_the_user(client: AsyncClient, session: AsyncSession) -> None:
    created = await sign_up(client, email="gone@example.com")
    owner = uuid.UUID(created["user"]["id"])
    session.add(profile_row(owner))
    await session.flush()

    await session.delete(await session.get(User, owner))
    await session.flush()
    session.expire_all()

    assert await session.get(UserProfile, owner) is None


@pytest.mark.anyio
@pytest.mark.parametrize(
    "changes",
    [
        {"gender": "robot"},
        {"unit_system": "stone"},
        {"height_cm": Decimal("49.9")},
        {"height_cm": Decimal("272.1")},
        {"weight_kg": Decimal("19.9")},
        {"weight_kg": Decimal("400.1")},
    ],
)
async def test_the_table_refuses_values_outside_the_rules(
    client: AsyncClient, session: AsyncSession, changes: dict[str, object]
) -> None:
    created = await sign_up(client, email="checks@example.com")
    session.add(profile_row(uuid.UUID(created["user"]["id"]), **changes))

    with pytest.raises(IntegrityError):
        async with session.begin_nested():
            await session.flush()


# PUT


def put_body(**changes: object) -> dict[str, object]:
    body: dict[str, object] = dict(load_example("profile/profile_put_request.json"))
    body.update(changes)
    return body


async def stored(session: AsyncSession, owner: uuid.UUID) -> UserProfile | None:
    session.expire_all()
    return await session.get(UserProfile, owner)


@pytest.mark.anyio
async def test_put_needs_a_token(client: AsyncClient) -> None:
    response = await client.put(URL, json=put_body())

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


@pytest.mark.anyio
async def test_the_first_save_creates_the_row_and_get_returns_it(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    response = await client.put(URL, json=put_body(), headers=user)

    assert response.status_code == 200, response.text
    assert response.json() == load_example("profile/profile.json")
    assert (await client.get(URL, headers=user)).json() == load_example("profile/profile.json")
    owner = uuid.UUID((await client.get(f"{PREFIX}/users/me", headers=user)).json()["id"])
    row = await stored(session, owner)
    assert row is not None
    assert (row.first_name, row.height_cm, row.unit_system) == ("Max", Decimal("180.3"), "imperial")


@pytest.mark.anyio
async def test_a_later_save_replaces_every_field_and_null_clears_a_value(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    await client.put(URL, json=put_body(), headers=user)
    changed = put_body(
        first_name="Lan", last_name=None, birthday=None, state=None, weight_kg=None,
        unit_system="metric",
    )  # fmt: skip

    response = await client.put(URL, json=changed, headers=user)

    assert response.status_code == 200
    assert response.json() == changed
    assert (await client.get(URL, headers=user)).json() == changed
    owner = uuid.UUID((await client.get(f"{PREFIX}/users/me", headers=user)).json()["id"])
    rows = list(await session.scalars(select(UserProfile).where(UserProfile.user_id == owner)))
    assert len(rows) == 1


@pytest.mark.anyio
async def test_a_save_of_all_nulls_reads_as_the_empty_profile(
    client: AsyncClient, user: dict[str, str]
) -> None:
    await client.put(URL, json=put_body(), headers=user)
    empty = load_example("profile/profile_empty.json")

    response = await client.put(URL, json=empty, headers=user)

    assert response.status_code == 200
    assert response.json() == empty


@pytest.mark.anyio
async def test_the_text_is_stored_trimmed(client: AsyncClient, user: dict[str, str]) -> None:
    response = await client.put(URL, json=put_body(first_name="  Max  "), headers=user)

    assert response.json()["first_name"] == "Max"


@pytest.mark.anyio
async def test_one_user_never_changes_anothers_profile(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    other = await sign_up(client, email="other@example.com")
    other_headers = bearer(other["tokens"]["access_token"])
    await client.put(URL, json=put_body(first_name="Other"), headers=other_headers)

    await client.put(URL, json=put_body(first_name="Mine", country="VN"), headers=user)

    theirs = (await client.get(URL, headers=other_headers)).json()
    assert (theirs["first_name"], theirs["country"]) == ("Other", "US")
    assert (await client.get(URL, headers=user)).json()["first_name"] == "Mine"
    assert len(list(await session.scalars(select(UserProfile)))) == 2


@pytest.mark.anyio
async def test_a_broken_rule_answers_422_naming_each_field_and_stores_nothing(
    client: AsyncClient, user: dict[str, str], session: AsyncSession
) -> None:
    response = await client.put(URL, json=put_body(country="us", height_cm=300), headers=user)

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["fields"] == load_example("profile/error_validation.json")["error"]["fields"]
    assert (await client.get(URL, headers=user)).json() == load_example(
        "profile/profile_empty.json"
    )
    assert list(await session.scalars(select(UserProfile))) == []


@pytest.mark.anyio
async def test_a_missing_key_and_a_null_unit_system_are_422(
    client: AsyncClient, user: dict[str, str]
) -> None:
    body = put_body(unit_system=None)
    del body["state"]

    response = await client.put(URL, json=body, headers=user)

    assert response.status_code == 422
    assert {f["field"] for f in response.json()["error"]["fields"]} == {"state", "unit_system"}


@pytest.mark.anyio
async def test_a_failed_validation_keeps_the_stored_profile(
    client: AsyncClient, user: dict[str, str]
) -> None:
    await client.put(URL, json=put_body(), headers=user)

    response = await client.put(URL, json=put_body(first_name="   "), headers=user)

    assert response.status_code == 422
    assert (await client.get(URL, headers=user)).json() == load_example("profile/profile.json")
