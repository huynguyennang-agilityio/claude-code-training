# Implement and test (Phase 3)

Read this before you start implementing an issue. It holds the full rules of Phase 3: the build loop, the local hooks, CI and how to verify by ticket type. The evidence you record is described in [`evidence.md`](evidence.md). [`CLAUDE.md`](../../CLAUDE.md#workflow) keeps the loop in short form; if this file and `CLAUDE.md` disagree, `CLAUDE.md` wins.

## The build loop

Build in small steps. For each step:

1. Write the code.
2. Add or update tests. Every feature needs tests.
3. Run lint: `flutter analyze` in `mobile/`; `ruff check .` and `ruff format --check .` in `backend/`.
4. Run type checks: `flutter analyze` covers Dart; `mypy` in `backend/` (strict, configured in `pyproject.toml`).

## Working in a worktree

`/run-tasks` starts one session for each ready issue in the command turn, and **at most two sessions work at once**, each in its own git worktree ([plan 028](../../docs/plans/028-parallel-run-tasks.md), [plan 038](../../docs/plans/038-at-most-two-reviews.md)). In a worktree:

- Branch from `origin/develop` first (`git switch -c <type>/<issue>-<name> origin/develop`), never `git switch develop`, which fails while `develop` is checked out in the main folder.
- Then run `.claude/scripts/worktree-setup.sh <main checkout> <issue>`. It copies `.env` with the issue's own test database (`stridequest_i<issue>_test`, created by the integration conftest), creates `backend/.venv` and runs `flutter pub get`. The `export` line it prints has the password masked: never run it; the real URL is in the worktree's `.env`. If the script warns about an exported `TEST_DATABASE_URL`, prefix each test command with `env -u TEST_DATABASE_URL`, since each Bash call starts a new shell.
- **Never run `docker compose` from a worktree.** A compose project started there takes the same port as the main checkout's; the main checkout's `db` container serves every worktree.
- The knowledge graph (`backend/.ua/`, `mobile/.ua/`) is local to the main checkout; read it there.

## Local hooks

A `PostToolUse` hook (`.claude/hooks/format-on-edit.sh`, set up in `.claude/settings.json`) formats each Python file under `backend/` (`ruff format`) and each Dart file under `mobile/lib/` or `mobile/test/` (`dart format`) right after you write it with `Edit` or `Write`. Generated Dart files are skipped, and files changed through Bash are not formatted. The `Stop` hook below still checks them. Its tests are in `.claude/hooks/test-format-on-edit.sh`.

A `Stop` hook (`.claude/hooks/check.sh`, set up in `.claude/settings.json`) runs these checks for the files you changed when you try to finish, and blocks until they pass: `flutter analyze` and `flutter test` for `mobile/`; `ruff check`, `ruff format --check`, `mypy` and `pytest tests/unit` for `backend/`. It skips the integration tests, which need Docker, so run those yourself before Phase 4. After 3 failed stops in a row it lets you stop and warns the user. In GitHub Actions (`GITHUB_ACTIONS=true`) it does nothing. Its tests are in `.claude/hooks/test-check.sh`.

A macOS notification (`.claude/hooks/notify.sh`, on the `Stop` and `Notification` events in `.claude/settings.json`) tells the user when you finish or need them. It also appears for a stop that the `Stop` hook above then blocks. Set `STRIDEQUEST_NOTIFY=0` to switch it off. Its tests are in `.claude/hooks/test-notify.sh`.

A `SessionStart` hook (`.claude/hooks/automations-check.sh`, on `startup` in `.claude/settings.json`) checks whether this Mac has the `stridequest-pr-report` Desktop scheduled task, the 17:00 PR report from [plan 016](../../docs/plans/016-cloud-routines.md). If the task is missing, the hook asks you to offer `/setup-automations`. That skill creates the task only after the user says yes, and the task runs `/pr-report` (`.claude/skills/pr-report/`), so the report itself lives in the repo. The hook only prints a hint, and does nothing in GitHub Actions, in cloud sessions, off macOS, or when `STRIDEQUEST_AUTOMATIONS_HINT=0`. Its tests are in `.claude/hooks/test-automations-check.sh`. See [`docs/automations.md`](../../docs/automations.md).

The `security-guidance` plugin (enabled in `.claude/settings.json`, [plan 017](../../docs/plans/017-security-guidance-and-scan.md)) adds three hooks of its own:

- after each edit, a warning on dangerous patterns;
- when you finish a turn, a model review of the diff, which hands high-severity findings back to you;
- on `git commit` and `git push`, an agentic review that reads related files.

The second and third can wake you after you stop. Fix each finding, or answer it in your reply (an inline comment on the line saying why it is safe also counts). The project rules it applies are in `.claude/claude-security-guidance.md`: keep them under 8 KB and free of secrets. `SECURITY_GUIDANCE_DISABLE=1` turns the plugin off. The Claude GitHub workflows set it, and the README lists the other switches.

## CI

CI on GitHub runs the same checks on every PR into `develop` and every push to `develop`, plus the integration tests against PostgreSQL: `.github/workflows/backend-ci.yml` (job `backend`) and `.github/workflows/mobile-ci.yml` (jobs `mobile` and `goldens`). Each job always reports, and runs its checks only when its folder (`backend/**` or `mobile/**`), `docs/api/**` or its own workflow file changed. The golden tests run in the `goldens` job on `macos-15`, because the baselines only match on macOS (Apple Silicon); the `mobile` job on Linux skips them. All three jobs are required checks for merging into `develop`.

## Verify by ticket type

Passing tests don't prove everything works: `flutter_test` doesn't show the UI matches the design, and `pytest` doesn't show the mobile-backend flow works. Also verify by ticket type:

- **UI:** compare a screenshot of the running app with the design reference when the environment allows it.
- **Bug:** reproduce the bug before fixing it when feasible, then repeat the same steps after the fix.
- **API:** check the request, the response and the error contract.
- **Integration:** test the flow across components when it makes sense.

Record what you ran and what you saw as verification evidence ([`evidence.md`](evidence.md)). If you can't run the app on an emulator or device, or have no data to reproduce the issue, say so plainly with a `Not verified: <reason>` line. Never claim the UI or a fix was verified when it wasn't.
