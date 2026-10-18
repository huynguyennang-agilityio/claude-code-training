"""The admin routes that write the challenge catalog, against PostgreSQL and real tokens.

Cloudinary is replaced by a fake storage; `tests/unit/test_storage.py` covers the real one.
"""

from collections.abc import AsyncIterator
from copy import deepcopy
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session
from app.core.storage import StorageError, StorageNotConfiguredError, UploadedImage
from app.main import create_app
from app.modules.auth.deps import get_auth_settings
from app.modules.auth.models import UserRole
from app.modules.auth.repository import AuthRepository
from app.modules.auth.service import AuthService
from app.modules.challenges.deps import get_storage
from app.modules.runs.models import Run
from tests.api_docs import load_example
from tests.integration.query_counter import QueryCounter
from tests.integration.test_auth_api import (  # noqa: F401  (autouse fixture)
    PREFIX,
    SIGNUP,
    auth_settings,
    bearer,
    sign_up,
)

__all__ = ["auth_settings"]

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64
WEBP = b"RIFF\x00\x00\x00\x00WEBP" + b"\x00" * 64
MAX_QUERIES_FOR_A_CHALLENGE = 8  # challenge, quest, medals, role check and the commit


class FakeStorage:
    def __init__(self) -> None:
        self.error: Exception | None = None
        self.uploads: list[dict[str, Any]] = []

    async def upload_image(
        self, data: bytes, *, filename: str, content_type: str, kind: str
    ) -> UploadedImage:
        if self.error:
            raise self.error
        self.uploads.append({"size": len(data), "filename": filename, "type": content_type})
        return UploadedImage(
            public_id=f"stridequest/{kind}/x",
            url=f"https://res.cloudinary.com/demo/image/upload/stridequest/{kind}/x.png",
            width=100,
            height=50,
            size_bytes=len(data),
        )


@pytest.fixture
def storage() -> FakeStorage:
    return FakeStorage()


@pytest.fixture(autouse=True)
def _settings(auth_settings: None) -> None:  # noqa: PT004
    get_settings.cache_clear()


@pytest.fixture
async def client(session: AsyncSession, storage: FakeStorage) -> AsyncIterator[AsyncClient]:
    app: FastAPI = create_app()

    async def override_get_session() -> AsyncIterator[AsyncSession]:
        yield session

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_storage] = lambda: storage
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client


@pytest.fixture
async def admin(client: AsyncClient, session: AsyncSession) -> dict[str, str]:
    tokens = (await sign_up(client, email="admin@example.com"))["tokens"]
    await AuthService(session, AuthRepository(session), get_auth_settings()).set_role(
        "admin@example.com", UserRole.ADMIN
    )
    return bearer(tokens["access_token"])


@pytest.fixture
async def user(client: AsyncClient) -> dict[str, str]:
    return bearer((await sign_up(client, email=SIGNUP["email"]))["tokens"]["access_token"])


def create_body(**changes: Any) -> dict[str, Any]:
    body = deepcopy(load_example("challenges/challenge_create_request.json"))
    body.update(changes)
    return body


async def create(client: AsyncClient, admin: dict[str, str], **changes: Any) -> dict[str, Any]:
    response = await client.post(f"{PREFIX}/challenges", json=create_body(**changes), headers=admin)
    assert response.status_code == 201, response.text
    return dict(response.json())


# who may call


@pytest.mark.anyio
async def test_a_normal_user_cannot_write_the_catalog(
    client: AsyncClient, user: dict[str, str]
) -> None:
    response = await client.post(f"{PREFIX}/challenges", json=create_body(), headers=user)

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


@pytest.mark.anyio
async def test_a_call_without_a_token_is_not_authenticated(client: AsyncClient) -> None:
    response = await client.post(f"{PREFIX}/challenges", json=create_body())

    assert response.status_code == 401


# create


@pytest.mark.anyio
async def test_create_returns_the_documented_draft(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin)

    expected = load_example("challenges/challenge.json")
    assert challenge["status"] == "draft"
    assert set(challenge) == set(expected)
    assert [m["tier"] for m in challenge["medals"]] == ["bronze", "gold"]
    assert challenge["metric"] == "steps"
    assert challenge["mode"] == "solo"


@pytest.mark.anyio
async def test_create_names_every_broken_rule(client: AsyncClient, admin: dict[str, str]) -> None:
    response = await client.post(
        f"{PREFIX}/challenges", json=create_body(target_value=0, title=" "), headers=admin
    )

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert {item["field"] for item in error["fields"]} >= {"target_value", "title"}


