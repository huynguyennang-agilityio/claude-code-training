import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_settings_read_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.setenv("S3_ENDPOINT_URL", "http://localhost:8333")
    monkeypatch.setenv("S3_BUCKET", "medals")
    monkeypatch.setenv("JWT_SECRET", "s3cr3t-value")

    settings = Settings(_env_file=None)

    assert settings.database_url == "postgresql+asyncpg://u:p@localhost/db"
    assert settings.s3_bucket == "medals"
    assert settings.jwt_secret.get_secret_value() == "s3cr3t-value"
    assert "s3cr3t-value" not in repr(settings)


def test_settings_require_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)
