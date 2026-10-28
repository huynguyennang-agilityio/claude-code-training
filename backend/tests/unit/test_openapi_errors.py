"""The OpenAPI document describes the errors the API really returns."""

from typing import Any

import pytest

from app.main import create_app

ERROR_REF = {"$ref": "#/components/schemas/ErrorResponse"}


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    return create_app().openapi()


def operations(schema: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return [
        (f"{method.upper()} {path}", operation)
        for path, item in schema["paths"].items()
        for method, operation in item.items()
    ]


def test_validation_errors_are_documented_as_error_responses(schema: dict[str, Any]) -> None:
    documented = [
        op["responses"]["422"] for _, op in operations(schema) if "422" in op["responses"]
    ]

    assert documented
    for response in documented:
        assert response["content"]["application/json"]["schema"] == ERROR_REF


def test_fastapis_own_validation_schemas_are_gone(schema: dict[str, Any]) -> None:
    assert "HTTPValidationError" not in schema["components"]["schemas"]
    assert "ValidationError" not in schema["components"]["schemas"]
    assert "#/components/schemas/HTTPValidationError" not in str(schema)


def test_error_response_schema_is_complete(schema: dict[str, Any]) -> None:
    schemas = schema["components"]["schemas"]

    assert set(schemas["ErrorResponse"]["required"]) == {"error"}
    assert set(schemas["ErrorBody"]["properties"]) == {"code", "message", "fields"}
    assert set(schemas["FieldError"]["properties"]) == {"field", "message"}


def test_operations_with_a_body_document_an_unreadable_body(schema: dict[str, Any]) -> None:
    with_body = [(name, op) for name, op in operations(schema) if "requestBody" in op]

    assert with_body
    for name, operation in with_body:
        response = operation["responses"].get("400")
        assert response, name
        assert response["content"]["application/json"]["schema"] == ERROR_REF


def test_operations_without_a_body_do_not_document_400(schema: dict[str, Any]) -> None:
    for name, operation in operations(schema):
        if "requestBody" not in operation:
            assert "400" not in operation["responses"], name


def test_the_document_is_built_once(schema: dict[str, Any]) -> None:
    app = create_app()

    assert app.openapi() is app.openapi()


def test_password_rule_is_in_the_sign_up_schema(schema: dict[str, Any]) -> None:
    password = schema["components"]["schemas"]["SignUpRequest"]["properties"]["password"]

    assert (password["minLength"], password["maxLength"]) == (8, 128)
    assert password["allOf"] == [{"pattern": "[A-Za-z]"}, {"pattern": "[0-9]"}]
