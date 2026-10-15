from fastapi import FastAPI

# Load every module's models before anything queries the database: cross-module
# relationships are resolved by class name, so a model imported on its own
# cannot configure its mappers.
import app.modules.models  # noqa: F401
from app.api.v1.router import router as api_v1_router
from app.core.errors import register_exception_handlers


def create_app() -> FastAPI:
    app = FastAPI(title="StrideQuest API")
    register_exception_handlers(app)
    app.include_router(api_v1_router)
    return app


app = create_app()
