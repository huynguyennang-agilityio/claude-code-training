#!/usr/bin/env bash
# Claude Code `Stop` hook: keep a /run-tasks child session working until it has written its
# result file (plan 039, task 6). Exit 2 blocks the end of the turn and tells Claude why.
#
# Step 0 of the run-tasks session brief writes the marker `$(git rev-parse --git-dir)/run-task`
# together with `<results>/<issue>.working`. The marker has two lines: the absolute `<results>`
# path, then the issue number. The hook blocks only when all of these hold:
#   - the marker exists and both lines are valid;
#   - `<results>/<issue>.working` exists and holds epoch seconds;
#   - `<results>/<issue>.result` does not exist yet;
#   - less than 3 hours 15 minutes (the parent's 3-hour deadline plus its 15 minutes to stop)
#     have passed since `.working`.
# Otherwise (no marker, a malformed marker or `.working`, the wait turn of step 0, a result
# written, past the deadline) it lets the turn end. There is no block limit: the deadline is
# the way out, and the user's Stop button does not run Stop hooks. The hook only reads files.
# In GitHub Actions (GITHUB_ACTIONS=true) it does nothing, as check.sh.
set -uo pipefail

[ "${GITHUB_ACTIONS:-}" = "true" ] && exit 0

DEADLINE_SECONDS=11700 # 3 h 15 min

# The hook input is not needed; read it so the writer never gets a broken pipe.
cat >/dev/null

# The session's folder, not the shell's current one, which a `cd` may have moved.
git_dir=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
marker="$git_dir/run-task"
[ -f "$marker" ] || exit 0

{
  IFS= read -r results || true
  IFS= read -r issue || true
} <"$marker"
results=${results:-}
issue=${issue:-}
case "$results" in /*) ;; *) exit 0 ;; esac
[[ "$issue" =~ ^[0-9]+$ ]] || exit 0

working="$results/$issue.working"
result="$results/$issue.result"
[ -f "$result" ] && exit 0
[ -f "$working" ] || exit 0

started=$(head -n 1 "$working" 2>/dev/null | tr -d '[:space:]')
# A `.working` that is not epoch seconds (a human-readable date, milliseconds, a time in the
# future) has no deadline the hook can read, so it never blocks rather than block forever.
# At most 12 digits, so the arithmetic cannot overflow; 10# so a leading zero is not octal.
[[ "$started" =~ ^[0-9]{1,12}$ ]] || exit 0
now=$(date +%s)
[ $((10#$started)) -le "$now" ] || exit 0
[ $((now - 10#$started)) -lt "$DEADLINE_SECONDS" ] || exit 0

cat >&2 <<EOF
run-task-guard.sh: issue #$issue of a /run-tasks run is still running: $working exists and $result does not.
Don't end the turn yet. Finish the issue (session brief steps 1 to 12 of the run-tasks skill), or take the stop path of step 4, and write the result file with its RESULT: line (step 12).
EOF
exit 2
