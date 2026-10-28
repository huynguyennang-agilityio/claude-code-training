#!/usr/bin/env bash
# Tests for automations-check.sh: point CLAUDE_CONFIG_DIR at a throwaway folder, fake uname,
# and check what the hook prints for each case. Nothing outside the temp folder is touched.
#   bash .claude/hooks/test-automations-check.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/automations-check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake="$tmp/fakebin"
mkdir -p "$fake"
cat >"$fake/uname" <<'UNAME'
#!/usr/bin/env bash
echo "${FAKE_UNAME:-Darwin}"
UNAME
chmod +x "$fake/uname"

config="$tmp/config"
task="$config/scheduled-tasks/stridequest-pr-report/SKILL.md"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# run [VAR=value ...]: run the hook; sets $out (stdout) and $code.
run() {
  out=$(env -u GITHUB_ACTIONS -u CLAUDE_CODE_REMOTE -u STRIDEQUEST_AUTOMATIONS_HINT PATH="$fake:$PATH" CLAUDE_CONFIG_DIR="$config" "$@" \
    "$hook" <<<'{"hook_event_name":"SessionStart","source":"startup"}' 2>/dev/null)
  code=$?
}

# --- task missing on macOS: one JSON line with the hint ---
run
[ "$code" = 0 ] && ok || bad "missing: exit code was $code"
command -v jq >/dev/null 2>&1 || { echo "test-automations-check.sh: jq is required" >&2; exit 1; }
[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")" = SessionStart ] && ok || bad "missing: no SessionStart JSON"
jq -r '.hookSpecificOutput.additionalContext' <<<"$out" | grep -q "/setup-automations" && ok || bad "missing: hint does not name /setup-automations"

# --- task present: silent ---
mkdir -p "$(dirname "$task")"
echo "---" >"$task"
run
[ "$code" = 0 ] && [ -z "$out" ] && ok || bad "present: printed '$out' (exit $code)"
rm -f "$task"

# --- skipped environments: silent even when the task is missing ---
run GITHUB_ACTIONS=true
[ "$code" = 0 ] && [ -z "$out" ] && ok || bad "actions: printed '$out'"
run CLAUDE_CODE_REMOTE=true
[ "$code" = 0 ] && [ -z "$out" ] && ok || bad "cloud: printed '$out'"
run FAKE_UNAME=Linux
[ "$code" = 0 ] && [ -z "$out" ] && ok || bad "linux: printed '$out'"

run STRIDEQUEST_AUTOMATIONS_HINT=0
[ "$code" = 0 ] && [ -z "$out" ] && ok || bad "opt-out: printed '$out'"

# --- only the exact value "true" skips ---
run GITHUB_ACTIONS=1
[ -n "$out" ] && ok || bad "GITHUB_ACTIONS=1: expected the hint"

echo "test-automations-check.sh: $pass passed, $fail failed"
[ "$fail" = 0 ]
