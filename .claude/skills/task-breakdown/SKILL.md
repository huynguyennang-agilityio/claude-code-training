---
name: task-breakdown
description: How to break a StrideQuest plan's work into tasks, one issue each, with Requirements, Steps and a Checklist, and one backend endpoint per task. Use when writing or changing a plan's "Task breakdown" and "Issues to create" sections in docs/plans/.
---

# Task breakdown

Every plan breaks its work into tasks before it lists the issues ([plan 023](../../../docs/plans/023-task-breakdown-skill.md)). One task is one issue. The worked example is [plan 022](../../../docs/plans/022-profile-settings.md) once it is on `develop` (until then, its branch `docs/plan-022-profile-settings`), "Task breakdown".

The rules of Phase 1 are in [`.claude/workflow/plan.md`](../../workflow/plan.md) and the template in [`docs/plans/README.md`](../../../docs/plans/README.md#template). If this file and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix this file.

## The section

Put `## Task breakdown` after "Ticket evidence" and before "Issues to create":

````markdown
## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order: <which tasks can start at once, which wait, which run in parallel>.

### Task N: `[area] type: title`

**Requirements**

- What must be true when it is done, and the rules it follows: the contract, the architecture rules, security, the design frame.

**Steps**

1. What to do, in order, naming the files or folders it touches.
2. The tests to add.

**Checklist**

- [ ] Concrete, checkable items: behaviour, tests, evidence, lint and type checks.
````

- **Requirements** say only what the contract, `CLAUDE.md` and the plan's Approach do not already say for this task, plus the rules a reviewer will check it against.
- **Steps** are short and ordered. Each names a file, folder or command, so a fresh subagent can follow them. The last steps are the tests and the evidence.
- **Checklist** items are things a reviewer can tick from the diff, the test output or the evidence. No "works well", no "clean code".
- The `### Task N` title is the issue title, and `N` is the row number in "Issues to create".

## Rules

### Splitting

- **Backend: one endpoint per task.** A backend task adds or changes exactly one route (one method and path). Never put two routes in one task, even when they share a schema.
  - The first task of a new module also carries the module skeleton (`backend/app/modules/<module>/`, mounting) and the migration that the route needs.
  - A later endpoint that needs a schema change carries its own migration.
  - Shared service code (a helper both routes use) goes in the first task that needs it; the second task depends on it and reuses it.
- **Contract first.** A `docs` task writes `docs/api/<module>.md` and `docs/api/examples/<module>/` before the backend and mobile tasks that use them.
- **Mobile.** A flow that calls an endpoint is a `(mobile, mock)` task and a `(mobile, integration)` task ([`.claude/workflow/plan.md`](../../workflow/plan.md#mobile-tasks-mock-and-integration)). The integration task depends on its mock task and only on the backend tasks of the endpoints that flow calls, so one late endpoint does not hold back every screen. A screen with no backend call is one task.
- **Shared groundwork** used by several mobile tasks (a layout, routes, a shared widget) is its own task, so the tasks that use it can run in parallel instead of waiting for each other.
- **Docs-only and tooling plans** use the same three parts per task, without the endpoint rule.
- **Size.** Split a task that would pass about 400 changed lines, not counting generated files, tests and fixtures. `/run-tasks` lists a larger PR in its report.

### Checklists

Every task's checklist covers what applies of these:

- **Backend:** the route as in the contract and its level in `ROUTE_ACCESS`; the migration with up, down, up (and `\d <table>`) when there is one; unit and integration tests; auth sweep; contract and OpenAPI snapshot tests; `pytest -m fuzz`; the hurl file and its output; `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass.
- **Mobile screen:** the design frame (Figma node or design file); every state (loading, empty, error, success as they apply); 375×667 and 430×932 at text scale 1.0 and 2.0; keyboard handling for forms; goldens; `flutter analyze` and `flutter test` pass.
- **Mobile mock:** `Fake<Feature>RemoteDataSource` with fixtures equal to the examples, checked in `test/contract`; a screenshot with `API_MODE=mock`; the Integration row `Not verified: backend not merged`.
- **Mobile integration:** the app against the local backend, one success case and each documented error; ends with its gate (the backend tasks closed and their endpoints in `docs/api/openapi.json` on `develop`).
- **Every task:** the evidence it needs ([`.claude/workflow/evidence.md`](../../workflow/evidence.md)).

### The table

- "Issues to create" keeps one row per task, in the same order and with the same numbers.
- **Its "Acceptance criteria" column is the task's checklist, word for word**, items joined with `<br>`. `/approve-plan` copies the issue from the table, so the two must not drift. Write the checklist first, then copy it.
- Labels: the type label (`backend`, `frontend`, `docs`, `chore`), `mock` or `integration` for mobile pairs, and `area:<area>`.
- "Depends on" uses the task numbers; `/approve-plan` replaces them with issue numbers.

### The order line

Under the section heading, one line says which tasks can start at once, which chains wait on each other (`2 → 3`), which run in parallel, and which integration tasks wait for which backend tasks.

## Check before you finish

- Every backend task has exactly one route.
- Every task has the three parts, and its checklist equals its row in the table.
- Every dependency points to an earlier task, and the order line matches the "Depends on" column.
- No task depends on a task it does not really need (shared groundwork is split out).
