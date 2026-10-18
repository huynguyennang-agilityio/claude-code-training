"""`docs/api/runs.md` matches the errors raised in the progress service and the schemas."""

from app.modules.runs import progress
from app.modules.runs.schemas import (
    MyChallengePage,
    StepSyncRequest,
    StepSyncResult,
)
from tests.api_docs import API_DOCS_DIR, error_codes, load_example

DOC = API_DOCS_DIR / "runs.md"
# Raised by the framework for a body or query that breaks a schema, not by this module.
FRAMEWORK_CODES = {"validation_error"}


def test_every_documented_code_is_raised_or_from_the_framework() -> None:
    raised = {
        error.code
        for error in vars(progress).values()
        if isinstance(error, type)
        and issubclass(error, progress.DomainError)
        and error is not progress.DomainError
        and error.__module__ == progress.__name__
    }

    assert sorted(error_codes(DOC)) == sorted(raised | FRAMEWORK_CODES)


def test_the_request_example_is_a_valid_request() -> None:
    StepSyncRequest.model_validate(load_example("runs/step_sync_request.json"))


def test_the_result_example_is_a_valid_result() -> None:
    StepSyncResult.model_validate(load_example("runs/step_sync_result.json"))


def test_the_page_example_is_a_valid_page() -> None:
    MyChallengePage.model_validate(load_example("runs/my_challenge_page.json"))
