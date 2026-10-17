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
if $rate_limit; then run auth_rate_limit.hurl; fi
