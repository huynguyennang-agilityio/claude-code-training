# Plan 036: Local review before the first push

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 036"
Issues: #211, #212
Draft: https://claude.ai/artifact/SjSKxKvU63WxUXqJ2phjcx, version 1793281466-82d4

## Context

Based on: plan 014 (`claude-review.yml`) · plan 035 (a run never blocks halfway) · #206 stopped after 2 review rounds (commit `4498083`) · #201 / PR #202 stopped after 2 review rounds

### Prerequisites

- **Before `/run-tasks`:** none. No new key, secret or device.
- **Run:** after approval, run `/run-tasks <task 1>,<task 2>`. The two tasks both change `docs/workflow.md`, so they run one after the other. That run still follows the skill on `develop` when it starts; the local review step applies from the next run.

### Problem

Today code is reviewed only after the push, by `claude-review` on GitHub. Each fix round costs a push, an `@claude review` comment and up to 30 minutes of waiting. After 2 rounds with the review still requesting changes, the issue stops: #206 and #201 stopped exactly this way. Most findings (bugs, missing tests, scope drift) could be caught before the push. Locally, `.claude/workflow/pr-review.md` line 20 only allows running `code-reviewer` when the user asks.

### Decided by the user

- **Goal:** before the first push of each PR, Claude reviews locally and then fixes in one pass, so the review on GitHub usually approves on the first try.
- **Keep GitHub:** `claude-review` on GitHub stays the merge gate (the combination the user chose in chat on 2026-10-29). The local review cuts fix rounds; it does not replace the review on GitHub.
- **Out of scope:** no change to `claude-review.yml`, `claude-security-scan.yml`, the merge conditions, the limit of 2 fix rounds or the 30-minute review wait.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **When:** once, after the five points of Phase 4 have passed and before the first push of a branch for a PR, including the first push when rerunning a stopped issue. Not before the pushes of review fix rounds (steps 8 and 9 of `/run-tasks`). Plan PRs (`docs/plan-*`) and "decisions from run" PRs are skipped.
2. **Two reviewers in parallel,** on `git diff origin/develop...HEAD`: (a) a fresh `code-reviewer` subagent, given the issue number and the plan path, reviewing by the same 5 steps as on GitHub; (b) Claude Code's built-in `/code-review high` to catch correctness bugs. The `high` level is stated explicitly, because without it the command reuses the level typed last time.
3. **No `--fix`:** both reviewers only report; the session working on the issue fixes every finding itself in one pass. Reason: two reviewers running in parallel must not both edit one working tree, and the session knows the issue's scope, so it can drop fixes outside the scope.
4. **One fix pass:** each finding is fixed, or answered in the PR description when it is wrong or out of scope. Then the five Phase 4 points run again (lint, type checks, tests, diff in scope, evidence). No second local review.
5. **Record:** the PR's `## Evidence` has a "Local review" line with each reviewer's number of findings found, fixed and answered. This line is only a record, not a merge condition.
6. **No `/code-review`** (for example `@claude` on GitHub, or a session without this skill): run `code-reviewer` alone, and the Evidence says `Not verified: /code-review unavailable`.
7. **Model:** `code-reviewer` runs on the `model: opus` declared in `.claude/agents/code-reviewer.md`, the same as on GitHub, so that file does not change. `/code-review` runs on the model of the session working on the issue; the plan declares no other model.
8. **Measuring results:** the child's `RESULT:` line and the run report give, for each issue, the number of local findings and the number of `claude-review` rounds until it approved or the issue stopped. The next run shows whether this step cut the fix rounds.

## Approach

### Task 1: the local review rule

- `.claude/workflow/pr-review.md`: Phase 4 gets a sixth point, "Local review" (assumptions 1–6). In Phase 5 step 2 (line 20), the sentence "Claude runs the `code-reviewer` subagent locally only when the user asks…" changes to: it runs in point 6, and when the user asks.
- `CLAUDE.md` line 98, the Gate cell of Phase 4: add "local review pass done".
- `.github/pull_request_template.md`: the `## Evidence` comment gets a "Local review" line.
- `docs/workflow.md` line 36: the Phase 4 → 5 diagram gets the local review step.

### Task 2: `/run-tasks` runs the local review step

