"""Create the demo challenges through the API, as an admin, and publish them.

    DEMO_ADMIN_PASSWORD=... python -m demo.load_demo --email you@example.com
    python -m demo.load_demo --email you@example.com --with-blocked   # adds the overlapping one

The account must already be an admin (`python -m app.scripts.create_admin you@example.com`).
Covers and medals come from `backend/demo/images/` (`python -m demo.make_images` makes them) and
are uploaded through `POST /images`; the challenges are made with `POST /challenges` and
published. Running it again creates nothing twice: a challenge is found by its title, and a
draft left by an interrupted run is published.

The windows are fixed dates (see `DEMO_CHALLENGES`). Publishing needs an end date in the future,
so once they have passed, move the dates.
"""

import argparse
import getpass
import os
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

IMAGES_DIR = Path(__file__).resolve().parent / "images"
DEFAULT_BASE_URL = "http://localhost:8000/api/v1"
TIERS = ("bronze", "silver", "gold")


@dataclass(frozen=True)
class DemoChallenge:
    title: str
    type: str
    target_value: int  # steps for a run, metres for a swim or a ride
    starts_at: str
    ends_at: str
    city: str
    landmark: str
    cover: str  # file name in IMAGES_DIR
    medals: tuple[tuple[str, int], ...]  # (name, threshold) for bronze, silver and gold
    description_md: str
    terms_md: str


DEMO_CHALLENGES = [
    DemoChallenge(
        title="Old Quarter 50K Steps",
        type="run",
        target_value=50_000,
        starts_at="2026-10-01T00:00:00+07:00",
        ends_at="2026-10-31T23:59:59+07:00",
        city="Hà Nội",
        landmark="Hồ Hoàn Kiếm",
        cover="cover-old-quarter-50k-steps.png",
        medals=(("Lake Stroller", 20_000), ("Lake Strider", 35_000), ("Lake Master", 50_000)),
        description_md=(
            "Walk or run **50,000 steps** in October around the Old Quarter and Hoàn Kiếm Lake.\n\n"
            "Every step you take counts, in one go or spread over the month."
        ),
        terms_md="Steps are read from Apple Health or Health Connect.",
    ),
    DemoChallenge(
        title="Mỹ Khê Bay 20 km",
        type="swim",
        target_value=20_000,
        starts_at="2026-11-01T00:00:00+07:00",
        ends_at="2026-11-30T23:59:59+07:00",
        city="Đà Nẵng",
        landmark="Bãi biển Mỹ Khê",
        cover="cover-my-khe-bay-20km.png",
        medals=(("Shallows", 5_000), ("Open Water", 12_000), ("Bay Crosser", 20_000)),
        description_md=(
            "Swim **20 km** across November, the length of Mỹ Khê Beach and back, a few "
            "laps at a time."
        ),
        terms_md="Swims are read from workouts recorded on your device.",
    ),
    DemoChallenge(
        title="Sài Gòn Riverside 100 km Ride",
        type="cycle",
        target_value=100_000,
        starts_at="2026-10-10T00:00:00+07:00",
        ends_at="2026-12-10T23:59:59+07:00",
        city="TP. Hồ Chí Minh",
        landmark="Landmark 81",
        cover="cover-saigon-riverside-100km.png",
        medals=(("Riverbank", 30_000), ("Bridge Runner", 65_000), ("Centurion", 100_000)),
        description_md=(
            "Ride **100 km** along the Sài Gòn river, from the city centre past Landmark 81 "
            "and back, at your own pace."
        ),
        terms_md="Rides are read from workouts recorded on your device.",
    ),
]

# Overlaps "Old Quarter 50K Steps": it exists to show the blocked state of the Join button.
BLOCKED_DEMO = DemoChallenge(
    title="Hanoi Autumn 30K Steps",
    type="run",
    target_value=30_000,
    starts_at="2026-10-15T00:00:00+07:00",
    ends_at="2026-11-15T23:59:59+07:00",
    city="Hà Nội",
    landmark="Hồ Tây",
    cover="cover-hanoi-autumn-30k-steps.png",
    medals=(("First Loop", 10_000), ("Second Loop", 20_000), ("Autumn Walker", 30_000)),
    description_md="Walk or run **30,000 steps** between mid-October and mid-November.",
    terms_md="Steps are read from Apple Health or Health Connect.",
)


class DemoError(Exception):
    """A readable reason the demo could not be loaded."""


def _fail(response: httpx.Response, doing: str) -> DemoError:
    try:
        error = response.json()["error"]
        reason = f"{error['code']}: {error['message']}"
    except (ValueError, KeyError, TypeError):
        reason = response.text[:200]
    return DemoError(f"{doing} failed ({response.status_code}) {reason}")


