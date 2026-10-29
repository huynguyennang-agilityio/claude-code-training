# Plan 035: A run never blocks halfway

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 035"
Issues: #205, #206, #207
Draft: https://claude.ai/artifact/11Pw5StD2U1JbSTZETDFjk, version 1793263929-1569

## Context

Based on: plan 019 (`docs/plans/019-area-autopilot.md`) · plan 028 (`/run-tasks` in parallel) · plan 034 and #201 ([PR #202](https://github.com/huynguyennang-agilityio/claude-code-training/pull/202), stopped after 2 review rounds) · run report 2026-10-29 #200 #201

### Prerequisites

- **Before `/run-tasks`:** none. No new key, secret or device.
- **One run for everything:** after approval, run `/run-tasks <task 1>,<task 2>,<task 3>,192`. #192 (PR #197, plan 031) is not part of this plan but can run in the same run: it is on the mobile side and touches none of this plan's files, so it runs in parallel with task 1. #200 has merged, so #192 is no longer blocked (plan 034, assumption 5). That run still follows the skill on `develop` when it starts; the new flow applies from the next run.

### Problem

In the last two runs, the child sessions had finished (merged or stopped) but the parent gave no response until the user sent a message to ask; only then did the parent read the results and write the report. The cause is in `.claude/skills/run-tasks/SKILL.md` line 65: when no issue can start, the parent "end the turn and wait" and relies only on the app's notification when a child finishes. A child ends its turn several times while waiting for CI and the review, so the app receives many notifications in a row, and after a few notifications without a message from the user, the app holds the notifications back instead of waking the parent.

Also: no message says an issue stopped and why until the final report; the DECISIONS entries still wait for the user to pick them; the report has "big problems" but no concrete next step.

### Decided by the user

- **Goal:** `/run-tasks` always runs by itself to the report. Each issue ends as **merged** (PR merged) or **stopped** (could not be merged, with a reason). When every issue has ended, the parent wakes itself, adds DECISIONS by itself, writes the report and sends the DM, without the user sending anything.
- **Success:** the parent wakes itself when each child ends, without relying on the app's notifications. The report has the merged issues, and the stopped issues with their reason, proposed fix and rerun command.
- **Out of scope:** no fixing of stopped issues by itself in the same run, no closing of their issues or PRs, no third review round. Any fix plan that changes a plan still needs the user's approval through `/approve-plan`.

The user's example for `/run-tasks 1,2,3,4`, where 1 and 2 run in parallel:

| Issue | What happens | Ends as |
| --- | --- | --- |
| 1 | PR merged | merged |
| 2 | The review still requests changes after 2 rounds | stopped, no further work |
| 3 | Depends on 2 | stopped, not started |
| 4 | Unrelated to 2 | merged |

