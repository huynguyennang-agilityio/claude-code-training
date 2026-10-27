"""Helpers that read the API contract in `docs/api/` for the contract tests."""

import json
import re
from pathlib import Path
from typing import Any

API_DOCS_DIR = Path(__file__).resolve().parents[2] / "docs" / "api"
EXAMPLES_DIR = API_DOCS_DIR / "examples"

_MARKER = r"<!-- example: (?P<name>\S+) -->"
_FENCE = r"```json\n(?P<body>.*?)\n```"
MARKED_BLOCK = re.compile(rf"{_MARKER}\n{_FENCE}", re.DOTALL)
JSON_BLOCK = re.compile(_FENCE, re.DOTALL)
_ERROR_ROW = re.compile(r"^\| (?P<http>\d{3}|any 4xx/5xx) \| `(?P<code>\w+)` \|", re.MULTILINE)


def doc_files() -> list[Path]:
    return sorted(API_DOCS_DIR.glob("*.md"))


def example_files() -> list[str]:
    """Example paths relative to `docs/api/examples/`, e.g. `auth/user.json`."""
    return sorted(
        path.relative_to(EXAMPLES_DIR).as_posix() for path in EXAMPLES_DIR.rglob("*.json")
    )


def load_example(name: str) -> Any:
    return json.loads((EXAMPLES_DIR / name).read_text(encoding="utf-8"))


def error_codes(doc: Path) -> list[str]:
    """The `code` of each row in the doc's "Error codes" table."""
    text = doc.read_text(encoding="utf-8")
    section = text.split("## Error codes", 1)[1].split("\n## ", 1)[0]
    return [row["code"] for row in _ERROR_ROW.finditer(section)]


# The documented error codes only the auth module serves. They need a database, so
# `tests/integration/test_auth_api.py` covers them; `test_error_contract.py` checks
# that every code in the doc is either tested there or in the unit tests.
AUTH_MODULE_ERROR_CODES = frozenset(
    {
        "email_taken",
        "incorrect_password",
        "invalid_credentials",
        "invalid_refresh_token",
        "invalid_token",
        "token_expired",
        "rate_limited",
    }
)

# Documented in `docs/api/auth.md` before the backend serves them (plan 024). The tasks that
# add the routes move their codes into `AUTH_MODULE_ERROR_CODES` with the integration test
# that produces them, and empty this set again.
DOCUMENTED_NOT_YET_SERVED_ERROR_CODES: frozenset[str] = frozenset()
