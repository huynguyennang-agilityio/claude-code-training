# Plan 023: Task breakdown skill for plans

Status: draft
Approved: <YYYY-MM-DD; /approve-plan adds the user's words after the date>
Issues: <filled in after approval>

## Context

Today a plan lists its work only in the "Issues to create" table: a title, labels, acceptance criteria and dependencies per issue. The user wants every plan to break the work down further, as plan 022 now does ([`022-profile-settings.md`](022-profile-settings.md), "Task breakdown"):

- each task states its **requirements**, the **steps** to do it, and a concrete **checklist**;
- **each backend endpoint is its own task**, never several endpoints in one;
- the format is the same in every later session, so it lives in a skill and in the plan template, not in one conversation.

The user asked in chat (2026-10-26): "bạn có thể viết cụ thể trong plan cụ thể từng task như nào ..., kiểu task breakdown ấy, có yêu cầu, làm gì, và checklist cụ thể khi làm sẽ là gì, các API backend sẽ tách riêng, không làm chung 1 task, và hãy make skill này vào cho các session sau luôn".

## Open questions and assumptions

1. **Skill name:** `task-breakdown`, in `.claude/skills/task-breakdown/SKILL.md`. Claude may load it on its own (no `disable-model-invocation`), because it is guidance for writing a plan, not an action with side effects.
2. **"One endpoint per task" covers backend work only.** A backend task adds or changes exactly one route (one method and path). The first task of a new module also carries the module skeleton and its migration; a later endpoint that needs a schema change carries its own migration.
3. **Mobile tasks follow the endpoints.** A mobile flow that calls one endpoint keeps the mock and integration pair. The integration task depends only on the backend tasks of the endpoints that flow calls, so one late endpoint does not hold back every screen. Groundwork shared by several mobile tasks (a layout, routes) goes into its own task, so the tasks that use it can run in parallel.
4. **Docs-only and tooling plans** (like this one) use the same three parts per task, without the endpoint rule.
5. **The table stays the source for issues.** Each task's checklist is copied word for word into its row's "Acceptance criteria", as `/approve-plan` reads the table. Issue 2 changes `/approve-plan` to also copy the task's Requirements and Steps into the issue body, so an issue can be worked from GitHub alone.
6. **Old plans are not rewritten.** Plans 001 to 021 are records. Plan 022 already uses the format.

## Approach

Claude configuration and docs only. No app, API, schema or data change, and no cost.

### The format (what the skill teaches)

A plan gets a `## Task breakdown` section before `## Issues to create`:

````markdown
## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order: <which tasks can start at once, which wait, which run in parallel>.

### Task N: `[area] type: title`

**Requirements**

- What must be true when it is done, and the rules it follows (contract, architecture, security, design frame).

**Steps**

1. What to do, in order, naming the files or folders it touches.
2. ...
3. The tests to add.

**Checklist**

- [ ] Concrete, checkable items: behaviour, tests, evidence, lint and type checks.
````

Rules in the skill:

- **Backend:** one endpoint per task. The checklist names the route and its `ROUTE_ACCESS` level, the migration (up, down, up) when there is one, unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, the hurl file and its output, `docs/api/openapi.json` updated, `ruff`, `mypy` and the full `pytest`.
- **Contract first:** a `docs` task for `docs/api/` and its examples comes before the backend and mobile tasks that use it.
- **Mobile:** mock and integration tasks as in `.claude/workflow/plan.md`; the integration checklist ends with its gate. A screen task's checklist names the design frame, the states, both phone sizes and text scales, keyboard handling for forms, goldens and the `API_MODE=mock` screenshot.
- **Every task:** the build loop and an `## Evidence` section; the checklist is the table's acceptance criteria, word for word; `human-merge` on the Phase 2 risk categories.
- **Order line:** which tasks start at once, which run in parallel, which wait.
- **Size:** a task that would pass about 400 changed lines (not counting generated files, tests and fixtures) is split.

### Files

- New `.claude/skills/task-breakdown/SKILL.md`: the format, the rules above, and plan 022 as the worked example.
- `docs/plans/README.md`: the template gains the `## Task breakdown` section; the "Issues to create" rows say the acceptance criteria are the task's checklist.
- `.claude/workflow/plan.md`, Phase 1 step 2: the plan has a task breakdown made with the `task-breakdown` skill, and each backend endpoint is its own task.
- `.claude/agents/planner.md`: the Conventions section points to the skill instead of its own short task rules.
- `CLAUDE.md`: one line under "The rules that apply in every phase": plans break the work down with the `task-breakdown` skill, one backend endpoint per task.
- `.claude/skills/approve-plan/SKILL.md` (issue 2): the issue body template gains `## Requirements` and `## Steps`, copied from the task with the same number; a plan without a task breakdown keeps today's body.

### Touches the approval must cover

- **Claude configuration and the workflow rules** (`CLAUDE.md`, `.claude/workflow/plan.md`, a new skill, the planner agent, `/approve-plan`). On GitHub, the Claude workflows read `.claude/` and `CLAUDE.md` from `develop`, so the new rules apply to a PR only after this plan's PRs merge.
- `/approve-plan` creates issues and merges the plan PR. Issue 2 changes only the issue body it writes, not its checks or its merge. Because it edits a skill that merges, issue 2 carries `human-merge`.

