---
name: task-breakdown
description: How to break a StrideQuest plan's work into tasks, one issue each, in the planning-and-task-breakdown format (Description, Acceptance criteria, Verification, Dependencies, Files likely touched, Estimated scope), grouped in phases with checkpoints, and one backend endpoint per task. Use when writing or changing a plan's "Task breakdown" and "Issues to create" sections in docs/plans/.
---

# Task breakdown

Every plan breaks its work into tasks before it lists the issues ([plan 023](../../../docs/plans/023-task-breakdown-skill.md)). One task is one issue. The format and the review below are copied from the plugin skill `agent-skills:planning-and-task-breakdown` ([plan 032](../../../docs/plans/032-task-breakdown-format.md)), so `@claude` on GitHub, the `planner` subagent and machines without the plugin use the same rules. The repo keeps its own copy and changes it only through a plan; its splitting rules below come first.

The rules of Phase 1 are in [`.claude/workflow/plan.md`](../../workflow/plan.md) and the template in [`docs/plans/README.md`](../../../docs/plans/README.md#template). If this file and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix this file.

Plans drafted before plan 032 use the old format (`### Task N` with Requirements, Steps and a Checklist, and an `Order:` line). `/approve-plan` still reads it; write every new plan in the format below.

## The section

Put `## Task breakdown` after "Ticket evidence" and before "Issues to create":

````markdown
## Task breakdown

One task is one issue. Each backend endpoint is its own task.

### Phase 1: <name>

#### Task 1: `[area] type: title`

**Description:** One paragraph: what the task does, in the order of work, and the rules a reviewer will check it against (the contract, architecture, security, the design frame).

**Acceptance criteria:**
- [ ] A specific, testable behaviour

**Verification:**
- [ ] Tests pass: <commands>
- [ ] Lint and type checks: <commands>
- [ ] Manual check: <what to look at>
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `path/to/file`

**Estimated scope:** S: 2 files, about 80 lines

#### Checkpoint: <name>
- [ ] Tests pass, lint and type checks clean
- [ ] The main flow of this phase works
- [ ] The user reviews before the next phase starts
````

- **Description** says only what the contract, `CLAUDE.md` and the plan's Approach do not already say for this task. The order of work goes here (the old Steps part is gone). A task is **high risk** when it moves money or handles payment data, changes auth or another security boundary, runs a migration that can lose data, or touches real data or production. Its Description then says "High risk", so its local review runs `/code-review max` instead of `high` ([Phase 4 point 6](../../workflow/pr-review.md#phase-4-verification-gate)).
- **Acceptance criteria** are behaviour only: what a user, a client or another module can observe. **Aim for at most 3 items.** 4 or 5 are allowed only when the task cannot be split further (one endpoint, one screen); more than 5 means split the task. No "works well", no "clean code".
- **Verification** holds the commands, the repo's required checks for the task type (below) and the manual check. A reviewer ticks it from the test output and the evidence.
- **Dependencies** are lower task numbers, as in the table's "Depends on" (`1, 3`), or `None`. `/approve-plan` creates the issues in order, so a task never depends on a later one.
- **Files likely touched** lists paths, code first, then tests. A fresh subagent starts from this list.
- **Estimated scope** is the size from "Sizing", the number of code files and the estimated changed lines.
- The `#### Task N` title is the issue title, and `N` is the row number in "Issues to create". Tasks are numbered 1, 2, ... across the phases.

## Rules

### Splitting

- **Backend: one endpoint per task.** A backend task adds or changes exactly one route (one method and path). Never put two routes in one task, even when they share a schema.
  - The first task of a new module also carries the module skeleton (`backend/app/modules/<module>/`, mounting) and the migration that the route needs.
  - A later endpoint that needs a schema change carries its own migration.
  - Shared service code (a helper both routes use) goes in the first task that needs it; the second task depends on it and reuses it.
- **Contract first.** A `docs` task writes `docs/api/<module>.md` and `docs/api/examples/<module>/` before the backend and mobile tasks that use them.
- **Mobile.** A flow that calls an endpoint is a `(mobile, mock)` task and a `(mobile, integration)` task ([`.claude/workflow/plan.md`](../../workflow/plan.md#mobile-tasks-mock-and-integration)). The integration task depends on its mock task and only on the backend tasks of the endpoints that flow calls, so one late endpoint does not hold back every screen. A screen with no backend call is one task.
- **Shared groundwork** used by several mobile tasks (a layout, routes, a shared widget) is its own task, so the tasks that use it can run in parallel instead of waiting for each other.
- **Docs-only and tooling plans** use the same fields per task, without the endpoint rule.
- **No "and" in a title.** A title that needs "and" is two tasks.

### Sizing

Count code files: not tests, fixtures, examples or generated files. A Dart library and its `part` files (a bloc with its event and state) count as one file. A count on the boundary of two sizes takes the smaller one (2 files is S, 5 files is M).

| Size | Code files | Example |
| --- | --- | --- |
| XS | 1 | A config change, one validation rule |
| S | 1–2 | A contract, a small endpoint change |
| M | 3–5 | One endpoint with its service and repository, one screen |
| L | 5–8 | Too large: split it |
| XL | more than 8 | Too large: split it |

- **L and larger must be split.** An agent does best on S and M tasks.
- **The 400-line rule stays:** split a task that would pass about 400 changed lines, not counting generated files, tests and fixtures. `/run-tasks` lists a larger PR in its report.
- **Exception:** the first task of a new backend module may be L, because it carries the module skeleton and the migration. Its Estimated scope says why.

### Phases and checkpoints

- Tasks sit under `### Phase N: <name>`, in the order the dependencies allow. Each dependency is a lower-numbered task, in the same or an earlier phase. Tasks of one phase that depend on each other run one after the other in its batch.
- Put a high-risk task in the earliest phase its dependencies allow (fail fast); its Description says "High risk".
- After each phase comes `#### Checkpoint: <name>` with a checklist: the tests pass, the build or lint is clean, the main flow of the phase works, and the user reviews before the next phase. A checkpoint is not a task and gets no issue.
- **A checkpoint is a suggested `/run-tasks` batch:** run the tasks of one phase together, then stop for the user's review. `/run-tasks` itself does not change.
- A plan with 1–2 tasks has one phase and one checkpoint at the end.
- There is no `Order:` line: the phases and each task's Dependencies give the order.

### Verification by task type

Every task's Verification lists what applies of these, so the Acceptance criteria can stay behaviour only:

- **Backend:** the route's level in `ROUTE_ACCESS`; the migration with up, down, up (and `\d <table>`) when there is one; unit and integration tests; auth sweep; contract and OpenAPI snapshot tests; `pytest -m fuzz`; the hurl file and its output; `docs/api/openapi.json` updated; `ruff check .`, `ruff format --check .`, strict `mypy` and the full `pytest` pass.
- **Mobile screen:** the design frame (Figma node or design file); every state (loading, empty, error, success as they apply); 375×667 and 430×932 at text scale 1.0 and 2.0; keyboard handling for forms; goldens; `flutter analyze` and `flutter test` pass.
- **Mobile mock:** `Fake<Feature>RemoteDataSource` with fixtures equal to the examples, checked in `test/contract`; a screenshot with `API_MODE=mock`; the Integration row `Not verified: backend not merged`.
- **Mobile integration:** the app against the local backend, one success case and each documented error; the integration gate (the backend tasks closed and their endpoints in `docs/api/openapi.json` on `develop`).
- **Docs and tooling:** the diff limited to the listed files; the `Stop` hook checks pass.
- **Every task:** the Evidence section ([`.claude/workflow/evidence.md`](../../workflow/evidence.md)).

### The table

- "Issues to create" keeps one row per task, in the same order and with the same numbers.
- **Its "Acceptance criteria" column is the task's Acceptance criteria, word for word**, items joined with `<br>` (not its Verification). `/approve-plan` checks the two against each other and copies the issue's criteria from the table, so they must not drift. Write the task first, then copy its criteria.
- Labels: the type label (`backend`, `frontend`, `docs`, `chore`), `mock` or `integration` for mobile pairs, and `area:<area>`.
- "Depends on" uses the task numbers and names the same tasks as the task's Dependencies; `/approve-plan` replaces them with issue numbers.

## Review the breakdown

Run this review before you publish a draft or return one, and again after every change to the task breakdown. It is the "Verification" list of `agent-skills:planning-and-task-breakdown` plus the repo's rules. Fix every item that fails before publishing.

- [ ] Every task has Acceptance criteria (behaviour, 3 items as the target, at most 5) and Verification
- [ ] Dependencies are in the right order: each is a lower-numbered task, in the same or an earlier phase, and no task depends on a task it does not need (shared groundwork is split out)
- [ ] No task is L or larger, except the first task of a new backend module, which says why
- [ ] No task title has "and"
- [ ] There is a checkpoint after every phase
- [ ] Each backend task has exactly one route
- [ ] Every task that is high risk (see Description) says "High risk" in its Description
- [ ] The table matches the tasks: same titles, Acceptance criteria word for word, and "Depends on" equal to each task's Dependencies
