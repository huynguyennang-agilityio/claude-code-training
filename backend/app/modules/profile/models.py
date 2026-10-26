import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Numeric, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Gender(StrEnum):
    FEMALE = "female"
    MALE = "male"
    NON_BINARY = "non_binary"
    PREFER_NOT_TO_SAY = "prefer_not_to_say"


class UnitSystem(StrEnum):
    IMPERIAL = "imperial"
    METRIC = "metric"


def _one_of(column: str, values: type[StrEnum]) -> str:
    return f"{column} IN ({', '.join(repr(value.value) for value in values)})"


class UserProfile(Base):
    """The optional personal details of a user, one row per user.

    There is no row until the first save. Height and weight are always metric; `unit_system`
    is only a display preference. The row is deleted with the user.
    """

    __tablename__ = "user_profiles"
    __table_args__ = (
        CheckConstraint(_one_of("gender", Gender), name="ck_user_profiles_gender_valid"),
        CheckConstraint(
            _one_of("unit_system", UnitSystem), name="ck_user_profiles_unit_system_valid"
        ),
        CheckConstraint(
            "height_cm BETWEEN 50.0 AND 272.0", name="ck_user_profiles_height_cm_in_range"
        ),
        CheckConstraint(
            "weight_kg BETWEEN 20.0 AND 400.0", name="ck_user_profiles_weight_kg_in_range"
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    first_name: Mapped[str | None] = mapped_column(String(50))
    last_name: Mapped[str | None] = mapped_column(String(50))
    birthday: Mapped[date | None] = mapped_column(Date)
    country: Mapped[str | None] = mapped_column(String(2))
    state: Mapped[str | None] = mapped_column(String(100))
    gender: Mapped[str | None] = mapped_column(String(20))
    unit_system: Mapped[str] = mapped_column(
        String(10), default=UnitSystem.METRIC.value, server_default=UnitSystem.METRIC.value
    )
    height_cm: Mapped[Decimal | None] = mapped_column(Numeric(4, 1))
    weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(4, 1))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