## Risks

- **Plans get longer.** Mitigation: the steps are short and name files; the requirements say only what is not already in the contract or `CLAUDE.md`.
- **The checklist and the table drift apart.** Mitigation: the skill says the table row is the checklist copied word for word; `/approve-plan` (issue 2) stops when a task's checklist and its row differ.
- **Too many small backend tasks** for a module with many trivial routes. Mitigation: the rule is per endpoint by the user's choice; the order line shows which can run in parallel, and `/run-tasks` can take several at once.
- **The skill and `CLAUDE.md` disagree later.** The skill says `CLAUDE.md` wins and must be fixed, as the other skills do.

## Verification

- Issue 1: read the new skill, the template and `plan.md` together and check they say the same; ask Claude in a fresh session to write a small plan (for example a medals endpoint pair) and check it produces the breakdown with one backend endpoint per task. Paste the result in the evidence.
- Issue 2: run `/approve-plan` on a throwaway plan with a task breakdown on a test branch, with issues created in the repository and closed right after (the user decides whether that is acceptable; otherwise `Not verified` with a dry run that prints the bodies). Check a plan without a breakdown still gets today's body.
- The hook tests pass (`.claude/hooks/test-block-forbidden-command.sh`), since `.claude/` changes.

## Ticket evidence

Refactor / chore: scope and the behaviour that must stay unchanged are in Approach. `/approve-plan` keeps its checks, approval rules and merge exactly; only the body it writes changes.

## Task breakdown

One task is one issue. No backend endpoints in this plan.

Order: task 1 first; task 2 after it.

### Task 1: `[infra] chore: task-breakdown skill and plan template`

**Requirements**

- A session that writes a plan loads `task-breakdown` and produces the format in Approach.
- The skill, the template, `plan.md`, the planner agent and `CLAUDE.md` say the same thing; `CLAUDE.md` wins.

**Steps**

1. Write `.claude/skills/task-breakdown/SKILL.md` (frontmatter `name`, `description` that names when to use it).
2. Add the `## Task breakdown` section to the template in `docs/plans/README.md`.
3. Update Phase 1 step 2 in `.claude/workflow/plan.md`.
4. Replace the task rules in `.claude/agents/planner.md` Conventions with a pointer to the skill.
5. Add the one line to `CLAUDE.md`.
6. Try it in a fresh session and keep the output for the evidence.

**Checklist**

- [ ] `.claude/skills/task-breakdown/SKILL.md` describes Requirements, Steps and Checklist per task, one backend endpoint per task, the order line, the size limit, and links plan 022 as the example
- [ ] `docs/plans/README.md` template, `.claude/workflow/plan.md` step 2, `.claude/agents/planner.md` and `CLAUDE.md` point to the skill and agree with it
- [ ] A fresh session asked for a small plan produces a task breakdown with one backend endpoint per task; output in the evidence
- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes

### Task 2: `[infra] chore: /approve-plan copies the task breakdown into issues`

**Requirements**

- For a plan with a task breakdown, each issue body has `## Requirements`, `## Steps` and `## Acceptance criteria` from its task.
- A plan without a breakdown gets today's body. Nothing else in `/approve-plan` changes.

**Steps**

1. In step 4 of `.claude/skills/approve-plan/SKILL.md`, add the two sections to the body template, read from `### Task N` with the row's number.
2. In step 3, stop when a task's checklist differs from its row's acceptance criteria, naming the task.
3. Verify on a throwaway plan as in Verification.

**Checklist**

- [ ] Issue bodies from a plan with a task breakdown have `## Requirements`, `## Steps` and `## Acceptance criteria` copied from the task
- [ ] `/approve-plan` stops and names the task when a checklist and its table row differ
- [ ] A plan without a task breakdown gets today's body; approval, checks and merge are unchanged
- [ ] Evidence: the bodies from the throwaway plan, or `Not verified` with a dry run

## Issues to create

The acceptance criteria are each task's checklist above.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: task-breakdown skill and plan template` | chore, area:infra | - [ ] `.claude/skills/task-breakdown/SKILL.md` describes Requirements, Steps and Checklist per task, one backend endpoint per task, the order line, the size limit, and links plan 022 as the example<br>- [ ] `docs/plans/README.md` template, `.claude/workflow/plan.md` step 2, `.claude/agents/planner.md` and `CLAUDE.md` point to the skill and agree with it<br>- [ ] A fresh session asked for a small plan produces a task breakdown with one backend endpoint per task; output in the evidence<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes | none |
| 2 | `[infra] chore: /approve-plan copies the task breakdown into issues` | chore, area:infra, human-merge | - [ ] Issue bodies from a plan with a task breakdown have `## Requirements`, `## Steps` and `## Acceptance criteria` copied from the task<br>- [ ] `/approve-plan` stops and names the task when a checklist and its table row differ<br>- [ ] A plan without a task breakdown gets today's body; approval, checks and merge are unchanged<br>- [ ] Evidence: the bodies from the throwaway plan, or `Not verified` with a dry run | 1 |
