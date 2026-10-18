"""The demo images and the loader that creates the demo challenges through the API.

The API is a small fake behind `httpx.MockTransport`; the real routes are tested in
`tests/integration/`, and the real run against Cloudinary is in the MR's evidence.
"""

import json
from pathlib import Path
from typing import Any

import httpx
import pytest
from PIL import Image

from demo import make_images
from demo.load_demo import (
    BLOCKED_DEMO,
    DEMO_CHALLENGES,
    DemoError,
    DemoLoader,
)

IMAGES = Path(make_images.__file__).resolve().parent / "images"
CLOUDINARY_BYTES = 5 * 1024 * 1024


class FakeApi:
    """Just enough of the admin API to see what the loader asks of it."""

    def __init__(self, *, admin: bool = True) -> None:
        self.admin = admin
        self.challenges: list[dict[str, Any]] = []
        self.uploads: list[str] = []
        self.requests: list[tuple[str, str]] = []

    def handle(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path.removeprefix("/api/v1")
        self.requests.append((request.method, path))
        if path == "/auth/signin":
            ok = json.loads(request.content)["password"] == "right"
            if not ok:
                return httpx.Response(
                    401,
                    json={"error": {"code": "invalid_credentials", "message": "No.", "fields": []}},
                )
            return httpx.Response(200, json={"tokens": {"access_token": "token"}})
        if path == "/challenges" and request.method == "GET":
            return self._list(request)
        if path == "/challenges" and request.method == "POST":
            body = json.loads(request.content)
            challenge = {"id": len(self.challenges) + 1, "status": "draft", **body}
            self.challenges.append(challenge)
            return httpx.Response(201, json=challenge)
        if path.endswith("/publish"):
            challenge = self.challenges[int(path.split("/")[2]) - 1]
            challenge["status"] = "published"
            return httpx.Response(200, json=challenge)
        if path == "/images":
            name = request.content.split(b'filename="')[1].split(b'"')[0].decode()
            self.uploads.append(name)
            url = f"https://res.cloudinary.com/demo/image/upload/{name}"
            return httpx.Response(201, json={"url": url})
        return httpx.Response(404, json={"error": {"code": "not_found", "message": "?"}})

    def _list(self, request: httpx.Request) -> httpx.Response:
        status = request.url.params["status"]
        if status == "draft" and not self.admin:
            return httpx.Response(
                403, json={"error": {"code": "forbidden", "message": "No.", "fields": []}}
            )
        items = [c for c in self.challenges if c["status"] == status]
        return httpx.Response(200, json={"items": items, "next_cursor": None})


def loader_for(api: FakeApi, images: Path = IMAGES) -> DemoLoader:
    client = httpx.Client(base_url="http://test/api/v1", transport=httpx.MockTransport(api.handle))
    loader = DemoLoader(client, images)
    loader.sign_in("admin@example.com", "right")
    return loader


def test_the_images_exist_and_have_the_right_size_and_type() -> None:
    for name, _, _ in make_images.COVERS:
        with Image.open(IMAGES / f"{name}.png") as cover:
            assert (cover.format, cover.size) == ("PNG", make_images.COVER_SIZE)
    for kind in make_images.PALETTES:
        for tier in make_images.MEDAL_COLOURS:
            with Image.open(IMAGES / f"medal-{kind}-{tier}.png") as medal:
                assert (medal.format, medal.size) == ("PNG", (512, 512))
                assert medal.mode == "RGBA"


def test_every_image_the_demo_uses_is_a_file_under_the_upload_limit() -> None:
    used = {demo.cover for demo in [*DEMO_CHALLENGES, BLOCKED_DEMO]} | {
        f"medal-{demo.type}-{tier}.png"
        for demo in [*DEMO_CHALLENGES, BLOCKED_DEMO]
        for tier in ("bronze", "silver", "gold")
    }

    assert all((IMAGES / name).stat().st_size < CLOUDINARY_BYTES for name in used)


def test_generating_writes_the_same_images_again(tmp_path: Path) -> None:
    written = make_images.generate(tmp_path)

    assert len(written) == len(make_images.COVERS) + 9
    for path in written:
        # The pixels, not the file: the PNG encoder may differ between machines.
        with Image.open(path) as new, Image.open(IMAGES / path.name) as committed:
            assert new.tobytes() == committed.tobytes()


def test_the_demo_challenges_follow_the_rules_of_the_api() -> None:
    for demo in [*DEMO_CHALLENGES, BLOCKED_DEMO]:
        thresholds = [threshold for _, threshold in demo.medals]
        assert thresholds == sorted(set(thresholds)), demo.title
        assert thresholds[-1] == demo.target_value, demo.title
        assert demo.starts_at < demo.ends_at


def test_the_blocked_demo_overlaps_the_first_challenge_and_has_its_type() -> None:
    first = DEMO_CHALLENGES[0]

    assert BLOCKED_DEMO.type == first.type
    assert BLOCKED_DEMO.starts_at < first.ends_at
    assert first.starts_at < BLOCKED_DEMO.ends_at


def test_loading_creates_and_publishes_each_challenge_with_its_images() -> None:
    api = FakeApi()

    report = loader_for(api).load(DEMO_CHALLENGES)

    assert len(report) == 3
    assert [c["title"] for c in api.challenges] == [d.title for d in DEMO_CHALLENGES]
    assert {c["status"] for c in api.challenges} == {"published"}
    first = api.challenges[0]
    assert first["cover_image_url"].endswith("cover-old-quarter-50k-steps.png")
    assert [m["tier"] for m in first["medals"]] == ["bronze", "silver", "gold"]
    assert first["medals"][2]["image_url"].endswith("medal-run-gold.png")
    assert first["medals"][2]["threshold_value"] == first["target_value"]


def test_each_image_is_uploaded_once() -> None:
    api = FakeApi()

    loader_for(api).load([*DEMO_CHALLENGES, BLOCKED_DEMO])

    assert len(api.uploads) == len(set(api.uploads))
    # The blocked demo is a run too, so it reuses the run medals and adds only its cover.
    assert len(api.uploads) == 4 + 9


def test_running_it_again_creates_nothing_twice() -> None:
    api = FakeApi()
    loader_for(api).load(DEMO_CHALLENGES)
    uploads, posts = len(api.uploads), sum(1 for m, _ in api.requests if m == "POST")

    report = loader_for(api).load(DEMO_CHALLENGES)

    assert all(line.startswith("already there") for line in report)
    assert len(api.challenges) == 3
    assert len(api.uploads) == uploads
    # Only the sign in of the second loader was posted.
    assert sum(1 for m, _ in api.requests if m == "POST") == posts + 1


def test_a_draft_left_by_an_interrupted_run_is_published_not_duplicated() -> None:
    api = FakeApi()
    loader_for(api).load(DEMO_CHALLENGES[:1])
    api.challenges[0]["status"] = "draft"

    report = loader_for(api).load(DEMO_CHALLENGES[:1])

    assert report[0].startswith("published a draft")
    assert len(api.challenges) == 1
    assert api.challenges[0]["status"] == "published"


def test_a_wrong_password_is_a_readable_error() -> None:
    client = httpx.Client(
        base_url="http://test/api/v1", transport=httpx.MockTransport(FakeApi().handle)
    )

    with pytest.raises(DemoError, match="invalid_credentials"):
        DemoLoader(client, IMAGES).sign_in("admin@example.com", "wrong")


def test_an_account_that_is_not_an_admin_is_told_how_to_become_one() -> None:
    with pytest.raises(DemoError, match="create_admin"):
        loader_for(FakeApi(admin=False)).load(DEMO_CHALLENGES)


def test_a_missing_image_says_how_to_make_it(tmp_path: Path) -> None:
    with pytest.raises(DemoError, match="make_images"):
        loader_for(FakeApi(), tmp_path).load(DEMO_CHALLENGES[:1])
