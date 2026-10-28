# Plan 032: Task breakdown in the planning-and-task-breakdown format

Status: approved
Approved: 2026-10-28, by the user in chat: "/approve-plan 032"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/NZKJyBTeDhWhxbUjFHgZeP, version 1793180406-0471

## Context

Based on: plan 023 (task-breakdown skill, plan-artifact, /approve-plan) · plan 020 (reading `.claude/` from the base branch) · Plan 031 (example of applying it) · the plugin skill `agent-skills:planning-and-task-breakdown` (source of the format and the criteria).

Today the "Task breakdown" part of a plan follows the repo's `task-breakdown` skill (plan 023). Each task has three parts, **Requirements**, **Steps** and **Checklist**, plus an order line. When Plan 031 was reviewed with the plugin skill `agent-skills:planning-and-task-breakdown`, the plan became clearly better: an oversized task was split, and checkpoints and scope estimates were added.

The user wants the Task breakdown from now on to **use exactly the splitting of that plugin skill**, in place of the current format. Each task has: Description, Acceptance criteria, Verification, Dependencies, Files likely touched and Estimated scope. Tasks are grouped by Phase, and each Phase ends with a Checkpoint. Before publishing, the task breakdown is reviewed against the skill's checklist.

The format and the criteria are **copied into the repo**, so `@claude` on GitHub, the `planner` subagent and machines without the plugin can all use them. The other sections of a plan (Context, Approach, Risks, …) stay as they are.

### Prerequisites

- **Before `/run-tasks`:** none.
- **When running:** run tasks 2 and 3 in the same `/run-tasks` batch (see Checkpoint 2), so there is no period in which drafts are written half in the old format.
- **Note:** the PR changes files in `.claude/` and `CLAUDE.md`. Per plan 020, `@claude` on a PR reads these files from `develop`, so the new rules take effect only after the merge. Changes to the PR are made on a local machine.

### Decided by the user

- **The Task breakdown uses the format of `planning-and-task-breakdown`**, no longer the Requirements / Steps / Checklist format.
- **Copied into the repo**, not calling the plugin skill.
- **The repo's splitting rules stay:** contract first, one endpoint per backend task, mobile split into mock / integration, shared groundwork as its own task. No switch to fully vertical slices.
- **The issue holds the whole task:** Description, Acceptance criteria, Verification, Dependencies, Files likely touched, Estimated scope.
- **A checkpoint is a suggested batch for running `/run-tasks`.** `/run-tasks` is not changed.

## Open questions and assumptions

Each item has the answer the plan assumes. To change one, name its number.

1. **The format of one task** (as in the plugin skill):
   - `**Description:**` one paragraph saying what the task does, and the architecture or security rules the reviewer will check it against;
   - `**Acceptance criteria:**` the checkable conditions;
   - `**Verification:**` the test, lint, build commands and the manual check;
   - `**Dependencies:**` the numbers of the tasks that must be done first, or `None`;
   - `**Files likely touched:**` a list of paths;
   - `**Estimated scope:**` the size, the number of files and the estimated number of lines.

   The old Steps part is dropped: file names move to Files likely touched, the order of work moves into the Description.
2. **The repo's required items move to Verification**: `ruff`, `mypy`, `pytest`, `pytest -m fuzz`, hurl, `openapi.json`, `ROUTE_ACCESS`, goldens, screen sizes and text scales, the `API_MODE=mock` screenshot, the Integration row, the integration gate, and the Evidence section. Acceptance criteria keep only behaviour.
3. **Number of Acceptance criteria:** aim for at most 3 items, as in the plugin skill. 4–5 items are allowed when the task cannot be split further (one endpoint or one screen). More than 5 items must be split.
4. **The size scale** follows the plugin skill, counting code files (not tests, fixtures or generated files): XS 1 file, S 1–2, M 3–5, L 5–8, XL more than 8. L and larger must be split. The repo's 400-line rule stays. Exception: the first task of a new backend module may be L (because it carries the skeleton and the migration), and it must say why in Estimated scope.
5. **Phase and Checkpoint:** in `## Task breakdown`, tasks sit under `### Phase N: <name>` as `#### Task N: `[area] type: title``. After each phase comes `#### Checkpoint: <name>` with a checklist: tests pass, the build is clean, the main flow works, the user reviews before going on. Each checkpoint matches one `/run-tasks` batch. A plan with 1–2 tasks has a single phase and one checkpoint at the end.
6. **The `Order:` line is dropped**, replaced by the phases and each task's Dependencies. A high-risk task goes in the earliest phase its dependencies allow, and its Description says so. The "Issues to create" table keeps its Depends on column.
7. **The "Issues to create" table**: the Acceptance criteria column equals the task's Acceptance criteria, word for word. `/approve-plan` still checks this.
8. **The review before publishing** is the plugin skill's "Verification" list, plus the repo's rules:
   - every task has Acceptance criteria and Verification;
   - dependencies are in the right order;
   - no task is L or larger;
   - task titles have no "and";
   - there are checkpoints between phases;
   - each backend task has exactly one route;
   - the table matches the tasks.

   `plan-artifact` runs the review before the first publish and after every change to the task breakdown. `planner` runs it before returning a draft.