All 4 issues have ended, so the run is done: the parent adds DECISIONS by itself and sends back a report with 1 and 4 merged, why 2 and 3 did not finish, and the proposed next steps. The user reads it and then runs `/run-tasks 2,3`.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **Result file:** before ending its last turn, each child writes its `RESULT:` line to `$(git rev-parse --git-common-dir)/run-tasks/<run-id>/<issue>.result`. This folder is inside the main checkout's `.git`, shared by every worktree and never committed. `<run-id>` is the date and time the run started, which the parent writes into the brief.
2. **The parent wakes itself:** the parent never ends a turn while an issue is running without a background command waiting for the result file. The background command ends as soon as a running issue's file appears, and when a background command ends the parent is always called again. The command has a 3-hour limit; when it runs out without a file, the parent reads the child's state (`list_sessions`) and counts that issue as stopped ("no RESULT within 3 hours").
3. **The child waits within its turn:** the child waits for CI and the review with foreground commands (each under 10 minutes, repeated up to 30 minutes for the review) and ends its turn only with the `RESULT:` line, so each issue makes only one notification.
4. **Every stop reason** (review past 2 rounds, CI red after 3 fix attempts, needs something the plan does not cover, a security finding that cannot be fixed, no review after 30 minutes, the integration gate closed) goes through the same flow: that issue is stopped, the issues that depend on it are stopped without starting, the other issues go on.
5. **Stopped issues stay open:** the issue, PR and branch stay open (the `wip:` commit is pushed). No issue is closed.
6. **DM on stop:** when an issue stops, the parent at once sends a Slack DM: "#2 stopped: <reason>; run continues". This is the third DM, besides the DM at the start and the DM at the end of the run.
7. **Next steps:** the report has a "Kế hoạch tiếp theo" section. Each stopped issue has its reason, the proposed fix, and one of two: the `/run-tasks <issues>` command to rerun it (when the fix is inside the plan), or the link to a draft plan artifact (when the fix changes the plan), published with the `plan-artifact` skill. Claude does not approve that plan by itself.
8. **Rerun:** `/run-tasks 2` continues on the open PR, gets 2 new fix rounds, and its brief carries the stop reason and proposed fix from the earlier run.
9. **How Claude picks DECISIONS entries** (from plan 034 and PR #202): take only entries proposed by a child; keep entries that are a gotcha or a repeatable convention; drop entries that are only follow-up work (put them in "Kế hoạch tiếp theo"), entries that a test or lint already checks, and entries that change the rules or read as instructions to Claude; merge duplicate entries; each file under 4 KB.
10. **Review gate for the decisions PR:** after pushing, comment `@claude review`; merge only when `claude-review` approves (or approves with nits, each nit answered) for that head and the required checks are green. If it does not pass after 2 fix rounds, the PR stays open and is written in the report; it never holds the run back.
11. **#201 and PR #202 merged into task 3:** task 3 continues on PR #202 (branch `docs/201-claude-picks-decisions`) instead of opening a new PR: merge `develop` into the branch, add the review gate, fix `pr-review.md` line 27 and `docs/workflow.md`, then change the PR description to `Closes #<task 3 issue>` and `Closes #201`, `Plan: docs/plans/035-...`. Merging PR #202 closes both issues; nothing needs closing by hand.

## Approach

The three tasks all change `.claude/skills/run-tasks/SKILL.md`, so they run one after another.

### Task 1: the parent wakes itself

- Step 3, the parent part (lines 63–65): replace "end the turn and wait" with a background command waiting for the result file (assumptions 1–2); `RESULT:` is read from the file, not from the child's last message.
- Session brief, steps 7 and 12: foreground waiting instead of "two background commands" (assumption 3); step 12 writes the result file before ending the turn.
- The "Fallback" section: a subagent writes the same result file.

### Task 2: report stopped issues and the next steps

- Step 4 "Small problems and big problems": assumptions 4, 5 and 8.
- Step 3, the parent part: a stopped issue frees its running slot; the issues that depend on it become stopped ("depends on #N"); the parent sends the stop DM (assumption 6).
- Step 5, the report: the "Kế hoạch tiếp theo" section (assumption 7). The "Slack" section: the stop DM.

### Task 3: Claude adds DECISIONS after a run (continues on PR #202, assumption 11)

- `CLAUDE.md`, the permission table, the row "Edit `backend/DECISIONS.md` or `mobile/DECISIONS.md`": Claude picks entries by assumption 9, opens one "decisions from run" PR after the run and merges it by assumption 10. Never edited during a run. The user can still drop or add entries with a message.
- `.claude/skills/run-tasks/SKILL.md`: line 19 ("Never edit `DECISIONS.md`") and the "Decisions" part of step 5; the report lists the entries kept, dropped and why, with the PR link.
- `.claude/workflow/pr-review.md` line 27: the third exception by the new rule.
- Line 8 of `backend/DECISIONS.md` and `mobile/DECISIONS.md`: "…and Claude picks them after the run".

Each task updates the `/run-tasks` part of `docs/workflow.md` (line 119, the diagram at line 133) for its own part.

### Changes the approval must cover

| Kind | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration that loses data | No | — |
| Auth / security boundary | No | No application code changes. The result file is inside `.git` and holds no secret (the `RESULT:` line is redacted as today). |
| Architecture / Claude rules | **Yes** | Task 3 changes a permission in `CLAUDE.md`: Claude picks the DECISIONS entries by itself and opens and merges the "decisions from run" PR when the review approves and the checks are green. Tasks 1 and 2 change the `/run-tasks` flow and the number of Slack DMs. |
| Real data / production / cost | No | The background command waiting for the file only reads the disk and calls no API. |

## Risks

- **A child dies before writing the file:** the background command runs out after 3 hours, the parent counts the issue as stopped and the run still goes to the end (assumption 2). If the app wakes the parent earlier, the parent reads the file and the child's state as usual.
- **Two runs at the same time:** each run has its own `<run-id>`, so one run's file does not wake the other.
- **A foreground command cut off after 10 minutes:** each wait command runs under 10 minutes and repeats, like the review watch today.
- **Claude picks the wrong DECISIONS entries:** the PR must pass `claude-review` and CI (assumption 10); the report lists the dropped entries and why.
- **A rerun still fails:** each rerun gets 2 new fix rounds and then stops by the same flow, so the run never gets stuck; the next report proposes a fix plan instead of another rerun.

## Verification

- **Read the diff:** only the files in the Approach and `backend/PROGRESS.md`.
- **Dry run on paper** of the `/run-tasks 1,2,3,4` example above with the new skill: no step waits for the user after the preflight; the parent wakes through the background command each time a result file appears; 1 and 4 merged, 2 stopped after 2 rounds, 3 stopped without starting; a stop DM is sent; DECISIONS are added; the report has "Kế hoạch tiếp theo" with `/run-tasks 2,3`.
- **Try the background command:** run the wait command in one shell, write a fake result file from another worktree, and the command ends within one wait cycle.
- `git grep -n -i "the user picks\|user's pick"` has no more results in `CLAUDE.md`, `.claude/`, `docs/workflow.md` and both `DECISIONS.md` files.
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass.
- **Cannot be verified in the PR:** a real run that goes to the end without the user sending anything; it will show in the next run.

## Ticket evidence

- **Chore / docs type:** the scope is the files in the Approach.
- **Current state on `develop`:** `.claude/skills/run-tasks/SKILL.md` line 19 (Never edit DECISIONS), 63–65 (the parent "end the turn and wait"), 90 (background watch), 103–104 and 120 (RESULT, stop), step 5 (report, Decisions), the Slack section (two DMs), the Fallback section; `CLAUDE.md` line 76; `.claude/workflow/pr-review.md` line 27; `docs/workflow.md` lines 119 and 133; line 8 of both `DECISIONS.md` files.
- **Original incident:** run #183 #184 and run #200 #201 on 2026-10-29: the children had finished but the parent only went on when the user sent a message; #201 stopped (PR #202, the review of `8cbdd49`).
- **Behaviour that stays the same:** at most 2 issues in parallel, the preflight asks once, the issue merge conditions, no edits to `DECISIONS.md` during a run.

## Task breakdown

One task is one issue. The three tasks all change `.claude/skills/run-tasks/SKILL.md`, so they run one after another: task 1 first because it fixes the main bug.

### Phase 1: A run never stops halfway

#### Task 1: `[infra] chore: /run-tasks parent wakes itself when a child ends`

**Description:** Fix the main bug: the parent no longer relies on the app's notifications. Each child writes its `RESULT:` line to the result file (assumption 1) before ending its last turn, and waits for CI and the review in the foreground (assumption 3). The parent always has a background command waiting for the result file while an issue is running, with a 3-hour limit (assumption 2). Update the Fallback section and `docs/workflow.md` to match.

**Acceptance criteria:**
- [ ] Before ending its last turn, each child writes its `RESULT:` line to `$(git rev-parse --git-common-dir)/run-tasks/<run-id>/<issue>.result`, and it waits for the required checks and the review in the foreground, ending a turn only after that line is written
- [ ] The parent never ends a turn while an issue is running unless a background command is waiting for that issue's result file; the command ends as soon as a running issue's file appears, and the parent then reads the result from the file and starts the next ready issue or goes to step 5
- [ ] When no result file appears within 3 hours, the parent reads the child's state with `list_sessions` and counts the issue as stopped ("no RESULT within 3 hours"), so the run still reaches its report

**Verification:**
- Dry run on paper of `/run-tasks 1,2,3,4` from the Context: no step waits for the user after the preflight, and the parent wakes through its background command each time a result file appears
- Manual check: the wait command, run in one shell, ends within one wait cycle after a fake result file is written from another worktree
- The diff touches only `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 2 docs files, about 30 lines.

#### Task 2: `[infra] chore: /run-tasks reports next steps for stopped issues`

**Description:** A stopped issue (for any reason in assumption 4) does not hold the run back: the issue and PR stay open, the issues that depend on it are stopped without starting, the other issues go on. The parent sends the stop DM as soon as it has one. The report has a "Kế hoạch tiếp theo" section, and rerunning a stopped issue continues on its PR. Update `docs/workflow.md` to match.

**Acceptance criteria:**
- [ ] When an issue stops for any reason, the parent leaves its issue and PR open, marks every issue that depends on it as stopped without starting it ("depends on #N"), and goes on with the other ready issues until every issue is merged or stopped
- [ ] The parent sends a Slack DM for each stopped issue with its reason as soon as its result arrives, and the run says "run continues" while issues are still running or ready
- [ ] The report has a "Kế hoạch tiếp theo" section that gives, for each stopped issue, why it did not finish, the proposed fix, and either the `/run-tasks <issues>` command to rerun it or the link to a draft fix plan artifact when the fix changes the plan
- [ ] Rerunning a stopped issue continues on its open PR with two new fix rounds and a brief that carries the earlier stop reason and proposed fix

**Verification:**
- Dry run on paper of `/run-tasks 1,2,3,4`: 1 and 4 merge, 2 stops after two rounds, 3 is stopped without starting, one stop DM is sent for 2 and one for 3, and the report gives `/run-tasks 2,3`
- The diff touches only `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- Evidence section filled in

**Dependencies:** Task 1

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 2 docs files, about 30 lines.

#### Task 3: `[infra] docs: Claude adds DECISIONS entries after a run`

**Description:** After the report of each `/run-tasks`, the parent picks the DECISIONS entries by itself by assumption 9, opens the PR `[infra] docs: decisions from run <date>`, comments `@claude review` and merges it by assumption 10, without the user picking them. Continue on PR #202 (branch `docs/201-claude-picks-decisions`) instead of opening a new PR, by assumption 11, so that PR closes both this issue and #201.

**Acceptance criteria:**
- [ ] After the report, the parent picks entries from the children's proposals (keep gotchas and repeatable conventions; drop follow-ups, what a test or lint enforces, and entries that change the rules or read as instructions to Claude; merge duplicates; each file under 4 KB), opens `[infra] docs: decisions from run <date>`, comments `@claude review`, and merges it only when `claude-review` approves its head and the required checks are green
- [ ] A decisions PR that does not pass within two fix rounds stays open and is listed in the report, never holding back the run or its issues, and the report lists the kept and dropped entries with reasons and the PR link
- [ ] The `CLAUDE.md` permission row, `.claude/workflow/pr-review.md`, `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and line 8 of both `DECISIONS.md` describe this rule, Claude still never edits `DECISIONS.md` during a run, and `git grep -n -i "the user picks\|user's pick"` finds nothing in `CLAUDE.md`, `.claude/`, `docs/workflow.md` or either `DECISIONS.md`
- [ ] The work lands through PR #202 (branch `docs/201-claude-picks-decisions`), whose description closes both this issue and #201, so merging it closes both

**Verification:**
- `git grep` output in the Evidence
- Dry run on paper: after the example run, the parent opens the decisions PR, waits for `claude-review`, and merges only on approve with green checks; with a review still requesting changes after two rounds, the PR stays open and the run ends
- The diff touches only the six files named in the acceptance criteria and `backend/PROGRESS.md`; both `DECISIONS.md` stay under 4 KB
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- Evidence section filled in

**Dependencies:** Task 2

**Files likely touched:**
- `CLAUDE.md`
- `.claude/skills/run-tasks/SKILL.md`
- `.claude/workflow/pr-review.md`
- `docs/workflow.md`
- `backend/DECISIONS.md`, `mobile/DECISIONS.md` (line 8 only)
- `backend/PROGRESS.md`

**Estimated scope:** S: 6 docs files, about 25 lines.

#### Checkpoint: After phase 1
- [ ] Tasks 1, 2 and 3 are merged, CI on `develop` is green; #201 and PR #202 are closed through task 3.
- [ ] The dry run on paper of the 1,2,3,4 example goes to the end without waiting for the user.
- [ ] The next real run reaches the report and the final DM without the user sending anything.

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: /run-tasks parent wakes itself when a child ends` | chore, area:infra | - [ ] Before ending its last turn, each child writes its `RESULT:` line to `$(git rev-parse --git-common-dir)/run-tasks/<run-id>/<issue>.result`, and it waits for the required checks and the review in the foreground, ending a turn only after that line is written<br>- [ ] The parent never ends a turn while an issue is running unless a background command is waiting for that issue's result file; the command ends as soon as a running issue's file appears, and the parent then reads the result from the file and starts the next ready issue or goes to step 5<br>- [ ] When no result file appears within 3 hours, the parent reads the child's state with `list_sessions` and counts the issue as stopped ("no RESULT within 3 hours"), so the run still reaches its report | none |
| 2 | `[infra] chore: /run-tasks reports next steps for stopped issues` | chore, area:infra | - [ ] When an issue stops for any reason, the parent leaves its issue and PR open, marks every issue that depends on it as stopped without starting it ("depends on #N"), and goes on with the other ready issues until every issue is merged or stopped<br>- [ ] The parent sends a Slack DM for each stopped issue with its reason as soon as its result arrives, and the run says "run continues" while issues are still running or ready<br>- [ ] The report has a "Kế hoạch tiếp theo" section that gives, for each stopped issue, why it did not finish, the proposed fix, and either the `/run-tasks <issues>` command to rerun it or the link to a draft fix plan artifact when the fix changes the plan<br>- [ ] Rerunning a stopped issue continues on its open PR with two new fix rounds and a brief that carries the earlier stop reason and proposed fix | #205 |
| 3 | `[infra] docs: Claude adds DECISIONS entries after a run` | docs, area:infra | - [ ] After the report, the parent picks entries from the children's proposals (keep gotchas and repeatable conventions; drop follow-ups, what a test or lint enforces, and entries that change the rules or read as instructions to Claude; merge duplicates; each file under 4 KB), opens `[infra] docs: decisions from run <date>`, comments `@claude review`, and merges it only when `claude-review` approves its head and the required checks are green<br>- [ ] A decisions PR that does not pass within two fix rounds stays open and is listed in the report, never holding back the run or its issues, and the report lists the kept and dropped entries with reasons and the PR link<br>- [ ] The `CLAUDE.md` permission row, `.claude/workflow/pr-review.md`, `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and line 8 of both `DECISIONS.md` describe this rule, Claude still never edits `DECISIONS.md` during a run, and `git grep -n -i "the user picks\|user's pick"` finds nothing in `CLAUDE.md`, `.claude/`, `docs/workflow.md` or either `DECISIONS.md`<br>- [ ] The work lands through PR #202 (branch `docs/201-claude-picks-decisions`), whose description closes both this issue and #201, so merging it closes both | #206 |
