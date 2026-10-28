#!/usr/bin/env bash
# Tests for worktree-setup.sh: build a throwaway repo with a worktree, run the script there
# with WORKTREE_SETUP_SKIP_INSTALL=1 (no pip, no flutter), and check the .env it leaves and
# what it prints. Nothing real is installed.
#   bash .claude/scripts/test-worktree-setup.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/worktree-setup.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() {
  fail=$((fail + 1))
  echo "FAIL: $1"
}

# Ignore the developer's git config (commit signing, hooks), so the setup cannot fail on it.
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git "$@"; }

main="$tmp/main"
g init -q -b develop "$main"
g -C "$main" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
cat >"$main/.env" <<'EOF'
POSTGRES_PASSWORD=s3cret-pass
TEST_DATABASE_URL=postgresql+asyncpg://stridequest:s3cret-pass@localhost:5432/stridequest_test
OTHER=keep me
EOF

# run <worktree> <args...>: stdout and stderr together in $out, exit code in $code.
run() {
  local dir=$1
  shift
  out=$(cd "$dir" && WORKTREE_SETUP_SKIP_INSTALL=1 "$script" "$@" 2>&1)
  code=$?
}

# 1. A fresh worktree gets a copy of .env with its own test database.
wt="$tmp/wt-164"
g -C "$main" worktree add -q -b feat/164-x "$wt"
run "$wt" "$main" 164
[ $code -eq 0 ] && ok || bad "fresh worktree: exit $code: $out"
[ -f "$wt/.env" ] && ok || bad "fresh worktree: .env not copied"
grep -qx 'TEST_DATABASE_URL=postgresql+asyncpg://stridequest:s3cret-pass@localhost:5432/stridequest_i164_test' "$wt/.env" &&
  ok || bad "fresh worktree: TEST_DATABASE_URL not pointed at stridequest_i164_test"
grep -qx 'OTHER=keep me' "$wt/.env" && ok || bad "fresh worktree: other values changed"
grep -qx 'POSTGRES_PASSWORD=s3cret-pass' "$wt/.env" && ok || bad "fresh worktree: other values changed"
grep -q 'stridequest_test$' "$main/.env" && ok || bad "main .env was changed"

# 2. It prints the export line with the database name and without the password.
grep -qx 'export TEST_DATABASE_URL=postgresql+asyncpg://stridequest:\*\*\*\*@localhost:5432/stridequest_i164_test' <<<"$out" &&
  ok || bad "export line missing or wrong: $out"
grep -q 's3cret-pass' <<<"$out" && bad "the password was printed: $out" || ok

# 3. The database name is one the integration conftest accepts.
db=$(sed -n 's#^TEST_DATABASE_URL=.*/##p' "$wt/.env")
[[ $db =~ ^[A-Za-z0-9_]+_test$ ]] && ok || bad "database name '$db' does not match ^[A-Za-z0-9_]+_test$"

# 4. An existing .env is never overwritten, and a shared database is flagged.
wt2="$tmp/wt-165"
g -C "$main" worktree add -q -b feat/165-x "$wt2"
printf 'TEST_DATABASE_URL=postgresql+asyncpg://u:pw-local@localhost:5432/stridequest_test\nMINE=1\n' >"$wt2/.env"
before=$(cat "$wt2/.env")
run "$wt2" "$main" '#165'
[ $code -eq 0 ] && ok || bad "existing .env: exit $code: $out"
[ "$(cat "$wt2/.env")" = "$before" ] && ok || bad "existing .env was changed"
grep -q 'another worktree may use the same database' <<<"$out" && ok || bad "shared database not flagged: $out"
grep -q 'pw-local' <<<"$out" && bad "the password was printed: $out" || ok

# 5. A second run keeps the .env from the first.
run "$wt" "$main" 164
[ $code -eq 0 ] && grep -q 'stridequest_i164_test' "$wt/.env" && ok || bad "second run: exit $code: $out"

# 6. Bad input fails without writing anything.
run "$wt" "$main" abc
[ $code -ne 0 ] && ok || bad "a non-numeric issue was accepted"
run "$main" "$main" 7
[ $code -ne 0 ] && ok || bad "running in the main checkout was accepted"
wt3="$tmp/wt-166"
g -C "$main" worktree add -q -b feat/166-x "$wt3"
run "$wt3" "$tmp/nowhere" 166
[ $code -ne 0 ] && [ ! -e "$wt3/.env" ] && ok || bad "a missing main checkout was accepted"
mv "$main/.env" "$main/.env.off"
run "$wt3" "$main" 166
[ $code -ne 0 ] && [ ! -e "$wt3/.env" ] && ok || bad "a main checkout without .env was accepted"
mv "$main/.env.off" "$main/.env"

# 7. It never runs docker compose.
grep -Eq '^[^#]*docker([[:space:]]|-)compose' "$script" && bad "the script runs docker compose" || ok

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
