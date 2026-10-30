#!/usr/bin/env bash
# Prepare a git worktree for one issue of a parallel /run-tasks run (plan 028), so lint and
# the backend and mobile tests run there without touching another worktree.
#   .claude/scripts/worktree-setup.sh <main-checkout> <issue>
# Run it from inside the worktree. It:
#   - copies <main-checkout>/.env when the worktree has none, and points TEST_DATABASE_URL
#     in that copy at the issue's own database, stridequest_i<issue>_test (integration
#     conftest creates it on first use);
#   - in a worktree that already has an .env (a reused one), points a TEST_DATABASE_URL that
#     names another database at the issue's and keeps every other line; an .env that
#     already names it is not touched;
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

# A URL is read in plain bash, not sed, so a password may hold any character:
#   TEST_DATABASE_URL=[quote]<scheme>://[<user>[:<password>]@]<host>[:<port>]/<database>[?<query>][quote]
# The user part ends at the last "@", so "/" and "@" in a password are kept whole.
# split_url sets url_quote, url_scheme, url_user, url_password, url_has_password, url_host,
# url_database and url_query, and fails without printing the URL.
split_url() {
  local value=${1#TEST_DATABASE_URL=} rest after
  url_quote=""
  case "$value" in
    \"*\" | \'*\') url_quote=${value:0:1} value=${value:1:${#value}-2} ;;
  esac
  [[ $value == *://* ]] || return 1
  url_scheme=${value%%://*}
  rest=${value#*://}
  url_user="" url_password="" url_has_password=0
  if [[ $rest == *@* ]]; then
    url_user=${rest%@*}
    rest=${rest##*@}
    if [[ $url_user == *:* ]]; then
      url_password=${url_user#*:}
      url_user=${url_user%%:*}
      url_has_password=1
    fi
  fi
  url_host=${rest%%/*}
  after=${rest#"$url_host"}
  after=${after#/}
  url_database=${after%%\?*}
  url_query=${after#"$url_database"}
}
# join_url <password>: the TEST_DATABASE_URL line from the split parts.
join_url() {
  local userinfo=""
  if [ -n "$url_user" ] || [ "$url_has_password" = 1 ]; then
    userinfo=$url_user
    [ "$url_has_password" = 0 ] || userinfo+=":$1"
    userinfo+="@"
  fi
  printf 'TEST_DATABASE_URL=%s%s://%s%s/%s%s%s' "$url_quote" "$url_scheme" "$userinfo" "$url_host" \
    "$url_database" "$url_query" "$url_quote"
}
issue_url() {
  split_url "$1" || die "TEST_DATABASE_URL is not a <scheme>://... URL"
  url_database=$database
  join_url "$url_password"
}
masked() {
  split_url "$1" || die "TEST_DATABASE_URL is not a <scheme>://... URL"
  join_url "****"
}
database_of() {
  split_url "TEST_DATABASE_URL=$1" || return 0
  printf '%s' "$url_database"
}

# write_env <source>: write <source> to $root/.env with each TEST_DATABASE_URL line pointed
# at the issue's database and every other line kept byte for byte (a CRLF ending, a last
# line without a newline). It writes a private temp file and moves it into place in one
# step, so a stopped run leaves no .env on the shared database and no stray copy of the
# password.
write_env() {
  local l nl cr
  tmp=$(umask 077 && mktemp "$root/.env.XXXXXX") || return 1
  trap 'rm -f "$tmp"' EXIT
  while :; do
    nl=$'\n'
    if ! IFS= read -r l; then
      [ -n "$l" ] || break
      nl=""
    fi
    case "$l" in
      TEST_DATABASE_URL=*)
        cr=""
        [[ $l != *$'\r' ]] || cr=$'\r' l=${l%$'\r'}
        l=$(issue_url "$l")$cr || return 1
        ;;
    esac
    printf '%s%s' "$l" "$nl"
  done <"$1" >"$tmp"
  mv "$tmp" "$root/.env"
}

if [ -e "$root/.env" ]; then
  # Rewrite only when a TEST_DATABASE_URL line names another database (or cannot be read).
  stale=0 found=0
  while IFS= read -r l; do
    found=1
    l=${l%$'\r'}
    [ "$(database_of "${l#TEST_DATABASE_URL=}")" = "$database" ] || stale=1
  done < <(grep -E '^TEST_DATABASE_URL=' "$root/.env" || true)
  if [ "$stale" = 1 ]; then
    write_env "$root/.env" || exit 1
    echo "worktree-setup.sh: pointed TEST_DATABASE_URL in the existing $root/.env at $database; kept every other line." >&2
  elif [ "$found" = 1 ]; then
    echo "worktree-setup.sh: $root/.env already exists and names $database; left as it is." >&2
  fi
else
  [ -f "$main/.env" ] || die "$main/.env is missing; copy .env.example to it first"
  grep -qE '^TEST_DATABASE_URL=' "$main/.env" || die "$main/.env has no TEST_DATABASE_URL"
  write_env "$main/.env" || exit 1
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
shown=$(masked "$line") || exit 1
echo "export $shown"
echo "worktree-setup.sh: already written to $root/.env; do not run the line above, its password is masked." >&2
if [ "$(database_of "${line#TEST_DATABASE_URL=}")" != "$database" ]; then
  echo "worktree-setup.sh: TEST_DATABASE_URL in $root/.env does not name $database; another worktree may use the same database." >&2
fi
# An exported TEST_DATABASE_URL wins over .env in the backend settings, so flag one that
# names another database or holds the masked password from the line above.
if [ -n "${TEST_DATABASE_URL+set}" ] && { [ "$(database_of "$TEST_DATABASE_URL")" != "$database" ] ||
  [[ $TEST_DATABASE_URL == *':****@'* ]]; }; then
  echo "worktree-setup.sh: TEST_DATABASE_URL is exported in this shell and overrides $root/.env; unset it before running the tests here." >&2
fi
