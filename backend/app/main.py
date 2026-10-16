from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.v1.router import router as api_v1_router
from app.core.config import get_settings
from app.core.errors import register_exception_handlers

# Load every module's models before anything queries the database: cross-module
# relationships are resolved by class name, so a model imported on its own
# cannot configure its mappers.
from app.modules import models as _models  # noqa: F401


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # Fail at startup, not on first use, when a required setting is missing.
    get_settings()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="StrideQuest API", lifespan=lifespan)
    register_exception_handlers(app)
    app.include_router(api_v1_router)
    return app


app = create_app()