@pytest.mark.anyio
async def test_create_with_an_unknown_quest_is_not_found(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    response = await client.post(
        f"{PREFIX}/challenges", json=create_body(quest_id=9999), headers=admin
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "quest_not_found"


@pytest.mark.anyio
async def test_a_draft_challenge_costs_a_fixed_number_of_queries(
    client: AsyncClient, admin: dict[str, str], session: AsyncSession, query_counter: QueryCounter
) -> None:
    await create(client, admin)
    session.expunge_all()

    with query_counter.measure() as queries:
        response = await client.post(f"{PREFIX}/challenges", json=create_body(), headers=admin)

    assert response.status_code == 201
    assert len(queries) <= MAX_QUERIES_FOR_A_CHALLENGE, queries.text()


# edit


@pytest.mark.anyio
async def test_edit_changes_only_what_is_sent_and_can_clear_a_field(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin)

    response = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}",
        json=load_example("challenges/challenge_update_request.json"),
        headers=admin,
    )

    assert response.status_code == 200
    edited = response.json()
    assert edited["title"] == "Hoan Kiem Lake 50K Steps"
    assert edited["city"] is None
    assert edited["landmark"] == "Hoan Kiem Lake"
    assert edited["medals"] == challenge["medals"]


@pytest.mark.anyio
async def test_edit_replaces_the_medals(client: AsyncClient, admin: dict[str, str]) -> None:
    challenge = await create(client, admin)
    gold = {**challenge["medals"][1]}
    gold.pop("id")

    response = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}", json={"medals": [gold]}, headers=admin
    )

    assert response.status_code == 200
    assert [m["tier"] for m in response.json()["medals"]] == ["gold"]


@pytest.mark.anyio
async def test_edit_that_breaks_a_rule_changes_nothing(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin)

    response = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}",
        json={"title": "Changed", "target_value": 60000},
        headers=admin,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    again = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}", json={"title": "Same"}, headers=admin
    )
    assert again.json()["target_value"] == 50000
    assert again.json()["title"] == "Same"


@pytest.mark.anyio
async def test_edit_of_an_unknown_challenge_is_not_found(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    response = await client.patch(f"{PREFIX}/challenges/9999", json={"title": "x"}, headers=admin)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "challenge_not_found"


@pytest.mark.anyio
async def test_counted_fields_are_frozen_once_someone_joined(
    client: AsyncClient, admin: dict[str, str], session: AsyncSession
) -> None:
    from datetime import UTC, datetime

    challenge = await create(client, admin)
    session.add(Run(user_id="u1", challenge_id=challenge["id"], started_at=datetime.now(UTC)))
    await session.flush()

    frozen = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}", json={"type": "swim"}, headers=admin
    )
    allowed = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}", json={"description_md": "New."}, headers=admin
    )

    assert frozen.status_code == 409
    assert frozen.json()["error"]["code"] == "challenge_in_use"
    assert allowed.status_code == 200


# publish, unpublish, delete


@pytest.mark.anyio
async def test_a_draft_is_published_unpublished_and_deleted(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin, ends_at="2099-01-01T00:00:00Z")
    url = f"{PREFIX}/challenges/{challenge['id']}"

    published = await client.post(f"{url}/publish", headers=admin)
    blocked = await client.delete(url, headers=admin)
    unpublished = await client.post(f"{url}/unpublish", headers=admin)
    deleted = await client.delete(url, headers=admin)
    gone = await client.delete(url, headers=admin)

    assert published.json()["status"] == "published"
    assert (blocked.status_code, blocked.json()["error"]["code"]) == (409, "challenge_not_draft")
    assert unpublished.json()["status"] == "draft"
    assert deleted.status_code == 204
    assert gone.status_code == 404


@pytest.mark.anyio
async def test_an_incomplete_draft_cannot_be_published(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin, cover_image_url=None, medals=[])

    response = await client.post(f"{PREFIX}/challenges/{challenge['id']}/publish", headers=admin)

    assert response.status_code == 409
    error = response.json()["error"]
    assert error["code"] == "challenge_not_publishable"
    assert "a cover image" in error["message"]
    assert "at least one medal" in error["message"]


# quests


@pytest.mark.anyio
async def test_a_quest_is_created_by_an_admin_and_listed_for_a_user(
    client: AsyncClient, admin: dict[str, str], user: dict[str, str]
) -> None:
    body = load_example("challenges/quest_create_request.json")

    forbidden = await client.post(f"{PREFIX}/quests", json=body, headers=user)
    created = await client.post(f"{PREFIX}/quests", json=body, headers=admin)
    listed = await client.get(f"{PREFIX}/quests", headers=user)

    assert forbidden.status_code == 403
    assert created.status_code == 201
    assert set(created.json()) == set(load_example("challenges/quest.json"))
    assert body["title"] in [quest["title"] for quest in listed.json()]


