"""Cloudinary storage for challenge covers and medal images.

The database keeps only the delivery URL of an image. Uploads are signed with
the API secret and made by the backend alone; the mobile app never uploads.
The client uses `httpx`, so an upload never blocks the event loop and there is
no global SDK state.

This module raises plain `StorageError`s. The service that handles an upload
request turns them into typed `DomainError`s with codes from the API contract.
"""

import hashlib
import re
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Literal

import httpx

from app.core.config import Settings

ImageKind = Literal["covers", "medals"]

_UPLOAD_URL = "https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
_DELIVERY_URL = re.compile(r"^(https://res\.cloudinary\.com/[^/]+/image/upload/)(.+)$")
_UPLOAD_TIMEOUT_SECONDS = 30.0


class StorageError(Exception):
    """An image could not be stored. The message never contains a credential."""


class StorageNotConfiguredError(StorageError):
    """The Cloudinary settings are missing."""


@dataclass(frozen=True)
class UploadedImage:
    public_id: str
    url: str
    width: int
    height: int
    size_bytes: int


def sign_params(params: Mapping[str, str], api_secret: str) -> str:
    """Cloudinary's request signature: SHA-1 of the sorted `key=value` pairs and the secret."""
    to_sign = "&".join(f"{key}={params[key]}" for key in sorted(params))
    return hashlib.sha1((to_sign + api_secret).encode()).hexdigest()  # noqa: S324


def resized_url(url: str, *, width: int) -> str:
    """Ask Cloudinary for `url` at `width` pixels, in the best format and quality.

    Other URLs (and any URL that is not a Cloudinary delivery URL) come back
    unchanged. A URL that already has transformations is returned as it is.
    """
    match = _DELIVERY_URL.match(url)
    if match is None:
        return url
    prefix, rest = match.groups()
    first_segment = rest.split("/", 1)[0]
    if "," in first_segment or re.fullmatch(r"[a-z]{1,3}_[^/]+", first_segment):
        return url
    return f"{prefix}f_auto,q_auto,w_{width}/{rest}"


class CloudinaryStorage:
    """Uploads images to Cloudinary under `<folder>/challenges/<kind>`."""

    def __init__(
        self,
        *,
        cloud_name: str | None,
        api_key: str | None,
        api_secret: str | None,
        folder: str,
        transport: httpx.AsyncBaseTransport | None = None,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._cloud_name = cloud_name
        self._api_key = api_key
        self._api_secret = api_secret
        self._folder = folder.strip("/")
        self._transport = transport
        self._clock = clock

    def __repr__(self) -> str:
        return f"CloudinaryStorage(cloud_name={self._cloud_name!r}, folder={self._folder!r})"

    @classmethod
    def from_settings(
        cls, settings: Settings, *, transport: httpx.AsyncBaseTransport | None = None
    ) -> "CloudinaryStorage":
        secret = settings.cloudinary_api_secret
        return cls(
            cloud_name=settings.cloudinary_cloud_name,
            api_key=settings.cloudinary_api_key,
            api_secret=secret.get_secret_value() if secret is not None else None,
            folder=settings.cloudinary_folder,
            transport=transport,
        )

    async def upload_image(
        self, data: bytes, *, filename: str, content_type: str, kind: ImageKind
    ) -> UploadedImage:
        cloud_name, api_key, api_secret = self._credentials()
        params = {
            "folder": f"{self._folder}/challenges/{kind}",
            "timestamp": str(int(self._clock())),
        }
        form = {**params, "api_key": api_key, "signature": sign_params(params, api_secret)}
        try:
            async with httpx.AsyncClient(
                transport=self._transport, timeout=_UPLOAD_TIMEOUT_SECONDS
            ) as client:
                response = await client.post(
                    _UPLOAD_URL.format(cloud_name=cloud_name),
                    data=form,
                    files={"file": (filename, data, content_type)},
                )
        except httpx.HTTPError as error:
            raise StorageError("Could not reach Cloudinary.") from error
        return _parse_upload(response)

    def _credentials(self) -> tuple[str, str, str]:
        if not (self._cloud_name and self._api_key and self._api_secret):
            raise StorageNotConfiguredError(
                "Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET."
            )
        return self._cloud_name, self._api_key, self._api_secret


def _parse_upload(response: httpx.Response) -> UploadedImage:
    try:
        body = response.json()
    except ValueError as error:
        raise StorageError("Cloudinary returned a response that is not JSON.") from error
    if response.status_code != httpx.codes.OK:
        detail = body.get("error", {}).get("message") if isinstance(body, dict) else None
        raise StorageError(f"Cloudinary refused the upload ({response.status_code}): {detail}")
    try:
        return UploadedImage(
            public_id=body["public_id"],
            url=body["secure_url"],
            width=body["width"],
            height=body["height"],
            size_bytes=body["bytes"],
        )
    except (KeyError, TypeError) as error:
        raise StorageError("Cloudinary returned an unexpected response.") from error
