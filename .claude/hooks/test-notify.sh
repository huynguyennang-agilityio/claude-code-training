#!/usr/bin/env bash
# Tests for notify.sh: put a fake osascript (and a fake uname) first in PATH, feed each event
# to the hook as the JSON that Claude Code sends, and check the arguments osascript received.
# Nothing is shown on screen.
#   bash .claude/hooks/test-notify.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/notify.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake="$tmp/fakebin"
log="$tmp/osascript.log"
mkdir -p "$fake"
# The fake osascript writes each argument on its own line; its exit code is FAKE_OSASCRIPT_EXIT.
cat >"$fake/osascript" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >>"$log"
exit "\${FAKE_OSASCRIPT_EXIT:-0}"
EOF
cat >"$fake/uname" <<'EOF'
#!/usr/bin/env bash
echo "${FAKE_UNAME:-Darwin}"
EOF
chmod +x "$fake/osascript" "$fake/uname"

# A PATH with jq and the fake uname but no osascript, to test the missing-tool case.
nobin="$tmp/nobin"
mkdir -p "$nobin"
ln -s "$(command -v jq)" "$nobin/jq"
cp "$fake/uname" "$nobin/uname"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# run <json> [VAR=value ...]: run the hook with the fake tools, return its exit code.
run() {
  local json=$1
  shift
  : >"$log"
  env PATH="$fake:$PATH" "$@" "$hook" <<<"$json" >/dev/null 2>&1
}

# args: the arguments osascript received, one per line. With the hook's fixed call there are
# nine: -e, three script lines, then -- , the message and the title.
last_message() { sed -n '8p' "$log"; }
last_title() { sed -n '9p' "$log"; }
script_lines() { sed -n '1,7p' "$log"; }
calls() { [ -s "$log" ] && wc -l <"$log" | tr -d ' ' || echo 0; }

stop='{"hook_event_name":"Stop","cwd":"/work/myproj","session_id":"s1"}'

# --- Stop ---
run "$stop" CLAUDE_PROJECT_DIR=/Users/x/stridequest || bad "stop: exit code was not 0"
[ "$(last_message)" = "Finished in stridequest" ] && ok || bad "stop: message was '$(last_message)'"
[ "$(last_title)" = "Claude Code" ] && ok || bad "stop: title was '$(last_title)'"
baseline=$(script_lines)
[ "$(calls)" = 9 ] && ok || bad "stop: expected 9 argument lines, got $(calls)"

run_log_reset() { : >"$log"; }
run_log_reset
env -u CLAUDE_PROJECT_DIR PATH="$fake:$PATH" "$hook" <<<"$stop" >/dev/null 2>&1 || bad "stop without CLAUDE_PROJECT_DIR: exit code"
[ "$(last_message)" = "Finished in myproj" ] && ok || bad "stop without CLAUDE_PROJECT_DIR: message was '$(last_message)'"

# --- Notification ---
run '{"hook_event_name":"Notification","message":"Claude needs your permission to use Bash"}'
[ "$(last_message)" = "Claude needs your permission to use Bash" ] && ok || bad "notification: message was '$(last_message)'"
[ "$(script_lines)" = "$baseline" ] && ok || bad "notification: the AppleScript lines changed"

run '{"hook_event_name":"Notification"}'
[ "$(last_message)" = "Claude Code needs your attention" ] && ok || bad "notification without message: '$(last_message)'"
run '{"hook_event_name":"Notification","message":"   "}'
[ "$(last_message)" = "Claude Code needs your attention" ] && ok || bad "notification with blank message: '$(last_message)'"

# --- hostile and odd text ---
pwn="$tmp/pwned"
hostile=$(jq -n --arg m "x\"; do shell script \"touch $pwn\" -- \$(touch $pwn) \`touch $pwn\` it's" \
  '{hook_event_name: "Notification", message: $m}')
run "$hostile" || bad "hostile: exit code was not 0"
[ ! -e "$pwn" ] && ok || bad "hostile: a command ran"
[ "$(script_lines)" = "$baseline" ] && ok || bad "hostile: the AppleScript lines changed"
[ "$(calls)" = 9 ] && ok || bad "hostile: expected 9 argument lines, got $(calls)"
case "$(last_message)" in x\"*) ok ;; *) bad "hostile: message did not arrive whole: '$(last_message)'" ;; esac

newline=$(jq -n '{hook_event_name: "Notification", message: "line one\nline two\tTab\u001b[31m"}')
run "$newline"
[ "$(calls)" = 9 ] && [ "$(last_message)" = "line one line two Tab [31m" ] && ok || bad "control characters: '$(last_message)' ($(calls) lines)"

run '{"hook_event_name":"Notification","message":"-e display dialog"}'
[ "$(last_message)" = "-e display dialog" ] && [ "$(sed -n '7p' "$log")" = "--" ] && ok || bad "message starting with a dash"

long=$(jq -n --arg m "$(printf 'a%.0s' $(seq 1 500))" '{hook_event_name: "Notification", message: $m}')
run "$long"
len=$(last_message | tr -d '\n' | wc -c | tr -d ' ')
[ "$len" = 200 ] && ok || bad "long message: length was $len, expected 200"

viet=$(jq -n --arg m "$(printf 'ạ%.0s' $(seq 1 300))" '{hook_event_name: "Notification", message: $m}')
run "$viet"
count=$(last_message | jq -Rr 'length')
[ "$count" = 200 ] && ok || bad "multibyte message: $count characters, expected 200"

# --- does nothing ---
run "$stop" STRIDEQUEST_NOTIFY=0 && [ "$(calls)" = 0 ] && ok || bad "STRIDEQUEST_NOTIFY=0 still notified"
run "$stop" FAKE_UNAME=Linux && [ "$(calls)" = 0 ] && ok || bad "non-macOS still notified"
run '{"hook_event_name":"PreToolUse"}' && [ "$(calls)" = 0 ] && ok || bad "unknown event still notified"
for raw in '' 'not json' '{}'; do
  run "$raw" && [ "$(calls)" = 0 ] && ok || bad "input '$raw': exit code or call"
done
: >"$log"
env PATH="$nobin" "$BASH" "$hook" <<<"$stop" >/dev/null 2>&1 && ok || bad "without osascript: exit code was not 0"

# --- never blocks ---
run "$stop" FAKE_OSASCRIPT_EXIT=1 && ok || bad "failing osascript: exit code was not 0"

echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
