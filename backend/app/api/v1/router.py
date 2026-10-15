from fastapi import APIRouter

from app.api.v1 import health

API_V1_PREFIX = "/api/v1"

router = APIRouter(prefix=API_V1_PREFIX)
router.include_router(health.router)
# Module routers are mounted here as modules gain endpoints, e.g.
# router.include_router(runs_router).
