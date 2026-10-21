#!/usr/bin/env bash
# Tests for check.sh: build a throwaway git repo with a `develop` branch and a change under
# backend/ and mobile/, put fake flutter, ruff, mypy and pytest first in PATH, and check
# which tools the hook calls and what it exits with. Nothing real is run.
#   bash .claude/hooks/test-check.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake="$tmp/fakebin"
log="$tmp/tools.log"
mkdir -p "$fake"
# Each fake tool logs its name and exits with FAKE_TOOL_EXIT (0 by default).
for t in flutter ruff mypy pytest; do
  cat >"$fake/$t" <<EOF
#!/usr/bin/env bash
echo "$t \$*" >>"$log"
exit "\${FAKE_TOOL_EXIT:-0}"
EOF
  chmod +x "$fake/$t"
done

repo="$tmp/repo"
mkdir -p "$repo"
# Ignore the developer's git config (commit signing, hooks), so the setup cannot fail on it.
setup_git() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" "$@"; }
if ! { setup_git init -q -b develop &&
  setup_git -c user.name=t -c user.email=t@t commit -q --allow-empty -m base &&
  setup_git switch -q -c feature; }; then
  echo "test-check.sh: could not set up the test git repo" >&2
  exit 1
fi
mkdir -p "$repo/backend" "$repo/mobile"
echo "x = 1" >"$repo/backend/app.py"
echo "void main() {}" >"$repo/mobile/main.dart"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# run <session> [VAR=value ...]: run the hook from the repo; sets $code and $out (stderr).
run() {
  local session=$1
  shift
  : >"$log"
  # Start each run with no block counter, so one case's blocks never count toward another's
  # (without jq every session id would be "unknown" and share one counter).
  rm -f "$tmp"/stridequest-stop-hook-*
  out=$(cd "$repo" && env -u GITHUB_ACTIONS PATH="$fake:$PATH" TMPDIR="$tmp" "$@" \
    "$hook" <<<"{\"session_id\":\"$session\"}" 2>&1 >/dev/null)
  code=$?
}
calls() { [ -s "$log" ] && wc -l <"$log" | tr -d ' ' || echo 0; }

# --- GitHub Actions: skip everything, even when the checks would fail ---
run gha GITHUB_ACTIONS=true FAKE_TOOL_EXIT=1
[ "$code" = 0 ] && ok || bad "actions: exit code was $code, expected 0"
[ "$(calls)" = 0 ] && ok || bad "actions: $(calls) tool calls, expected none"
[ ! -e "$tmp/stridequest-stop-hook-gha" ] && ok || bad "actions: wrote a block counter"
grep -q "check.sh: skipped in GitHub Actions" <<<"$out" && ok || bad "actions: no skip line on stderr"

# --- local, checks pass: run all six checks, allow the stop ---
run pass FAKE_TOOL_EXIT=0
[ "$code" = 0 ] && ok || bad "local pass: exit code was $code, expected 0"
[ "$(calls)" = 6 ] && ok || bad "local pass: $(calls) tool calls, expected 6"
grep -q "^flutter analyze" "$log" && grep -q "^flutter test" "$log" && ok || bad "local pass: flutter analyze/test not called"
grep -q "^ruff check ." "$log" && grep -q "^ruff format --check ." "$log" && ok || bad "local pass: ruff not called"
grep -q "^mypy" "$log" && grep -q "^pytest -q tests/unit" "$log" && ok || bad "local pass: mypy/pytest not called"

# --- local, checks fail: block the stop with exit 2 and show the failures ---
run failing FAKE_TOOL_EXIT=1
[ "$code" = 2 ] && ok || bad "local fail: exit code was $code, expected 2"
grep -q "attempt 1 of 3" <<<"$out" && ok || bad "local fail: no attempt message"
grep -q "backend lint failed" <<<"$out" && ok || bad "local fail: backend failure not reported"

# --- only the exact value "true" skips ---
for value in false 1 TRUE ""; do
  run "other-$value" GITHUB_ACTIONS="$value" FAKE_TOOL_EXIT=1
  [ "$code" = 2 ] && ok || bad "GITHUB_ACTIONS='$value': exit code was $code, expected 2"
done

echo "test-check.sh: $pass passed, $fail failed"
[ "$fail" = 0 ]