- `.claude/skills/run-tasks/SKILL.md`, session brief step 3 (line 96): add the local review step before step 5 (PR), also when rerunning an issue; step 12: `RESULT:` gives the numbers of assumption 8; run step 5, report item 1 (line 167): give those numbers for each issue.
- `docs/workflow.md` line 119 and the diagram at line 128: add the local review step.

### Changes the approval must cover

| Category | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration that could lose data | No | — |
| Auth / security boundary | No | The merge gate stays `claude-review` on GitHub, running with the rules taken from `develop`. |
| Architecture / Claude rules | **Yes** | The Phase 4 gate in `CLAUDE.md` gets one more step; `/run-tasks` gets one more step before the push. |
| Real data / production / cost | **Yes (small)** | Each PR costs one more `opus` review and one more `/code-review high` from your Claude quota, and about 5–15 more minutes per issue, within the 3-hour limit. |

## Risks

- **Reviewing its own code:** `code-reviewer` runs as a fresh subagent, without the context of writing the code, and GitHub stays the merge gate.
- **`/code-review` does not review the right branch** (after committing, the working tree is clean, so the "current diff" may be empty): task 1 checks this on its own branch before pushing, to fail fast. If it cannot be used, assumption 6 applies and the report says so.
- **Fixes from the local review drift out of scope:** the five Phase 4 points run again after the fix pass (assumption 4), including the check that the diff is in scope.
- **The local review and GitHub disagree:** GitHub wins; GitHub's findings are handled as today, within 2 fix rounds.
- **The rounds do not go down:** the numbers of assumption 8 show it after one run; if they do not go down, write a new plan.

## Verification

- **Real run on task 1:** the local review step runs on task 1's branch before its first push; the Evidence has the "Local review" line.
- **Dry run on paper** of task 2 with one issue: preflight → implement → Phase 4 → local review → one fix pass → Phase 4 again → push → `claude-review`; `RESULT:` and the report carry the numbers.
- `git grep -n "only when the user asks" .claude/workflow/pr-review.md` finds nothing.
- `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass.
- **Cannot be verified in the PR:** whether the number of review rounds on GitHub goes down; the next run shows it.

## Ticket evidence

- **Type chore / docs:** the scope is the files in Approach.
- **Current state on `develop`:** `.claude/workflow/pr-review.md` lines 11–15 (the five Phase 4 points) and line 20; `CLAUDE.md` line 98; `.claude/skills/run-tasks/SKILL.md` lines 96, 98 and 167; `docs/workflow.md` lines 36, 119 and 128; the `## Evidence` comment of `.github/pull_request_template.md`.
- **Original incidents:** #206 stopped with "review still requests changes after two fix rounds" (commit `4498083`); #201 / PR #202 stopped for the same reason (plan 035).
- **Behavior that stays unchanged:** `claude-review.yml`, `claude-security-scan.yml`, the merge conditions of `/run-tasks`, 2 fix rounds, the 30-minute review wait, the stop reasons.

## Task breakdown

One task is one issue. The two tasks both change `docs/workflow.md`, so they run one after the other.

### Phase 1: local review before the push

#### Task 1: `[infra] chore: local review pass before the first push`

**Description:** Add point 6, "Local review", to Phase 4 in `.claude/workflow/pr-review.md` following assumptions 1–6, change the sentence in Phase 5 step 2, then update to match the Phase 4 cell in `CLAUDE.md`, the Evidence comment in the PR template and the diagram at `docs/workflow.md` line 36. This task is high risk: it runs the local review step on its own branch before pushing, to check early that `/code-review high` can review the branch against `origin/develop`.

**Acceptance criteria:**
- [ ] Phase 4 in `.claude/workflow/pr-review.md` has a sixth point, "Local review": once, after the other five points pass and before the first push of a branch for a PR (also the first push of a rerun; not before review fix pushes; plan PRs and "decisions from run" PRs skip it), Claude runs a fresh `code-reviewer` subagent given the issue and plan, and `/code-review high`, in parallel and report-only, on `git diff origin/develop...HEAD`
- [ ] Claude fixes every finding in one pass, or answers it in the PR description when it is wrong or out of scope, then re-runs the other five Phase 4 points, with no second local round; when `/code-review` is not available the pass runs `code-reviewer` alone and the Evidence says `Not verified: /code-review unavailable`
- [ ] The PR's `## Evidence` has a "Local review" line with each reviewer's findings found, fixed and answered; the `CLAUDE.md` Phase 4 row, Phase 5 step 2 of `pr-review.md`, `.github/pull_request_template.md` and `docs/workflow.md` describe the pass, and `claude-review` on GitHub stays the merge gate unchanged

