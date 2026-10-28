import pytest

# Register every model so mappers configure no matter which test imports what.
import app.modules.models  # noqa: F401


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    """Session scope, so session-scoped async fixtures share one event loop."""
    return "asyncio"
