#!/usr/bin/env bash
# Claude Code `Stop` and `Notification` hook: show a macOS notification when Claude finishes
# its turn or needs the user (a permission prompt, or waiting for input).
#
#   Stop          "Finished in <project folder>"
#   Notification  the message Claude Code provides, or a default text
#
# The text goes to osascript as an argument, never into the AppleScript source, so a quote
# or `$(...)` in a message that came from a tool cannot run as code. Control characters
# become spaces and the text is cut to 200 characters.
# The hook never blocks: it always exits 0. It does nothing when STRIDEQUEST_NOTIFY=0, off
# macOS, or without jq or osascript. On Stop it runs next to check.sh, so a notification can
# also appear for a stop that check.sh then blocks.
# Tests: .claude/hooks/test-notify.sh
set -o pipefail

[ "${STRIDEQUEST_NOTIFY:-1}" = 0 ] && exit 0
[ "$(uname)" = Darwin ] || exit 0
command -v osascript >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null) || exit 0

title="Claude Code"
case "$event" in
  Stop)
    project=$(basename "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)}")
    message="Finished in ${project:-the project}"
    ;;
  Notification) message=$(jq -r '.message // ""' <<<"$input" 2>/dev/null) || exit 0 ;;
  *) exit 0 ;;
esac

# One line of text, at most 200 characters (jq counts characters, not bytes).
# shellcheck disable=SC2016
message=$(printf '%s' "$message" | jq -Rrs 'gsub("\\p{Cc}"; " ") | .[0:200]' 2>/dev/null) || exit 0
[ -n "${message// /}" ] || message="Claude Code needs your attention"

osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
  -e 'end run' \
  -- "$message" "$title" >/dev/null 2>&1

exit 0
