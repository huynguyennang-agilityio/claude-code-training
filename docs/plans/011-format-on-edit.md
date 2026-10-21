# Plan 011: Format files after Claude edits them

Status: approved
Approved: 2026-10-21
Issues: <filled in after approval>

## Context

The `Stop` hook (`.claude/hooks/check.sh`) already fails when `ruff format --check` finds an unformatted Python file, so today Claude finds out about bad formatting only at the end of a task and then has to fix it. This plan adds a `PostToolUse` hook that formats each Python or Dart file right after Claude writes it, so the file is already formatted when the checks run. It is the second of three hooks the user wants; plan 010 (block-forbidden-command) is done, notify-on-finish is plan 012.

State of the repo today (checked 2026-10-21 on `develop`): `dart format --output=none --set-exit-if-changed lib test` in `mobile/` reports 0 files changed out of 185, and `ruff format --check .` in `backend/` reports 110 files already formatted. So the hook will not reformat code Claude did not touch.

## Open questions and assumptions

1. **Format only, no fixes (assumption).** The hook runs `dart format` and `ruff format`. It does not run `dart fix` or `ruff check --fix`, because those change behaviour, not just layout.
2. **Only the `Edit` and `Write` tools (assumption).** Files changed through Bash (`sed -i`, `build_runner`, a code generator) are not formatted by this hook. The `Stop` hook still catches a Python file left unformatted.
3. **Generated Dart files are skipped.** `*.g.dart`, `*.freezed.dart` and `*.config.dart` come from `build_runner` and are committed as generated (see `CLAUDE.md`). They are already excluded from the analyzer in `mobile/analysis_options.yaml`.
4. **Default Dart line width (80).** `mobile/analysis_options.yaml` has no `formatter:` section, and the existing code already matches the default. Python uses `line-length = 100` from `backend/pyproject.toml`. Nothing is changed in either config.
5. **Not formatted: `mobile/ios/`, `mobile/android/`, `mobile/build/`, `.dart_tool/`, `backend/.venv/` and anything outside the project folder.**
6. **The hook never blocks.** If a formatter fails (for example a file with a syntax error half way through a task) the hook exits 0 and leaves the file as it is. The `Stop` hook reports real problems at the end.

## Approach

Tooling only. No mobile, backend, API, schema or database change.

- `.claude/hooks/format-on-edit.sh` (new, executable). Reads the hook JSON on stdin, takes `tool_input.file_path` with `jq`, and:
  - for `*.py` under `backend/`: runs `ruff format <file>` from `backend/`, so `pyproject.toml` applies. It uses `backend/.venv/bin/ruff` when it exists, as `check.sh` does, and `ruff` from `PATH` otherwise.
  - for `*.dart` under `mobile/lib/` or `mobile/test/`, except the generated suffixes above: runs `dart format <file>` from `mobile/`.
  - for any other path, a missing file, a missing tool or input it cannot parse: does nothing and exits 0.
  - only touches the one file Claude just edited, never the whole project.
- `.claude/settings.json`: add a `PostToolUse` entry with matcher `Edit|Write` that runs the script. The other hooks are unchanged.
- `.claude/hooks/test-format-on-edit.sh` (new): runs the hook on copies of files in a throwaway project folder. Cases: an unformatted `.py` and an unformatted `.dart` get formatted; an already formatted file is byte for byte the same; a generated Dart file, a `.md` file, a file outside `backend/` and `mobile/`, a missing file, a file with a syntax error and garbage input are all left alone with exit 0. When `ruff` or `dart` is not installed the matching cases print `SKIPPED` instead of failing.
- `CLAUDE.md`: one sentence in Phase 3 saying that Python and Dart files are formatted automatically after each edit, and that the `Stop` hook still checks them.

This touches nothing in the product. It does rewrite files on disk after Claude edits them, which the approval must cover.

Effect of rewriting a file: after the hook runs, the file on disk can differ from what Claude just wrote. The harness already tells Claude when a file changed on disk, so a following `Edit` works from the current content. If an `Edit` fails because the text moved, Claude reads the file again.

Alternatives considered:

- **Format the whole project at the end (in `check.sh`).** Would change files only when Claude stops, and would mix formatting changes into the `Stop` checks. The per-file hook is simpler and keeps the file formatted at every step.
- **A git `pre-commit` hook.** Runs for the user too, and only at commit time; Claude would still write unformatted code first.

## Risks

- **A different Dart SDK formats differently.** `dart format` output depends on the SDK version (3.10.4 here). Someone on another version would see their editor and the hook disagree. Contained by the repo being formatted with the same tool today; a CI check is out of scope (the repo has no CI).
- **Formatting a half-written file.** A syntax error makes the formatter fail; the hook ignores the failure and exits 0, so no work is lost.
- **Slower edits.** `dart format` on one file takes well under a second. The hook has a 30 second timeout, and a timeout does not block anything.
- **A formatter rewrites unrelated lines of an already unformatted file.** Not a problem today (the repo is clean, see Context). Phase 4 (`git diff develop...HEAD`) would show it if it ever happens.

## Verification

- `bash .claude/hooks/test-format-on-edit.sh`: all cases pass.
- `shellcheck` on both scripts when it is installed.
- Live check in a Claude Code session: ask Claude to write a badly formatted Python file under `backend/` and a Dart file under `mobile/lib/`, then show the files; both are formatted. A generated file stays as written.
- `dart format --output=none --set-exit-if-changed lib test` and `ruff format --check .` still report no changes on `develop`.
- Not checked: Windows and Linux (the repo is developed on macOS).

## Ticket evidence

Chore: the scope is above. Behaviour that must stay unchanged: the other hooks, the formatter configs, and every file that is already formatted. No images needed. Verification evidence is the test script output and the live check.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: format Python and Dart files after Claude edits them` | chore | - [ ] `.claude/hooks/format-on-edit.sh` formats an edited `*.py` under `backend/` with `ruff format` and an edited `*.dart` under `mobile/lib/` or `mobile/test/` with `dart format`<br>- [ ] It leaves generated Dart files, other file types, paths outside the project and missing files alone, and always exits 0<br>- [ ] `.claude/settings.json` registers it as `PostToolUse` on `Edit\|Write`; the other hooks are unchanged<br>- [ ] `.claude/hooks/test-format-on-edit.sh` covers each case above and passes<br>- [ ] `CLAUDE.md` notes the automatic formatting<br>- [ ] Evidence: test script output and a live check in a session | none |
