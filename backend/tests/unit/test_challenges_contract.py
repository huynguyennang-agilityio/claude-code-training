"""The "Error codes" table of `docs/api/challenges.md` matches the errors raised in the module."""

import re

from app.modules.challenges import images, service
from app.modules.runs import enrollments
from tests.api_docs import API_DOCS_DIR, error_codes

DOC = API_DOCS_DIR / "challenges.md"
_ROW = re.compile(r"^\| (?P<status>\d{3}) \| `(?P<code>\w+)` \|", re.MULTILINE)


def raised_errors() -> dict[str, int]:
    """code -> HTTP status of each `DomainError` defined in the challenges service and images."""
    return {
        error.code: error.status_code
        for module in (service, images, enrollments)
        for error in vars(module).values()
        if isinstance(error, type)
        and issubclass(error, service.DomainError)
        and error is not service.DomainError
        and error.__module__ == module.__name__
    }


def test_every_documented_code_is_raised_and_every_raised_code_is_documented() -> None:
    assert sorted(error_codes(DOC)) == sorted(raised_errors())


def test_the_documented_status_codes_match() -> None:
    section = DOC.read_text(encoding="utf-8").split("## Error codes", 1)[1]
    documented = {row["code"]: int(row["status"]) for row in _ROW.finditer(section)}

    assert documented == raised_errors()