**Verification:**
- [ ] Manual check: the pass runs on this task's own branch before its first push; both reviewers return findings for the branch diff, each finding is fixed or answered, and the Evidence has the "Local review" line
- [ ] `git grep -n "only when the user asks" .claude/workflow/pr-review.md` finds nothing
- [ ] The diff touches only `.claude/workflow/pr-review.md`, `CLAUDE.md`, `.github/pull_request_template.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/workflow/pr-review.md`
- `CLAUDE.md`
- `.github/pull_request_template.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** M: 4 docs files, about 30 lines

#### Task 2: `[infra] chore: /run-tasks runs the local review pass`

**Description:** Bring point 6 of Phase 4 into the `/run-tasks` session brief (step 3, before step 5), also when rerunning an issue. Add the numbers of assumption 8 to `RESULT:` (step 12) and to the report (run step 5). Update `docs/workflow.md` lines 119 and 128 to match.

**Acceptance criteria:**
- [ ] Step 3 of the `/run-tasks` session brief runs the local review pass of Phase 4 point 6 before the first push of step 5, also on a rerun before its first push, and not before the pushes of review fix rounds (steps 8 and 9)
- [ ] The child's `RESULT:` line gives the local review counts (found, fixed, answered) and the number of `claude-review` rounds until the review approved or the issue stopped, and the run report lists them for each issue
- [ ] The merge conditions, the two fix rounds, the 30-minute review wait and the stop reasons stay unchanged

**Verification:**
- [ ] Dry run on paper of one issue: preflight, implement, Phase 4, local review, one fix pass, Phase 4 again, push, `claude-review`; the `RESULT:` line and the report carry the counts
- [ ] The diff touches only `.claude/skills/run-tasks/SKILL.md`, `docs/workflow.md` and `backend/PROGRESS.md`
- [ ] `.claude/hooks/test-block-forbidden-command.sh` and the required checks (`backend`, `mobile`, `goldens`) pass
- [ ] Not verified in the PR: whether GitHub review rounds go down; the next run shows it
- [ ] Evidence section filled in

**Dependencies:** Task 1

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `docs/workflow.md`
- `backend/PROGRESS.md`

**Estimated scope:** S: 2 docs files, about 20 lines

#### Checkpoint: after phase 1
- [ ] Tasks 1 and 2 merged, CI on `develop` green.
- [ ] The local review step has run for real on task 1.
- [ ] The next real run: the report has the number of local findings and of GitHub review rounds for each issue; you look at it before deciding whether anything more needs to change.

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: local review pass before the first push` | chore, area:infra | - [ ] Phase 4 in `.claude/workflow/pr-review.md` has a sixth point, "Local review": once, after the other five points pass and before the first push of a branch for a PR (also the first push of a rerun; not before review fix pushes; plan PRs and "decisions from run" PRs skip it), Claude runs a fresh `code-reviewer` subagent given the issue and plan, and `/code-review high`, in parallel and report-only, on `git diff origin/develop...HEAD`<br>- [ ] Claude fixes every finding in one pass, or answers it in the PR description when it is wrong or out of scope, then re-runs the other five Phase 4 points, with no second local round; when `/code-review` is not available the pass runs `code-reviewer` alone and the Evidence says `Not verified: /code-review unavailable`<br>- [ ] The PR's `## Evidence` has a "Local review" line with each reviewer's findings found, fixed and answered; the `CLAUDE.md` Phase 4 row, Phase 5 step 2 of `pr-review.md`, `.github/pull_request_template.md` and `docs/workflow.md` describe the pass, and `claude-review` on GitHub stays the merge gate unchanged | none |
| 2 | `[infra] chore: /run-tasks runs the local review pass` | chore, area:infra | - [ ] Step 3 of the `/run-tasks` session brief runs the local review pass of Phase 4 point 6 before the first push of step 5, also on a rerun before its first push, and not before the pushes of review fix rounds (steps 8 and 9)<br>- [ ] The child's `RESULT:` line gives the local review counts (found, fixed, answered) and the number of `claude-review` rounds until the review approved or the issue stopped, and the run report lists them for each issue<br>- [ ] The merge conditions, the two fix rounds, the 30-minute review wait and the stop reasons stay unchanged | #211 |
