import argparse
import uuid
from datetime import UTC, datetime

import pytest

from app.modules.auth.deps import require_admin
from app.modules.auth.models import User, UserRole
from app.modules.auth.service import ForbiddenError, UnknownUserError
from app.scripts import create_admin


def make_user(role: str) -> User:
    return User(
        id=uuid.uuid4(),
        email="runner@example.com",
        password_hash="x",
        display_name="Lan Runner",
        role=role,
        created_at=datetime(2026, 10, 18, tzinfo=UTC),
    )


@pytest.mark.anyio
async def test_an_admin_passes_the_guard() -> None:
    admin = make_user(UserRole.ADMIN.value)

    assert await require_admin(admin) is admin


@pytest.mark.anyio
@pytest.mark.parametrize("role", [UserRole.USER.value, "", "root", "ADMIN"])
async def test_anyone_else_is_forbidden(role: str) -> None:
    with pytest.raises(ForbiddenError) as raised:
        await require_admin(make_user(role))

    assert raised.value.status_code == 403
    assert raised.value.code == "forbidden"


def test_the_role_defaults_to_user_in_the_model() -> None:
    assert [role.value for role in UserRole] == ["user", "admin"]


class TestCreateAdminScript:
    def test_makes_an_admin(
        self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        calls: list[tuple[str, UserRole]] = []

        async def fake_set_role(email: str, role: UserRole) -> None:
            calls.append((email, role))

        monkeypatch.setattr(create_admin, "set_role", fake_set_role)

        assert create_admin.main(["lan@example.com"]) == 0
        assert calls == [("lan@example.com", UserRole.ADMIN)]
        assert "lan@example.com is now admin." in capsys.readouterr().out

    def test_revokes_with_the_flag(self, monkeypatch: pytest.MonkeyPatch) -> None:
        calls: list[tuple[str, UserRole]] = []

        async def fake_set_role(email: str, role: UserRole) -> None:
            calls.append((email, role))

        monkeypatch.setattr(create_admin, "set_role", fake_set_role)

        assert create_admin.main(["lan@example.com", "--revoke"]) == 0
        assert calls == [("lan@example.com", UserRole.USER)]

    def test_an_unknown_email_fails_with_a_message(
        self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        async def fake_set_role(email: str, role: UserRole) -> None:
            raise UnknownUserError(email)

        monkeypatch.setattr(create_admin, "set_role", fake_set_role)

        assert create_admin.main(["nobody@example.com"]) == 1
        assert "Sign up first" in capsys.readouterr().err

    def test_needs_an_email(self) -> None:
        with pytest.raises(SystemExit) as raised:
            create_admin.main([])

        assert raised.value.code == 2

    def test_parser_accepts_only_the_documented_arguments(self) -> None:
        namespace = create_admin._parse(["a@b.co", "--revoke"])

        assert namespace == argparse.Namespace(email="a@b.co", revoke=True)
