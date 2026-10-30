#!/usr/bin/env bash
# Tests for run-task-guard.sh: build a throwaway git repo with a linked worktree and a
# results folder, write the marker and the run files each case needs, and check what the
# hook exits with. Nothing outside the temporary folder is read or written.
#   bash .claude/hooks/test-run-task-guard.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/run-task-guard.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
tree="$tmp/tree"
results="$tmp/results"
mkdir -p "$repo" "$results"
# Ignore the developer's git config (commit signing, hooks), so the setup cannot fail on it.
setup_git() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" "$@"; }
if ! { setup_git init -q -b develop &&
  setup_git -c user.name=t -c user.email=t@t commit -q --allow-empty -m base &&
  setup_git worktree add -q -b feature "$tree"; }; then
  echo "test-run-task-guard.sh: could not set up the test git repo" >&2
  exit 1
fi
marker="$(cd "$tree" && git rev-parse --git-dir)/run-task"
case "$marker" in /*) ;; *) marker="$tree/$marker" ;; esac

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# reset: no marker and no run files.
reset() { rm -f "$marker" "$results"/*; }
# working <seconds ago>: write `.working` for issue 7 as epoch seconds.
working() { echo $(($(date +%s) - $1)) >"$results/7.working"; }
# run [dir] [VAR=value ...]: run the hook from the worktree (or dir); sets $code and $out (stderr).
run() {
  local dir=${1:-$tree}
  [ $# -gt 0 ] && shift
  out=$(cd "$dir" && env -u GITHUB_ACTIONS -u CLAUDE_PROJECT_DIR "$@" "$hook" \
    <<<'{"session_id":"s","stop_hook_active":false}' 2>&1 >/dev/null)
  code=$?
}
snapshot() { (cd "$tmp" && find . -print | LC_ALL=C sort && cat "$results"/* 2>/dev/null); }
allows() { [ "$code" = 0 ] && ok || bad "$1: exit code was $code, expected 0"; }

# --- no marker: let the turn end ---
reset
working 60
run
allows "no marker"

# --- working, no result yet: block with exit 2 and say what to do ---
reset
printf '%s\n%s\n' "$results" 7 >"$marker"
working 60
before=$(snapshot)
run
[ "$code" = 2 ] && ok || bad "working: exit code was $code, expected 2"
grep -q "issue #7" <<<"$out" && ok || bad "working: message does not name the issue"
grep -q "Finish the issue" <<<"$out" && ok || bad "working: message does not say to finish the issue"
grep -q "write the result file" <<<"$out" && ok || bad "working: message does not say to write the result file"
grep -q "stop path of step 4" <<<"$out" && ok || bad "working: message does not name the stop path"
[ "$(snapshot)" = "$before" ] && ok || bad "working: the hook wrote or removed a file"

# --- the same, a few seconds before the 3 h 15 min mark: still blocks ---
working $((11700 - 30))
run
[ "$code" = 2 ] && ok || bad "just before the deadline: exit code was $code, expected 2"

# --- from a subfolder of the worktree, or with the shell moved out of it: still blocks ---
mkdir -p "$tree/sub"
run "$tree/sub"
[ "$code" = 2 ] && ok || bad "subfolder: exit code was $code, expected 2"
run "$results" CLAUDE_PROJECT_DIR="$tree"
[ "$code" = 2 ] && ok || bad "cwd moved out: exit code was $code, expected 2"

# --- a leading zero is read as decimal, not octal: still blocks ---
echo "0$(($(date +%s) - 60))" >"$results/7.working"
run
[ "$code" = 2 ] && ok || bad "leading zero: exit code was $code, expected 2"

# --- GitHub Actions: does nothing, even with a marker ---
working 60
run "$tree" GITHUB_ACTIONS=true
allows "GitHub Actions"

# --- the main checkout has no marker of its own: not blocked by the worktree's ---
run "$repo"
allows "main checkout"
run "$tree" CLAUDE_PROJECT_DIR="$repo"
allows "CLAUDE_PROJECT_DIR is the main checkout"

# --- a result present: let the turn end ---
echo "RESULT: merged #7 PR #1" >"$results/7.result"
run
allows "result present"

# --- no .working yet (the wait turn of step 0): let the turn end ---
reset
printf '%s\n%s\n' "$results" 7 >"$marker"
run
allows "no .working yet"

# --- past the deadline: let the turn end ---
working 11700
run
allows "past the deadline"

# --- .working is not epoch seconds: let the turn end, never block forever ---
echo "Thu Oct 30 21:55:11 +07 2026" >"$results/7.working"
run
allows "human-readable .working"
: >"$results/7.working"
run
allows "empty .working"
echo $(($(date +%s) * 1000)) >"$results/7.working"
run
allows "milliseconds .working"
echo $(($(date +%s) + 3600)) >"$results/7.working"
run
allows "future .working"
echo 0089 >"$results/7.working"
run
allows "leading-zero .working past the deadline"

# --- malformed marker: let the turn end ---
working 60
for content in "" "$results" "relative/results"$'\n'"7" "$results"$'\n'"#7" "$results"$'\n'"7x"; do
  printf '%s\n' "$content" >"$marker"
  run
  allows "marker '${content//$'\n'/|}'"
done

# --- outside a git repo: let the turn end ---
run "$results"
allows "outside a git repo"

echo "test-run-task-guard.sh: $pass passed, $fail failed"
[ "$fail" = 0 ]
