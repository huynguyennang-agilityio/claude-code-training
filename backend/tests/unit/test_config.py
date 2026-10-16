from pathlib import Path

import pytest
from alembic.config import Config
from pydantic import ValidationError

from alembic import command
from app.core.config import DatabaseSettings, Settings, get_database_settings


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


def test_settings_require_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.setenv("S3_ENDPOINT_URL", "http://localhost:8333")
    monkeypatch.setenv("S3_BUCKET", "medals")
    monkeypatch.delenv("JWT_SECRET", raising=False)

    with pytest.raises(ValidationError, match="jwt_secret"):
        Settings(_env_file=None)


def test_database_settings_need_only_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("S3_ENDPOINT_URL", "S3_BUCKET", "JWT_SECRET"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

    settings = DatabaseSettings(_env_file=None)

    assert settings.database_url == "postgresql+asyncpg://u:p@localhost/db"


def test_alembic_runs_with_only_database_url(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """`alembic upgrade head --sql` works when DATABASE_URL is the only setting."""
    backend_dir = Path(__file__).resolve().parents[2]
    for name in ("S3_ENDPOINT_URL", "S3_BUCKET", "JWT_SECRET"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    # An empty directory has no `.env` for the settings to fall back on.
    monkeypatch.chdir(tmp_path)
    get_database_settings.cache_clear()
    config = Config()
    config.set_main_option("script_location", str(backend_dir / "alembic"))

    command.upgrade(config, "head", sql=True)

    assert "CREATE TABLE" in capsys.readouterr().out
    get_database_settings.cache_clear()