9. **`/approve-plan` still accepts the old format** (`### Task N` with Requirements / Steps / Checklist), for drafts written before this plan (Plan 030, Plan 031) and old-flow plan PRs that are open. New drafts use the new format. Plan 031 is rewritten in the new format only when the user asks.
10. **Plan 032 itself uses the old format**, because the current `/approve-plan` can only read that format.
11. **The plugin skill's `tasks/plan.md` and `tasks/todo.md` are not used.** The plan is still `docs/plans/NNN-*.md`, and a task is still a GitHub issue.
12. **`/run-tasks` does not change.** It still reads the acceptance criteria and the plan section from the issue. With Files likely touched added, pairing becomes more precise without any change.
13. **After the merge,** the local memory `plan-breakdown-review-before-publish` is deleted, because the repo records this rule.

## Approach

### The new format in the template (`docs/plans/README.md`)

```markdown
## Task breakdown

One task is one issue. Each backend endpoint is its own task.

### Phase 1: Contract

#### Task 1: `[auth] docs: delete account contract`

**Description:** Write the contract for `POST /api/v1/users/me/delete` ...

**Acceptance criteria:**
- [ ] `docs/api/auth.md` documents the route, its order of checks and `409 last_admin`
- [ ] The request and error examples exist and match the section

**Verification:**
- [ ] Tests pass: `pytest` (docs and contract tests)
- [ ] Lint: `ruff check .`, `mypy`
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `docs/api/auth.md`
- `docs/api/examples/auth/delete_account_request.json`

**Estimated scope:** S: 3 files, about 80 lines

#### Checkpoint: Contract
- [ ] Tests pass, lint clean
- [ ] You review the contract before the backend and mobile work start

### Phase 2: Backend and mobile mock
...
```

### Files changed

- `.claude/skills/approve-plan/SKILL.md` (task 1):
  - reads `### Phase N`, `#### Task N` and `#### Checkpoint`;
  - checks each task's Acceptance criteria against the column in the table;
  - the new issue body has `## Description`, `## Acceptance criteria`, `## Verification`, `## Files likely touched`, `## Estimated scope`, `## Dependencies` (with real issue numbers);
  - the old format is still accepted and produces the issue body as before;
  - the plan translation keeps the field labels in English.
- `CLAUDE.md` (task 2): the "Task breakdown" bullet follows the new format.
- `.claude/workflow/plan.md` (task 2): Phase 1 step 2 follows the new format and names the review.
- `.claude/skills/task-breakdown/SKILL.md` (task 2): rewrite the task format, phases, checkpoints, the size scale and the "Review the breakdown" step. Keep the repo's Splitting part. Turn the "Checklists" part into the default Verification items per task type. Name the plugin skill as the source.
- `docs/plans/README.md` (task 2): the "Task breakdown" bullet and the template, as in the example above.
- `.claude/skills/plan-artifact/SKILL.md` (task 3): the Vietnamese labels become Mô tả (Description), Tiêu chí chấp nhận (Acceptance criteria), Kiểm chứng (Verification), Phụ thuộc (Dependencies), File dự kiến (Files likely touched), Phạm vi (Estimated scope), Giai đoạn (Phase), Điểm dừng (Checkpoint). Add the review step before publishing.
- `.claude/agents/planner.md` (task 3): change the description of the task format, and run the review before returning a draft.
- **Unchanged:** `/run-tasks`, the other sections of the template, the approved plans, and application code.

### Changes the approval must cover (Phase 2)

| Category | Yes? | Detail |
| --- | --- | --- |
| Public API / breaking contract | No | — |
| Schema / migration | No | — |
| Auth / security boundary | No | The permission table in `CLAUDE.md` does not change. |
| Architecture / core technology | No | Changes Claude's working rules (Phase 0): `CLAUDE.md`, skills and subagent. |
| Real data / production / cost | No | Affects only issues created from later plans. |

## Risks

- **`/approve-plan` breaks on new or old plans.** Task 1 goes first and accepts both formats. Checkpoint 1 does a dry run on paper with an old-format plan (Plan 031 version 2) and a new-format sample.
- **Drafts mix the two formats during the switch:** run tasks 2 and 3 in the same batch. `/approve-plan` accepts both formats, so no plan is blocked.
- **The "Steps" information is lost for the subagent doing a task:** Files likely touched together with a Description that gives the order of work replace Steps. The Phase 4 gate still checks Verification.
- **Acceptance criteria too short, so behaviour is missed:** the 3-item limit is only a target, up to 5 when the task cannot be split. The technical checks sit in Verification.
- **The format in the repo drifts from the plugin:** this is intended. The repo keeps its own copy and changes it only through a plan.

