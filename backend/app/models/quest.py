from typing import TYPE_CHECKING

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.challenge import Challenge


class Quest(Base):
    """A themed group of running challenges."""

    __tablename__ = "quests"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")

    challenges: Mapped[list["Challenge"]] = relationship(
        back_populates="quest", cascade="all, delete-orphan"
    )
