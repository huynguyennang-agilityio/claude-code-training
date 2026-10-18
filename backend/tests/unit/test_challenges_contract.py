"""The "Error codes" table of `docs/api/challenges.md` matches the errors the service raises."""

import re

from app.modules.challenges import service
from tests.api_docs import API_DOCS_DIR, error_codes

DOC = API_DOCS_DIR / "challenges.md"
_ROW = re.compile(r"^\| (?P<status>\d{3}) \| `(?P<code>\w+)` \|", re.MULTILINE)


def raised_errors() -> dict[str, int]:
    """code -> HTTP status of each `DomainError` defined in the challenges service."""
    return {
        error.code: error.status_code
        for error in vars(service).values()
        if isinstance(error, type)
        and issubclass(error, service.DomainError)
        and error is not service.DomainError
    }


def test_every_documented_code_is_raised_and_every_raised_code_is_documented() -> None:
    assert sorted(error_codes(DOC)) == sorted(raised_errors())


def test_the_documented_status_codes_match() -> None:
    section = DOC.read_text(encoding="utf-8").split("## Error codes", 1)[1]
    documented = {row["code"]: int(row["status"]) for row in _ROW.finditer(section)}

    assert documented == raised_errors()
