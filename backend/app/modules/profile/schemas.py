import re
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Annotated

from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    StringConstraints,
    WithJsonSchema,
    field_validator,
)

from app.core.text import SINGLE_LINE_PATTERN
from app.modules.profile.models import Gender, UnitSystem

EARLIEST_BIRTHDAY = date(1900, 1, 1)  # a birthday must be after this day
COUNTRY_PATTERN = r"^[A-Z]{2}$"
_ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MIN_HEIGHT_CM, MAX_HEIGHT_CM = Decimal("50.0"), Decimal("272.0")
MIN_WEIGHT_KG, MAX_WEIGHT_KG = Decimal("20.0"), Decimal("400.0")
# A float such as 180.3 is not exact; this far from a multiple of 0.1 is rounding noise.
_FLOAT_NOISE = 1e-6


def _nullable(schema: dict[str, object]) -> WithJsonSchema:
    return WithJsonSchema({"anyOf": [schema, {"type": "null"}]})


def _line(max_length: int) -> StringConstraints:
    """Text on one line, trimmed, 1 to `max_length` characters (the shared text rules)."""
    return StringConstraints(
        strip_whitespace=True, min_length=1, max_length=max_length, pattern=SINGLE_LINE_PATTERN
    )


def _measure(label: str, unit: str, low: Decimal, high: Decimal) -> tuple[object, object]:
    """A JSON number with at most one decimal, from `low` to `high` (both included).

    Pydantic documents a `Decimal` as a number or a string; the API takes only a number, so
    the JSON schema is written out.
    """

    def check(value: object) -> object:
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int | float | Decimal):
            raise ValueError(f"{label} must be a number.")
        if isinstance(value, float):
            if value != value or abs(value) == float("inf"):  # NaN or infinity
                raise ValueError(f"{label} must be a number.")
            tenths = value * 10
            if abs(tenths - round(tenths)) > _FLOAT_NOISE:
                raise ValueError(f"{label} can have at most one decimal.")
            number = Decimal(round(tenths)) / 10
        else:
            number = Decimal(value)
            if not number.is_finite():
                raise ValueError(f"{label} must be a number.")
            exponent = number.as_tuple().exponent
            if not isinstance(exponent, int) or exponent < -1:
                raise ValueError(f"{label} can have at most one decimal.")
        if not low <= number <= high:
            raise ValueError(f"{label} must be between {low} and {high} {unit}.")
        return number

    schema: dict[str, object] = {
        "type": "number",
        "minimum": float(low),
        "maximum": float(high),
        "multipleOf": 0.1,
    }
    return BeforeValidator(check), _nullable(schema)


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


Name = Annotated[str, _line(50)] | None
State = Annotated[str, _line(100)] | None


class ProfileWrite(BaseModel):
    """The body of `PUT`: the whole profile. All nine keys are required, so a client that forgets
    one gets a `422` instead of wiping a stored value. `null` clears a value, except for
    `unit_system`, which is never `null`."""

    first_name: Name
    last_name: Name
    birthday: Annotated[date | None, _nullable({"type": "string", "format": "date"})]
    country: Annotated[str | None, _nullable({"type": "string", "pattern": COUNTRY_PATTERN})]
    state: State
    gender: Gender | None
    unit_system: UnitSystem
    height_cm: Annotated[Decimal | None, *_measure("Height", "cm", MIN_HEIGHT_CM, MAX_HEIGHT_CM)]
    weight_kg: Annotated[Decimal | None, *_measure("Weight", "kg", MIN_WEIGHT_KG, MAX_WEIGHT_KG)]

    @field_validator("birthday", mode="before")
    @classmethod
    def _birthday_is_an_iso_date(cls, value: object) -> object:
        """Only `YYYY-MM-DD` text: Pydantic would also take a Unix time or a date and time."""
        if value is None:
            return None
        if not isinstance(value, str) or not _ISO_DATE.fullmatch(value):
            raise ValueError("Birthday must be a date as YYYY-MM-DD.")
        try:
            return date.fromisoformat(value)
        except ValueError:
            raise ValueError("Birthday must be a date as YYYY-MM-DD.") from None

    @field_validator("birthday")
    @classmethod
    def _birthday_in_range(cls, value: date | None) -> date | None:
        if value is not None and not EARLIEST_BIRTHDAY < value <= _today():
            raise ValueError("Birthday must be after 1900-01-01 and not in the future.")
        return value

    @field_validator("country")
    @classmethod
    def _country_is_a_code(cls, value: str | None) -> str | None:
        if value is not None and not re.fullmatch(COUNTRY_PATTERN, value):
            raise ValueError("Country must be a two-letter code in capitals.")
        return value
