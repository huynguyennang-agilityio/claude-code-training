"""Typed errors and the `ErrorResponse` shape from `docs/api/auth.md`.

Services raise a `DomainError` subclass. The handlers registered here turn
it, and request validation errors, into the shared error body so clients
can branch on `error.code` instead of parsing messages.
"""

import logging
from typing import Any, ClassVar

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.openapi.constants import REF_PREFIX
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)

VALIDATION_ERROR_CODE = "validation_error"
VALIDATION_ERROR_MESSAGE = "Request is invalid."

NOT_FOUND_CODE = "not_found"
METHOD_NOT_ALLOWED_CODE = "method_not_allowed"
NOT_AUTHENTICATED_CODE = "not_authenticated"
HTTP_ERROR_CODE = "http_error"
INTERNAL_ERROR_CODE = "internal_error"

# FastAPI's security helpers raise `HTTPException(401, "Not authenticated")` when the
# `Authorization` header is missing.
_MISSING_CREDENTIAL_DETAIL = "Not authenticated"

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

    def __init__(self, message: str, *, headers: dict[str, str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        # Extra response headers, e.g. `Retry-After` or `WWW-Authenticate`.
        self.headers = headers


def _error_response(
    status_code: int, body: ErrorBody, headers: dict[str, str] | None = None
) -> JSONResponse:
    content = ErrorResponse(error=body).model_dump(mode="json")
    return JSONResponse(status_code=status_code, content=content, headers=headers)


async def domain_error_handler(_: Request, exc: DomainError) -> JSONResponse:
    return _error_response(
        exc.status_code, ErrorBody(code=exc.code, message=exc.message), exc.headers
    )


async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    fields = [
        FieldError(field=_field_name(error), message=_field_message(error))
        for error in exc.errors()
    ]
    body = ErrorBody(code=VALIDATION_ERROR_CODE, message=VALIDATION_ERROR_MESSAGE, fields=fields)
    return _error_response(422, body)


async def http_exception_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    code, message = _http_error_body(exc)
    return _error_response(
        exc.status_code, ErrorBody(code=code, message=message), dict(exc.headers or {})
    )


async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    logger.error("Unhandled exception", exc_info=exc)
    return _error_response(
        500, ErrorBody(code=INTERNAL_ERROR_CODE, message="Something went wrong.")
    )


def _http_error_body(exc: StarletteHTTPException) -> tuple[str, str]:
    if exc.status_code == 404:
        return NOT_FOUND_CODE, "Resource not found."
    if exc.status_code == 405:
        return METHOD_NOT_ALLOWED_CODE, "Method not allowed."
    if exc.status_code == 401 and exc.detail == _MISSING_CREDENTIAL_DETAIL:
        return NOT_AUTHENTICATED_CODE, "Authentication is required."
    message = exc.detail if isinstance(exc.detail, str) else "Request failed."
    return HTTP_ERROR_CODE, message


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
    return str(error["msg"])


def register_exception_handlers(app: FastAPI) -> None:
    # Starlette types handlers as taking any `Exception`, but calls each one only
    # with the class it is registered for, so the narrower parameter types are safe.
    app.add_exception_handler(DomainError, domain_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(RequestValidationError, validation_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)  # type: ignore[arg-type]
    app.add_exception_handler(Exception, unhandled_exception_handler)


_HTTP_METHODS = ("get", "put", "post", "delete", "options", "head", "patch", "trace")
_ERROR_REF = {"$ref": f"{REF_PREFIX}ErrorResponse"}


def document_error_responses(app: FastAPI) -> None:
    """Make the OpenAPI document say what the API does with errors.

    FastAPI documents `422` as its own `HTTPValidationError`, but the handlers above
    return `ErrorResponse`. This replaces it, and adds the `400 http_error` an
    unreadable request body gets. Call it after the routers are included.
    """
    original = app.openapi

    def openapi() -> dict[str, Any]:
        if app.openapi_schema is not None:
            return app.openapi_schema
        schema = original()
        components = schema.setdefault("components", {}).setdefault("schemas", {})
        error_schema = ErrorResponse.model_json_schema(ref_template=f"{REF_PREFIX}{{model}}")
        components.update(error_schema.pop("$defs", {}))
        components["ErrorResponse"] = error_schema
        for operation in (op for item in schema.get("paths", {}).values() for op in item.values()):
            if not isinstance(operation, dict):
                continue
            responses = operation.setdefault("responses", {})
            content = {"application/json": {"schema": _ERROR_REF}}
            if "422" in responses:
                responses["422"] = {
                    "description": "Request is invalid (`validation_error`).",
                    "content": content,
                }
            if "requestBody" in operation:
                responses.setdefault(
                    "400",
                    {
                        "description": "The request body can't be read (`http_error`).",
                        "content": content,
                    },
                )
        for unused in ("HTTPValidationError", "ValidationError"):
            components.pop(unused, None)
        return schema

    app.openapi = openapi  # type: ignore[method-assign]
