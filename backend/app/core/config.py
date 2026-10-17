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

    s3_endpoint_url: str
    s3_bucket: str
    jwt_secret: SecretStr
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()


@lru_cache
def get_database_settings() -> DatabaseSettings:
    return DatabaseSettings()
