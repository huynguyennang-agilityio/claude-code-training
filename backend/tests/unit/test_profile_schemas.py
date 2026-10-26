"""The field rules of `PUT /users/me/profile` (`docs/api/profile.md`), on the schema alone."""

from copy import deepcopy
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

import pytest
from pydantic import ValidationError

from app.core.errors import fields_from_validation_error
from app.modules.profile.schemas import ProfileWrite
from tests.api_docs import load_example


def body(**changes: Any) -> dict[str, Any]:
    data = deepcopy(load_example("profile/profile_put_request.json"))
    data.update(changes)
    return data


def failing_fields(data: dict[str, Any]) -> dict[str, str]:
    with pytest.raises(ValidationError) as caught:
        ProfileWrite.model_validate(data)
    return {item.field: item.message for item in fields_from_validation_error(caught.value)}


def test_the_documented_example_is_valid() -> None:
    profile = ProfileWrite.model_validate(body())

    assert profile.height_cm == Decimal("180.3")
    assert profile.weight_kg == Decimal("84.4")


def test_every_field_but_unit_system_can_be_null() -> None:
    data = {key: None for key in body()} | {"unit_system": "metric"}

    assert ProfileWrite.model_validate(data).model_dump()["first_name"] is None


@pytest.mark.parametrize("key", list(load_example("profile/profile_put_request.json")))
def test_a_missing_key_is_named(key: str) -> None:
    data = body()
    del data[key]

    assert list(failing_fields(data)) == [key]


def test_unit_system_is_never_null() -> None:
    assert list(failing_fields(body(unit_system=None))) == ["unit_system"]


def test_unit_system_must_be_a_known_value() -> None:
    assert list(failing_fields(body(unit_system="stone"))) == ["unit_system"]


@pytest.mark.parametrize("key", ["first_name", "last_name", "state"])
@pytest.mark.parametrize("value", ["", "   ", "\t\n", 5, ["a"], "a\x00b", "a\nb"])
def test_a_text_field_refuses_empty_blank_or_odd_values(key: str, value: object) -> None:
    assert list(failing_fields(body(**{key: value}))) == [key]


@pytest.mark.parametrize(("key", "limit"), [("first_name", 50), ("last_name", 50), ("state", 100)])
def test_a_text_field_has_a_length_limit_after_trimming(key: str, limit: int) -> None:
    ok = ProfileWrite.model_validate(body(**{key: f"  {'a' * limit}  "}))

    assert getattr(ok, key) == "a" * limit
    assert list(failing_fields(body(**{key: "a" * (limit + 1)}))) == [key]


def test_text_is_stored_trimmed() -> None:
    assert ProfileWrite.model_validate(body(first_name="  Max ")).first_name == "Max"


def test_a_birthday_is_after_1900_01_01() -> None:
    assert list(failing_fields(body(birthday="1900-01-01"))) == ["birthday"]
    assert ProfileWrite.model_validate(body(birthday="1900-01-02")).birthday is not None


def test_a_birthday_may_be_today_in_utc_but_not_tomorrow() -> None:
    today = datetime.now(UTC).date()

    assert ProfileWrite.model_validate(body(birthday=today.isoformat())).birthday == today
    assert list(failing_fields(body(birthday=(today + timedelta(days=1)).isoformat()))) == [
        "birthday"
    ]


@pytest.mark.parametrize(
    "value",
    [
        "24/06/1991",
        "not a date",
        19910624,
        "1991-06-24T10:00:00",
        "1991-06-24T00:00:00",
        "677721600",
        "1991-02-30",
    ],
)
def test_a_birthday_must_be_an_iso_date(value: object) -> None:
    assert list(failing_fields(body(birthday=value))) == ["birthday"]


@pytest.mark.parametrize("value", ["us", "USA", "U", "", "U1", " US", "US\n", 12])
def test_a_country_is_two_capital_letters(value: object) -> None:
    fields = failing_fields(body(country=value))

    assert list(fields) == ["country"]


def test_the_country_message_is_the_documented_one() -> None:
    assert failing_fields(body(country="us"))["country"] == (
        "Country must be a two-letter code in capitals."
    )


@pytest.mark.parametrize("value", ["robot", "", "Male", 1])
def test_a_gender_is_one_of_the_four_values(value: object) -> None:
    assert list(failing_fields(body(gender=value))) == ["gender"]


@pytest.mark.parametrize("value", ["female", "male", "non_binary", "prefer_not_to_say"])
def test_every_documented_gender_is_accepted(value: str) -> None:
    assert ProfileWrite.model_validate(body(gender=value)).gender == value


@pytest.mark.parametrize(
    ("key", "low", "high"), [("height_cm", 50.0, 272.0), ("weight_kg", 20.0, 400.0)]
)
def test_height_and_weight_have_inclusive_ranges(key: str, low: float, high: float) -> None:
    assert getattr(ProfileWrite.model_validate(body(**{key: low})), key) == Decimal(str(low))
    assert getattr(ProfileWrite.model_validate(body(**{key: high})), key) == Decimal(str(high))
    for bad in (low - 0.1, high + 0.1, 0, -5):
        assert list(failing_fields(body(**{key: bad}))) == [key]


def test_the_height_message_is_the_documented_one() -> None:
    assert failing_fields(body(height_cm=300))["height_cm"] == (
        "Height must be between 50.0 and 272.0 cm."
    )


@pytest.mark.parametrize("value", [180.25, 180.123, "180.3", True, [180], {"v": 1}, "abc"])
def test_height_is_a_number_with_at_most_one_decimal(value: object) -> None:
    assert list(failing_fields(body(height_cm=value))) == ["height_cm"]


@pytest.mark.parametrize("field", ["height_cm", "weight_kg"])
@pytest.mark.parametrize("value", [1e308, -1e308])
def test_a_huge_float_is_a_validation_error_not_a_crash(field: str, value: float) -> None:
    assert list(failing_fields(body(**{field: value}))) == [field]


def test_a_whole_number_is_a_valid_weight() -> None:
    assert ProfileWrite.model_validate(body(weight_kg=70)).weight_kg == Decimal("70")


def test_every_broken_field_is_reported_at_once() -> None:
    fields = failing_fields(body(country="us", height_cm=300, first_name=" "))

    assert set(fields) == {"country", "height_cm", "first_name"}


def test_the_openapi_document_states_the_real_rules() -> None:
    properties = ProfileWrite.model_json_schema()["properties"]

    assert properties["height_cm"] == {
        "anyOf": [
            {"type": "number", "minimum": 50.0, "maximum": 272.0, "multipleOf": 0.1},
            {"type": "null"},
        ],
        "title": "Height Cm",
    }
    assert properties["weight_kg"]["anyOf"][0]["maximum"] == 400.0
    assert {"type": "string", "pattern": "^[A-Z]{2}$"} in properties["country"]["anyOf"]
    assert {"type": "string", "format": "date"} in properties["birthday"]["anyOf"]
    first = next(item for item in properties["first_name"]["anyOf"] if item["type"] == "string")
    assert (first["minLength"], first["maxLength"], "pattern" in first) == (1, 50, True)
    state = next(item for item in properties["state"]["anyOf"] if item["type"] == "string")
    assert state["maxLength"] == 100


@pytest.mark.parametrize("value", [50.30000000000001, 99.99999999999999, 180.3])
def test_float_noise_is_not_a_second_decimal(value: float) -> None:
    assert ProfileWrite.model_validate(body(height_cm=value)).height_cm is not None
