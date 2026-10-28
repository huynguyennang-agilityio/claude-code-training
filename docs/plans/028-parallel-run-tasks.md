# Plan 028: `/run-tasks` runs up to two issues at once, each in its own session

Status: approved
Approved: 2026-10-28, by the user in chat: "/approve-plan 028"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/Az6NuuLkmZJVoaDRWQ29ML, version 1793171568-b46e

Based on: `docs/plans/019-area-autopilot.md`, `docs/plans/021-gh-forbidden-commands.md`, `.claude/skills/run-tasks/SKILL.md`, the Plan 027 draft (not approved).

## Prerequisites

- **Run `/run-tasks` in the Claude desktop app, Code tab.** Child sessions can only be created there. When it runs in the CLI terminal or as `@claude` on GitHub, the command uses the fallback (assumption 3).
- **The Slack connector is connected** in the session, to send the DM with the report link.
- **The project's permission mode does not ask on every command** (for example auto mode). Otherwise each child session stops and waits for you to click Allow.
- **Docker Desktop is running**, `gh auth status` is signed in, and the `.env` file at the root of the main checkout has `TEST_DATABASE_URL`.

On every run, `/run-tasks` checks the above again and asks you **only once** before it starts (assumption 5).

## Context

Today `/run-tasks #91 #92` (plan 019) works on one issue at a time, in order, in the same checkout. Each issue goes to a subagent, but the branch, the tests and the PR all happen in the main folder. As a result, two tickets cannot run at the same time, and the user cannot see each ticket's step on its own. On top of that, a PR with the `human-merge` label (or above 400 lines) has to stop and wait for the user to merge it.

The repo already has what parallel runs need: the Claude desktop app can create child sessions, each running in its own worktree (like the "Kết nối Figma · 1 nested session" screenshot). A few worktrees were made by hand (`wt-128`, `wt-130`, `wt-131`). Still, there are no rules for parallel runs, and the shared resources are not separated: the test database, the Docker port, `.env`, `.venv`.

### Decided by the user

- Typing `/run-tasks 1,2,3,4` runs all those issues. The session where the command is typed is the parent session; each issue gets its own child session, shown under the parent session like the "Kết nối Figma" screenshot. **At most 2 child sessions run at the same time.**
- Any key or config that is needed is asked once, right before the start. After that Claude does everything; small errors are fixed without asking.
- After each `/run-tasks` run, Claude writes an artifact report: what was done and which big problems remain. The report link is sent over Slack, and then both sides plan the next fixes. Ask the user as little as possible.
- **Drop the `human-merge` label entirely.**

