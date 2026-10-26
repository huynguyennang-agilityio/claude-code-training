from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.modules.profile.models import Gender, UnitSystem


class ProfileRead(BaseModel):
    """The caller's profile. A user who never saved one reads as all `null` and `metric`."""

    model_config = ConfigDict(from_attributes=True)

    first_name: str | None = None
    last_name: str | None = None
    birthday: date | None = None
    country: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    state: str | None = None
    gender: Gender | None = None
    unit_system: UnitSystem = UnitSystem.METRIC
    # `float`, not `Decimal`: Pydantic would write a Decimal as a JSON string.
    height_cm: float | None = None
    weight_kg: float | None = None
