"""Typed errors and the `ErrorResponse` shape from `docs/api/auth.md`.

Services raise a `DomainError` subclass. The handlers registered here turn
it, and request validation errors, into the shared error body so clients
can branch on `error.code` instead of parsing messages.
"""

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

VALIDATION_ERROR_CODE = "validation_error"


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

    Subclasses set `status_code` and `code`; the message is for logs and may change.
    """

    status_code: int = 400
    code: str = "domain_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


def _error_response(status_code: int, body: ErrorBody) -> JSONResponse:
    content = ErrorResponse(error=body).model_dump()
    return JSONResponse(status_code=status_code, content=jsonable_encoder(content))


async def domain_error_handler(_: Request, exc: DomainError) -> JSONResponse:
    return _error_response(exc.status_code, ErrorBody(code=exc.code, message=exc.message))


async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    fields = [
        FieldError(field=_field_name(error["loc"]), message=error["msg"]) for error in exc.errors()
    ]
    body = ErrorBody(code=VALIDATION_ERROR_CODE, message="Request body is invalid.", fields=fields)
    return _error_response(422, body)


def _field_name(loc: tuple[int | str, ...]) -> str:
    """`("body", "password")` becomes `"password"`; nested paths are dotted."""
    parts = [str(part) for part in loc]
    if parts and parts[0] in {"body", "query", "path", "header", "cookie"}:
        parts = parts[1:]
    return ".".join(parts)


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(DomainError, domain_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
