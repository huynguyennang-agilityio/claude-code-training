import re
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, ConfigDict, field_validator

from app.modules.profile.models import Gender, UnitSystem

EARLIEST_BIRTHDAY = date(1900, 1, 1)  # a birthday must be after this day
COUNTRY_PATTERN = re.compile(r"^[A-Z]{2}$")
# One line of text: NUL and the other control characters are refused.
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")
MIN_HEIGHT_CM, MAX_HEIGHT_CM = Decimal("50.0"), Decimal("272.0")
MIN_WEIGHT_KG, MAX_WEIGHT_KG = Decimal("20.0"), Decimal("400.0")


def _text(label: str, max_length: int) -> BeforeValidator:
    """Trim a text value; it must then be 1 to `max_length` characters on one line."""

    def check(value: object) -> object:
        if value is None:
            return None
        if not isinstance(value, str):
            raise ValueError(f"{label} must be text.")
        trimmed = value.strip()
        if not 1 <= len(trimmed) <= max_length:
            raise ValueError(f"{label} must be 1 to {max_length} characters, or null.")
        if _CONTROL.search(trimmed):
            raise ValueError(f"{label} must not contain control characters.")
        return trimmed

    return BeforeValidator(check)


def _measure(label: str, unit: str, low: Decimal, high: Decimal) -> BeforeValidator:
    """A JSON number with at most one decimal, from `low` to `high` (both included)."""

    def check(value: object) -> object:
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int | float | Decimal):
            raise ValueError(f"{label} must be a number.")
        number = Decimal(str(value))
        if not number.is_finite():
            raise ValueError(f"{label} must be a number.")
        exponent = number.as_tuple().exponent
        if not isinstance(exponent, int) or exponent < -1:
            raise ValueError(f"{label} can have at most one decimal.")
        if not low <= number <= high:
            raise ValueError(f"{label} must be between {low} and {high} {unit}.")
        return number

    return BeforeValidator(check)


def _today() -> date:
    return datetime.now(UTC).date()


class ProfileRead(BaseModel):
    """The caller's profile. A user who never saved one reads as all `null` and `metric`."""

    model_config = ConfigDict(from_attributes=True)

    first_name: str | None = None
    last_name: str | None = None
    birthday: date | None = None
    # No format check on read: the table has none, so a stored value must never turn
    # into a 500. `PUT` (#122) validates `^[A-Z]{2}$` on write.
    country: str | None = None
    state: str | None = None
    gender: Gender | None = None
    unit_system: UnitSystem = UnitSystem.METRIC
    # `float`, not `Decimal`: Pydantic would write a Decimal as a JSON string.
    height_cm: float | None = None
    weight_kg: float | None = None


class ProfileWrite(BaseModel):
    """The body of `PUT`: the whole profile. All nine keys are required, so a client that forgets
    one gets a `422` instead of wiping a stored value. `null` clears a value, except for
    `unit_system`, which is never `null`."""

    first_name: Annotated[str | None, _text("First name", 50)]
    last_name: Annotated[str | None, _text("Last name", 50)]
    birthday: date | None
    country: str | None
    state: Annotated[str | None, _text("State", 100)]
    gender: Gender | None
    unit_system: UnitSystem
    height_cm: Annotated[Decimal | None, _measure("Height", "cm", MIN_HEIGHT_CM, MAX_HEIGHT_CM)]
    weight_kg: Annotated[Decimal | None, _measure("Weight", "kg", MIN_WEIGHT_KG, MAX_WEIGHT_KG)]

    @field_validator("birthday", mode="before")
    @classmethod
    def _birthday_is_text(cls, value: object) -> object:
        """A date is sent as `YYYY-MM-DD` text; Pydantic would also take a bare number."""
        if value is not None and not isinstance(value, str):
            raise ValueError("Birthday must be a date as YYYY-MM-DD.")
        return value

    @field_validator("birthday")
    @classmethod
    def _birthday_in_range(cls, value: date | None) -> date | None:
        if value is not None and not EARLIEST_BIRTHDAY < value <= _today():
            raise ValueError("Birthday must be after 1900-01-01 and not in the future.")
        return value

    @field_validator("country")
    @classmethod
    def _country_is_a_code(cls, value: str | None) -> str | None:
        if value is not None and not COUNTRY_PATTERN.fullmatch(value):
            raise ValueError("Country must be a two-letter code in capitals.")
        return value
