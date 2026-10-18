import httpx
import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.core.storage import (
    CloudinaryStorage,
    StorageError,
    StorageNotConfiguredError,
    resized_url,
    sign_params,
)

SECRET = "s3cret"
CLOCK_NOW = 1_700_000_000.4
DELIVERY = "https://res.cloudinary.com/demo/image/upload"
UPLOAD_OK = {
    "public_id": "stridequest/challenges/covers/abc123",
    "secure_url": f"{DELIVERY}/v1700000000/stridequest/challenges/covers/abc123.png",
    "width": 1200,
    "height": 675,
    "bytes": 4321,
}


def make_storage(
    handler: httpx.MockTransport | None = None, **overrides: object
) -> CloudinaryStorage:
    options: dict[str, object] = {
        "cloud_name": "demo",
        "api_key": "key-1",
        "api_secret": SECRET,
        "folder": "stridequest",
        "transport": handler,
        "clock": lambda: CLOCK_NOW,
    }
    options.update(overrides)
    return CloudinaryStorage(**options)  # type: ignore[arg-type]


def test_signature_matches_a_digest_computed_outside_the_code() -> None:
    # printf 'folder=stridequest/challenges/covers&timestamp=1700000000s3cret' | shasum
    params = {"timestamp": "1700000000", "folder": "stridequest/challenges/covers"}

    assert sign_params(params, SECRET) == "100b7f3e00a1b92e12f8866a11e70d421b28e38d"


def test_signature_does_not_depend_on_the_order_of_the_parameters() -> None:
    assert sign_params({"a": "1", "b": "2"}, SECRET) == sign_params({"b": "2", "a": "1"}, SECRET)


class TestResizedUrl:
    def test_inserts_the_size_format_and_quality(self) -> None:
        url = f"{DELIVERY}/v1700000000/stridequest/challenges/covers/abc123.png"

        assert resized_url(url, width=640) == (
            f"{DELIVERY}/f_auto,q_auto,w_640/v1700000000/stridequest/challenges/covers/abc123.png"
        )

    def test_works_without_a_version_segment(self) -> None:
        assert resized_url(f"{DELIVERY}/sample.jpg", width=100) == (
            f"{DELIVERY}/f_auto,q_auto,w_100/sample.jpg"
        )

    def test_leaves_a_url_that_already_has_transformations(self) -> None:
        url = f"{DELIVERY}/w_200,c_fill/sample.jpg"

        assert resized_url(url, width=640) == url

    @pytest.mark.parametrize(
        "url",
        ["https://example.com/a.png", "http://res.cloudinary.com/demo/image/upload/a.png", ""],
    )
    def test_leaves_other_urls_alone(self, url: str) -> None:
        assert resized_url(url, width=640) == url


@pytest.mark.anyio
async def test_upload_sends_a_signed_multipart_request_and_returns_the_image() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json=UPLOAD_OK)

    storage = make_storage(httpx.MockTransport(handler))

    image = await storage.upload_image(
        b"\x89PNG-bytes", filename="cover.png", content_type="image/png", kind="covers"
    )

    assert image.public_id == "stridequest/challenges/covers/abc123"
    assert image.url == UPLOAD_OK["secure_url"]
    assert (image.width, image.height, image.size_bytes) == (1200, 675, 4321)
    (request,) = seen
    assert str(request.url) == "https://api.cloudinary.com/v1_1/demo/image/upload"
    body = request.read().decode("latin-1")
    for part in ('name="api_key"', "key-1", 'name="folder"', "stridequest/challenges/covers"):
        assert part in body
    assert 'name="timestamp"' in body and "1700000000" in body
    assert 'name="file"; filename="cover.png"' in body and "image/png" in body
    expected = sign_params(
        {"folder": "stridequest/challenges/covers", "timestamp": "1700000000"}, SECRET
    )
    assert expected in body


@pytest.mark.anyio
async def test_upload_never_sends_the_api_secret() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json=UPLOAD_OK)

    await make_storage(httpx.MockTransport(handler)).upload_image(
        b"x", filename="m.png", content_type="image/png", kind="medals"
    )

    (request,) = seen
    assert SECRET not in request.read().decode("latin-1")
    assert SECRET not in str(request.url) and SECRET not in str(request.headers)