## Verification

- **Read the diff:** the seven files in Approach, no other file.
- **Dry run of `/approve-plan` on paper:** with Plan 031 version 2 (old format) and the new-format sample, write out the issue bodies it would create, without creating real issues.
- **Dry run of the new format:** rewrite Plan 031's Task breakdown in the new format into the Evidence. The result must be 5 tasks, with checkpoints, and no task L or larger.
- The `Stop` hook (lint and tests) still passes, because no code changes.
- **Cannot be verified in the PR:** `@claude` on GitHub, because it reads the new `.claude/` only after the merge. It shows in the next draft plan.

## Ticket evidence

- **Chore / docs type:** the scope is the seven files in Approach.
- **Behaviour that must stay the same:** the other template sections, the repo's splitting rules, the table equal to the task's criteria, `/approve-plan` accepting the old format, and `/run-tasks`.
- **Examples available:** Plan 031 version 1 and version 2 ([artifact](https://claude.ai/artifact/2W9eonAAPhrb43KZtphSMx)), and the plugin skill `agent-skills:planning-and-task-breakdown`.

## Task breakdown

One task is one issue. This plan is written in the old format (assumption 10).

Order: 1 → 2 → 3, one after the other. Task 1 (`/approve-plan`) has the highest risk, so it goes first. Tasks 2 and 3 should run in the same `/run-tasks` batch.

Checkpoints:

- **Checkpoint 1, after task 1:** `/approve-plan` reads both formats (dry run on paper). The user reviews the PR.
- **Checkpoint 2, after tasks 2 and 3:** Plan 031 rewritten in the new format gives 5 tasks, with checkpoints. The user reviews, and the local memory is deleted.

### Task 1: `[infra] chore: /approve-plan reads the new task format`

**Scope:** S, 1 file (`.claude/skills/approve-plan/SKILL.md`), about 40 lines.

**Requirements**

- Accepts the new format per assumptions 1, 5 and 7. Still accepts the old format (assumption 9).
- The other steps of `/approve-plan` (plan number, labels, PR, merge checks) do not change.

**Steps**

1. Translation step: add how to translate `### Phase`, `#### Task`, `#### Checkpoint` and the field labels. The labels stay in English.
2. Step 4: check each task's title and Acceptance criteria against its row in the table (new format), or its Checklist (old format).
3. Step 5: add the issue body for the new format. Dependencies are written with real issue numbers. Keep the old-format body unchanged.
4. Dry run on paper with Plan 031 version 2 and a new-format sample, recorded in the Evidence.

**Checklist**

- [ ] `.claude/skills/approve-plan/SKILL.md` reads `### Phase N`, `#### Task N` and `#### Checkpoint` in `## Task breakdown`
- [ ] Step 4 checks each task's title and Acceptance criteria against its table row (new format) or its Checklist (old format)
- [ ] New-format issue bodies have `## Description`, `## Acceptance criteria`, `## Verification`, `## Files likely touched`, `## Estimated scope` and `## Dependencies` with real issue numbers
- [ ] Old-format plans still produce the old issue body
- [ ] Dry run on Plan 031 version 2 and on a new-format sample, recorded in the evidence; no issue created
- [ ] Evidence section filled in

### Task 2: `[infra] chore: task format from planning-and-task-breakdown`

**Scope:** M, 4 Markdown files, about 150 lines.

**Requirements**

- The format, size scale, phases, checkpoints and review per assumptions 1–8.
- Keep the repo's splitting rules (contract first, one endpoint, mock / integration, shared groundwork).
- `CLAUDE.md` and `.claude/workflow/plan.md` say the same thing, so there is no conflict.

**Steps**

1. `.claude/skills/task-breakdown/SKILL.md`: rewrite "The section", turn "Checklists" into "Verification by task type", add "Sizing" and "Phases and checkpoints", turn "Check before you finish" into "Review the breakdown", name the source.
2. `docs/plans/README.md`: change the "Task breakdown" bullet and the template's `## Task breakdown` part.
3. `CLAUDE.md`: change the "Task breakdown" bullet.
4. `.claude/workflow/plan.md`: change Phase 1 step 2.
5. Rewrite Plan 031's Task breakdown in the new format into the Evidence.

**Checklist**

- [ ] `.claude/skills/task-breakdown/SKILL.md` describes the task fields (Description, Acceptance criteria, Verification, Dependencies, Files likely touched, Estimated scope), phases with checkpoints, the size scale with the 400-line rule and the first-module exception, and keeps the repo's splitting rules
- [ ] The repo's required checks per task type are listed under Verification, and Acceptance criteria aim at 3 items with at most 5
- [ ] "Review the breakdown" lists the checks of assumption 8 and names `agent-skills:planning-and-task-breakdown` as the source
- [ ] `docs/plans/README.md` template uses `### Phase N`, `#### Task N` and `#### Checkpoint`, with no `Order:` line; other template sections unchanged
- [ ] `CLAUDE.md` and `.claude/workflow/plan.md` describe the new task format and the review
- [ ] Plan 031's task breakdown rewritten in the new format gives 5 tasks, checkpoints and no task of size L or larger, recorded in the evidence
- [ ] Evidence section filled in

### Task 3: `[infra] chore: draft plans in the new task format`

**Scope:** S, 2 Markdown files, about 30 lines.

**Requirements**

- Vietnamese drafts use the labels of the new format, each with its English name so `/approve-plan` can map it.
- The review runs before the first publish, after every change to the task breakdown, and before `planner` returns a draft.

**Steps**

1. `.claude/skills/plan-artifact/SKILL.md`: change the "Task breakdown" bullet (new labels, phases, checkpoints) and add the "Review the breakdown" step to "Publishing and updating".
2. `.claude/agents/planner.md`: change the task description and add the review step.

**Checklist**

- [ ] `.claude/skills/plan-artifact/SKILL.md` lists the Vietnamese labels with their English names: Mô tả (Description), Tiêu chí chấp nhận (Acceptance criteria), Kiểm chứng (Verification), Phụ thuộc (Dependencies), File dự kiến (Files likely touched), Phạm vi (Estimated scope), Giai đoạn (Phase), Điểm dừng (Checkpoint)
- [ ] `.claude/skills/plan-artifact/SKILL.md` runs "Review the breakdown" before the first publish and after every change to the task breakdown
- [ ] `.claude/agents/planner.md` describes the new task format and runs "Review the breakdown" before it returns a draft or writes an old-flow plan file
- [ ] Evidence section filled in

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: /approve-plan reads the new task format` | chore, area:infra | - [ ] `.claude/skills/approve-plan/SKILL.md` reads `### Phase N`, `#### Task N` and `#### Checkpoint` in `## Task breakdown`<br>- [ ] Step 4 checks each task's title and Acceptance criteria against its table row (new format) or its Checklist (old format)<br>- [ ] New-format issue bodies have `## Description`, `## Acceptance criteria`, `## Verification`, `## Files likely touched`, `## Estimated scope` and `## Dependencies` with real issue numbers<br>- [ ] Old-format plans still produce the old issue body<br>- [ ] Dry run on Plan 031 version 2 and on a new-format sample, recorded in the evidence; no issue created<br>- [ ] Evidence section filled in | none |
| 2 | `[infra] chore: task format from planning-and-task-breakdown` | chore, area:infra | - [ ] `.claude/skills/task-breakdown/SKILL.md` describes the task fields (Description, Acceptance criteria, Verification, Dependencies, Files likely touched, Estimated scope), phases with checkpoints, the size scale with the 400-line rule and the first-module exception, and keeps the repo's splitting rules<br>- [ ] The repo's required checks per task type are listed under Verification, and Acceptance criteria aim at 3 items with at most 5<br>- [ ] "Review the breakdown" lists the checks of assumption 8 and names `agent-skills:planning-and-task-breakdown` as the source<br>- [ ] `docs/plans/README.md` template uses `### Phase N`, `#### Task N` and `#### Checkpoint`, with no `Order:` line; other template sections unchanged<br>- [ ] `CLAUDE.md` and `.claude/workflow/plan.md` describe the new task format and the review<br>- [ ] Plan 031's task breakdown rewritten in the new format gives 5 tasks, checkpoints and no task of size L or larger, recorded in the evidence<br>- [ ] Evidence section filled in | 1 |
| 3 | `[infra] chore: draft plans in the new task format` | chore, area:infra | - [ ] `.claude/skills/plan-artifact/SKILL.md` lists the Vietnamese labels with their English names: Mô tả (Description), Tiêu chí chấp nhận (Acceptance criteria), Kiểm chứng (Verification), Phụ thuộc (Dependencies), File dự kiến (Files likely touched), Phạm vi (Estimated scope), Giai đoạn (Phase), Điểm dừng (Checkpoint)<br>- [ ] `.claude/skills/plan-artifact/SKILL.md` runs "Review the breakdown" before the first publish and after every change to the task breakdown<br>- [ ] `.claude/agents/planner.md` describes the new task format and runs "Review the breakdown" before it returns a draft or writes an old-flow plan file<br>- [ ] Evidence section filled in | 2 |
