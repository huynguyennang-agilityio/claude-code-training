import subprocess
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[2]

CHECK = """
import app.main
from sqlalchemy.orm import configure_mappers
from app.core.database import Base
configure_mappers()
print(" ".join(sorted(m.class_.__name__ for m in Base.registry.mappers)))
"""


def test_app_import_registers_and_configures_every_model() -> None:
    """A fresh interpreter that only imports the app knows every model."""
    result = subprocess.run(  # noqa: S603 - fixed interpreter and code, no user input
        [sys.executable, "-c", CHECK],
        cwd=BACKEND_DIR,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [
        "Challenge",
        "DailyActivity",
        "LoginAttempt",
        "Medal",
        "Quest",
        "RefreshToken",
        "Run",
        "StepSample",
        "User",
        "UserProfile",
    ]
