# Backend progress

One line per finished task, appended at the end, in the task's last commit before its PR opens ([plan 019](../docs/plans/019-area-autopilot.md)). Use the issue number, not the PR number: the issue links to its PR through `Closes #N`, and adding a PR number later would re-run CI.

```text
- YYYY-MM-DD [area] #<issue> <issue title without the [area] prefix>. <one sentence on what changed>
```

A task that touches `mobile/` too also writes a line in `mobile/PROGRESS.md`. Read the end of this file with `tail -n 30`. Past 200 lines, move the older lines to `PROGRESS-archive.md`.

## Done
- 2026-10-26 [profile] #120 docs: profile, email and password contract. Adds `docs/api/profile.md`, the email and password routes and `incorrect_password` in `docs/api/auth.md`, and their examples.
- 2026-10-26 [profile] #121 feat: GET /users/me/profile (backend). Adds the `profile` module, the `user_profiles` table and `GET /api/v1/users/me/profile`, which returns an empty profile when the user never saved one.
- 2026-10-26 [profile] #122 feat: PUT /users/me/profile (backend). Adds `PUT /api/v1/users/me/profile`, an upsert that replaces the whole profile, with every contract field rule checked as `422 validation_error`.
- 2026-10-27 [auth] #123 feat: PUT /users/me/email (backend). Adds `PUT /api/v1/users/me/email` with the current-password check, the shared sign-in rate limit, `403 incorrect_password` and `409 email_taken`.
- 2026-10-27 [auth] #124 feat: PUT /users/me/password (backend). Adds `PUT /api/v1/users/me/password`, which checks the current password like the email change, revokes every refresh token of the user and returns a new token pair.
- 2026-10-27 [infra] #150 chore: backend Docker image for production. Adds `backend/Dockerfile` (python:3.12-slim, non-root, uvicorn on `$PORT`) and `.dockerignore`, builds the image in the `backend` CI job, and starts `docs/deploy.md`.
- 2026-10-27 [infra] #151 chore: API release workflow to Render with Neon migrations. Adds `render.yaml` and `release-api.yml` (Neon migration, then a Render deploy of the same commit through the API, polled until live and healthy) and the API section of `docs/deploy.md`.
- 2026-10-27 [infra] #154 chore: full release workflow and release skills. Adds `release.yml` (API, then iOS and Android), the `/release`, `/release-api`, `/release-ios` and `/release-android` skills with shared `steps.md`, the hook rules against deleting, moving or force-pushing a tag, and the Release docs.
- 2026-10-28 [infra] #164 chore: remove the human-merge label rule. `/run-tasks` no longer stops on the `human-merge` label (it lists PRs above 400 lines in its report instead), and the forbidden-command hook no longer guards the label.
- 2026-10-28 [infra] #170 ci: post the Claude review through an artifact with a secret check. `claude-review` passes the review to the `post` job as a one-day artifact after `.github/scripts/check-no-secrets.sh` finds no job secret or token-shaped string, instead of a job output GitHub may drop.
- 2026-10-28 [infra] #171 ci: post the security scan through an artifact with a secret check. `claude-security-scan` passes its report to the `post` job as a one-day artifact after the same `check-no-secrets.sh` check, instead of a job output.
- 2026-10-28 [infra] #165 chore: worktree setup script for parallel runs. Adds `.claude/scripts/worktree-setup.sh`, which copies `.env` into a worktree with its own `stridequest_i<issue>_test` database, creates `backend/.venv` and runs `flutter pub get`, with tests in `test-worktree-setup.sh`.
- 2026-10-28 [infra] #166 docs: run up to two issues in parallel sessions with /run-tasks. `/run-tasks` asks once in a preflight, runs each issue in its own child session and worktree (at most two at once), merges `develop` in before each merge, and ends with a report artifact sent over Slack.
- 2026-10-28 [infra] #176 chore: /approve-plan reads the new task format. `/approve-plan` reads `### Phase N` / `#### Task N` / `#### Checkpoint` breakdowns, checks each task's Acceptance criteria against its table row and writes the new issue body (Description, Acceptance criteria, Verification, Files likely touched, Estimated scope, Dependencies), while old-format plans keep the old body.
- 2026-10-28 [infra] #177 chore: task format from planning-and-task-breakdown. The `task-breakdown` skill, the plan template, `CLAUDE.md` and `.claude/workflow/plan.md` describe tasks with Description, Acceptance criteria, Verification, Dependencies, Files likely touched and Estimated scope, grouped in phases with checkpoints, sized XS to XL with L split, and reviewed before publishing.
