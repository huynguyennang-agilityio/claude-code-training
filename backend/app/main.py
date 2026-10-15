from fastapi import FastAPI

from app.api.v1.router import router as api_v1_router
from app.core.errors import register_exception_handlers


def create_app() -> FastAPI:
    app = FastAPI(title="StrideQuest API")
    register_exception_handlers(app)
    app.include_router(api_v1_router)
    return app


app = create_app()
