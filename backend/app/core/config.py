from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseSettings):
    """Only the database URL, for code that must not need the other settings.

    Alembic and the database engine use this, so a migration job can run with
    just `DATABASE_URL`.
    """

    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    database_url: str


class Settings(DatabaseSettings):
    """All backend settings, read from the environment or a `.env` file."""

    jwt_secret: SecretStr
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30

    # Cloudinary, for challenge cover and medal images. All optional so the app and
    # its tests start without credentials; `app.core.storage` raises
    # `StorageNotConfiguredError` when an upload needs them.
    cloudinary_cloud_name: str | None = None
    cloudinary_api_key: str | None = None
    cloudinary_api_secret: SecretStr | None = None
    cloudinary_folder: str = "stridequest"


@lru_cache
def get_settings() -> Settings:
    return Settings()


@lru_cache
def get_database_settings() -> DatabaseSettings:
    return DatabaseSettings()
