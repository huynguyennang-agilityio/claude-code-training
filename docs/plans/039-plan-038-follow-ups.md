# Plan 039: Clean up what is left after plan 038 (Follow-ups from the plan 038 runs)

Status: approved
Approved: 2026-10-30, by the user in chat: "/approve-plan 039"
Issues: #236, #237, #238, #239, #240, #241
Draft: https://claude.ai/artifact/9vMV4PWJTWVeaSCyP3unwm, version 1793353984-c432

## Context

Based on: [plan 038](https://claude.ai/artifact/7GyE6YTwACo5shU6RwLDPb) · [Run 2026-10-30 #225–#229](https://claude.ai/artifact/GUYpo5n4F3m3LgLeKfQXQX) · [Run 2026-10-30 #227 #228 #229](https://claude.ai/artifact/MZJMWN86R4pZqKNavE1XdD) · PR #231, #232, #233, #234

Labels: `area:infra` · 6 tasks · 2 phases

### Prerequisites

- **After task 5 merges** (not before, because a required check with no workflow on `develop` blocks every PR): in GitHub → Settings → Rules → ruleset "Require CI on develop", add the status check `scripts` (source GitHub Actions).
- No other key, secret or device is needed.

### Problem

The three `/run-tasks` runs of plan 038 merged all 5 issues (#225–#229), but the reports and the `RESULT:` lines left work that needs a plan:

- **Stale text left** outside the files plan 038 changed: `CLAUDE.md:55` and `.claude/workflow/implement.md:16` still say "at most two issue sessions at once" (now every issue is started in the command turn, and at most two issues *work* at once); the diagram at `docs/workflow.md:36` still says the two reviewers run "in parallel"; `README.md` "Asking for a review" does not yet state the budget of 2 reviews.
- **Reviewer running in the background:** in #225, #227, #228 and #229, the Agent tool put `code-reviewer` in the background even without `run_in_background`. The #225 child session ended its turn before it had a result file and only went on after the parent messaged it.
- **Shared test database:** `worktree-setup.sh` leaves the existing `.env` of a reused worktree as it is, still pointing at another issue's database (seen with `stridequest_i189_test` and `stridequest_i212_test`), and only warns.
- **`PROGRESS.md` always conflicts:** two PRs both add a line at the end of the file, so the PR that merges second almost always conflicts at step 9 and spends one review.
- **Script tests have no CI:** no job runs `.github/scripts/test-*.sh`, `.claude/hooks/test-*.sh` or `.claude/scripts/test-*.sh`.
- **Order in step 0** (a Medium finding of #225): the wait gate checks the integration gate before the `git fetch origin` of step 1, so it may read a stale `origin/develop`.

Out of scope for this plan: a time limit for `/code-review max` (#228), upload-artifact v4 with an empty file (#228).

### Decided by the user

- Reviewer in the background: fixed with a **Stop hook** that stops a child session from ending its turn when it has started work and has no result file yet.
- The new CI job is a **required check** named `scripts`; the user adds it to the ruleset (Prerequisites).

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **The Stop hook's marker:** step 0 of the session brief, when it writes `<results>/<issue>.working`, also writes `$(git rev-parse --git-dir)/run-task` in the worktree, holding the `<results>` path and the issue number. The file sits in the worktree's git folder, so it is never committed, and it goes away with the worktree.
2. **When the hook blocks:** only when there is a marker, there is `<issue>.working`, there is no `<issue>.result` yet, and less than 3 hours 15 minutes have passed since `.working` (the 3-hour deadline plus the 15 minutes the parent gives to stop). In every other case the hook lets the turn end. The wait turn of step 0 (no `.working` yet) is not blocked.
3. **No limit on the number of blocks** like the `MAX_BLOCKS=3` of `check.sh`: the 3 hours 15 minutes mark is the way out. When the user presses Stop to interrupt a session, the Stop hook does not run, so the user can always interrupt.
4. **The new hook is its own file** `.claude/hooks/run-task-guard.sh`, added to the `Stop` array of `.claude/settings.json` before `check.sh`; it is not merged into `check.sh`. In GitHub Actions there is no marker, so the hook does nothing.
5. **`worktree-setup.sh`** when `.env` already exists: if `TEST_DATABASE_URL` points at another database, replace only that line with `stridequest_i<issue>_test` (write a temp file, then `mv`, as when copying), and keep every other line as it is; if it is already right, don't touch the file.
6. **Union merge:** a new `.gitattributes` with `backend/PROGRESS.md merge=union` and `mobile/PROGRESS.md merge=union`. Union is a driver built into git, so `git merge origin/develop` at step 9 keeps both lines with no conflict. It does not apply to the DECISIONS files (they have a header, and both sides may edit the same line).
7. **The `scripts` job:** a new workflow `.github/workflows/scripts-ci.yml`, running on `ubuntu-latest` for every PR into `develop` and every push to `develop`, with no `paths:` filter (it always reports, like `backend`), and `permissions: contents: read`. It runs every `test-*.sh` in the three folders above. A test that needs a tool only macOS has (for example `osascript` in `test-notify.sh`) gets a stand-in tool installed by the job, or skips exactly that part with a line saying so; it never skips the whole file.
8. **Merge conditions:** step 10 of the session brief and the ruleset description in `README.md` add `scripts` to the list of required checks.

## Approach

- **Task 1 (docs):** `CLAUDE.md:55`, `.claude/workflow/implement.md:16` (one session per issue, started in the command turn, at most two sessions working at once); the `LR` node at `docs/workflow.md:36` (the two reviewers run in the foreground in one message); `README.md` "Asking for a review" (at most 2 `claude-review` runs, the second is the last, remaining nits go to `## Nits left`).
- **Task 2:** `.claude/skills/run-tasks/SKILL.md` step 0 and the integration gate item of step 2: a `(mobile, integration)` issue runs `git fetch origin` before checking the gate on `origin/develop`.
- **Task 3:** `.claude/scripts/worktree-setup.sh` and `.claude/scripts/test-worktree-setup.sh` (assumption 5).
- **Task 4:** a new `.gitattributes`; the sentence "keep both lines in `PROGRESS.md`" at step 9 of `SKILL.md` becomes "PROGRESS.md merges by itself (union)".
- **Task 5:** a new `.github/workflows/scripts-ci.yml`; `SKILL.md` step 10; the ruleset in `README.md` (line 390) and the workflow table in the README.
- **Task 6:** a new `.claude/hooks/run-task-guard.sh` and `.claude/hooks/test-run-task-guard.sh`; `.claude/settings.json`; `SKILL.md` step 0 writes the marker.
- No change to the API, schema, migrations, real data or production. No new dependency.

### Changes the approval must cover

| Category | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration that could lose data | No | — |
| Auth / security boundary | **Yes (low)** | The new workflow has only `contents: read`, no secret, and runs no model. The new hook only reads files on disk. |
| Architecture / Claude rules | **Yes** | A new Stop hook, a new required check in the merge conditions, how `PROGRESS.md` merges, the text in `CLAUDE.md`. |
| Real data / production / cost | No | A few more CI minutes per PR. |

## Risks

- **The Stop hook keeps a session running forever:** the 3 hours 15 minutes mark, and the user can always interrupt with the Stop button (assumption 3). The hook's tests cover each case that lets the turn end.
- **The hook wrongly blocks a session that is not part of `/run-tasks`:** with no marker it does not block; the marker sits in each worktree's git folder, and the main checkout never has one.
- **Union merge puts lines out of order**, or repeats a line when both sides add exactly the same text: harmless for a log file; step 9 still re-runs the five Phase 4 points.
- **A merge on GitHub does not use `.gitattributes`:** no problem, because step 9 merges `develop` locally before the PR is merged.
- **A script test cannot run on Linux** (it needs `osascript`, `flutter`, `ruff`...): task 5 installs the tool or skips exactly that part with a line saying so (assumption 7); a red job is not merged.
- **Adding the required check too early** blocks every PR: the manual step is done only after task 5 merges (Prerequisites).

## Verification

- Tasks 1, 4, 5: `git grep -n` for the old text from the repository root finds nothing (except plans and `PROGRESS.md`).
- Task 3: `.claude/scripts/test-worktree-setup.sh` has new cases for an existing `.env` pointing at another database, and for an `.env` that is already right and is not changed.
- Task 4: a test in a temporary repository: two branches both add a line at the end of `backend/PROGRESS.md`, the merge has no conflict and keeps both lines.
- Task 5: the `scripts` job is green on its own PR; the list of tests run is in the log.
- Task 6: `.claude/hooks/test-run-task-guard.sh` covers: no marker, a result present, no `.working` yet, past the deadline (let through), and working with no result (blocked, exit 2).
- Cannot be verified in the PR: the hook blocking in a real `/run-tasks` run; the next run shows it.

## Ticket evidence

All 6 tasks are **Refactor / chore**: they need the scope and the behaviour that must stay unchanged, and no images. The scope is in each task; the behaviour that stays unchanged: `/run-tasks` still runs as in plan 038, `worktree-setup.sh` still never prints the password, and the existing CI (`backend`, `mobile`, `goldens`) does not change. Sources: the `RESULT:` lines of #225–#229 and the two run reports at the top of the page.

## Task breakdown

One task is one issue.

### Phase 1: text fixes and small fixes

#### Task 1: `[infra] docs: fix wording left behind by plan 038`

**Description:** Fix the four places that still describe the rules from before plan 038: `CLAUDE.md:55` and `.claude/workflow/implement.md:16` (one session per issue, started in the command turn, at most two sessions working at once), the `LR` node at `docs/workflow.md:36` (keeping the Mermaid syntax), and the "Asking for a review" section of `README.md`. Text only; no rule changes.

**Acceptance criteria:**
- [ ] `CLAUDE.md` and `.claude/workflow/implement.md` say that `/run-tasks` starts one session for each ready issue in the command turn, and at most two sessions work at once, each in its own worktree
- [ ] The local review node in `docs/workflow.md` says `code-reviewer` and `/code-review` run in the foreground in the same message
- [ ] The "Asking for a review" section of `README.md` says a PR gets at most two `claude-review` runs, the second is the last, and the remaining nits go under `## Nits left`

**Verification:**
- [ ] `git grep -n "two issue sessions at once" -- ':/' ':/!docs/plans' ':/!*PROGRESS.md'` finds nothing
- [ ] `git grep -n "/code-review high in parallel" -- ':/' ':/!docs/plans' ':/!*PROGRESS.md'` finds nothing
- [ ] The diff touches only `CLAUDE.md`, `.claude/workflow/implement.md`, `docs/workflow.md`, `README.md` and `backend/PROGRESS.md`; the `docs/workflow.md` diagram renders on GitHub
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks pass; the `Stop` hook checks pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `CLAUDE.md`
- `.claude/workflow/implement.md`
- `docs/workflow.md`
- `README.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 4 docs files, about 15 lines

#### Task 2: `[infra] chore: run-tasks step 0 fetches before the integration gate`

**Description:** In the session brief of `.claude/skills/run-tasks/SKILL.md`, step 0 for a `(mobile, integration)` issue runs `git fetch origin` before checking the integration gate, and the gate reads `docs/api/openapi.json` from the just-fetched `origin/develop` and the issue states from GitHub. Fix the matching sentence in step 2 to agree. Change only `SKILL.md`.

**Acceptance criteria:**
- [ ] Step 0 of the session brief says a `(mobile, integration)` issue runs `git fetch origin` before checking the integration gate
- [ ] The gate reads `docs/api/openapi.json` from `origin/develop` after that fetch, and the state of the backend issues from GitHub

**Verification:**
- [ ] Dry run on paper: an integration issue whose backend issue merged just after the worktree was created sees the gate open
- [ ] The diff touches only `.claude/skills/run-tasks/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `backend/PROGRESS.md`

**Estimated scope:** XS: 1 docs file, about 3 lines

#### Task 3: `[infra] chore: worktree-setup points a reused worktree at its own test database`

**Description:** By assumption 5: when the worktree already has an `.env`, `.claude/scripts/worktree-setup.sh` replaces a `TEST_DATABASE_URL` line that points at another database with the issue's database, writing a temp file with mode 600 and then `mv`, and keeps every other line; an `.env` that is already right is not touched. Update the comment at the top of the file and the messages. The password is never printed. Add cases to `.claude/scripts/test-worktree-setup.sh`.

**Acceptance criteria:**
- [ ] When the worktree already has an `.env` whose `TEST_DATABASE_URL` points at another database, the script changes only that line to `stridequest_i<issue>_test` and keeps every other line as it is
- [ ] An existing `.env` that already points at the issue's database is kept byte for byte
- [ ] The script's output never contains the password; the `export` line still masks the password with `****`

**Verification:**
- [ ] Tests pass: `.claude/scripts/test-worktree-setup.sh` (new cases: an existing `.env` pointing at another database; an existing `.env` that is already right; a password with the characters `@` and `/`)
- [ ] `git grep -n "never overwrites one" -- ':/' ':/!docs/plans' ':/!*PROGRESS.md'` finds nothing
- [ ] The diff touches only `.claude/scripts/worktree-setup.sh`, `.claude/scripts/test-worktree-setup.sh` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/scripts/worktree-setup.sh`
- `.claude/scripts/test-worktree-setup.sh`
- `backend/PROGRESS.md`

**Estimated scope:** S: 1 code file, about 40 lines (not counting tests)

#### Task 4: `[infra] chore: PROGRESS.md merges with the union driver`

**Description:** By assumption 6: add `.gitattributes` with `backend/PROGRESS.md merge=union` and `mobile/PROGRESS.md merge=union`. Change the sentence "keep both lines in `PROGRESS.md`" at step 9 of `.claude/skills/run-tasks/SKILL.md` to: `PROGRESS.md` merges by itself (union), only check that both lines are there. The DECISIONS files keep their way of merging.

**Acceptance criteria:**
- [ ] `git merge origin/develop` on a branch that added a line to `backend/PROGRESS.md` or `mobile/PROGRESS.md`, while `develop` added another line, ends with no conflict and keeps both lines
- [ ] Step 9 of the session brief says `PROGRESS.md` merges by itself with union and only needs a check that both lines are there

**Verification:**
- [ ] A test in a temporary repository (with a copy of `.gitattributes`): two branches both add a line at the end of `backend/PROGRESS.md`, `git merge` reports no conflict; paste the commands and output into Evidence
- [ ] `git grep -n "keep both lines" -- ':/' ':/!docs/plans' ':/!*PROGRESS.md'` finds nothing
- [ ] The diff touches only `.gitattributes`, `.claude/skills/run-tasks/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.gitattributes`
- `.claude/skills/run-tasks/SKILL.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 2 files, about 8 lines

#### Checkpoint: after Phase 1
- [ ] Tests pass, lint and type checks clean
- [ ] No old text left in the greps of tasks 1, 3 and 4
- [ ] The user reviews before Phase 2 starts

### Phase 2: new safety nets

#### Task 5: `[infra] ci: scripts job runs the shell script tests`

**Description:** By assumptions 7 and 8: add `.github/workflows/scripts-ci.yml`, job `scripts`, which runs every `test-*.sh` in `.github/scripts/`, `.claude/hooks/` and `.claude/scripts/` and prints the name of each test it ran. No `paths:` filter, `permissions: contents: read`, no secret. A test that needs a tool only macOS has gets a stand-in tool installed, or skips exactly that part with a line saying so. Add `scripts` to the required checks at step 10 of `.claude/skills/run-tasks/SKILL.md`, and to the ruleset description and the workflow table in `README.md`.

**Acceptance criteria:**
- [ ] Every PR into `develop` and every push to `develop` has a `scripts` check, which runs every `test-*.sh` in `.github/scripts/`, `.claude/hooks/` and `.claude/scripts/`, and is red when a test there fails
- [ ] The job has `permissions: contents: read`, uses no secret, and always reports (no `paths:` filter)
- [ ] Step 10 of the session brief and the ruleset description in `README.md` list `scripts` together with `backend`, `mobile` and `goldens`

**Verification:**
- [ ] The `scripts` check is green on this task's PR; the log lists each test that ran and each skipped part with its reason
- [ ] Red test: a temporary commit that breaks a test makes `scripts` red (then drop that commit before the review)
- [ ] `git grep -n 'backend`, `mobile` and `goldens' -- ':/' ':/!docs/plans' ':/!*PROGRESS.md'` finds nothing
- [ ] The diff touches only `.github/workflows/scripts-ci.yml`, `.claude/skills/run-tasks/SKILL.md`, `README.md` and `backend/PROGRESS.md`, plus any test file that needs a change to run on Linux
- [ ] Not verified in the PR: that the check is required; the user adds it to the ruleset after the merge (Prerequisites)
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.github/workflows/scripts-ci.yml`
- `.claude/skills/run-tasks/SKILL.md`
- `README.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 3 files, about 70 lines

#### Task 6: `[infra] chore: Stop hook keeps a run-tasks child working until its result file`

**Description:** By assumptions 1 to 4: step 0 of the session brief in `.claude/skills/run-tasks/SKILL.md` writes the marker `$(git rev-parse --git-dir)/run-task` (the `<results>` path and the issue number) when it writes `.working`. A new hook `.claude/hooks/run-task-guard.sh`, placed in the `Stop` array of `.claude/settings.json` before `check.sh`, blocks the end of the turn (exit 2) only when there is a marker, there is `<issue>.working`, there is no `<issue>.result` yet and less than 3 hours 15 minutes have passed since `.working`; its message says to finish the issue (or take the stop path of step 4) and write the result file. The hook only reads files and writes nothing. Tests follow the pattern of `.claude/hooks/test-check.sh`.

**Acceptance criteria:**
- [ ] In a worktree with a marker naming an issue that has `<issue>.working` and no `<issue>.result`, the Stop hook blocks the end of the turn (exit 2) with a message that says to finish the issue and write the result file
- [ ] The hook lets the turn end when there is no marker, when the result file exists, when there is no `.working` yet (the wait turn of step 0), and once 3 hours 15 minutes have passed since `.working`
- [ ] Step 0 of the session brief writes the marker together with `.working`

**Verification:**
- [ ] Tests pass: `.claude/hooks/test-run-task-guard.sh` (no marker; a result present; no `.working` yet; past the deadline; working with no result)
- [ ] `jq . .claude/settings.json` is valid and the `Stop` array has the new hook before `check.sh`
- [ ] The diff touches only `.claude/hooks/run-task-guard.sh`, `.claude/hooks/test-run-task-guard.sh`, `.claude/settings.json`, `.claude/skills/run-tasks/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks pass
- [ ] Not verified in the PR: the hook blocking in a real `/run-tasks` run; the next run shows it
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/hooks/run-task-guard.sh`
- `.claude/settings.json`
- `.claude/skills/run-tasks/SKILL.md`
- `.claude/hooks/test-run-task-guard.sh`
- `backend/PROGRESS.md`

**Estimated scope:** M: 3 code files, about 80 lines (not counting tests)

#### Checkpoint: after Phase 2
- [ ] Tests pass, the `scripts` check is green on `develop`
- [ ] The user has added `scripts` to the ruleset (Prerequisites)
- [ ] The user reviews; the next `/run-tasks` run verifies the hook for real

Suggested runs: Phase 1 is one `/run-tasks` for tasks 1–4; tasks 2 and 4 both change `SKILL.md`, so they run one after the other in one lane. Phase 2 is tasks 5–6, which also both change `SKILL.md`.

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] docs: fix wording left behind by plan 038` | docs, area:infra | - [ ] `CLAUDE.md` and `.claude/workflow/implement.md` say that `/run-tasks` starts one session for each ready issue in the command turn, and at most two sessions work at once, each in its own worktree<br>- [ ] The local review node in `docs/workflow.md` says `code-reviewer` and `/code-review` run in the foreground in the same message<br>- [ ] The "Asking for a review" section of `README.md` says a PR gets at most two `claude-review` runs, the second is the last, and the remaining nits go under `## Nits left` | none |
| 2 | `[infra] chore: run-tasks step 0 fetches before the integration gate` | chore, area:infra | - [ ] Step 0 of the session brief says a `(mobile, integration)` issue runs `git fetch origin` before checking the integration gate<br>- [ ] The gate reads `docs/api/openapi.json` from `origin/develop` after that fetch, and the state of the backend issues from GitHub | none |
| 3 | `[infra] chore: worktree-setup points a reused worktree at its own test database` | chore, area:infra | - [ ] When the worktree already has an `.env` whose `TEST_DATABASE_URL` points at another database, the script changes only that line to `stridequest_i<issue>_test` and keeps every other line as it is<br>- [ ] An existing `.env` that already points at the issue's database is kept byte for byte<br>- [ ] The script's output never contains the password; the `export` line still masks the password with `****` | none |
| 4 | `[infra] chore: PROGRESS.md merges with the union driver` | chore, area:infra | - [ ] `git merge origin/develop` on a branch that added a line to `backend/PROGRESS.md` or `mobile/PROGRESS.md`, while `develop` added another line, ends with no conflict and keeps both lines<br>- [ ] Step 9 of the session brief says `PROGRESS.md` merges by itself with union and only needs a check that both lines are there | none |
| 5 | `[infra] ci: scripts job runs the shell script tests` | chore, area:infra | - [ ] Every PR into `develop` and every push to `develop` has a `scripts` check, which runs every `test-*.sh` in `.github/scripts/`, `.claude/hooks/` and `.claude/scripts/`, and is red when a test there fails<br>- [ ] The job has `permissions: contents: read`, uses no secret, and always reports (no `paths:` filter)<br>- [ ] Step 10 of the session brief and the ruleset description in `README.md` list `scripts` together with `backend`, `mobile` and `goldens` | none |
| 6 | `[infra] chore: Stop hook keeps a run-tasks child working until its result file` | chore, area:infra | - [ ] In a worktree with a marker naming an issue that has `<issue>.working` and no `<issue>.result`, the Stop hook blocks the end of the turn (exit 2) with a message that says to finish the issue and write the result file<br>- [ ] The hook lets the turn end when there is no marker, when the result file exists, when there is no `.working` yet (the wait turn of step 0), and once 3 hours 15 minutes have passed since `.working`<br>- [ ] Step 0 of the session brief writes the marker together with `.working` | none |
