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

# run <worktree> <args...>: stdout and stderr together in $out, exit code in $code. A
# TEST_DATABASE_URL exported by the caller's shell is left out, except where a case sets it.
run() {
  local dir=$1
  shift
  out=$(cd "$dir" && env -u TEST_DATABASE_URL ${RUN_ENV:+"$RUN_ENV"} WORKTREE_SETUP_SKIP_INSTALL=1 "$script" "$@" 2>&1)
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
echo 'MARKER=kept' >>"$wt/.env"
run "$wt" "$main" 164
[ $code -eq 0 ] && grep -qx 'MARKER=kept' "$wt/.env" && ok || bad "second run: exit $code: $out"

# 6. Bad input fails without writing anything.
wt3="$tmp/wt-166"
g -C "$main" worktree add -q -b feat/166-x "$wt3"
run "$wt3" "$main" abc
[ $code -ne 0 ] && [ ! -e "$wt3/.env" ] && ok || bad "a non-numeric issue was accepted"
run "$main" "$main" 7
[ $code -ne 0 ] && ok || bad "running in the main checkout was accepted"
run "$wt3" "$tmp/nowhere" 166
[ $code -ne 0 ] && [ ! -e "$wt3/.env" ] && ok || bad "a missing main checkout was accepted"
mv "$main/.env" "$main/.env.off"
run "$wt3" "$main" 166
[ $code -ne 0 ] && [ ! -e "$wt3/.env" ] && ok || bad "a main checkout without .env was accepted"
mv "$main/.env.off" "$main/.env"

# 7. A quoted URL keeps its quotes and is not flagged.
quoted="$tmp/quoted"
g init -q -b develop "$quoted"
g -C "$quoted" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf 'TEST_DATABASE_URL="postgresql+asyncpg://u:pw-q@localhost:5432/stridequest_test?ssl=disable"\n' >"$quoted/.env"
wt4="$tmp/wt-167"
g -C "$quoted" worktree add -q -b feat/167-x "$wt4"
run "$wt4" "$quoted" 167
grep -qx 'TEST_DATABASE_URL="postgresql+asyncpg://u:pw-q@localhost:5432/stridequest_i167_test?ssl=disable"' "$wt4/.env" &&
  ok || bad "quoted URL: $(cat "$wt4/.env")"
grep -q 'another worktree may use the same database' <<<"$out" && bad "quoted URL flagged: $out" || ok

# 8. An exported TEST_DATABASE_URL naming another database is flagged, without the URL.
RUN_ENV="TEST_DATABASE_URL=postgresql+asyncpg://u:pw-env@localhost:5432/stridequest_test" run "$wt" "$main" 164
grep -q 'exported in this shell and overrides' <<<"$out" && ok || bad "exported URL not flagged: $out"
grep -q 'pw-env' <<<"$out" && bad "the exported password was printed: $out" || ok
RUN_ENV="TEST_DATABASE_URL=postgresql+asyncpg://u:pw-env@localhost:5432/stridequest_i164_test" run "$wt" "$main" 164
grep -q 'exported in this shell' <<<"$out" && bad "a matching exported URL was flagged: $out" || ok

RUN_ENV="TEST_DATABASE_URL=postgresql+asyncpg://u:****@localhost:5432/stridequest_i164_test" run "$wt" "$main" 164
grep -q 'exported in this shell and overrides' <<<"$out" && ok || bad "an exported masked URL was not flagged: $out"
grep -q 'do not run the line above' <<<"$out" && ok || bad "no warning against running the export line: $out"

# 9. A password with a raw @ is masked whole.
at="$tmp/at"
g init -q -b develop "$at"
g -C "$at" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf 'TEST_DATABASE_URL=postgresql+asyncpg://u:ab@cd-secret@localhost:5432/stridequest_test\n' >"$at/.env"
wt5="$tmp/wt-168"
g -C "$at" worktree add -q -b feat/168-x "$wt5"
run "$wt5" "$at" 168
grep -qx 'export TEST_DATABASE_URL=postgresql+asyncpg://u:\*\*\*\*@localhost:5432/stridequest_i168_test' <<<"$out" &&
  ok || bad "password with @ not masked whole: $out"
grep -q 'cd-secret' <<<"$out" && bad "part of the password was printed: $out" || ok

# 10. A password with a raw / is kept whole, masked whole, and the database is swapped.
slash="$tmp/slash"
g init -q -b develop "$slash"
g -C "$slash" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf 'TEST_DATABASE_URL=postgresql+asyncpg://u:ab/cd-secret@localhost:5432/stridequest_test\n' >"$slash/.env"
wt6="$tmp/wt-169"
g -C "$slash" worktree add -q -b feat/169-x "$wt6"
run "$wt6" "$slash" 169
grep -qx 'TEST_DATABASE_URL=postgresql+asyncpg://u:ab/cd-secret@localhost:5432/stridequest_i169_test' "$wt6/.env" &&
  ok || bad "password with /: wrong .env line"
grep -q 'cd-secret' <<<"$out" && bad "password with /: part of the password was printed" || ok
grep -qx 'export TEST_DATABASE_URL=postgresql+asyncpg://u:\*\*\*\*@localhost:5432/stridequest_i169_test' <<<"$out" &&
  ok || bad "password with /: export line wrong"
grep -q 'another worktree may use the same database' <<<"$out" && bad "password with /: flagged as shared" || ok

# 11. A URL it cannot read fails without printing it or writing .env.
bad_url="$tmp/bad-url"
g init -q -b develop "$bad_url"
g -C "$bad_url" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf 'TEST_DATABASE_URL=not-a-url-pw-hidden\n' >"$bad_url/.env"
wt7="$tmp/wt-170"
g -C "$bad_url" worktree add -q -b feat/170-x "$wt7"
run "$wt7" "$bad_url" 170
[ $code -ne 0 ] && [ ! -e "$wt7/.env" ] && ok || bad "an unreadable URL was accepted"
grep -q 'pw-hidden' <<<"$out" && bad "an unreadable URL was printed" || ok
ls "$wt7"/.env.* >/dev/null 2>&1 && bad "a temp .env file was left behind" || ok

# 12. It never runs docker compose.
grep -Eq '^[^#]*docker([[:space:]]|-)compose' "$script" && bad "the script runs docker compose" || ok

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
