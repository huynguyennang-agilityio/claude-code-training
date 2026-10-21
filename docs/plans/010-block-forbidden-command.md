# Plan 010: Block forbidden git commands with a PreToolUse hook

Status: Approved
Approved: 2026-10-21
Issues: #22

## Context

[`CLAUDE.md`](../../CLAUDE.md#git-and-github-permissions) says what Claude must never do with git: push to `develop` or `main`, force-push, delete branches, push to the `gitlab` remote. Today that is only a written rule, so it holds only as long as Claude follows it. The repo has one hook, the `Stop` hook `.claude/hooks/check.sh`, which runs checks but blocks no command.

This plan adds a `PreToolUse` hook on the `Bash` tool that refuses those commands before they run, so the rule is enforced by the harness and not by memory. It is the first of three hooks the user wants (format-on-edit and notify-on-finish come in later plans).

## Open questions and assumptions

1. **Scope is the four "Never" rows only (assumption).** The hook blocks: any push to `develop` or `main`, any force-push, any branch deletion, any push to the `gitlab` remote. It does not try to enforce the "only when the user asks" rows (`git commit`, `git push` to a feature branch, `gh pr merge`), because a hook cannot tell whether the user asked. Say if you want `gh pr merge` blocked outright, so that merging always means running it yourself.
2. **Fail open when `jq` is missing (assumption, same as `check.sh`).** Without `jq` the hook cannot read the command, so it prints a warning and allows it. Failing closed would block every Bash call. Say if you prefer closed.
3. **The hook guards Claude's Bash tool only.** It does not stop you typing the same command in your own terminal. That is intended: the rules bind Claude, not you.
4. **Best effort, not a security boundary.** A command built through `eval`, a variable or a script file can slip past a text match. The hook catches the plain forms Claude actually writes, and `CLAUDE.md` stays the rule. This limit is written into the hook's header and the docs.

## Approach

Tooling only. No mobile, backend, API, schema or database change.

- `.claude/hooks/block-forbidden-command.sh` (new, executable). Reads the hook JSON from stdin, takes `tool_input.command` with `jq`, and splits it into simple commands on `;`, `&&`, `||`, `|` and newlines, so `cd x && git push -f` is seen. For each `git` command it blocks, with exit code 2 and a one-line reason on stderr that names the rule and what to do instead:
  - `git push` with `--force`, `-f`, `--force-with-lease`, `--mirror`, `--delete`/`-d`, or a refspec that starts with `+` or `:`.
  - `git push` whose remote is `gitlab`.
  - `git push` whose refspec or destination is `develop` or `main` (`develop`, `HEAD:develop`, `refs/heads/main`), and a bare `git push` or `git push origin` while the current branch is `develop` or `main`.
  - `git branch -d`, `-D`, `--delete` and `git push --delete`.
  - Global options before the subcommand (`git -C dir push`, `git -c k=v push`) are skipped over, so they do not hide the subcommand.
- `.claude/settings.json`: add a `PreToolUse` entry with matcher `Bash` that runs the script, next to the existing `Stop` entry. The `Stop` hook is unchanged.
- `.claude/hooks/test-block-forbidden-command.sh` (new): a table of commands with the expected result (blocked or allowed), run by feeding each one to the hook as JSON. Allowed cases include `git push -u origin feat/1-readme`, `git push origin docs/plan-010-x`, `git branch --show-current`, `git log --oneline`, and the word `develop` in a commit message or a file path.
- `CLAUDE.md`: one sentence under "Git and GitHub permissions" saying the rows marked Never are also enforced by this hook, and where it lives. `docs/workflow.md` is not changed.

This touches a security boundary of the development process (what Claude may run), not of the product: the approval covers adding a hook that can refuse commands. It affects no real data, production or cost.

Alternatives considered:

- **`permissions.deny` rules in `settings.json`.** Simple, but they match command prefixes, so `git push --force` is caught while `git push origin feat/x --force` and `git -C . push -f` are not. A hook can read the whole command.
- **A git `pre-push` hook.** It only sees pushes, runs for the user too, and is not part of the Claude workflow.

## Risks

- **False positive blocks a legitimate command** (for example a branch literally named `main-menu`). Contained by matching `develop`/`main` as whole refspec parts, not substrings, and by the allowed cases in the test table. The message tells Claude to ask you to run the command.
- **False negative on an obfuscated command.** Accepted, see assumption 4.
- **The script breaks and blocks all Bash.** Contained by running every case in the test table, and by exiting 0 on any input it cannot parse.
- **Hooks are shared settings.** If the file is wrong, every contributor's Claude session is affected. Contained by the test script and by the review of this change.

## Verification

- `bash .claude/hooks/test-block-forbidden-command.sh`: every blocked and allowed case passes.
- A live check in a Claude Code session: ask Claude to run `git push --force origin feat/x` and `git push origin develop`; both are refused with the hook's message, and `git status` still works.
- `shellcheck` on both scripts when it is installed; otherwise `Not verified: shellcheck is not installed`.
- Not checked: the hook on Windows, where `bash` and `jq` may be missing. The repo is developed on macOS.

## Ticket evidence

Chore: the scope is above. Behaviour that must stay unchanged: the `Stop` hook and every allowed git command. No images needed. Verification evidence is the test script output and the live refusal.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: block forbidden git commands with a PreToolUse hook` | chore, tooling | - [ ] `.claude/hooks/block-forbidden-command.sh` blocks pushes to `develop`/`main`, force-pushes, branch deletions and pushes to `gitlab`, with exit code 2 and a clear message<br>- [ ] It allows `git push -u origin <feature-branch>` and read-only git commands<br>- [ ] `.claude/settings.json` registers it as `PreToolUse` on `Bash`; the `Stop` hook is unchanged<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` covers each blocked and allowed case and passes<br>- [ ] `CLAUDE.md` notes that the Never rows are enforced by the hook<br>- [ ] Evidence: test script output and a live refusal in a session | none |
