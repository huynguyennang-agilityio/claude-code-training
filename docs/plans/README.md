# Plans

Every non-trivial change starts with a plan, before any issue, branch or code. The flow is in [`.claude/workflow/plan.md`](../../.claude/workflow/plan.md#phase-1-plan-approval-and-issues) and drawn in [`../workflow.md`](../workflow.md).

- **Draft:** a draft plan is a Vietnamese artifact (a private claude.ai page), written with the [`plan-artifact`](../../.claude/skills/plan-artifact/SKILL.md) skill ([plan 023](023-task-breakdown-skill.md)). Nothing reaches git or GitHub until the user runs `/approve-plan <NNN>`, which writes the file here in English, with a `Draft:` line naming the artifact link and version. Without the Artifact tool (for example `@claude` on GitHub), the draft is a file on its own branch and PR, as before.
- **Name:** `docs/plans/NNN-<short-name>.md`, where `NNN` is the next number (`001`, `002`, ...), counting the open `docs/plan-*` branches too.
- **Branch:** `docs/plan-NNN-<short-name>` from `develop`, with its own PR into `develop`, made by `/approve-plan` (or by hand in the old flow). A plan needs no issue.
- **Status:** the first line after the title is `Status: draft` or `Status: approved`. **Only the user approves a plan**: in chat, by running `/approve-plan <NNN>` (Claude cannot start it; a plain "plan 019 ok" gets a request to run the command), after which the skill writes `approved` with the date and their words, creates the issues and merges the plan PR; or on GitHub, by setting `approved` with the date and merging the PR. Claude never writes `approved` any other way. A plan edited after approval goes back to `draft`; recording its issue numbers, and merging `develop` into the plan branch without changing the plan file, are not edits.
- **Issues:** Claude creates issues only from an approved plan, exactly as the plan lists them, and writes the numbers into the `Issues:` line and the "Depends on" column. Through `/approve-plan` this happens in the plan PR itself, so one PR covers the plan, its approval and its issue numbers. A plan approved on GitHub gets its issues once it is on `develop`, with a separate docs PR for the numbers.
- **Issue titles and areas:** every issue title starts with its area, `[area] type: summary` (for example `[auth] feat: sign in (mobile, mock)`), and the issue carries the matching `area:<area>` label next to its other labels. Tools filter by the label (`gh issue list --label area:auth`), not by the title. The areas are below; a new one is added here through a plan ([plan 019](019-area-autopilot.md)).
- **Trivial changes** (a typo, a one-line fix) need no plan.
- **Task breakdown:** every plan breaks its work into tasks, one issue each, in the format of `agent-skills:planning-and-task-breakdown`: **Description**, **Acceptance criteria**, **Verification**, **Dependencies**, **Files likely touched** and **Estimated scope**, grouped in `### Phase N` sections that each end with a `#### Checkpoint`, no task of size L or larger, and **one backend endpoint per task**. The rules and the review to run before publishing are in the [`task-breakdown`](../../.claude/skills/task-breakdown/SKILL.md) skill ([plan 023](023-task-breakdown-skill.md), [plan 032](032-task-breakdown-format.md)); the table's acceptance criteria are each task's Acceptance criteria, word for word.
- **Mobile features that call an endpoint** are listed as two issues, `(mobile, mock)` and `(mobile, integration)`, as in the template below. The scope, evidence and the integration gate are in [`.claude/workflow/plan.md`](../../.claude/workflow/plan.md#mobile-tasks-mock-and-integration).

## Areas

An area matches a backend module (`backend/app/modules/`) or a mobile feature (`mobile/lib/features/`), so the tasks of one area touch the same code.

| Area | Label | Covers |
| --- | --- | --- |
| `auth` | `area:auth` | Sign in, sign up, sessions and tokens |
| `challenges` | `area:challenges` | Challenges and quests |
| `runs` | `area:runs` | Runs and workouts |
| `medals` | `area:medals` | Medals and rewards |
| `profile` | `area:profile` | The user's profile |
| `home` | `area:home` | The home screen |
| `health` | `area:health` | Apple Health and Health Connect data (`HealthRepository`), used by every workout type |
| `infra` | `area:infra` | CI, tooling, Claude configuration, chores and docs that belong to no feature |

A task that spans areas takes the area of the code it mostly changes.

## Template

Copy this into `docs/plans/NNN-<short-name>.md`.

````markdown
# Plan NNN: <title>

Status: draft
Approved: <YYYY-MM-DD; /approve-plan adds the user's words after the date>
Issues: <filled in after approval>
Draft: <artifact link, version id, filled in by /approve-plan; the author of a plan written as a file writes "none">

## Context

What is wanted, and why. Link the design, the request or the bug report.

## Open questions and assumptions

- Question or assumption, and who answers it.

## Approach

- Layers and files touched (mobile `lib/features/...`, backend `app/modules/...`).
- API and data contract changes (`docs/api/`), database tables and migrations.
- Say plainly if it touches: a public API or breaking contract, the schema, authentication or authorization, architecture or core technology, real data, production or cost. The approval must cover these.

## Risks

What could go wrong, and how it is contained.

## Verification

How each acceptance criterion will be checked (commands, requests, screens, devices), and what cannot be checked.

## Ticket evidence

What the ticket evidence gate in `.claude/workflow/plan.md` requires for each issue, and where it is (design link, sample request and response, reproduction steps).

## Task breakdown

One task is one issue. Each backend endpoint is its own task.

### Phase 1: <name>

#### Task 1: `[area] type: short title`

**Description:** What the task does, in the order of work, and the rules a reviewer checks it against.

**Acceptance criteria:**
- [ ] A specific, testable behaviour (3 items as the target, at most 5)

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

<one `### Phase N` per phase and one `#### Task N` per row below, made and reviewed with the `task-breakdown` skill>

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[area] type: short title` | frontend, area:<area> | - [ ] ... | none |
| 2 | `[area] docs: <module> contract` | docs, area:<area> | - [ ] `docs/api/<module>.md` and `docs/api/examples/<module>/` | none |
| 3 | `[area] feat: <METHOD> <path> (backend)` | backend, area:<area> | - [ ] The route answers as in `docs/api/<module>.md`: <the observable behaviour> | 2 |
| 4 | `[area] feat: <feature> (mobile, mock)` | frontend, mock, area:<area> | - [ ] <what the user sees and can do on the screen, with the fake> | 2 |
| 5 | `[area] feat: <feature> (mobile, integration)` | frontend, integration, area:<area> | - [ ] Against the local backend, <the main flow> works and each documented error shows its message | 3, 4 |
````