(The decisions above come from the user's messages of 2026-10-28.)

## Open questions and assumptions

1. **Syntax:** both `/run-tasks 1,2,3,4` and `/run-tasks #1 #2 #3 #4` are accepted.
2. **The parent session only orchestrates:** it orders the issues, opens the child sessions, collects their results and writes the report. It does not change code and does not switch the main checkout's branch.
3. **Child sessions:** one session per issue, created with the desktop app's start-session tool, with `use_worktree: true` and `context: "fresh"`, plus the issue's brief. The brief quotes the user's `/run-tasks` command word for word, because that command authorizes the child session to take the issue up to the merge. **Fallback** when that tool is missing (running in the CLI): `Agent` subagents with `isolation: "worktree"`, in the background, at most 2 at once. On GitHub (`@claude`) it runs in order as today.
4. **Two issues run in parallel only when** neither depends on the other and they share no file. Usually that means two issues on different sides (backend and mobile) or in different areas. Two issues in the same area and on the same side run one after the other. A `(mobile, integration)` issue still waits for the integration gate.
5. **Ask once, at the start of the run (preflight).** Before opening the first child session, the parent session checks `gh auth status`, the Slack connector, Docker and `docker compose up -d --wait db` (run from the main checkout), `flutter` and `python3.12`, that `.env` has `TEST_DATABASE_URL`, and every key or secret the issues mention. Whatever is missing is gathered into **one** question. After that no more questions until the final report. Exception: the user's "stop" message is always followed.
6. **Small errors are fixed without asking**, as long as they are inside the issue's and the plan's scope: a red test, a lint or type check error, a merge conflict, a review comment, a flaky CI run, a missing fixture, `openapi.json` or `PROGRESS.md` out of date after merging `develop`.
   **A big problem stops that issue** (`wip:` commit, push), goes into the report, and the other issues go on. A big problem is: something the plan does not have (a new endpoint, a schema change, a new dependency, a contract change), a High security finding that cannot be fixed inside the issue's scope, CI still red after 3 fixes, or a review still requesting changes after 2 rounds.
7. **The child session merges** its own PR when the `/run-tasks` merge conditions hold (without the `human-merge` condition). Right before merging, it merges `origin/develop` into its branch, resolves conflicts, re-runs the checks and waits for CI to be green on the new commit. That way two parallel PRs don't break each other.
8. **Drop `human-merge` everywhere:** in `/run-tasks`, `/approve-plan`, `task-breakdown`, `CLAUDE.md`, `.claude/workflow/pr-review.md`, `docs/workflow.md`, `README.md`, and the part of the `block-forbidden-command.sh` hook that guards this label (with its tests). A PR above 400 lines is no longer blocked; it is listed in the report with a suggestion for how to split it. The label on GitHub stays; it is not deleted, just no longer used. To delete the label, reply "change 8".
9. **Slack:** only two DMs: at the start (the run order and the left-out issues) and at the end (the report link with a 3-line summary). No DM after each merge as today. To keep a DM per merge, reply "change 9".
10. **The final report is a private artifact** in Vietnamese, named `Run YYYY-MM-DD #a #b …`, with: (a) each issue with its PR, status (merged / stopped / left out), main changes and CI on `develop`; (b) **the big problems that remain**, each with a proposed fix to plan next; (c) the `Not verified` lines, PRs above 400 lines, review comments answered but not fixed; (d) proposed `DECISIONS.md` entries (numbered); (e) the GitLab mirror reminder. The chat also gets a short summary with the link.
11. **Each worktree is separated:** copy `.env` from the main checkout (not committed); use its own test database `stridequest_i<issue>_test` through the `TEST_DATABASE_URL` environment variable (conftest creates this database); never run `docker compose` in a worktree, only use the main checkout's `db` container; its own `backend/.venv`; its own `flutter pub get`; read the `.ua/` knowledge graph from the main checkout. A script does all of this (Task 2).
12. **Cleanup:** at the end, the parent session archives the merged child sessions (the app cleans up their worktrees). The child session of a stopped issue is kept for inspection. The old worktrees (`wt-128`, `wt-130`, `wt-131`, `wt-dev`) are not part of this plan.
13. **Relation to Plan 027** (draft: `/approve-plan` runs the issues right away): the two plans are independent. If 027 is approved, `/approve-plan` runs the issues the parallel way of this plan. The 027 draft still mentions `human-merge`, so whichever plan merges second must align its wording.

## Approach

Only Claude configuration, docs and one hook change, and one script is added. No backend or mobile code changes, and no GitHub workflow changes.

### Run flow

```text
/run-tasks 1,2,3,4                    (parent session, main checkout)
 ├─ preflight: check, ask once if something is missing
 ├─ order + pair for parallel runs → Slack DM "start"
 ├─ open child session #1 (worktree)   ─┐  at most 2 at once
 ├─ open child session #3 (worktree)   ─┘
 │     each child session: set up worktree → code + test → PR
 │     → review / fix → merge develop → merge PR → report "RESULT"
 ├─ #1 done → open #2;  #3 done → open #4
 └─ no issues left → report artifact → Slack DM link → archive merged child sessions
```

### Task 1: drop `human-merge`

- `.claude/hooks/block-forbidden-command.sh`: drop the rules that block removing, deleting or renaming the `human-merge` label (through `gh pr edit`, `gh issue edit`, `gh label`, `gh api`). Keep every other rule unchanged: pushing to `develop`/`main`, force-pushing, deleting branches, deleting tags, pushing to `gitlab`, `--delete-branch`, `--cleanup-tag`. `.claude/hooks/test-block-forbidden-command.sh`: drop the `human-merge` test cases, keep the others.
- `CLAUDE.md`: drop `human-merge` from the Merge row of the permission table, from the hook paragraph, and from the Phase 6 gate.
- `.claude/skills/run-tasks/SKILL.md`: drop every check for or addition of the label; the Size check step only writes to the report.
- `.claude/skills/approve-plan/SKILL.md`, `.claude/skills/task-breakdown/SKILL.md`, `.claude/workflow/pr-review.md`, `docs/workflow.md` (including the diagram), `README.md`, `docs/plans/README.md` (if it mentions it): drop the label. The old approved plans (019, 021, 023, 024, 025) stay as they are, because they are history.

### Task 2: worktree setup script

- `.claude/scripts/worktree-setup.sh <main-checkout> <issue>`, run inside the worktree: copy `<main>/.env` when the worktree has none; create `backend/.venv` and install `requirements-dev.txt`; run `flutter pub get` in `mobile/`; print the line `export TEST_DATABASE_URL=…/stridequest_i<issue>_test` (host, port and user taken from `TEST_DATABASE_URL` in `.env`, the password never printed to the log). The script never runs `docker compose`.
- `.claude/scripts/test-worktree-setup.sh`: tests the script on a temporary repo (copies `.env`, does not overwrite an existing `.env`, database name matches `^[A-Za-z0-9_]+_test$`, does not print the password). Environment variables skip the `pip` and `flutter` install steps in the test.
- `.claude/hooks/check.sh` (Stop hook) needs no change: it already runs from `git rev-parse --show-toplevel`, that is, from the right worktree.

### Task 3: parallel `/run-tasks`

- `.claude/skills/run-tasks/SKILL.md` rewritten to the flow above:
  - "Arguments": accepts both syntaxes.
  - Add "Preflight": ask once.
  - "Order the issues": add the pairing rule (assumption 4).
  - "For each issue": becomes "Session brief", the steps a child session takes, including the worktree setup, merging `origin/develop` before merging the PR, and the final result line `RESULT: merged|stopped #<issue> PR #<n> — <reason>`.
  - Add "Orchestrate": at most 2 child sessions; when an event says a child session ended a turn, read the `RESULT` line to tell whether it is done or waiting for CI; open the next ready issue; the fallback with `Agent` + `isolation: "worktree"`.
  - "Stop an issue, not the run": add the small error / big problem rule (assumption 6).
  - "Slack" (assumption 9) and "Report" (artifact, assumption 10).
- `CLAUDE.md`: the Commit, Push/PR and Merge rows of the permission table state that a child session opened by `/run-tasks` has the same permissions as the run, only for its own issue. Add one line in General rules: "Parallel runs: at most two issue sessions at once, each in its own worktree; never run `docker compose` from a worktree."
- `.claude/workflow/implement.md`: add a "Working in a worktree" section (the Task 2 script, its own test database, no `docker compose`).
- `docs/workflow.md`, the `/run-tasks` section (text and mermaid diagram), and `README.md`: describe the parallel run and the final report.

### Changes the approval must cover (Phase 2)

- **Authorization boundary:** dropping `human-merge` means `/run-tasks` merges *every* PR that meets the conditions, including PRs that touch auth, the schema, migrations, or large PRs. Those changes still need plan approval (Phase 2), but there is no longer any gate at the merge step. The hook also no longer guards this label. Approving this plan means agreeing to both.
- **Cost:** two sessions in parallel use close to twice the tokens in the same time.
- No change to the public API, the schema, the app architecture, real data or production. The GitHub ruleset still blocks direct pushes to `develop`/`main`, and the Never rows of the permission table are unchanged.

## Risks

- **Two parallel PRs conflict in shared files** (`PROGRESS.md`, `docs/api/openapi.json`, `pubspec.lock`). Mitigation: the pairing rule, plus merging `origin/develop` and re-running the checks right before merging the PR. Generated files are regenerated, not edited by hand.
- **Two integration test runs overwrite each other's database.** Mitigation: one `_test` database per issue; conftest already refuses names that do not end in `_test`.
- **The app stops calling the parent session back** after many events in a row with no message from the user, so a long run may hang halfway. Mitigation: when it cannot open a child session, the parent session sends the DM "run paused, send 'tiếp' to continue", and running `/run-tasks` again with the issues still open skips the merged ones.
- **Risky PRs are merged with nobody looking**, because `human-merge` is gone. This is the trade-off the user chose. Limits: only issues of an approved plan; CI green, `claude-review` approving and High security findings handled are still required; the final report lists large PRs and PRs that touch auth/schema for the user to look at later.
- **A child session asks for permission and waits.** Mitigation: the Prerequisites section; preflight warns when the permission mode will ask.
- **The brief from the parent session is treated as "a message from another session"**, without the authority of a user message. Mitigation: the brief is the child session's first prompt and quotes the user's command word for word; the authorized scope names exactly one issue.

## Verification

- Task 1: `.claude/hooks/test-block-forbidden-command.sh` passes; `grep -rn "human-merge" CLAUDE.md README.md .claude/ docs/workflow.md docs/plans/README.md` finds nothing; pushing to `develop`, force-pushing and `--delete-branch` are still blocked.
- Task 2: `.claude/scripts/test-worktree-setup.sh` passes; `shellcheck` is clean if installed.
- Task 3: re-read the skill against the checklist; `grep -n "RESULT:" .claude/skills/run-tasks/SKILL.md` finds a match; the mermaid diagram in `docs/workflow.md` renders.
- Cannot be checked before merging: a real run with 2 parallel sessions. The first `/run-tasks` after merging (best with 2 small issues on different sides) is the first check; that run's report records the result.

## Ticket evidence

All three tasks are chores (Claude configuration, tooling). The gate asks for the scope and the behavior that must stay unchanged.

- Task 1. Scope: the `human-merge` label in the listed files. Unchanged: every other hook rule and the Never rows.
- Task 2. Scope: the new script and its test. Unchanged: `docker-compose.yml`, conftest, `check.sh`.
- Task 3. Scope: the `run-tasks` skill and the docs. Unchanged: the merge conditions (except `human-merge`), the integration gate, no `DECISIONS.md` edits during a run. Source: the user's message of 2026-10-28, with the "Kết nối Figma · 1 nested session" screenshot.

## Task breakdown

Order: task 1 and task 2 can run in parallel (different files). Task 3 waits for both: it edits `run-tasks/SKILL.md` after task 1 and uses the task 2 script.

### Task 1: `[infra] chore: remove the human-merge label rule`

**Requirements**

- No current skill, rule or doc uses, adds, checks or guards the `human-merge` label anymore.
- `/run-tasks` lists a PR above 400 lines in the report instead of blocking the merge.
- Every other hook rule and the Never rows stay unchanged.

**Steps**

1. Edit `.claude/hooks/block-forbidden-command.sh` and `.claude/hooks/test-block-forbidden-command.sh` as in Approach, Task 1.
2. Edit `CLAUDE.md`, `.claude/skills/run-tasks/SKILL.md`, `.claude/skills/approve-plan/SKILL.md`, `.claude/skills/task-breakdown/SKILL.md`, `.claude/workflow/pr-review.md`, `docs/workflow.md`, `README.md`, `docs/plans/README.md`.
3. Run the Task 1 checks.

**Checklist**

- [ ] `.claude/hooks/block-forbidden-command.sh` no longer blocks removing, deleting or renaming `human-merge`; every other rule is unchanged
- [ ] `.claude/hooks/test-block-forbidden-command.sh` drops the `human-merge` cases and passes
- [ ] `grep -rn "human-merge" CLAUDE.md README.md .claude/ docs/workflow.md docs/plans/README.md` finds nothing
- [ ] `.claude/skills/run-tasks/SKILL.md`: a PR above 400 changed lines is listed in the run report with how it could have been split, and does not block the merge
- [ ] The Never rows of the permission table in `CLAUDE.md` are unchanged

### Task 2: `[infra] chore: worktree setup script for parallel runs`

**Requirements**

- One command prepares a worktree so lint, the backend tests (unit and integration) and the mobile tests can run without touching any other worktree.
- A test database per issue; no password printed; no `docker compose`.

**Steps**

1. Write `.claude/scripts/worktree-setup.sh` as in Approach, Task 2.
2. Write `.claude/scripts/test-worktree-setup.sh`.
3. Run the test, and `shellcheck` if available.

**Checklist**

- [ ] `.claude/scripts/worktree-setup.sh <main-checkout> <issue>` copies `<main-checkout>/.env` when the worktree has none and never overwrites an existing one
- [ ] It creates `backend/.venv` with `requirements-dev.txt` and runs `flutter pub get` in `mobile/`
- [ ] It prints `export TEST_DATABASE_URL=...stridequest_i<issue>_test` built from the `.env` URL, and never prints the password
- [ ] It never runs `docker compose`
- [ ] `.claude/scripts/test-worktree-setup.sh` passes

### Task 3: `[infra] docs: run up to two issues in parallel sessions with /run-tasks`

**Requirements**

- `/run-tasks 1,2,3,4` opens one child session per issue, each in its own worktree, at most 2 at once, paired by assumption 4.
- Ask the user only once, at preflight. Small errors are fixed without asking; a big problem stops the issue and goes into the report.
- The child session merges `origin/develop` into its branch and re-runs the checks before merging the PR.
- The run ends with a Vietnamese report artifact, its link sent by Slack DM.
- There is a fallback when child sessions are unavailable.

**Steps**

1. Rewrite `.claude/skills/run-tasks/SKILL.md` as in Approach, Task 3.
2. Edit `CLAUDE.md` (permission table, General rules) and `.claude/workflow/implement.md` (the "Working in a worktree" section).
3. Edit `docs/workflow.md` (text and diagram) and `README.md`.
4. Run the Task 3 checks.

**Checklist**

- [ ] `.claude/skills/run-tasks/SKILL.md` accepts `/run-tasks 1,2,3,4` and `/run-tasks #1 #2`
- [ ] It has a Preflight step that asks the user at most once, before the first issue session starts
- [ ] It starts one desktop session per issue with `use_worktree: true`, at most two at once, pairing only issues with no dependency between them and no shared files, and falls back to `Agent` with `isolation: "worktree"` (at most two) when sessions are unavailable
- [ ] The session brief runs `.claude/scripts/worktree-setup.sh`, merges `origin/develop` and re-runs the checks before merging the PR, and ends with `RESULT: merged|stopped #<issue> PR #<n>`
- [ ] Small problems inside the issue's scope are fixed without asking; big problems (outside the plan, unfixable High security finding, CI red after 3 tries, changes requested after 2 rounds) stop only that issue and go to the report
- [ ] The run ends with a Vietnamese report artifact (per-issue status, big problems with a proposed fix, `Not verified` lines, PRs above 400 lines, proposed decisions, GitLab reminder), and one Slack DM with its link; the only other DM is the start DM
- [ ] Merged issue sessions are archived at the end; stopped ones are kept
- [ ] `CLAUDE.md` and `.claude/workflow/implement.md` state: at most two issue sessions at once, each in its own worktree, and never `docker compose` from a worktree
- [ ] `docs/workflow.md` (text and mermaid diagram) and `README.md` describe the parallel run and the report

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: remove the human-merge label rule` | chore, area:infra | - [ ] `.claude/hooks/block-forbidden-command.sh` no longer blocks removing, deleting or renaming `human-merge`; every other rule is unchanged<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` drops the `human-merge` cases and passes<br>- [ ] `grep -rn "human-merge" CLAUDE.md README.md .claude/ docs/workflow.md docs/plans/README.md` finds nothing<br>- [ ] `.claude/skills/run-tasks/SKILL.md`: a PR above 400 changed lines is listed in the run report with how it could have been split, and does not block the merge<br>- [ ] The Never rows of the permission table in `CLAUDE.md` are unchanged | none |
| 2 | `[infra] chore: worktree setup script for parallel runs` | chore, area:infra | - [ ] `.claude/scripts/worktree-setup.sh <main-checkout> <issue>` copies `<main-checkout>/.env` when the worktree has none and never overwrites an existing one<br>- [ ] It creates `backend/.venv` with `requirements-dev.txt` and runs `flutter pub get` in `mobile/`<br>- [ ] It prints `export TEST_DATABASE_URL=...stridequest_i<issue>_test` built from the `.env` URL, and never prints the password<br>- [ ] It never runs `docker compose`<br>- [ ] `.claude/scripts/test-worktree-setup.sh` passes | none |
| 3 | `[infra] docs: run up to two issues in parallel sessions with /run-tasks` | docs, area:infra | - [ ] `.claude/skills/run-tasks/SKILL.md` accepts `/run-tasks 1,2,3,4` and `/run-tasks #1 #2`<br>- [ ] It has a Preflight step that asks the user at most once, before the first issue session starts<br>- [ ] It starts one desktop session per issue with `use_worktree: true`, at most two at once, pairing only issues with no dependency between them and no shared files, and falls back to `Agent` with `isolation: "worktree"` (at most two) when sessions are unavailable<br>- [ ] The session brief runs `.claude/scripts/worktree-setup.sh`, merges `origin/develop` and re-runs the checks before merging the PR, and ends with `RESULT: merged\|stopped #<issue> PR #<n>`<br>- [ ] Small problems inside the issue's scope are fixed without asking; big problems (outside the plan, unfixable High security finding, CI red after 3 tries, changes requested after 2 rounds) stop only that issue and go to the report<br>- [ ] The run ends with a Vietnamese report artifact (per-issue status, big problems with a proposed fix, `Not verified` lines, PRs above 400 lines, proposed decisions, GitLab reminder), and one Slack DM with its link; the only other DM is the start DM<br>- [ ] Merged issue sessions are archived at the end; stopped ones are kept<br>- [ ] `CLAUDE.md` and `.claude/workflow/implement.md` state: at most two issue sessions at once, each in its own worktree, and never `docker compose` from a worktree<br>- [ ] `docs/workflow.md` (text and mermaid diagram) and `README.md` describe the parallel run and the report | 1, 2 |
