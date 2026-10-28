from pathlib import Path

import pytest
from alembic.config import Config
from pydantic import ValidationError

from alembic import command
from app.core.config import DatabaseSettings, Settings, get_database_settings, get_settings
from app.main import create_app


def test_settings_read_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.setenv("JWT_SECRET", "s3cr3t-value")

    settings = Settings(_env_file=None)

    assert settings.database_url == "postgresql+asyncpg://u:p@localhost/db"
    assert settings.cloudinary_folder == "stridequest"
    assert settings.jwt_secret.get_secret_value() == "s3cr3t-value"
    assert "s3cr3t-value" not in repr(settings)


def test_settings_require_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_settings_require_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.delenv("JWT_SECRET", raising=False)

    with pytest.raises(ValidationError, match="jwt_secret"):
        Settings(_env_file=None)


def test_database_settings_need_only_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

    settings = DatabaseSettings(_env_file=None)

    assert settings.database_url == "postgresql+asyncpg://u:p@localhost/db"


def test_alembic_runs_with_only_database_url(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """`alembic upgrade head --sql` works when DATABASE_URL is the only setting."""
    backend_dir = Path(__file__).resolve().parents[2]
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    # An empty directory has no `.env` for the settings to fall back on.
    monkeypatch.chdir(tmp_path)
    get_database_settings.cache_clear()
    config = Config()
    config.set_main_option("script_location", str(backend_dir / "alembic"))

    command.upgrade(config, "head", sql=True)

    assert "CREATE TABLE" in capsys.readouterr().out
    get_database_settings.cache_clear()


@pytest.fixture
def bare_environment(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> pytest.MonkeyPatch:
    """Only DATABASE_URL is set, and there is no `.env` to fall back on."""
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")
    monkeypatch.chdir(tmp_path)
    get_settings.cache_clear()
    yield monkeypatch
    get_settings.cache_clear()


@pytest.mark.anyio
async def test_app_startup_fails_when_a_required_setting_is_missing(
    bare_environment: pytest.MonkeyPatch,
) -> None:
    app = create_app()

    with pytest.raises(ValidationError, match="jwt_secret"):
        async with app.router.lifespan_context(app):
            pass


@pytest.mark.anyio
async def test_app_starts_when_all_settings_are_present(
    bare_environment: pytest.MonkeyPatch,
) -> None:
    bare_environment.setenv("JWT_SECRET", "s3cr3t-value")
    app = create_app()

    async with app.router.lifespan_context(app):
        pass
