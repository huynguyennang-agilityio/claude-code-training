from app.modules.runs.repository import RunRepository


class RunService:
    def __init__(self, repository: RunRepository) -> None:
        self._repository = repository

    async def count_participants(self, challenge_id: int) -> int:
        """How many users have joined the challenge. A challenge with participants can't
        change what they are counting toward (see `ChallengeService.update`)."""
        return await self._repository.count_for_challenge(challenge_id)
