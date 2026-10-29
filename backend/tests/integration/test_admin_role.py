"""The admin role, against PostgreSQL and real tokens.

The app has no admin route yet, so a test route guarded by `AdminUserDep` stands in:
it proves the guard works end to end with a real sign in, and that the role can only
change through the service the command-line script uses.
"""

from collections.abc import AsyncIterator, Iterator

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session
from app.main import create_app
from app.modules.auth.deps import AdminUserDep, get_auth_settings
from app.modules.auth.models import User, UserRole
from app.modules.auth.repository import AuthRepository
from app.modules.auth.service import AuthService, UnknownUserError
from app.modules.runs.repository import RunRepository
from app.modules.runs.service import RunService

SECRET = "an-integration-test-secret-that-is-long-enough"
PREFIX = "/api/v1"
SIGNUP = {"email": "lan@example.com", "password": "run4medals", "display_name": "Lan Runner"}


@pytest.fixture(autouse=True)
def settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("JWT_SECRET", SECRET)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
async def app_client(session: AsyncSession) -> AsyncIterator[AsyncClient]:
    app: FastAPI = create_app()

    async def override_get_session() -> AsyncIterator[AsyncSession]:
        yield session

    app.dependency_overrides[get_session] = override_get_session

    @app.get("/test/admin-only")
    async def admin_only(user: AdminUserDep) -> dict[str, str]:
        return {"email": user.email}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


async def sign_up(client: AsyncClient) -> dict[str, str]:
    response = await client.post(f"{PREFIX}/auth/signup", json=SIGNUP)
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


async def set_role(session: AsyncSession, email: str, role: UserRole) -> None:
    service = AuthService(
        session, AuthRepository(session), get_auth_settings(), RunService(RunRepository(session))
    )
    await service.set_role(email, role)


@pytest.mark.anyio
async def test_a_new_account_is_a_user(app_client: AsyncClient) -> None:
    response = await app_client.post(f"{PREFIX}/auth/signup", json=SIGNUP)

    assert response.json()["user"]["role"] == "user"


@pytest.mark.anyio
async def test_the_admin_route_answers_401_403_and_200(
    app_client: AsyncClient, session: AsyncSession
) -> None:
    headers = await sign_up(app_client)

    assert (await app_client.get("/test/admin-only")).status_code == 401
    forbidden = await app_client.get("/test/admin-only", headers=headers)
    assert forbidden.status_code == 403
    assert forbidden.json()["error"]["code"] == "forbidden"

    await set_role(session, "lan@example.com", UserRole.ADMIN)
    allowed = await app_client.get("/test/admin-only", headers=headers)
    assert allowed.status_code == 200
    assert allowed.json() == {"email": "lan@example.com"}


@pytest.mark.anyio
async def test_the_role_shows_in_users_me(app_client: AsyncClient, session: AsyncSession) -> None:
    headers = await sign_up(app_client)
    await set_role(session, "lan@example.com", UserRole.ADMIN)

    response = await app_client.get(f"{PREFIX}/users/me", headers=headers)

    assert response.json()["role"] == "admin"


@pytest.mark.anyio
async def test_revoking_the_role_closes_the_route_again(
    app_client: AsyncClient, session: AsyncSession
) -> None:
    headers = await sign_up(app_client)
    await set_role(session, "lan@example.com", UserRole.ADMIN)
    await set_role(session, "lan@example.com", UserRole.USER)

    assert (await app_client.get("/test/admin-only", headers=headers)).status_code == 403


@pytest.mark.anyio
async def test_sign_up_cannot_ask_for_a_role(
    app_client: AsyncClient, session: AsyncSession
) -> None:
    response = await app_client.post(f"{PREFIX}/auth/signup", json={**SIGNUP, "role": "admin"})

    assert response.status_code == 201
    assert response.json()["user"]["role"] == "user"
    user = await session.scalar(select(User).where(User.email == "lan@example.com"))
    assert user is not None and user.role == "user"


@pytest.mark.anyio
async def test_set_role_finds_the_account_ignoring_case_and_spaces(
    app_client: AsyncClient, session: AsyncSession
) -> None:
    await sign_up(app_client)

    await set_role(session, "  LAN@Example.com ", UserRole.ADMIN)

    user = await session.scalar(select(User).where(User.email == "lan@example.com"))
    assert user is not None and user.role == "admin"


@pytest.mark.anyio
async def test_set_role_for_an_unknown_email_raises(session: AsyncSession) -> None:
    with pytest.raises(UnknownUserError):
        await set_role(session, "nobody@example.com", UserRole.ADMIN)


@pytest.mark.anyio
async def test_the_database_refuses_an_unknown_role(
    app_client: AsyncClient, session: AsyncSession
) -> None:
    await sign_up(app_client)
    user = await session.scalar(select(User).where(User.email == "lan@example.com"))
    assert user is not None

    user.role = "root"
    with pytest.raises(IntegrityError, match="ck_users_role_valid"):
        await session.flush()
