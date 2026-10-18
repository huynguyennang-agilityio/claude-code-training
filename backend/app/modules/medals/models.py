from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    # Type-only: SQLAlchemy resolves this relationship by class name at runtime.
    from app.modules.challenges.models import Challenge


class Medal(Base):
    """The digital medal awarded for completing a challenge.

    The image itself lives in Cloudinary; only its delivery URL is stored here.
    """

    __tablename__ = "medals"

    id: Mapped[int] = mapped_column(primary_key=True)
    challenge_id: Mapped[int] = mapped_column(
        ForeignKey("challenges.id", ondelete="CASCADE"), unique=True
    )
    name: Mapped[str] = mapped_column(String(120))
    image_url: Mapped[str] = mapped_column(String(2048))

    challenge: Mapped["Challenge"] = relationship(back_populates="medal")
