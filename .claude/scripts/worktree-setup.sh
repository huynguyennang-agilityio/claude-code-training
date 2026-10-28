#!/usr/bin/env bash
# Prepare a git worktree for one issue of a parallel /run-tasks run (plan 028), so lint and
# the backend and mobile tests run there without touching another worktree.
#   .claude/scripts/worktree-setup.sh <main-checkout> <issue>
# Run it from inside the worktree. It:
#   - copies <main-checkout>/.env when the worktree has none (never overwrites one), and
#     points TEST_DATABASE_URL in that copy at the issue's own database,
#     stridequest_i<issue>_test (integration conftest creates it on first use);
#   - creates backend/.venv and installs requirements-dev.txt;
#   - runs `flutter pub get` in mobile/;
#   - prints the TEST_DATABASE_URL line with the password masked.
# It never runs `docker compose`: a compose project started from a worktree takes the same
# port as the main checkout's. Use the main checkout's `db` container.
# WORKTREE_SETUP_SKIP_INSTALL=1 skips the pip and flutter steps (tests).
# Tests: .claude/scripts/test-worktree-setup.sh
set -euo pipefail

die() {
  echo "worktree-setup.sh: $1" >&2
  exit 1
}

[ $# -eq 2 ] || die "usage: worktree-setup.sh <main-checkout> <issue>"
main=$1
issue=${2#\#}
[[ $issue =~ ^[0-9]+$ ]] || die "the issue must be a number, got '$2'"
[ -d "$main" ] || die "no main checkout at $main"

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it inside the worktree"
[ "$(cd "$main" && pwd -P)" != "$(cd "$root" && pwd -P)" ] || die "run it inside the worktree, not the main checkout"

database="stridequest_i${issue}_test"

# The URL with its database replaced, and the same URL with the password masked.
# Shape: <scheme>://<user>[:<password>]@<host>[:<port>]/<database>
issue_url() {
  sed -E "s#^(TEST_DATABASE_URL=[^/]*//[^/]*/)[^?]*#\1${database}#" <<<"$1"
}
masked() {
  sed -E 's#^(TEST_DATABASE_URL=[^/]*//[^:/@]*):[^@]*@#\1:****@#' <<<"$1"
}

if [ -e "$root/.env" ]; then
  echo "worktree-setup.sh: $root/.env already exists; left as it is." >&2
else
  [ -f "$main/.env" ] || die "$main/.env is missing; copy .env.example to it first"
  line=$(grep -E '^TEST_DATABASE_URL=' "$main/.env" | tail -n 1) ||
    die "$main/.env has no TEST_DATABASE_URL"
  new=$(issue_url "$line")
  # Copy, then swap only the TEST_DATABASE_URL lines, so no other value changes.
  (umask 077 && cp "$main/.env" "$root/.env")
  tmp=$(mktemp "$root/.env.XXXXXX")
  while IFS= read -r l || [ -n "$l" ]; do
    case "$l" in
      TEST_DATABASE_URL=*) printf '%s\n' "$new" ;;
      *) printf '%s\n' "$l" ;;
    esac
  done <"$root/.env" >"$tmp"
  mv "$tmp" "$root/.env"
  echo "Copied $main/.env to $root/.env with the issue's test database."
fi

if [ "${WORKTREE_SETUP_SKIP_INSTALL:-0}" != 1 ]; then
  if [ -d "$root/backend" ]; then
    [ -d "$root/backend/.venv" ] || python3.12 -m venv "$root/backend/.venv"
    "$root/backend/.venv/bin/pip" install -q -r "$root/backend/requirements-dev.txt"
  fi
  if [ -d "$root/mobile" ]; then
    (cd "$root/mobile" && flutter pub get >/dev/null)
  fi
fi

line=$(grep -E '^TEST_DATABASE_URL=' "$root/.env" | tail -n 1) || die "$root/.env has no TEST_DATABASE_URL"
echo "export $(masked "$line")"
case "$line" in
  */"$database") ;;
  *) echo "worktree-setup.sh: TEST_DATABASE_URL in $root/.env does not name $database; another worktree may use the same database." >&2 ;;
esac
