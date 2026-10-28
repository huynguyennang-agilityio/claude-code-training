"""Reading the profile, with the repository mocked.

The route and the table's checks are in `tests/integration/test_profile_api.py`.
"""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.modules.profile.models import UserProfile
from app.modules.profile.repository import ProfileRepository
from app.modules.profile.schemas import ProfileWrite
from app.modules.profile.service import ProfileService
from tests.api_docs import load_example

USER = uuid.UUID("00000000-0000-0000-0000-000000000001")


def service(row: UserProfile | None) -> tuple[ProfileService, AsyncMock]:
    repository = MagicMock(spec=ProfileRepository)
    repository.get = AsyncMock(return_value=row)
    return ProfileService(AsyncMock(), repository), repository.get


@pytest.mark.anyio
async def test_a_user_without_a_row_gets_the_empty_profile() -> None:
    profiles, get = service(None)

    profile = await profiles.get(USER)

    get.assert_awaited_once_with(USER)
    assert profile.model_dump(mode="json") == load_example("profile/profile_empty.json")


@pytest.mark.anyio
async def test_a_stored_row_is_returned_as_the_documented_shape() -> None:
    row = UserProfile(
        user_id=USER,
        first_name="Max",
        last_name="Darsonval",
        birthday=date(1991, 6, 24),
        country="US",
        state="California",
        gender="male",
        unit_system="imperial",
        height_cm=Decimal("180.3"),
        weight_kg=Decimal("84.4"),
        updated_at=datetime(2026, 11, 3, tzinfo=UTC),
    )
    profiles, _ = service(row)

    profile = await profiles.get(USER)

    assert profile.model_dump(mode="json") == load_example("profile/profile.json")


NOW = datetime(2026, 11, 3, 22, 0, tzinfo=UTC)


@pytest.mark.anyio
async def test_replace_upserts_with_the_time_and_commits_after_the_write() -> None:
    data = ProfileWrite.model_validate(load_example("profile/profile_put_request.json"))
    row = UserProfile(user_id=USER, **data.model_dump(), updated_at=NOW)
    calls: list[str] = []
    repository = MagicMock(spec=ProfileRepository)
    repository.upsert = AsyncMock(side_effect=lambda *_: calls.append("upsert") or row)
    session = AsyncMock()
    session.commit.side_effect = lambda: calls.append("commit")
    profiles = ProfileService(session, repository, now=lambda: NOW)

    saved = await profiles.replace(USER, data)

    values = repository.upsert.await_args.args[1]
    assert repository.upsert.await_args.args[0] == USER
    assert values["updated_at"] == NOW
    assert values["first_name"] == "Max"
    assert calls == ["upsert", "commit"]
    assert saved.model_dump(mode="json") == load_example("profile/profile.json")
