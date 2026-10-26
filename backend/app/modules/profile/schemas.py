from datetime import date

from pydantic import BaseModel, ConfigDict

from app.modules.profile.models import Gender, UnitSystem


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
