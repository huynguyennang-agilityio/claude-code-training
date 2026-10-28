from app.modules.medals.models import Medal
from app.modules.medals.repository import MedalRepository
from app.modules.medals.schemas import MedalInput


class MedalService:
    """Creates and changes medals. Other modules go through it: a medal is never
    written by assigning `challenge.medals`."""

    def __init__(self, repository: MedalRepository) -> None:
        self._repository = repository

    async def add_medals(self, challenge_id: int, inputs: list[MedalInput]) -> list[Medal]:
        """Add the medals of a challenge.

        It does not commit: it is called inside the caller's transaction, and the
        calling service decides when to commit.
        """
        medals = [
            Medal(
                challenge_id=challenge_id,
                tier=item.tier.value,
                threshold_value=item.threshold_value,
                name=item.name,
                image_url=str(item.image_url),
            )
            for item in inputs
        ]
        return await self._repository.add_all(medals)

    async def replace_medals(self, challenge_id: int, inputs: list[MedalInput]) -> list[Medal]:
        """Replace all the medals of a challenge. Like `add_medals`, it does not commit.

        Only for a challenge nobody has joined: the medals get new ids.
        """
        await self._repository.delete_for_challenge(challenge_id)
        return await self.add_medals(challenge_id, inputs)
