# Plan 033: Gates check the issue's Verification

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 033,"
Issues: #183, #184
Draft: https://claude.ai/artifact/7q6oyHYKgcyLLoUGfHYkQ5, version 1793239470-8063

## Context

Based on: plan 032 (new task format, issues #176–#178) · plan 020 (reading `.claude/` from the base branch) · plan 028 (`/run-tasks` running in parallel).

Since plan 032, a new issue has two separate parts: `## Acceptance criteria` holds behaviour only, and `## Verification` holds the required checks for the task type. That list is in the "Verification by task type" part of `.claude/skills/task-breakdown/SKILL.md`, and includes `ROUTE_ACCESS`, the migration up/down/up, `pytest -m fuzz`, hurl, `openapi.json`, goldens, screen sizes and text scales…

But the places that check on `develop` still read only the acceptance criteria:

- Phase 4 in `.claude/workflow/pr-review.md` (items 1 and 5), and the Correctness and Tests steps of the PR review;
- `.claude/workflow/evidence.md`: "Map each acceptance criterion to at least one piece of evidence";
- `.claude/skills/run-tasks/SKILL.md`: the brief for each issue (step 2), the Phase 4 gate (step 3 of the session brief) and the merge condition (step 10);
- `.claude/agents/code-reviewer.md` (the Tests step), the `## Evidence` part of `.github/pull_request_template.md`, and the Phase 4 row in `CLAUDE.md`.

The consequence: a PR can skip goldens, fuzz or `ROUTE_ACCESS` and still pass the gate and be merged by `/run-tasks` on its own. The `Stop` hook only runs lint and tests, so it does not catch these items. No issue in the new format is open yet, so the gap has done no harm. It will show at the first plan approved in the new format (Plan 030 or 031).

### Prerequisites

- **Before `/run-tasks`:** none.
- **Order:** merge this plan before running `/approve-plan` for Plan 030 or 031.
- **Note:** by plan 020, `@claude` on a PR reads `.claude/` and `CLAUDE.md` from `develop`. So the new rules only take effect after the merge: task 1's PR is reviewed under the old rules, task 2's PR under the rules task 1 merged.

### Decided by the user

- **Fix this gap first**, before Plan 030 and 031 are approved in the new format.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **Only the written rules change.** No hook or CI check by machine that the Evidence covers all of the Verification. If needed, that part is done in another plan.
2. **Verification is checked like the acceptance criteria:** each item must be met, and the Evidence has evidence for that item or a `Not verified: <reason>` line. `/run-tasks` lists the Not verified lines in the `RESULT:` line, as it does today.
3. **Old-format issues (without `## Verification`) stay as they are:** their required checks are in the acceptance criteria and are checked as before.
4. **Plan 032 is not wrong**, so `task-breakdown`, `approve-plan`, `plan-artifact` and `planner` do not change. The `/run-tasks` flow (batches, worktrees, pairing) does not change either.
5. **`.claude/workflow/plan.md` line 50** says the acceptance criteria of a UI task must name the states, screen sizes and text scales. In the new format, these items are in Verification. Task 1 fixes this line to match.
6. **This plan uses the new format**, because `/approve-plan` reads this format since plan 032.

## Approach

Wherever a check says "each acceptance criterion", add "and each Verification item of the issue (when it has one)". Task 1 settles the exact wording in `pr-review.md`, and task 2 reuses exactly that wording.

### Files changed

- `.claude/workflow/pr-review.md` (task 1): Phase 4 items 1 and 5; the PR review steps 1 (Correctness) and 2 (Tests).
- `.claude/workflow/evidence.md` (task 1): the "Map each acceptance criterion…" bullet also covers the Verification items.
- `.claude/workflow/plan.md` (task 1): the line about a UI task's states, sizes and text scales (assumption 5).
- `CLAUDE.md` (task 1): the "4. Verification gate" row in the Phases table says "Criteria and Verification met".
- `.claude/skills/run-tasks/SKILL.md` (task 2): the brief for each issue also carries the Verification; step 3 of the session brief; the merge condition in step 10.
- `.claude/agents/code-reviewer.md` (task 2): the Tests step compares the tests with the issue's Verification as well.
- `.github/pull_request_template.md` (task 2): the comment of `## Evidence` names each acceptance criterion and each Verification item.
- **Unchanged:** the plan-writing skills (assumption 4), the GitHub workflows, the hooks, and the application code.

### Changes the approval must cover (Phase 2)

| Kind | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration | No | — |
| Auth / security boundary | No | The permission table in `CLAUDE.md` does not change. The gate becomes stricter, not looser. |
| Architecture / core technology | No | Changes Claude's working rules (Phase 0): `CLAUDE.md`, workflow, skill and subagent. |
| Real data / production / cost | No | — |

## Risks

- **A stricter gate makes `/run-tasks` stop more often:** a Verification item that cannot be done gets `Not verified: <reason>`, as with the acceptance criteria (assumption 2), so a missing environment alone does not block the merge.
- **Written rules can still be skipped:** assumption 1 accepts this. `claude-review` is the second layer of checking, because after task 2 `code-reviewer` reads the Verification too.
- **Two different wordings across the files:** task 2 depends on task 1 and reuses exactly the wording of `pr-review.md`.
- **Old-format issues asked for a Verification they do not have:** each change says "when it has one" (assumption 3).

## Verification

- **Read the diff:** the seven files in the Approach, no other file.
- **Look for anything missed:** `git grep -n -i "acceptance criteri\|each criterion" -- .claude/workflow .claude/skills/run-tasks .claude/agents/code-reviewer.md .github CLAUDE.md`. Every hit that is a gate or Evidence names Verification.
- **Dry run on paper:** a sample new-format issue (the first backend task of Plan 031) has a PR with no `pytest -m fuzz` evidence. Walk it through Phase 4 and the `/run-tasks` merge condition, and the PR must be blocked. Do the same with old-format issue #176: it is checked as before.
- The `Stop` hook (lint and tests) still passes, because no code changes.
- **Cannot be verified in the PR:** `@claude` on GitHub running under the new rules, because it only reads `.claude/` after the merge. It will show at the first PR of Plan 030 or 031.

## Ticket evidence

- **Chore / docs type:** the scope is the seven files in the Approach.
- **Current state on `develop`:** `.claude/workflow/pr-review.md` lines 11, 15, 41; `.claude/workflow/evidence.md` line 8; `.claude/skills/run-tasks/SKILL.md` lines 52, 73, 97; `.claude/agents/code-reviewer.md` line 35; `.github/pull_request_template.md` line 17; `CLAUDE.md` line 98; `.claude/workflow/plan.md` line 50.
- **Source of the Verification items:** the "Verification by task type" part of `.claude/skills/task-breakdown/SKILL.md`, and the new-format issue body in `.claude/skills/approve-plan/SKILL.md` (with `## Verification`).
- **Behaviour that must stay the same:** how old-format issues are checked, the `/run-tasks` flow, and the other merge conditions.

## Task breakdown

One task is one issue. The plan has 2 tasks, so it has a single phase and one checkpoint at the end.

### Phase 1: Gates read Verification

#### Task 1: `[infra] chore: gate rules check the issue's Verification`

**Description:** Change the gate rules so that each Verification item of the issue is checked like an acceptance criterion: it must be met, and the Evidence has evidence or a `Not verified: <reason>` line. Do `pr-review.md` first and settle the wording there, then reuse that wording in `evidence.md`, `plan.md` and `CLAUDE.md`. Each place says "when it has one", so old-format issues are checked as before. This task has the highest risk, because task 2 reuses its wording.

**Acceptance criteria:**
- [ ] Phase 4 in `.claude/workflow/pr-review.md` requires each acceptance criterion and each Verification item of the issue to be met, with evidence or a `Not verified: <reason>` line
- [ ] The PR review steps Correctness and Tests in `.claude/workflow/pr-review.md`, `.claude/workflow/evidence.md` and the Phase 4 row of `CLAUDE.md` name the issue's Verification next to its acceptance criteria
- [ ] An issue without `## Verification` is checked as before, and `.claude/workflow/plan.md` puts a UI task's states, screen sizes and text scales in its Verification (new format) or its acceptance criteria (old format)

**Verification:**
- [ ] The diff is limited to the four files below
- [ ] `git grep -n -i "acceptance criteri\|each criterion" -- .claude/workflow CLAUDE.md`: every gate or evidence hit names Verification
- [ ] Dry run on paper: a new-format issue with no `pytest -m fuzz` evidence fails Phase 4; old-format issue #176 passes as before
- [ ] The `Stop` hook checks pass
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `.claude/workflow/pr-review.md`
- `.claude/workflow/evidence.md`
- `.claude/workflow/plan.md`
- `CLAUDE.md`

**Estimated scope:** M: 4 files, about 20 lines.

#### Task 2: `[infra] chore: gate tools read the issue's Verification`

**Description:** Make the tools that run the gate read the issue's Verification, using exactly the wording task 1 settled in `pr-review.md`. In `/run-tasks`: the brief for each issue also carries the Verification, the child session checks the Verification in step 3, and the merge condition in step 10 asks for Evidence for each Verification item. Then change the Tests step of `code-reviewer` and the `## Evidence` comment of the PR template. The `/run-tasks` flow stays the same.

**Acceptance criteria:**
- [ ] The issue brief in `.claude/skills/run-tasks/SKILL.md` carries the issue's Verification, and its step 3 and merge condition require evidence for each acceptance criterion and each Verification item
- [ ] `.claude/agents/code-reviewer.md` compares the tests with the issue's Verification as well as its acceptance criteria
- [ ] The `## Evidence` comment in `.github/pull_request_template.md` asks for each acceptance criterion and each Verification item

**Verification:**
- [ ] The diff is limited to the three files below
- [ ] `git grep -n -i "acceptance criteri\|each criterion" -- .claude/skills/run-tasks .claude/agents/code-reviewer.md .github`: every gate or evidence hit names Verification
- [ ] Dry run on paper: `/run-tasks` with the new-format issue of task 1's dry run does not merge it; old-format issue #176 merges as before
- [ ] The `Stop` hook checks pass
- [ ] Evidence section filled in

**Dependencies:** 1

**Files likely touched:**
- `.claude/skills/run-tasks/SKILL.md`
- `.claude/agents/code-reviewer.md`
- `.github/pull_request_template.md`

**Estimated scope:** M: 3 files, about 15 lines.

#### Checkpoint: Gates read Verification
- [ ] The `Stop` hook passes, and the diff has only the seven files
- [ ] Dry run on paper: a new-format issue with no fuzz evidence is blocked at Phase 4 and at the merge condition; old-format issue #176 passes as before
- [ ] The user reviews before running `/approve-plan` for Plan 030 or 031

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: gate rules check the issue's Verification` | chore, area:infra | - [ ] Phase 4 in `.claude/workflow/pr-review.md` requires each acceptance criterion and each Verification item of the issue to be met, with evidence or a `Not verified: <reason>` line<br>- [ ] The PR review steps Correctness and Tests in `.claude/workflow/pr-review.md`, `.claude/workflow/evidence.md` and the Phase 4 row of `CLAUDE.md` name the issue's Verification next to its acceptance criteria<br>- [ ] An issue without `## Verification` is checked as before, and `.claude/workflow/plan.md` puts a UI task's states, screen sizes and text scales in its Verification (new format) or its acceptance criteria (old format) | none |
| 2 | `[infra] chore: gate tools read the issue's Verification` | chore, area:infra | - [ ] The issue brief in `.claude/skills/run-tasks/SKILL.md` carries the issue's Verification, and its step 3 and merge condition require evidence for each acceptance criterion and each Verification item<br>- [ ] `.claude/agents/code-reviewer.md` compares the tests with the issue's Verification as well as its acceptance criteria<br>- [ ] The `## Evidence` comment in `.github/pull_request_template.md` asks for each acceptance criterion and each Verification item | #183 |
