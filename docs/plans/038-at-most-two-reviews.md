# Plan 038: At most two GitHub reviews, and every issue started in the command turn

Status: approved
Approved: 2026-10-30, by the user in chat: "/approve-plan 038"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/7GyE6YTwACo5shU6RwLDPb, version 1793331598-15de

## Context

Based on: plan 036 (local review, #211 #212) · plan 037 (#214–#217) · [run 20261029-223500](https://claude.ai/artifact/JsgQaKCFPAVxYASY3LABm3)

### Prerequisites

- **Before `/run-tasks`:** no new key, secret or device.
- **Run:** after approval, run `/run-tasks <task 1>,<task 2>,<task 3>,<task 4>,<task 5>`. Task 1 and task 2 run in parallel because they change no file in common. Tasks 3, 4 and 5 run one after the other.
- **Note:** that run still follows the current skill, so after tasks 1 and 2 you still have to send a message to start each of tasks 3, 4 and 5. The new rule applies from the next run.

### Problem

- **The review on GitHub repeats many rounds with no real defect.** #211 and #216 each took 3 rounds, and every one was *approve with nits*. There are three causes:
  - Each review reads the whole PR from the start, so it picks up new nits.
  - Fixing a nit changes the head, and the merge condition requires a review of that exact head SHA, so another review is forced.
  - The plan does not list every file that mentions the changed rule. For example, #217 missed `/code-review high` in the PR template.
- **The parent cannot start the next issue by itself.** The app refuses `start_session` in every turn that does not begin with your words, including a turn that begins with a child session's note. So assumption 9 of plan 037 is wrong. The last run needed 5 messages from you.
- **Child sessions give up their turn in the middle of the local review.** #211 and #212 ended their turn while the `code-reviewer` subagent was still running in the background. Without someone messaging them, they sit idle until the 3-hour deadline.

### Decided by the user

- Review flow: local review, then fixes → push → GitHub review 1, then fix everything (nits too) → GitHub review 2 is the last.
- Review 2 approves, nits included: merge, and the nits go to the report.
- Review 2 requests changes: **no merge**. The issue, PR and branch stay open. The report carries a draft plan to fix that PR. After you approve the plan, that PR reruns with the related issues in one `/run-tasks`.
- Review 2 checks only the earlier findings and the new changes (change the `claude-review.yml` prompt).
- The plan writes the review criteria up front: a task's Verification has a `git grep` command for every file that mentions what is changed.
- Kept as is: `claude-review` stays the merge gate, and a High finding of `claude-security-scan` still blocks the merge.
- Out of scope: the small follow-ups in the run report, the GitHub Code Review app, application code, `claude-security-scan.yml`, the 3-hour deadline and the 30-minute review wait.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **Review budget:** each PR has at most 2 `claude-review` runs. Review 1 runs by itself when the PR opens. If review 1 approves with no findings, merge at once. If it has any finding (nits too), Claude fixes them all in one pass, pushes, then comments `@claude review` exactly once to get review 2.
2. **Review 2 approves or approves with nits:** merge without another push, so the "review of the head SHA" condition still holds. The unfixed nits are written in the PR description (a `## Nits left` section) and in the run report.
3. **Review 2 requests changes:** the issue stops with the reason "final review requests changes". The issue, PR and branch stay open. The report links a draft fix plan (an artifact) that gathers those findings, instead of a plain rerun command. After `/approve-plan`, that PR and the issues that depend on it run together in one `/run-tasks`.
4. **Step 9 (merging `develop` into the branch):**
   - A merge with no conflict: no new review is needed. The merge condition accepts a review of the **first parent** of that merge commit. CI still runs on the new head.
   - Resolving a conflict has to edit the PR's own files: if review 2 has not been used yet, this is review 2. If it has been used, there is **one** more review of the conflict only, which does not count toward the budget. If that review requests changes, the issue stops as in item 3.
5. **Security scan:** a High finding must still be fixed or answered before the merge. If the fix needs a push after review 2, the issue stops as in item 3.
6. **Review 2 checks only the changes:**
   - A fixed script that runs no model (`.github/scripts/review-context.sh`) runs before the Claude step.
   - The script finds the earlier `claude-review` comment and its SHA. It writes the earlier review and the changes from that SHA to the head (through the compare API, the PR's files only) to `.review-context/` in the working tree.
   - The reviewer says for each earlier finding whether it is fixed and reviews only the new part. On unchanged lines it raises a new finding only when it is High severity (a security hole or a correctness bug).
   - No earlier review, or the earlier SHA is no longer in the PR's history: the full five-step review as today. The model gets no new tool.
7. **Start every issue in the turn of your command:**
   - The parent calls `start_session` for **every** ready issue in the turn of the `/run-tasks` command. Each child session's brief names the issues it must wait for: its dependencies, and the issue before it in the pairing order, so that at most 2 sessions work at once.
   - A child session begins with a **wait gate**: a background wait that only reads the disk, 25 minutes per round, until the issues it waits for have result files. If such an issue merged, it goes on from step 1. If it stopped, it writes `RESULT: stopped ... depends on #N` and ends.
   - The 3-hour deadline counts from when the child session starts work (it writes a `<issue>.working` file), not from when the parent started it.
8. **Options considered for item 7:**
   - (A) A fallback with an `Agent` subagent in its own worktree. Not chosen: a subagent cannot call `code-reviewer` for the local review, and it is not a session you can open and look at.
   - (C) A "reply to continue" DM. Not chosen: it still needs your message for each issue.
   - The 15-minute start wait from #214 is dropped. The "Run paused" DM is used only when `start_session` or `list_sessions` fails in the turn of the command.
9. **Reviewers in the foreground:** point 6 calls `code-reviewer` (Agent, without `run_in_background`) and `/code-review` in the same message. Claude does not end the turn until both have returned.
10. **Grep in the plan:** a task that changes a rule, name, value or command written in several files has a `git grep -n "<old text>"` in its Verification, and its Files likely touched lists every file the grep finds.
11. **Rerun:** the budget is reset to 2 reviews, replacing today's "two new fix rounds" rule.
12. **PRs not run through `/run-tasks`:** `pr-review.md` Phase 5 applies the same budget of 2 reviews.

## Approach

```text
local review + fixes (one pass, both reviewers in the foreground)
  → push → claude-review #1 ── approve, no findings ──→ merge
                 │ findings (nits too)
                 ↓ fix all, push, @claude review (once)
           claude-review #2 (earlier findings + new diff only)
                 ├─ approve / nits ──→ merge, nits to the report
                 └─ request changes ─→ stop, everything left open; draft fix plan
step 9: clean develop merge → no review; conflict in the PR's files → use #2 or 1 review of the conflict
```

### Task 1: start every issue in the command turn

- `.claude/skills/run-tasks/SKILL.md`:
  - Step 3: start every issue and write the list of issues to wait for into the brief; drop the start wait.
  - Session brief: add the wait gate before step 1; the 3-hour deadline counts from the `.working` file.
  - The Slack section ("Run paused") and report item 1 (the note/command line).
- `docs/workflow.md`: the `/run-tasks` text and diagram.

### Task 2: grep every file that mentions what is changed

- `.claude/skills/task-breakdown/SKILL.md`: the "Verification by task type" section (add an "Every task" line) and "Review the breakdown" (add a check item).

### Task 3: local review waits for both reviewers in one turn

- `.claude/workflow/pr-review.md` Phase 4 point 6, and `.claude/skills/run-tasks/SKILL.md` session brief step 3.

### Task 4: review 2 checks only earlier findings and the changes

- `.github/scripts/review-context.sh` (new) and `.github/scripts/test-review-context.sh` (new, after the pattern of `test-check-no-secrets.sh`).
- `.github/workflows/claude-review.yml`: a step that runs the script before the Claude step, with a read-only token only (`pull-requests: read`). The prompt splits in two branches: with context, review the changes; without it, the full review.
- `.gitignore`: `.review-context/`. The files sit in the working tree because the model may not read the runner's temp folder.
- `.claude/workflow/pr-review.md` Phase 5 step 2 and `docs/workflow.md`: describe the second review.

### Task 5: at most 2 GitHub reviews per PR

- `.claude/skills/run-tasks/SKILL.md`:
  - Steps 7 to 10: the budget, the merge after review 2, the first-parent condition at step 9.
  - The stop list: replace "after two fix rounds" with "final review requests changes".
  - Rerun: reset the budget.
  - Report: a draft fix plan for each stop of this kind.
- `.claude/workflow/pr-review.md` Phases 5 and 6, the Phase 5 Gate cell in `CLAUDE.md`, line 30 of `.github/pull_request_template.md` (with the `## Nits left` section), and `docs/workflow.md`.

### Changes the approval must cover

| Category | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration that could lose data | No | — |
| Auth / security boundary | **Yes** | `claude-review.yml` runs with a token. The new step runs no model and has only a read-only token, and the model gets no new tool. The review gate is looser on nits: unfixed nits are still merged. Security holes are still blocked (items 5 and 6). |
| Architecture / Claude rules | **Yes** | The merge condition (2 reviews, first parent at step 9), the stop reasons, how `/run-tasks` starts issues, and the rule for writing Verification. |
| Real data / production / cost | **Yes (lower)** | Fewer `opus` reviews, and review 2 reads less. Waiting child sessions only run disk-reading commands. |

## Risks

- **Nits pile up:** unfixed nits accumulate on `develop`. Mitigation: they are in `## Nits left` and the report, and you gather them into a clean-up plan when there are enough.
- **The narrow review misses a defect on unchanged lines:** High severity is still raised (item 6), and review 1 already did the full five steps.
- **A clean merge that conflicts in meaning with `develop`** (when step 9 skips a new review): CI runs on the new head, and the `develop` part was reviewed in its own PR.
- **The "since the earlier SHA" diff mixes in `develop`'s changes after step 9:** the script takes only the PR's files. If the earlier SHA is no longer in the history, the review is the full one (item 6).
- **Many child sessions waiting at once** (a long chain):
  - They only run disk-reading commands. The 3-hour deadline counts from the start of work, so they are not cut off wrongly.
  - You see them in the sidebar in a waiting state.
  - A child session that waits very long (for example the whole 3 hours of the issue before it) still wakes itself after each 25-minute round.
- **Task 4 can only be checked for real after it merges:** `@claude review` runs the workflow from `develop`. There is a script test with fixtures before the merge, and the next run shows the real result.
- **The app also refuses `start_session` for the third session onward in the same turn:** task 1 checks this early. If it is refused, the task stops and goes back to Phase 1.

## Verification

- **Dry run on paper** for these cases:
  - review 1 approves cleanly;
  - review 2 has nits;
  - review 2 requests changes;
  - a clean step 9 merge, and a step 9 with a conflict;
  - a chain A→B→C with D paired with A, and the case where B stops.
- `.github/scripts/test-review-context.sh` passes, with these cases: no earlier review, an earlier review, a lost earlier SHA.
- `git grep -n -i "fix round"` over `CLAUDE.md .claude docs/workflow.md .github` finds nothing.
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass.
- **Cannot be verified in the PR:** the real number of review rounds, the narrow review on GitHub, and a run that needs no message between issues. The next run shows them.

## Ticket evidence

- **Type chore / ci:** the scope is the files in Approach.
- **Current state on `develop` (`9077f69`):**
  - `claude-review.yml` line 11 (a new review only on `@claude review`), lines 120–138 (the prompt), lines 198–236 (the post job edits a single comment);
  - `run-tasks/SKILL.md` lines 77–102 (the start wait), 130–132, 166, 173;
  - `pr-review.md` lines 16–18 and 25.
- **Original incidents:**
  - Run `20261029-223500`: #211 (PR #220) and #216 (PR #222) each took 3 review rounds, every one approve with nits.
  - `start_session` was refused after #211's note and after #212's.
  - #211 and #212 gave up their turn while `code-reviewer` was still running in the background.
  - #217 missed `/code-review high` at `.github/pull_request_template.md:21` and `docs/workflow.md:36`.
- **Behavior that stays unchanged:** `claude-security-scan.yml`, `claude-review` as the merge gate, at most 2 issues running at once, the 3-hour deadline, the 30-minute review wait, the preflight asking only once.

## Task breakdown

One task is one issue.

### Phase 1: the run starts itself, the plan writes the review criteria up front

#### Task 1: `[infra] chore: /run-tasks starts every issue in the command turn`

**Description:** Change `.claude/skills/run-tasks/SKILL.md` by assumptions 7 and 8:
- Step 3 starts every ready issue in the command turn and writes into the brief the issues to wait for.
- The session brief has a wait gate before step 1. The 3-hour deadline counts from `<results>/<issue>.working`.
- Drop the start wait, and update the Slack section and report item 1.
- Update `docs/workflow.md` to match.

First thing: try calling `start_session` for 3 sessions in the same command turn. If the app refuses from the third session onward, stop the task (back to Phase 1).

**Acceptance criteria:**
- [ ] In the turn of the user's command, the parent starts a child session for every ready issue, and each brief names the issues its child waits for, so that at most two children work at once and an issue's dependencies merge before it starts work
- [ ] A waiting child starts work only once every issue it waits for has a result file: after merged ones it continues from step 1, after a stopped one it writes `RESULT: stopped #<issue> PR #none — depends on #<n>` and ends; its 3-hour deadline counts from when it starts work
- [ ] The 15-minute start wait is gone, and `Run paused` is sent only when `start_session` or `list_sessions` fails in the command turn

**Verification:**
- [ ] Dry run on paper: chain A → B → C with D paired with A; the case where B stops; the case where C's deadline starts only when C starts work
- [ ] `git grep -n "start wait\|start-wait" -- .claude docs/workflow.md` finds nothing
- [ ] The diff touches only `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Not verified in the PR: a real run with no message between issues; the next run shows it
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 2 docs files, about 50 lines

#### Task 2: `[infra] chore: task-breakdown greps every file that states a changed rule`

**Description:** By assumption 10, add to `.claude/skills/task-breakdown/SKILL.md`:
- The "Verification by task type" section gets an "Every task" line: a task that changes a rule, name, value or command written in several files has a `git grep -n "<old text>"` in its Verification, and its Files likely touched lists every file the grep finds.
- The "Review the breakdown" section gets a matching check item.

Change no other file.

**Acceptance criteria:**
- [ ] The `task-breakdown` skill says that a task changing a rule, name, value or command stated in more than one file lists in its Verification a `git grep -n "<old text>"` that finds nothing once the task is done, and lists every file that grep finds under Files likely touched
- [ ] "Review the breakdown" has a check item for it

**Verification:**
- [ ] Dry run on paper with #217's case: the rule would have listed `.github/pull_request_template.md` and `docs/workflow.md`, which #217 missed
- [ ] The diff touches only `.claude/skills/task-breakdown/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/skills/task-breakdown/SKILL.md`
- `backend/PROGRESS.md`

**Estimated scope:** XS: 1 docs file, about 8 lines

#### Task 3: `[infra] chore: local review waits for both reviewers in the same turn`

**Description:** By assumption 9:
- Phase 4 point 6 of `.claude/workflow/pr-review.md` says plainly that both reviewers run in the foreground in the same message (`code-reviewer` through Agent, without `run_in_background`; `/code-review` through Skill), and that Claude does not end the turn until both have returned.
- Step 3 of the session brief in `.claude/skills/run-tasks/SKILL.md` repeats this.

Runs after task 1 because both change `SKILL.md`.

**Acceptance criteria:**
- [ ] Phase 4 point 6 says both reviewers run in the foreground in one message (the `code-reviewer` Agent call without `run_in_background`, and `/code-review`), and Claude ends no turn until both have returned
- [ ] Step 3 of the `/run-tasks` session brief says the same

**Verification:**
- [ ] Manual check: this task's own local review runs both reviewers in the foreground in one turn, and the Evidence says so
- [ ] The diff touches only `.claude/workflow/pr-review.md`, `.claude/skills/run-tasks/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** 1

**Files likely touched:**
- `.claude/workflow/pr-review.md`
- `.claude/skills/run-tasks/SKILL.md`
- `backend/PROGRESS.md`

**Estimated scope:** XS: 2 docs files, about 6 lines

#### Checkpoint: after Phase 1
- [ ] Tasks 1–3 merged, CI on `develop` green
- [ ] The next `/run-tasks` starts every issue in the command turn
- [ ] The user reviews before Phase 2 starts

### Phase 2: at most two reviews on GitHub

#### Task 4: `[infra] ci: second claude-review checks only what changed since the first`

**Description:** **High risk**: it changes a workflow that runs with a token (a security boundary), so the local review uses `/code-review max`. By assumption 6:
- Write `.github/scripts/review-context.sh`, which runs no model. It reads the earlier `claude-review` comment and its SHA, then gets the changes from that SHA to the head with `gh api repos/<repo>/compare/<sha>...<head>`, keeps only the PR's files, and writes them to `.review-context/`. The script has a test with fixtures.
- `claude-review.yml` runs the script before the Claude step, with a read-only token. The prompt splits in two branches.
- Add no tool to `--allowedTools`. Keep the secret check and the post job as they are.
- Update Phase 5 step 2 of `pr-review.md` and `docs/workflow.md` to match.

**Acceptance criteria:**
- [ ] When the PR already has a `claude-review` comment for an earlier head SHA, the review job writes that review and the PR's changes since that SHA (the PR's own files only) to `.review-context/` before the Claude step, with a script that runs no model and holds only a read-only token
- [ ] With that context the reviewer says for each earlier finding whether it is fixed, reviews only the new changes, and raises a new finding on unchanged lines only when it is High severity (a security hole or a correctness bug); the review still starts with `## Claude review · <sha>`
- [ ] Without an earlier review, or when its SHA is no longer in the PR's history, the review is the full five-step review of today, and the reviewer gets no new tool

**Verification:**
- [ ] Tests pass: `.github/scripts/test-review-context.sh` (no earlier review, an earlier review, a lost SHA, a file outside the PR left out)
- [ ] `git diff origin/develop...HEAD -- .github/workflows/claude-review.yml` shows `--allowedTools` and `--disallowedTools` unchanged and the new step with `pull-requests: read` only
- [ ] Local review ran at `max` (High risk), and the Evidence names the level
- [ ] The diff touches only `.github/workflows/claude-review.yml`, `.github/scripts/review-context.sh`, `.github/scripts/test-review-context.sh`, `.gitignore`, `.claude/workflow/pr-review.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Not verified in the PR: a scoped second review on GitHub, because `@claude review` runs the workflow from `develop`; the next run shows it
- [ ] Evidence section filled in

**Dependencies:** 3

**Files likely touched:**
- `.github/workflows/claude-review.yml`
- `.github/scripts/review-context.sh`
- `.claude/workflow/pr-review.md`
- `docs/workflow.md`
- `.gitignore`
- `.github/scripts/test-review-context.sh`
- `backend/PROGRESS.md`

**Estimated scope:** M: 5 files, about 120 lines

#### Task 5: `[infra] chore: at most two GitHub reviews per PR`

**Description:** By assumptions 1–5, 11 and 12, change:
- `.claude/skills/run-tasks/SKILL.md`: steps 7–10, the stop list, Rerun, and the report (a draft fix plan for each "final review requests changes" stop).
- `.claude/workflow/pr-review.md` Phases 5 and 6.
- The Phase 5 Gate cell of `CLAUDE.md`.
- `.github/pull_request_template.md`: line 30 and the `## Nits left` section.
- `docs/workflow.md`.

The merge still needs a review of the head, except for the first-parent case at step 9. Runs after task 4 because the budget relies on the narrow review.

**Acceptance criteria:**
- [ ] A PR gets at most two `claude-review` runs: when the first has findings (nits too), Claude fixes them all and comments `@claude review` once; when the first approves with no findings, it merges without a second
- [ ] When the second review approves or approves with nits, Claude merges without another push and lists the unfixed nits under `## Nits left` and in the run report; when it requests changes, or a high-severity security-scan finding needs a push after it, the issue stops with its issue, PR and branch open, and the report links a draft fix plan that reruns the PR with the issues that depend on it in one `/run-tasks`
- [ ] A conflict-free merge of `develop` in step 9 needs no new review (a review of the merge commit's first parent counts); a merge that edits the PR's own files uses the second review, or one more review of the conflict only when the second is spent
- [ ] A rerun starts with a new budget of two reviews, and `CLAUDE.md`, `.claude/workflow/pr-review.md`, `.github/pull_request_template.md` and `docs/workflow.md` describe the budget

**Verification:**
- [ ] Dry run on paper: a clean first approve; nits on the second; changes requested on the second; a clean step 9 merge; a step 9 conflict after the second review
- [ ] `git grep -n -i "fix round" -- CLAUDE.md .claude docs/workflow.md .github` finds nothing
- [ ] The diff touches only `.claude/skills/run-tasks/SKILL.md`, `.claude/workflow/pr-review.md`, `CLAUDE.md`, `.github/pull_request_template.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Not verified in the PR: the number of review rounds in a real run; the next run shows it
- [ ] Evidence section filled in

**Dependencies:** 1, 3, 4

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `.claude/workflow/pr-review.md`
- `CLAUDE.md`
- `.github/pull_request_template.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 5 docs files, about 60 lines

#### Checkpoint: after Phase 2
- [ ] Tasks 4 and 5 merged, CI on `develop` green
- [ ] The next real run: at most two `claude-review` runs per PR, and the second one reviews only earlier findings and new changes
- [ ] The user looks at that run's report before deciding whether anything more needs to change

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: /run-tasks starts every issue in the command turn` | chore, area:infra | - [ ] In the turn of the user's command, the parent starts a child session for every ready issue, and each brief names the issues its child waits for, so that at most two children work at once and an issue's dependencies merge before it starts work<br>- [ ] A waiting child starts work only once every issue it waits for has a result file: after merged ones it continues from step 1, after a stopped one it writes `RESULT: stopped #<issue> PR #none — depends on #<n>` and ends; its 3-hour deadline counts from when it starts work<br>- [ ] The 15-minute start wait is gone, and `Run paused` is sent only when `start_session` or `list_sessions` fails in the command turn | none |
| 2 | `[infra] chore: task-breakdown greps every file that states a changed rule` | chore, area:infra | - [ ] The `task-breakdown` skill says that a task changing a rule, name, value or command stated in more than one file lists in its Verification a `git grep -n "<old text>"` that finds nothing once the task is done, and lists every file that grep finds under Files likely touched<br>- [ ] "Review the breakdown" has a check item for it | none |
| 3 | `[infra] chore: local review waits for both reviewers in the same turn` | chore, area:infra | - [ ] Phase 4 point 6 says both reviewers run in the foreground in one message (the `code-reviewer` Agent call without `run_in_background`, and `/code-review`), and Claude ends no turn until both have returned<br>- [ ] Step 3 of the `/run-tasks` session brief says the same | 1 |
| 4 | `[infra] ci: second claude-review checks only what changed since the first` | chore, area:infra | - [ ] When the PR already has a `claude-review` comment for an earlier head SHA, the review job writes that review and the PR's changes since that SHA (the PR's own files only) to `.review-context/` before the Claude step, with a script that runs no model and holds only a read-only token<br>- [ ] With that context the reviewer says for each earlier finding whether it is fixed, reviews only the new changes, and raises a new finding on unchanged lines only when it is High severity (a security hole or a correctness bug); the review still starts with `## Claude review · <sha>`<br>- [ ] Without an earlier review, or when its SHA is no longer in the PR's history, the review is the full five-step review of today, and the reviewer gets no new tool | 3 |
| 5 | `[infra] chore: at most two GitHub reviews per PR` | chore, area:infra | - [ ] A PR gets at most two `claude-review` runs: when the first has findings (nits too), Claude fixes them all and comments `@claude review` once; when the first approves with no findings, it merges without a second<br>- [ ] When the second review approves or approves with nits, Claude merges without another push and lists the unfixed nits under `## Nits left` and in the run report; when it requests changes, or a high-severity security-scan finding needs a push after it, the issue stops with its issue, PR and branch open, and the report links a draft fix plan that reruns the PR with the issues that depend on it in one `/run-tasks`<br>- [ ] A conflict-free merge of `develop` in step 9 needs no new review (a review of the merge commit's first parent counts); a merge that edits the PR's own files uses the second review, or one more review of the conflict only when the second is spent<br>- [ ] A rerun starts with a new budget of two reviews, and `CLAUDE.md`, `.claude/workflow/pr-review.md`, `.github/pull_request_template.md` and `docs/workflow.md` describe the budget | 1, 3, 4 |