class DemoLoader:
    def __init__(self, client: httpx.Client, images_dir: Path = IMAGES_DIR) -> None:
        self._client = client
        self._images_dir = images_dir
        self._uploaded: dict[tuple[str, str], str] = {}

    def sign_in(self, email: str, password: str) -> None:
        response = self._client.post("/auth/signin", json={"email": email, "password": password})
        if response.status_code != 200:
            raise _fail(response, "Sign in")
        token = response.json()["tokens"]["access_token"]
        self._client.headers["Authorization"] = f"Bearer {token}"

    def load(self, challenges: Sequence[DemoChallenge]) -> list[str]:
        """Create and publish what is missing. Returns one line per challenge."""
        existing = self._existing()
        report = []
        for demo in challenges:
            found = existing.get(demo.title)
            if found is None:
                created = self._create(demo)
                self._publish(created["id"])
                report.append(f"created and published  {demo.title}")
            elif found["status"] == "draft":
                self._publish(found["id"])
                report.append(f"published a draft      {demo.title}")
            else:
                report.append(f"already there          {demo.title}")
        return report

    def _existing(self) -> dict[str, dict[str, Any]]:
        """Every challenge by title, published ones and drafts (this is an admin's view)."""
        found: dict[str, dict[str, Any]] = {}
        for status in ("published", "draft"):
            cursor: str | None = None
            while True:
                params: dict[str, Any] = {"status": status, "limit": 50}
                if cursor:
                    params["cursor"] = cursor
                response = self._client.get("/challenges", params=params)
                if response.status_code == 403:
                    raise DemoError(
                        "This account is not an admin. "
                        "Run `python -m app.scripts.create_admin <email>`."
                    )
                if response.status_code != 200:
                    raise _fail(response, "Listing the challenges")
                page = response.json()
                for item in page["items"]:
                    found.setdefault(item["title"], item)
                cursor = page["next_cursor"]
                if cursor is None:
                    break
        return found

    def _create(self, demo: DemoChallenge) -> dict[str, Any]:
        tiers = [
            {
                "tier": tier,
                "name": name,
                "threshold_value": threshold,
                "image_url": self._upload(f"medal-{demo.type}-{tier}.png", "medals"),
            }
            for tier, (name, threshold) in zip(TIERS, demo.medals, strict=True)
        ]
        response = self._client.post(
            "/challenges",
            json={
                "title": demo.title,
                "type": demo.type,
                "target_value": demo.target_value,
                "starts_at": demo.starts_at,
                "ends_at": demo.ends_at,
                "description_md": demo.description_md,
                "terms_md": demo.terms_md,
                "cover_image_url": self._upload(demo.cover, "covers"),
                "city": demo.city,
                "landmark": demo.landmark,
                "medals": tiers,
            },
        )
        if response.status_code != 201:
            raise _fail(response, f"Creating “{demo.title}”")
        return dict(response.json())

    def _publish(self, challenge_id: int) -> None:
        response = self._client.post(f"/challenges/{challenge_id}/publish")
        if response.status_code != 200:
            raise _fail(response, f"Publishing challenge {challenge_id}")

    def _upload(self, file_name: str, kind: str) -> str:
        """Upload an image once per run, and reuse its URL for the other challenges."""
        key = (file_name, kind)
        if key not in self._uploaded:
            path = self._images_dir / file_name
            if not path.is_file():
                raise DemoError(f"{path} is missing. Run `python -m demo.make_images`.")
            response = self._client.post(
                "/images",
                data={"kind": kind},
                files={"file": (file_name, path.read_bytes(), "image/png")},
                timeout=60,
            )
            if response.status_code != 201:
                raise _fail(response, f"Uploading {file_name}")
            self._uploaded[key] = str(response.json()["url"])
        return self._uploaded[key]


def _parse(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="load_demo", description=__doc__.split("\n")[0])
    parser.add_argument("--email", required=True, help="an admin account")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="the API base")
    parser.add_argument(
        "--with-blocked",
        action="store_true",
        help="also create the challenge that overlaps the first, to see the blocked state",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse(argv)
    password = os.environ.get("DEMO_ADMIN_PASSWORD") or getpass.getpass("Password: ")
    challenges = [*DEMO_CHALLENGES, *([BLOCKED_DEMO] if args.with_blocked else [])]
    try:
        with httpx.Client(base_url=args.base_url, timeout=30) as client:
            loader = DemoLoader(client)
            loader.sign_in(args.email, password)
            for line in loader.load(challenges):
                print(line)
    except (DemoError, httpx.HTTPError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
