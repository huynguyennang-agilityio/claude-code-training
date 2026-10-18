"""Uploading a cover or a medal image.

The image is checked here (size and the real file type, not the name or the header the
client sent) and then stored in Cloudinary through `app.core.storage`.
"""

from app.core.errors import DomainError
from app.core.storage import (
    CloudinaryStorage,
    ImageKind,
    StorageError,
    StorageNotConfiguredError,
    UploadedImage,
)

MAX_IMAGE_BYTES = 5 * 1024 * 1024


# The codes below are listed in `docs/api/challenges.md`.
class ImageTooLargeError(DomainError):
    status_code = 413
    code = "image_too_large"


class UnsupportedImageTypeError(DomainError):
    status_code = 415
    code = "unsupported_image_type"


class ImageUploadFailedError(DomainError):
    status_code = 502
    code = "upload_failed"


class ImageStorageNotConfiguredError(DomainError):
    status_code = 503
    code = "storage_not_configured"


def sniff_image_type(data: bytes) -> str | None:
    """The file extension of a JPEG, PNG or WebP, judged from its first bytes."""
    if data.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return None


_CONTENT_TYPES = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}


class ImageService:
    def __init__(self, storage: CloudinaryStorage) -> None:
        self._storage = storage

    async def upload(self, data: bytes, *, kind: ImageKind) -> UploadedImage:
        if len(data) > MAX_IMAGE_BYTES:
            raise ImageTooLargeError(
                f"An image can be at most {MAX_IMAGE_BYTES // 1024 // 1024} MB."
            )
        extension = sniff_image_type(data)
        if extension is None:
            raise UnsupportedImageTypeError("Send a JPEG, PNG or WebP image.")
        try:
            return await self._storage.upload_image(
                data,
                filename=f"{kind.removesuffix('s')}.{extension}",
                content_type=_CONTENT_TYPES[extension],
                kind=kind,
            )
        except StorageNotConfiguredError as error:
            raise ImageStorageNotConfiguredError("Image storage is not set up.") from error
        except StorageError as error:
            raise ImageUploadFailedError("The image could not be stored. Try again.") from error
