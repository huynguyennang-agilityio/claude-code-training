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
hurl --test --variable "base=$base" --variable "admin_token=$admin_token" \
  --variable "user_token=$user_token" --variable "other_token=$other_token" \
  --variable "day_yesterday=$(day -1)" --variable "day_today=$(day 0)" \
  --variable "day_after_tomorrow=$(day 2)" \
  --variable "title=Hurl runs $stamp" --variable "sample_start=$sample_start" \
  --variable "sample_end=$sample_end" "$dir/runs.hurl"
if $rate_limit; then run auth_rate_limit.hurl; fi
