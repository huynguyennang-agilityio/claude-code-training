"""Typed errors and the `ErrorResponse` shape from `docs/api/auth.md`.

Services raise a `DomainError` subclass. The handlers registered here turn
it, and request validation errors, into the shared error body so clients
can branch on `error.code` instead of parsing messages.
"""

from typing import Any, ClassVar

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

VALIDATION_ERROR_CODE = "validation_error"
VALIDATION_ERROR_MESSAGE = "Request is invalid."

_LOCATIONS = {"body", "query", "path", "header", "cookie"}


class FieldError(BaseModel):
    field: str
    message: str


class ErrorBody(BaseModel):
    code: str
    message: str
    fields: list[FieldError] = []


class ErrorResponse(BaseModel):
    error: ErrorBody


class DomainError(Exception):
    """A business-rule failure with a stable, machine-readable code.

    Raise a subclass, never this class: each subclass must set `code` (listed in
    the API contract) and may override `status_code`. The message is for logs
    and may change.
    """

    status_code: ClassVar[int] = 400
    code: ClassVar[str]

    def __init_subclass__(cls, **kwargs: Any) -> None:
        super().__init_subclass__(**kwargs)
        if not isinstance(getattr(cls, "code", None), str):
            raise TypeError(f"{cls.__name__} must set a string `code`")

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


def _error_response(status_code: int, body: ErrorBody) -> JSONResponse:
    content = ErrorResponse(error=body).model_dump(mode="json")
    return JSONResponse(status_code=status_code, content=content)


async def domain_error_handler(_: Request, exc: DomainError) -> JSONResponse:
    return _error_response(exc.status_code, ErrorBody(code=exc.code, message=exc.message))


async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    fields = [
        FieldError(field=_field_name(error), message=_field_message(error))
        for error in exc.errors()
    ]
    body = ErrorBody(code=VALIDATION_ERROR_CODE, message=VALIDATION_ERROR_MESSAGE, fields=fields)
    return _error_response(422, body)


def _field_name(error: dict[str, Any]) -> str:
    """Name the failing input: `("body", "items", 0, "n")` becomes `"items.0.n"`.

    When there is no field below the location (missing body, a body of the
    wrong type, malformed JSON), the location itself is named, e.g. `"body"`.
    """
    loc = [str(part) for part in error["loc"]]
    if error["type"] == "json_invalid":
        return loc[0] if loc else "body"
    if loc and loc[0] in _LOCATIONS:
        return ".".join(loc[1:]) or loc[0]
    return ".".join(loc) or "body"


def _field_message(error: dict[str, Any]) -> str:
    """Pydantic prefixes custom validator messages with "Value error, "; drop it."""
    if error["type"] == "value_error" and "error" in error.get("ctx", {}):
        return str(error["ctx"]["error"])
    return error["msg"]


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(DomainError, domain_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
