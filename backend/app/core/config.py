from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend settings, read from the environment or a `.env` file."""

    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    database_url: str
    s3_endpoint_url: str
    s3_bucket: str
    jwt_secret: SecretStr


@lru_cache
def get_settings() -> Settings:
    return Settings()
