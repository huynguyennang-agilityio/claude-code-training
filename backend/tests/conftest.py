import pytest

# Register every model so mappers configure no matter which test imports what.
import app.modules.models  # noqa: F401


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"
