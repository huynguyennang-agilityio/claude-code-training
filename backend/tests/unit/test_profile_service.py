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
from app.modules.profile.service import ProfileService
from tests.api_docs import load_example

USER = uuid.UUID("00000000-0000-0000-0000-000000000001")


def service(row: UserProfile | None) -> tuple[ProfileService, AsyncMock]:
    repository = MagicMock(spec=ProfileRepository)
    repository.get = AsyncMock(return_value=row)
    return ProfileService(repository), repository.get


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
