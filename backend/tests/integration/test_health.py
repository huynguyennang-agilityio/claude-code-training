import pytest
from httpx import AsyncClient


@pytest.mark.anyio
async def test_health_is_served_under_api_v1(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.anyio
async def test_old_health_path_is_gone(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 404
