#!/usr/bin/env bash
# Replay the hurl files against a running API and print what hurl saw.
#
#   backend/hurl/run.sh [base_url] [--rate-limit]
#
# base_url defaults to http://localhost:8000/api/v1. Nothing is started for you:
# run `docker compose up -d --wait db` and the API first. `--rate-limit` also runs
# auth_rate_limit.hurl, which uses part of the per-IP failed sign-in budget.
set -euo pipefail

base=http://localhost:8000/api/v1
rate_limit=false
for arg in "$@"; do
  case "$arg" in
    --rate-limit) rate_limit=true ;;
    *) base=$arg ;;
  esac
done

dir=$(cd "$(dirname "$0")" && pwd)
run() {
  # A unique address per file, so runs never collide with earlier ones.
  hurl --test --variable "base=$base" \
    --variable "email=hurl-$(date +%s)-$RANDOM@example.com" "$dir/$1"
}

run auth.hurl

# challenges.hurl needs an admin and a normal user. The admin role can only be given on the
# server, so this makes the account with the same script an operator would use. It must run
# from backend/ with the virtualenv active.
signup() {
  curl -fsS -X POST "$base/auth/signup" -H 'Content-Type: application/json' \
    -d "{\"email\": \"$1\", \"password\": \"run4medals\", \"display_name\": \"Hurl\"}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["tokens"]["access_token"])'
}
stamp="$(date +%s)-$RANDOM"
admin_token=$(signup "hurl-admin-$stamp@example.com")
user_token=$(signup "hurl-user-$stamp@example.com")
other_token=$(signup "hurl-other-$stamp@example.com")
(cd "$dir/.." && python -m app.scripts.create_admin "hurl-admin-$stamp@example.com")
hurl --test --variable "base=$base" --variable "admin_token=$admin_token" \
  --variable "user_token=$user_token" --variable "title=Hurl $stamp" "$dir/challenges.hurl"
# runs.hurl needs one step sample that the server will count: it starts after the user joins
# and ends less than 5 minutes ahead.
sample_start=$(python3 -c 'from datetime import UTC, datetime, timedelta; print((datetime.now(UTC) + timedelta(seconds=40)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
sample_end=$(python3 -c 'from datetime import UTC, datetime, timedelta; print((datetime.now(UTC) + timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
day() { python3 -c "from datetime import UTC, datetime, timedelta; print((datetime.now(UTC) + timedelta(days=$1)).date())"; }
hour() { python3 -c "from datetime import UTC, datetime, timedelta; print((datetime.now(UTC).replace(minute=0, second=0, microsecond=0) + timedelta(hours=$1, minutes=$2)).strftime('%Y-%m-%dT%H:%M:%SZ'))"; }
hurl --test --variable "base=$base" --variable "admin_token=$admin_token" \
  --variable "user_token=$user_token" --variable "other_token=$other_token" \
  --variable "hour_now=$(hour 0 0)" --variable "hour_half=$(hour 0 30)" \
  --variable "day_yesterday=$(day -1)" --variable "day_today=$(day 0)" \
  --variable "day_after_tomorrow=$(day 2)" \
  --variable "title=Hurl runs $stamp" --variable "sample_start=$sample_start" \
  --variable "sample_end=$sample_end" "$dir/runs.hurl"

# step_hours.hurl needs an enrollment whose hours count: an hour counts only from the join time,
# so a fresh user joins a run challenge and its counting times are moved three days back. That
# step writes to the database of the local backend settings (`.env`), so it needs the API at
# base_url and that database on this machine, like create_admin above.
hours_email="hurl-hours-$stamp@example.com"
hours_token=$(signup "$hours_email")
auth() { echo "Authorization: Bearer $1"; }
post() { curl -fsS -X POST "$base/$1" -H 'Content-Type: application/json' -H "$(auth "$2")" -d "${3:-"{}"}"; }
field() { python3 -c "import json,sys; print(json.load(sys.stdin)[\"$1\"])"; }
hours_quest=$(post quests "$admin_token" "{\"title\": \"Hurl hours $stamp\", \"description\": \"Created by hurl.\"}" | field id)
hours_challenge=$(post challenges "$admin_token" "{\"quest_id\": $hours_quest, \"title\": \"Hurl hours $stamp\", \"type\": \"run\", \"target_value\": 50000, \"starts_at\": \"2026-10-01T00:00:00Z\", \"ends_at\": \"2099-01-01T00:00:00Z\", \"description_md\": \"Walk 50,000 steps.\", \"cover_image_url\": \"https://res.cloudinary.com/demo/image/upload/sample.jpg\", \"medals\": [{\"tier\": \"gold\", \"name\": \"Gold\", \"threshold_value\": 50000, \"image_url\": \"https://res.cloudinary.com/demo/image/upload/sample.jpg\"}]}" | field id)
post "challenges/$hours_challenge/publish" "$admin_token" > /dev/null
post "challenges/$hours_challenge/join" "$hours_token" > /dev/null
(cd "$dir/.." && HOURS_EMAIL="$hours_email" python - <<'PY'
import asyncio
import os

from sqlalchemy import text

from app.core.database import get_engine


async def main() -> None:
    email = os.environ["HOURS_EMAIL"]
    engine = get_engine()
    async with engine.begin() as connection:
        await connection.execute(
            text(
                "UPDATE runs SET hours_from = now() - interval '3 days', "
                "counting_from = now() - interval '3 days' "
                "WHERE user_id = (SELECT id FROM users WHERE email = :email)"
            ),
            {"email": email},
        )
        await connection.execute(
            text(
                "UPDATE users SET session_started_at = now() - interval '3 days' "
                "WHERE email = :email"
            ),
            {"email": email},
        )
    await engine.dispose()


asyncio.run(main())
PY
)
hurl --test --variable "base=$base" --variable "admin_token=$admin_token" \
  --variable "hours_token=$hours_token" --variable "challenge_id=$hours_challenge" \
  --variable "hour_3=$(hour -3 0)" --variable "hour_2=$(hour -2 0)" \
  --variable "hour_1=$(hour -1 0)" --variable "hour_next=$(hour 2 0)" "$dir/step_hours.hurl"
hurl --test --variable "base=$base" --variable "user_token=$user_token" \
  --variable "other_token=$other_token" "$dir/profile.hurl"
if $rate_limit; then run auth_rate_limit.hurl; fi
