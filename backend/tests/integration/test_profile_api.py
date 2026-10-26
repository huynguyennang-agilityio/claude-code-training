"""`GET /users/me/profile`, against PostgreSQL and real tokens."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from httpx import AsyncClient
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
