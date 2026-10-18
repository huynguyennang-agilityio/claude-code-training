from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.modules.challenges.deps import ChallengeServiceDep
from app.modules.runs.enrollments import EnrollmentService
from app.modules.runs.repository import RunRepository


def get_enrollment_service(
    session: Annotated[AsyncSession, Depends(get_session)], challenges: ChallengeServiceDep
) -> EnrollmentService:
    return EnrollmentService(session, RunRepository(session), challenges.get)


EnrollmentServiceDep = Annotated[EnrollmentService, Depends(get_enrollment_service)]
