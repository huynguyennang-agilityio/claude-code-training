# Plan 037: DECISIONS per area, written by each issue

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 037"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/EGUAVUf9bthgriELgHLu9q, version 1793285785-0b59

## Context

Based on: plan 019 (DECISIONS) · plan 035 (a run never blocks halfway, #205–#207) · plan 036 (local review, #211 #212, approved) · [run #206 #207](https://claude.ai/artifact/2sjt48vj27W4PMpMBen445) (the run paused before #207) · [run #207](https://claude.ai/artifact/EchkAhPgq2xtoxi5PVcNJb)

### Prerequisites

- **Before `/run-tasks`:** none. No new key, secret or device.
- **Run together with plan 036 in one command:** after approval, run `/run-tasks <task 1>,<task 2>,211,212,<task 3>,<task 4>`. The run order is:
  1. task 1 and task 2 run in parallel, because they change no file in common;
  2. #211;
  3. #212;
  4. task 3;
  5. task 4.

  From step 2 on they must run one after the other, because the issues all change `SKILL.md`, `CLAUDE.md` or `pr-review.md`. Task 1 runs first to fix the parent not starting the next issue by itself. After task 1 merges, the parent follows the new rule within the same run, as it did with #205. If the run pauses before task 1 merges, you only need to type the `/run-tasks` command again for the remaining issues.

### Problem

- **DECISIONS takes a detour.** After a run, the parent picks entries from the `DECISION:` lines and opens a "decisions from run" PR with its own review (#207). #201/#207 took three runs just because of this process. Meanwhile, each issue's PR already has a review.
- **Each side has only one 4 KB file.** `backend/DECISIONS.md` is already 3.2 KB and `mobile/DECISIONS.md` 3.6 KB, nearly full.
- **The parent cannot start the next issue by itself.** When a background wait wakes the parent, the app refuses `start_session`, because the app only allows starting a session in a turn that begins with the user's words or with a session's note. Run #206 #207 had to pause for this reason. In run #205 #206 #207, #206 did start, because that turn began with the child session's note.
- **The local review level is the same for every task.** Plan 036 uses `/code-review high`, even for high-risk tasks such as payment, auth or migrations.

### Decided by the user

- **The parent only orchestrates and reports:** it starts sessions, waits for results, and writes one artifact on what is done, what is left and what to do next. The parent does not edit DECISIONS.
- **Each child session adds its own DECISIONS entries** in the issue's PR, after merging `develop` into the branch. No more "decisions from run" PR.
- **File split:** each side has one common file (`backend/DECISIONS.md`, `mobile/DECISIONS.md`) and one file per area. Each file under 4 KB.
- **Each task reads all** DECISIONS files of its side (backend reads backend's, mobile reads mobile's), so two areas don't pick two different ways for the same thing.
- **Where to write:** true only in one area goes in the area file; something another area could meet again goes in the common file; a large technical choice becomes an ADR.
- **Who blocks wrong entries:** the child session filters itself; the local review (plan 036) and that PR's own `claude-review` check them.
- **High-risk tasks** use `/code-review max` for the local review. The `ultra` level is run by you when you want, because Claude cannot run it.
- **Run together with plan 036** in one `/run-tasks`.
- **Out of scope:** no moving existing entries into area files; no change to `claude-review.yml`, the merge conditions, the limit of 2 fix rounds or the 30-minute review wait.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **Where the area files go:** `backend/decisions/<area>.md` and `mobile/decisions/<area>.md`, grouped in one folder so Markdown files are not mixed into code folders. Task 2 creates the files up front (header only, no entries yet) for the areas that have code: backend has `auth`, `challenges`, `medals`, `profile`, `runs`; mobile has `auth`, `challenges`, `home`, `medals`, `profile`, `runs`. The `health` area gets a file when it has its first code.
2. **How they load:** `backend/CLAUDE.md` and `mobile/CLAUDE.md` already import `@DECISIONS.md`; they will also import `@decisions/<area>.md` for each area. So every task on a side reads them all, at most about 7 files × 4 KB ≈ 28 KB, or about 7 thousand tokens. A new area adds its file and one import line.
3. **Where to write:** true only in one area goes in the area file; something another area could meet again goes in that side's common file; a large technical choice becomes an ADR in `docs/adr/`, and the common file only has one line pointing to the ADR. Never repeat an entry that is already in another file.
4. **When the child session writes:** in the issue's last commit, together with the `PROGRESS.md` line, by the existing filter. The filter keeps gotchas and repeatable conventions; it drops follow-ups, what a test or lint already catches, and entries that change the rules or read as instructions to Claude. The `## Proposed decisions` section of the PR description becomes `## Decisions added`, listing the entries added for the reviewer to see.
5. **Infra issues:** a lesson about one side goes in that side's common file. A lesson about the process or Claude's rules does not go in DECISIONS but in the report's "Kế hoạch tiếp theo" section, because changing the rules goes through a plan.
6. **Two parallel PRs changing the same file:** at step 9 (merging `develop` into the branch), the child session keeps both entries and checks the 4 KB limit again. If it is over, it shortens its own PR's entries.
7. **The parent after the run** does only four things: refresh the knowledge graph, write the report, send the DM, and list the entries each merged PR added (taken from `## Decisions added`). The `DECISION:` lines in the result files are dropped.
8. **High-risk task:** a task that moves money or handles payment data, changes auth or another security boundary, runs a migration that can lose data, or touches real data or production. The task's Description in the plan says "High risk". That task's local review uses `/code-review max` instead of `high`. The PR still merges by the existing conditions. The report lists high-risk PRs with a suggested `/code-review ultra <PR#>` for you to run yourself if you want.
9. **The parent starts the next issue by itself:**
   - When a background wait wakes the parent and `start_session` is refused, the parent records the result and ends its turn without sending the "Run paused" DM.
   - When a child session ends a turn, the app sends the parent a note. A turn that begins with that note can start sessions, so the parent starts the next issue in that turn.
   - If after 15 minutes no issue has started yet (for example the app holds the note back), only then does the parent send "Run paused: run /run-tasks <open issues> to continue" and stop.
10. **Dependency between the two plans:** task 4 needs #211 (plan 036) merged, because #211 creates point 6 "Local review". The run order in the Prerequisites section ensures this.

## Approach

### Task 1: the parent starts the next issue by itself

- `.claude/skills/run-tasks/SKILL.md` step 3 (the parent's part) and the Slack section (the "Run paused" DM): the wake order is the background wait, then the session's note, then the pause DM (assumption 9).
- `docs/workflow.md` line 119 and the `/run-tasks` diagram.

### Task 2: DECISIONS files per area

- Create `backend/decisions/<area>.md` and `mobile/decisions/<area>.md` (assumption 1), each with the shared header.
- `backend/CLAUDE.md` and `mobile/CLAUDE.md`: add the `@decisions/<area>.md` lines (assumption 2).
- The header of `backend/DECISIONS.md` and `mobile/DECISIONS.md`: the where-to-write rule (assumption 3). Line 8 (who writes) is left for task 3.
- `docs/plans/README.md` Areas section: a new area adds a `decisions/<area>.md` file and an import line.

### Task 3: child sessions add DECISIONS entries themselves

- `CLAUDE.md` permission table: the "Edit DECISIONS" row (a child session edits them in the issue's PR), and drop "decisions from run" from the Commit, Push and Merge rows.
- `.claude/workflow/pr-review.md` line 27: drop the third exception.
- `.claude/skills/run-tasks/SKILL.md`: line 19; session brief steps 4, 5, 9 and 12 (drop the `DECISION:` lines); run step 5 (drop the "Decisions" part and the decisions PR; report item 4 lists the entries added); the Report section.
- `.github/pull_request_template.md`: `## Proposed decisions` becomes `## Decisions added`.
- `docs/workflow.md` line 119 and the `DP` node at line 148.
- Line 8 of every DECISIONS file (both the common files and the area files).

### Task 4: max local review for high-risk tasks

- `.claude/workflow/pr-review.md` Phase 4 point 6 (added by #211): use `max` for high-risk tasks, and the Evidence line names the level that ran.
- `.claude/skills/task-breakdown/SKILL.md`: what a high-risk task is (assumption 8), and the task's Description says "High risk".
- `.claude/skills/run-tasks/SKILL.md` report: list high-risk PRs with a suggested `/code-review ultra <PR#>`.

### Changes the approval must cover

| Category | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration that could lose data | No | — |
| Auth / security boundary | No | No change to app code. The merge gate stays `claude-review`. Because the DECISIONS entries are in the reviewed PR, no source outside the review can slip in (the PR description is no longer a source). |
| Architecture / Claude rules | **Yes** | `CLAUDE.md`: a child session may edit `DECISIONS.md` in the issue's PR; no more "decisions from run" PR. `/run-tasks` changes its wake order and its report. Each task loads all DECISIONS files of its side. |
| Real data / production / cost | **Yes (small)** | `/code-review max` for high-risk tasks costs more quota than `high`. Each task loads at most about 7 thousand more tokens of DECISIONS. |

## Risks

- **A wrong entry slips in and affects every later task:** the child session filters itself, and the local review and `claude-review` look at the PR's diff. A wrong entry is fixed by a later PR like any other bug.
- **A file goes over 4 KB:** the child session checks `wc -c` before committing and at step 9, then shortens its own PR's entries. A full area file is a sign that some entries should become tests, lint or ADRs.
- **Two parallel PRs change the common file:** step 9 keeps both entries (assumption 6). Two issues of the same area already run one after the other.
- **The app holds the session's note back** (after many notes in a row with no message from the user): after 15 minutes the parent sends the "Run paused" DM. This is no worse than today.
- **Task 1 can only be verified in a real run:** this run itself is the test. The report says which issues started on a session note.
- **Dependency between the two plans** (task 4 needs #211): the run order ensures it. If #211 stops, task 4 stops too ("depends on #211").

## Verification

- **Real run:** in the run shared with plan 036, after task 1 merges, the next issues start without you typing a command, unless the app holds the note back.
- **Reads all files:** a new session on `backend/` has both the common file and every backend area file in its context (check with `/memory` or by asking it about an entry in an area file).
- **Dry run on paper:** an `auth` issue adds one entry to `backend/decisions/auth.md` and one to `backend/DECISIONS.md`; the PR has `## Decisions added`; the report lists both entries; there is no decisions PR.
- `git grep -n -i "decisions from run\|DECISION:" -- CLAUDE.md .claude docs/workflow.md backend/DECISIONS.md mobile/DECISIONS.md` finds nothing.
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass.
- **Cannot be verified in the PR:** whether `/code-review max` catches more for high-risk tasks; the first high-risk task shows it.

## Ticket evidence

- **Type chore / docs:** the scope is the files in Approach.
- **Current state on `develop` (`3fdf271`):**
  - `backend/CLAUDE.md` and `mobile/CLAUDE.md` only have `@DECISIONS.md`; line 8 of both DECISIONS files states the "decisions from run" rule.
  - Sizes: `backend/DECISIONS.md` 3235 bytes, `mobile/DECISIONS.md` 3609 bytes.
  - `CLAUDE.md` lines 73–76; `.claude/workflow/pr-review.md` line 27.
  - `.claude/skills/run-tasks/SKILL.md` lines 19, 126–134, 175–186 and 207.
  - `docs/workflow.md` lines 119 and 148.
- **Original incidents:** #201/#207 took three runs for the decisions PR (PR #202). Run #206 #207 paused because `start_session` was refused after a background wait woke the parent.
- **Behavior that stays unchanged:** at most 2 issues running at once, the preflight asks only once, the merge conditions, 2 fix rounds, the 30-minute review wait, and the existing DECISIONS entries.

## Task breakdown

One task is one issue. Tasks 1 and 2 change no file in common, so they run in parallel. Tasks 3 and 4 change `SKILL.md` in common with each other and with #212, so they run afterwards, one at a time.

### Phase 1: the run continues by itself, DECISIONS has room

#### Task 1: `[infra] chore: /run-tasks starts the next issue on a session note`

**Description:** Change step 3 (the parent's part) and the Slack section in `.claude/skills/run-tasks/SKILL.md` by assumption 9: when a background wait wakes the parent and `start_session` is refused, the parent records the result and ends its turn; the next issue starts in the turn that the child session's note wakes; the "Run paused" DM is sent only after 15 minutes without starting any issue. Update `docs/workflow.md` to match. This task runs first in the shared run, so the later issues benefit from the new rule.

**Acceptance criteria:**
- [ ] When a result wait wakes the parent and `start_session` is refused, the parent records that issue's result, sends no "Run paused" DM, and ends its turn; on the next turn that a session note starts, it starts the next ready issues, each with its result wait
- [ ] Before ending such a turn the parent starts one 15-minute wait; if it ends and no issue has started since, the parent sends `Run paused: run /run-tasks <open issues> to continue`, naming only the issues not yet merged or stopped, and stops
- [ ] The run report says, for each issue after the first, whether it started on a session note or after the user's command

**Verification:**
- [ ] Dry run on paper: issues A then B, one after the other; A's result wait wakes the parent, the start is refused, the parent ends its turn, A's session note starts B; and the case where no note comes within 15 minutes ends with the pause DM
- [ ] Real check in the shared run with plan 036: the report shows which issues started on a session note
- [ ] The diff touches only `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 2 docs files, about 20 lines

#### Task 2: `[infra] docs: per-area DECISIONS files read on every task`

**Description:** Create the area files by assumption 1, have `backend/CLAUDE.md` and `mobile/CLAUDE.md` import them (assumption 2), add the where-to-write rule (assumption 3) to the header of every DECISIONS file, and state in `docs/plans/README.md` that a new area adds a file. Move no existing entry. Do not change line 8 (who writes): that is task 3's job.

**Acceptance criteria:**
- [ ] `backend/decisions/<area>.md` exists for `auth`, `challenges`, `medals`, `profile` and `runs`, and `mobile/decisions/<area>.md` for `auth`, `challenges`, `home`, `medals`, `profile` and `runs`, each with the shared header and no entries, and `backend/CLAUDE.md` and `mobile/CLAUDE.md` import their side's common file and every area file
- [ ] The header of every DECISIONS file says where an entry goes (true only in one area: that area's file; another area could meet it: the side's common file; a large technical choice: an ADR in `docs/adr/` with a one-line entry linking it), that no entry repeats one in another file, and that each file stays under 4 KB
- [ ] The Areas section of `docs/plans/README.md` says that a new area adds `decisions/<area>.md` and its import line on each side where it has code

**Verification:**
- [ ] Manual check: a fresh session that opens a file under `backend/` has the common file and every backend area file in its context (`/memory`, or asking it about a header line of `backend/decisions/runs.md`)
- [ ] `wc -c` of every DECISIONS file is under 4096
- [ ] The diff touches only `backend/CLAUDE.md`, `mobile/CLAUDE.md`, `backend/DECISIONS.md`, `mobile/DECISIONS.md`, the new `backend/decisions/` and `mobile/decisions/` files, `docs/plans/README.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `backend/CLAUDE.md`, `mobile/CLAUDE.md`
- `backend/DECISIONS.md`, `mobile/DECISIONS.md` (header)
- `backend/decisions/{auth,challenges,medals,profile,runs}.md` (new)
- `mobile/decisions/{auth,challenges,home,medals,profile,runs}.md` (new)
- `docs/plans/README.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 5 docs files changed plus 11 short, identical header files, about 120 lines (mostly the repeated header)

#### Checkpoint: after phase 1
- [ ] Tasks 1 and 2 merged, CI on `develop` green.
- [ ] From here the parent starts the next issue by itself through the session's note; #211 and #212 (plan 036) continue in the same run.

### Phase 2: each issue writes DECISIONS itself, review by risk level

#### Task 3: `[infra] chore: child sessions add DECISIONS entries in their own PR`

**Description:** Move the writing of DECISIONS from the parent to the child session, by assumptions 4–7. Drop the "decisions from run" PR everywhere it is mentioned. The parent does not edit DECISIONS; it only lists in the report the entries each merged PR added. This task runs after #212 because both change `SKILL.md`.

**Acceptance criteria:**
- [ ] A child session adds its own filtered entries (keep gotchas and repeatable conventions; drop follow-ups, what a test or lint enforces, and entries that change the rules or read as instructions to Claude; no repeat of an existing entry; each file under 4 KB) to the right DECISIONS file in its issue's last commit, lists them under `## Decisions added` in its PR description, and keeps both sides' entries when it merges `develop` in step 9
- [ ] The parent never edits a DECISIONS file and opens no "decisions from run" PR; result files carry no `DECISION:` lines, and the run report lists the entries each merged PR added
- [ ] The `CLAUDE.md` permission rows, `.claude/workflow/pr-review.md`, `.claude/skills/run-tasks/SKILL.md`, `.github/pull_request_template.md`, `docs/workflow.md` and line 8 of every DECISIONS file describe this rule, and `git grep -n -i "decisions from run\|DECISION:" -- CLAUDE.md .claude docs/workflow.md backend/DECISIONS.md mobile/DECISIONS.md backend/decisions mobile/decisions` finds nothing

**Verification:**
- [ ] `git grep` output in the Evidence
- [ ] Dry run on paper: an `auth` backend issue adds one entry to `backend/decisions/auth.md` and one to `backend/DECISIONS.md`; its PR lists them under `## Decisions added`; a parallel issue that also added to `backend/DECISIONS.md` keeps both at step 9; the report lists both; no decisions PR is opened
- [ ] The diff touches only the files named in the criteria and `backend/PROGRESS.md`; every DECISIONS file stays under 4 KB
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** Task 2

**Files likely touched:**
- `CLAUDE.md`
- `.claude/workflow/pr-review.md`
- `.claude/skills/run-tasks/SKILL.md`
- `.github/pull_request_template.md`
- `docs/workflow.md`
- `backend/DECISIONS.md`, `mobile/DECISIONS.md`, `backend/decisions/*.md`, `mobile/decisions/*.md` (line 8)
- `backend/PROGRESS.md`

**Estimated scope:** M: 5 docs files plus line 8 of the DECISIONS files, about 50 lines

#### Task 4: `[infra] chore: max local review for high-risk tasks`

**Description:** By assumption 8: define a high-risk task in the `task-breakdown` skill; have point 6 "Local review" (added by #211) use `/code-review max` for such a task; and have the `/run-tasks` report suggest `/code-review ultra <PR#>` for high-risk PRs. Claude never runs ultra itself. Needs #211 (plan 036) merged (assumption 10). Runs after task 3 because both change `SKILL.md`.

**Acceptance criteria:**
- [ ] Phase 4 point 6 of `.claude/workflow/pr-review.md` runs `/code-review max` instead of `/code-review high` for a task whose Description says "High risk", and the Evidence "Local review" line names the level that ran
- [ ] The `task-breakdown` skill says a task is high risk when it moves money or handles payment data, changes auth or another security boundary, runs a migration that can lose data, or touches real data or production, and that its Description then says "High risk"
- [ ] The `/run-tasks` report lists each high-risk PR with `/code-review ultra <PR#>` as an optional check for the user, and Claude never starts an ultra review

**Verification:**
- [ ] Dry run on paper: a task marked "High risk" runs `/code-review max` in its local review, its Evidence says so, and the report lists its PR with the ultra command
- [ ] The diff touches only `.claude/workflow/pr-review.md`, `.claude/skills/task-breakdown/SKILL.md`, `.claude/skills/run-tasks/SKILL.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Not verified in the PR: whether `max` finds more on a real high-risk task; the first one shows it
- [ ] Evidence section filled in

**Dependencies:** Task 3 (both change `SKILL.md`). Outside this plan: #211 (plan 036) merged.

**Files likely touched:**
- `.claude/workflow/pr-review.md`
- `.claude/skills/task-breakdown/SKILL.md`
- `.claude/skills/run-tasks/SKILL.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 3 docs files, about 20 lines

#### Checkpoint: after phase 2
- [ ] Tasks 3 and 4 merged (together with #211, #212), CI on `develop` green.
- [ ] The shared run's report has no decisions PR, and says which issues started on a session note.
- [ ] The next real run: check that DECISIONS entries are in the issue's PR, and look at the number of local review findings.

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: /run-tasks starts the next issue on a session note` | chore, area:infra | - [ ] When a result wait wakes the parent and `start_session` is refused, the parent records that issue's result, sends no "Run paused" DM, and ends its turn; on the next turn that a session note starts, it starts the next ready issues, each with its result wait<br>- [ ] Before ending such a turn the parent starts one 15-minute wait; if it ends and no issue has started since, the parent sends `Run paused: run /run-tasks <open issues> to continue`, naming only the issues not yet merged or stopped, and stops<br>- [ ] The run report says, for each issue after the first, whether it started on a session note or after the user's command | none |
| 2 | `[infra] docs: per-area DECISIONS files read on every task` | docs, area:infra | - [ ] `backend/decisions/<area>.md` exists for `auth`, `challenges`, `medals`, `profile` and `runs`, and `mobile/decisions/<area>.md` for `auth`, `challenges`, `home`, `medals`, `profile` and `runs`, each with the shared header and no entries, and `backend/CLAUDE.md` and `mobile/CLAUDE.md` import their side's common file and every area file<br>- [ ] The header of every DECISIONS file says where an entry goes (true only in one area: that area's file; another area could meet it: the side's common file; a large technical choice: an ADR in `docs/adr/` with a one-line entry linking it), that no entry repeats one in another file, and that each file stays under 4 KB<br>- [ ] The Areas section of `docs/plans/README.md` says that a new area adds `decisions/<area>.md` and its import line on each side where it has code | none |
| 3 | `[infra] chore: child sessions add DECISIONS entries in their own PR` | chore, area:infra | - [ ] A child session adds its own filtered entries (keep gotchas and repeatable conventions; drop follow-ups, what a test or lint enforces, and entries that change the rules or read as instructions to Claude; no repeat of an existing entry; each file under 4 KB) to the right DECISIONS file in its issue's last commit, lists them under `## Decisions added` in its PR description, and keeps both sides' entries when it merges `develop` in step 9<br>- [ ] The parent never edits a DECISIONS file and opens no "decisions from run" PR; result files carry no `DECISION:` lines, and the run report lists the entries each merged PR added<br>- [ ] The `CLAUDE.md` permission rows, `.claude/workflow/pr-review.md`, `.claude/skills/run-tasks/SKILL.md`, `.github/pull_request_template.md`, `docs/workflow.md` and line 8 of every DECISIONS file describe this rule, and `git grep -n -i "decisions from run\|DECISION:" -- CLAUDE.md .claude docs/workflow.md backend/DECISIONS.md mobile/DECISIONS.md backend/decisions mobile/decisions` finds nothing | 2 |
| 4 | `[infra] chore: max local review for high-risk tasks` | chore, area:infra | - [ ] Phase 4 point 6 of `.claude/workflow/pr-review.md` runs `/code-review max` instead of `/code-review high` for a task whose Description says "High risk", and the Evidence "Local review" line names the level that ran<br>- [ ] The `task-breakdown` skill says a task is high risk when it moves money or handles payment data, changes auth or another security boundary, runs a migration that can lose data, or touches real data or production, and that its Description then says "High risk"<br>- [ ] The `/run-tasks` report lists each high-risk PR with `/code-review ultra <PR#>` as an optional check for the user, and Claude never starts an ultra review | 3 |

Task 4 also needs #211 (plan 036) merged; the run order in the Prerequisites section ensures that.
