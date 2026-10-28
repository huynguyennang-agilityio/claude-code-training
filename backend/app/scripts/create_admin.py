"""Make an existing account an admin (or take the role away).

Run from `backend/` after the person has signed up through the app:

    python -m app.scripts.create_admin someone@example.com
    python -m app.scripts.create_admin someone@example.com --revoke

This is the only way to make an admin: no API route sets a role.
"""

import argparse
import asyncio
import sys
from collections.abc import Sequence
from datetime import timedelta

from app.core.config import get_settings
from app.core.database import get_engine, get_sessionmaker
from app.modules.auth.models import UserRole
from app.modules.auth.repository import AuthRepository
from app.modules.auth.service import AuthService, AuthSettings, UnknownUserError


def _parse(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="create_admin", description=__doc__.split("\n")[0])
    parser.add_argument("email", help="the email the person signed up with")
    parser.add_argument(
        "--revoke", action="store_true", help="make the account a normal user again"
    )
    return parser.parse_args(argv)


async def set_role(email: str, role: UserRole) -> None:
    """Set the role of the account with `email`; raises `UnknownUserError` if there is none."""
    settings = get_settings()
    auth_settings = AuthSettings(
        jwt_secret=settings.jwt_secret.get_secret_value(),
        access_token_ttl=timedelta(minutes=settings.access_token_ttl_minutes),
        refresh_token_ttl=timedelta(days=settings.refresh_token_ttl_days),
    )
    try:
        async with get_sessionmaker()() as session:
            service = AuthService(session, AuthRepository(session), auth_settings)
            await service.set_role(email, role)
    finally:
        await get_engine().dispose()


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse(argv)
    role = UserRole.USER if args.revoke else UserRole.ADMIN
    try:
        asyncio.run(set_role(args.email, role))
    except UnknownUserError:
        print(f"No account has the email {args.email!r}. Sign up first.", file=sys.stderr)
        return 1
    print(f"{args.email} is now {role.value}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
