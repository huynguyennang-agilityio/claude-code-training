# Plan 012: Notify the user when Claude finishes or needs them

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

Long tasks (a full `flutter test`, the `Stop` hook's checks, a code review) leave the user looking at the terminal. This plan adds a macOS notification when Claude finishes its turn and when it stops to ask for permission or input, so the user can work elsewhere. It is the last of three hooks the user wants; plan 010 (block-forbidden-command) is done and plan 011 is format-on-edit.

Claude Code has two events for this: `Stop` (Claude finished its turn) and `Notification` (Claude needs a permission or has been idle waiting). The machine has `osascript` (built in to macOS) and `terminal-notifier`.

## Open questions and assumptions

1. **Shared or personal (the user answers).** A notification is a personal preference, and `.claude/settings.json` is shared with everyone who clones the repo. Assumption: the user is the only developer (as plan 007 assumed), so the hook is registered in the shared `.claude/settings.json`. If someone else joins, they can switch it off with `STRIDEQUEST_NOTIFY=0`. The alternative is to commit only the script and let each person register it in `.claude/settings.local.json` or `~/.claude/settings.json`; say if you prefer that.
2. **`osascript` only (assumption).** It needs nothing installed. `terminal-notifier` is not used, so the hook works on any Mac. The notification has no sound.
3. **Off-macOS and missing tools do nothing (assumption).** If `uname` is not `Darwin`, or `osascript` or `jq` is missing, the hook exits 0 without a message.
4. **An extra notification when the `Stop` checks fail (accepted).** `check.sh` and the notify hook both run on `Stop`, at the same time, and the notify hook cannot know whether `check.sh` will block the stop. When the checks fail and Claude carries on fixing them, the user still gets one "finished" notification for that attempt. Say if this is too noisy; the fix would be to notify only from `check.sh` when it passes, which couples two hooks.
5. **Message content (assumption).** `Stop`: title "Claude Code", message "Finished in <project folder name>". `Notification`: the message Claude Code provides, for example that it needs permission, cut to 200 characters.

## Approach

Tooling only. No mobile, backend, API, schema or database change.

- `.claude/hooks/notify.sh` (new, executable). Reads the hook JSON on stdin and takes `hook_event_name` and, for `Notification`, `message` with `jq`. Builds the title and text as in assumption 5 and calls:

  ```bash
  osascript -e 'on run argv' \
            -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
            -e 'end run' -- "$message" "$title"
  ```

  The text goes in as an argument, never spliced into the AppleScript source. This matters because the `Notification` message can contain text that came from a tool, and a quote in it must not turn into AppleScript or shell code. Control characters are replaced by spaces and the text is cut to 200 characters first.
- Always exits 0 and never blocks Claude. If `STRIDEQUEST_NOTIFY=0` is set, it exits at once.
- `.claude/settings.json`: add a `Stop` entry for `notify.sh` next to the existing `check.sh` entry, and a new `Notification` entry. The `check.sh` entry and the `PreToolUse` hook are unchanged.
- `.claude/hooks/test-notify.sh` (new): puts a fake `osascript` (and a fake `uname` for the non-macOS case) first in `PATH`, feeds each event to the hook as JSON, and checks the arguments the fake received. Cases: `Stop` gives the title and the project name; `Notification` passes its message; a message with quotes, `$(...)`, backticks and a newline reaches `osascript` as one literal argument and creates no file; a 500 character message is cut to 200; `STRIDEQUEST_NOTIFY=0`, a non-Darwin system, garbage input and empty input all exit 0 without calling `osascript`.
- `CLAUDE.md`: one sentence in Phase 3 saying that a notification appears when Claude finishes or needs the user, and how to switch it off.

This changes what runs on the user's machine at the end of every turn and adds a second hook to the `Stop` event. It reads the hook input and sends nothing outside the machine. The approval must cover this.

Alternatives considered:

- **`terminal-notifier`.** Nicer (click to focus, grouping), but needs `brew install` and fails silently on a clean Mac.
- **A terminal bell (`printf '\a'`).** No dependency, but the hook's output does not reach the terminal and a bell is easy to miss.
- **Notify only after a long turn.** The hook does not get the duration of the turn, so it would need to read the transcript or keep state between events. More moving parts for little gain.

## Risks

- **Notification noise.** One per turn plus one per permission prompt. Contained by `STRIDEQUEST_NOTIFY=0`; assumption 4 is the known extra case.
- **macOS may not show the banner.** The first notification from the terminal app needs "Notifications" allowed in System Settings for that app, and Focus modes can hide it. The hook cannot detect this, so the verification asks the user to confirm the banner.
- **Injection through the message text.** Contained by passing it as an `osascript` argument and tested with hostile strings.
- **A slow or hung `osascript` delays the end of a turn.** The hook has a 10 second timeout, after which the turn ends anyway.

## Verification

- `bash .claude/hooks/test-notify.sh`: all cases pass.
- `shellcheck` on both scripts when it is installed.
- Live check: `echo '{"hook_event_name":"Stop","cwd":"/tmp/x"}' | .claude/hooks/notify.sh` shows a banner on the user's screen, and so does a real permission prompt in a Claude Code session. Claude cannot see the user's screen, so the user confirms: `Not verified by Claude: the banner itself`.
- The existing `Stop` hook still blocks on a failing check (the notify entry does not change its exit code).
- Not checked: Linux and Windows. The repo is developed on macOS.

## Ticket evidence

Chore: the scope is above. Behaviour that must stay unchanged: `check.sh` and its blocking, and the other hooks. No images needed. Verification evidence is the test script output and the user's confirmation of the banner.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: notify the user when Claude finishes or needs them` | chore | - [ ] `.claude/hooks/notify.sh` shows a macOS notification for the `Stop` and `Notification` events, with the text from assumption 5<br>- [ ] The text reaches `osascript` as an argument; a message with quotes, `$(...)` and newlines runs no code<br>- [ ] It always exits 0, does nothing when `STRIDEQUEST_NOTIFY=0`, off macOS or without `osascript`/`jq`<br>- [ ] `.claude/settings.json` registers it for `Stop` (next to `check.sh`, which is unchanged) and `Notification`<br>- [ ] `.claude/hooks/test-notify.sh` covers each case above and passes<br>- [ ] `CLAUDE.md` notes the notification and `STRIDEQUEST_NOTIFY=0`<br>- [ ] Evidence: test script output; the user confirms the banner (otherwise `Not verified: the banner itself`) | none |
