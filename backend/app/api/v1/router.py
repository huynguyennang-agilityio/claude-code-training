from fastapi import APIRouter

from app.api.v1 import health
from app.modules.auth.router import router as auth_router
from app.modules.challenges.router import router as challenges_router

API_V1_PREFIX = "/api/v1"

router = APIRouter(prefix=API_V1_PREFIX)
router.include_router(health.router)
router.include_router(auth_router)
router.include_router(challenges_router)
# Module routers are mounted here as modules gain endpoints, e.g.
# router.include_router(runs_router).