@pytest.mark.anyio
async def test_a_blank_quest_title_is_invalid(client: AsyncClient, admin: dict[str, str]) -> None:
    response = await client.post(f"{PREFIX}/quests", json={"title": " "}, headers=admin)

    assert response.status_code == 422


# images


async def upload(
    client: AsyncClient, headers: dict[str, str], data: bytes, kind: str = "covers"
) -> Any:
    return await client.post(
        f"{PREFIX}/images",
        data={"kind": kind},
        files={"file": ("cover.bin", data, "application/octet-stream")},
        headers=headers,
    )


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("data", "mime"), [(PNG, "image/png"), (JPEG, "image/jpeg"), (WEBP, "image/webp")]
)
async def test_an_image_is_judged_by_its_bytes_and_stored(
    client: AsyncClient, admin: dict[str, str], storage: FakeStorage, data: bytes, mime: str
) -> None:
    response = await upload(client, admin, data)

    assert response.status_code == 201, response.text
    assert set(response.json()) == set(load_example("challenges/uploaded_image.json"))
    assert storage.uploads[0]["type"] == mime


@pytest.mark.anyio
async def test_a_file_that_is_not_an_image_is_refused(
    client: AsyncClient, admin: dict[str, str], storage: FakeStorage
) -> None:
    response = await upload(client, admin, b"GIF89a" + b"\x00" * 20)

    assert response.status_code == 415
    assert response.json()["error"]["code"] == "unsupported_image_type"
    assert not storage.uploads


@pytest.mark.anyio
async def test_an_image_over_5_mb_is_refused(
    client: AsyncClient, admin: dict[str, str], storage: FakeStorage
) -> None:
    response = await upload(client, admin, PNG + b"\x00" * (5 * 1024 * 1024))

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "image_too_large"
    assert not storage.uploads


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("error", "status", "code"),
    [
        (StorageNotConfiguredError("off"), 503, "storage_not_configured"),
        (StorageError("down"), 502, "upload_failed"),
    ],
)
async def test_storage_problems_become_documented_errors(
    client: AsyncClient,
    admin: dict[str, str],
    storage: FakeStorage,
    error: Exception,
    status: int,
    code: str,
) -> None:
    storage.error = error

    response = await upload(client, admin, PNG)

    assert (response.status_code, response.json()["error"]["code"]) == (status, code)


@pytest.mark.anyio
async def test_an_unknown_image_kind_is_invalid(client: AsyncClient, admin: dict[str, str]) -> None:
    response = await upload(client, admin, PNG, kind="avatars")

    assert response.status_code == 422


@pytest.mark.anyio
async def test_only_an_admin_uploads(client: AsyncClient, user: dict[str, str]) -> None:
    assert (await upload(client, user, PNG)).status_code == 403


# input the database or the schema could not take


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("changes", "field"),
    [
        ({"title": "Bad\x00title"}, "title"),
        ({"title": "Two\nlines"}, "title"),
        ({"description_md": "Bad\x00text"}, "description_md"),
        ({"starts_at": 0}, "starts_at"),
    ],
)
async def test_text_the_database_cannot_store_is_a_validation_error(
    client: AsyncClient, admin: dict[str, str], changes: dict[str, Any], field: str
) -> None:
    response = await client.post(f"{PREFIX}/challenges", json=create_body(**changes), headers=admin)

    assert response.status_code == 422
    assert field in {item["field"] for item in response.json()["error"]["fields"]}


@pytest.mark.anyio
async def test_markdown_keeps_its_line_breaks(client: AsyncClient, admin: dict[str, str]) -> None:
    challenge = await create(client, admin, description_md="One.\n\n- two\n\tthree")

    assert challenge["description_md"] == "One.\n\n- two\n\tthree"


@pytest.mark.anyio
@pytest.mark.parametrize("challenge_id", [0, 2**31])
async def test_an_id_outside_the_integer_range_is_a_validation_error(
    client: AsyncClient, admin: dict[str, str], challenge_id: int
) -> None:
    response = await client.post(f"{PREFIX}/challenges/{challenge_id}/publish", headers=admin)

    assert response.status_code == 422


@pytest.mark.anyio
async def test_a_null_cannot_clear_a_required_field(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    challenge = await create(client, admin)

    response = await client.patch(
        f"{PREFIX}/challenges/{challenge['id']}", json={"title": None}, headers=admin
    )

    assert response.status_code == 422


@pytest.mark.anyio
async def test_an_unsupported_method_lists_every_method_of_the_path(
    client: AsyncClient, admin: dict[str, str]
) -> None:
    response = await client.post(f"{PREFIX}/challenges/1", headers=admin)

    assert response.status_code == 405
    assert response.headers["allow"] == "DELETE, GET, HEAD, PATCH"