@pytest.mark.anyio
async def test_upload_folder_follows_the_kind_and_the_configured_base_folder() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json=UPLOAD_OK)

    storage = make_storage(httpx.MockTransport(handler), folder="/team/dev/")

    await storage.upload_image(b"x", filename="m.png", content_type="image/png", kind="medals")

    assert "team/dev/challenges/medals" in seen[0].read().decode("latin-1")


@pytest.mark.anyio
async def test_a_refused_upload_becomes_a_storage_error_without_the_secret() -> None:
    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"error": {"message": "Invalid Signature"}})

    storage = make_storage(httpx.MockTransport(handler))

    with pytest.raises(StorageError, match="401.*Invalid Signature") as raised:
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")
    assert SECRET not in str(raised.value)


@pytest.mark.anyio
@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(200, text="<html>not json</html>"),
        httpx.Response(200, json={"public_id": "only-this"}),
        httpx.Response(200, json=["not", "an", "object"]),
        httpx.Response(500, text="Bad gateway"),
    ],
)
async def test_an_unexpected_response_becomes_a_storage_error(response: httpx.Response) -> None:
    storage = make_storage(httpx.MockTransport(lambda _: response))

    with pytest.raises(StorageError):
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")


@pytest.mark.anyio
async def test_a_failure_with_an_html_body_keeps_the_status_code() -> None:
    storage = make_storage(
        httpx.MockTransport(lambda _: httpx.Response(502, text="<html>Bad</html>"))
    )

    with pytest.raises(StorageError, match=r"\(502\)$"):
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("body", "detail"),
    [
        ({"error": "rate limited"}, ": rate limited"),
        ({"error": None}, ""),
        ({"error": {"message": 42}}, ""),
        ({"error": {}}, ""),
        ([], ""),
    ],
)
async def test_an_error_body_of_any_shape_is_still_a_storage_error(
    body: object, detail: str
) -> None:
    storage = make_storage(httpx.MockTransport(lambda _: httpx.Response(429, json=body)))

    with pytest.raises(StorageError) as raised:
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")

    assert str(raised.value) == f"Cloudinary refused the upload (429){detail}"


@pytest.mark.anyio
async def test_a_network_failure_becomes_a_storage_error() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    storage = make_storage(httpx.MockTransport(handler))

    with pytest.raises(StorageError, match="Could not reach Cloudinary"):
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")


@pytest.mark.anyio
@pytest.mark.parametrize("missing", ["cloud_name", "api_key", "api_secret"])
async def test_upload_needs_every_credential(missing: str) -> None:
    called = False

    def handler(_: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(200, json=UPLOAD_OK)

    storage = make_storage(httpx.MockTransport(handler), **{missing: None})

    with pytest.raises(StorageNotConfiguredError, match="CLOUDINARY_"):
        await storage.upload_image(b"x", filename="c.png", content_type="image/png", kind="covers")
    assert called is False


def test_it_is_built_from_the_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.setenv("JWT_SECRET", "jwt-secret-value")
    monkeypatch.setenv("CLOUDINARY_CLOUD_NAME", "demo")
    monkeypatch.setenv("CLOUDINARY_API_KEY", "key-1")
    monkeypatch.setenv("CLOUDINARY_API_SECRET", SECRET)
    settings = Settings(_env_file=None)

    storage = CloudinaryStorage.from_settings(settings)

    assert settings.cloudinary_folder == "stridequest"
    assert "demo" in repr(storage)
    assert SECRET not in repr(storage)
    assert SECRET not in repr(settings)
    assert isinstance(settings.cloudinary_api_secret, SecretStr)


def test_settings_do_not_need_the_cloudinary_variables(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.setenv("JWT_SECRET", "jwt-secret-value")
    for name in ("CLOUDINARY_CLOUD_NAME", "CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET"):
        monkeypatch.delenv(name, raising=False)

    settings = Settings(_env_file=None)

    assert settings.cloudinary_cloud_name is None
    assert settings.cloudinary_api_secret is None
    assert settings.cloudinary_folder == "stridequest"
