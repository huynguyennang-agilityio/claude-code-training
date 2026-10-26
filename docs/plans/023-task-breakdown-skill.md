# Plan 023: Plan drafts as artifacts, and a task breakdown skill

Status: approved
Approved: 2026-10-26, by the user in chat: "/approve-plan 023"
Issues: #113, #114, #115

## Context

Two changes to Phase 1, both asked by the user in chat on 2026-10-26.

**1. Task breakdown.** Today a plan lists its work only in the "Issues to create" table. The user wants every plan to break the work into tasks, as plan 022 now does ([`022-profile-settings.md`](022-profile-settings.md), "Task breakdown"): each task has **requirements**, the **steps** to do it and a **checklist**; **each backend endpoint is its own task**; and the format holds in every later session, so it lives in a skill. The user's words: "bạn có thể viết cụ thể trong plan cụ thể từng task như nào ..., kiểu task breakdown ấy, có yêu cầu, làm gì, và checklist cụ thể khi làm sẽ là gì, các API backend sẽ tách riêng, không làm chung 1 task, và hãy make skill này vào cho các session sau luôn".

**2. Draft plans as artifacts.** Today a draft plan is a Markdown file on a `docs/plan-NNN-<name>` branch with its own PR, opened before the user has read it. The user reviewed plan 022 more easily as a Vietnamese artifact (a private claude.ai page) and wants that to be the draft: "giờ plan sẽ đưa ra artifact trước, sau khi approved thì mới chuyển artifact thành md, add vào như trước rồi chia task luôn". So:

- the draft is an artifact, written in Vietnamese, that Claude publishes and updates while the user reviews it;
- nothing reaches git or GitHub until the user approves;
- `/approve-plan <NNN>` then turns the approved artifact into `docs/plans/NNN-<name>.md` in English, opens the plan PR, creates the issues from the task breakdown and merges the plan PR, in one run as today.

## Open questions and assumptions

Each has the answer the plan assumes; say if one is wrong.

1. **Language.** The artifact is in Vietnamese, because `CLAUDE.md` says to explain things to the user in Vietnamese. The plan file, issues and PR stay in English, because `CLAUDE.md` says docs and issues are in English. Code names, paths, routes, error codes, labels and issue titles stay in English inside the artifact too, so they carry over unchanged.
2. **What the user approves** is the artifact **version** that is live when they run `/approve-plan <NNN>`. The skill records the artifact link and its version id in the plan file (`Draft:` line). Claude does not republish the artifact between asking for approval and running the skill. If the artifact changed after the user's last message about it, the skill stops and asks.
3. **The translation adds nothing.** The plan file says what the artifact says, in English, section for section. Checklist items are translated one to one, so their count and order match. Anything that needs new content is not done in the skill: it goes back to the artifact for a new review.
4. **The plan PR is still merged by `/approve-plan` without a separate review**, as today. The user does not review the English file before the merge; they can read it on `develop` afterwards, and a wrong translation is fixed through a docs PR. This is the main new risk (see Risks).
5. **Plan number.** The artifact title is `Plan NNN: <title>` with the next free number (the highest of `docs/plans/` on `develop` and the open `docs/plan-*` branches, plus one). `/approve-plan` checks it again; if the number was taken meanwhile, it uses the next free one and says so.
6. **Plans already open as PRs** (plan 022, and this plan) keep the old flow: `/approve-plan` still works on an open plan PR. The skill handles both cases.
7. **Where the Artifact tool is missing** (for example `@claude` on GitHub), a plan is written the old way, as a file on a plan branch with a PR, and approved as today.
8. **Approval on GitHub** (setting `Status: approved` and merging a plan PR by hand) stays possible for plans written the old way. An artifact draft is approved only in chat with `/approve-plan`.
9. **"One endpoint per task" covers backend work only.** A backend task adds or changes exactly one route (one method and path). The first task of a new module also carries the module skeleton and its migration. A mobile integration task depends only on the backend tasks of the endpoints it calls. Groundwork shared by several mobile tasks (a layout, routes) is its own task, so the tasks that use it can run in parallel. Docs-only and tooling plans use the same three parts per task, without the endpoint rule.
10. **Old plans are not rewritten.** Plans 001 to 021 are records.

## Approach

Claude configuration and docs only. No app, API, schema or data change, and no cost.

### The new Phase 1 flow

1. Classify the ticket and check its evidence (unchanged).
2. Write the plan as an **artifact** in Vietnamese, with the same sections as the template (context, open questions and assumptions, approach, risks, verification, ticket evidence, task breakdown, issues to create) and a `Status: draft` badge. Publish it, give the user the link, and stop. No branch, file, PR or issue yet.
3. The user comments in chat; Claude edits and republishes the same artifact (same link, new version).
4. The user runs `/approve-plan <NNN>`. The skill:
   1. finds the artifact of plan `<NNN>` in this session, or asks for its link;
   2. reads the live version and checks assumption 2;
   3. writes `docs/plans/NNN-<name>.md` in English from it, with `Status: approved`, the `Approved:` line with the user's words, and `Draft: <artifact link>, version <id>`;
   4. creates the branch `docs/plan-NNN-<name>` from `develop`, commits only that file, pushes, and opens the plan PR (body: the artifact link and version, and "approved in chat");
   5. creates the issues from the task breakdown, records their numbers in the file, and merges the plan PR after the required checks, as today.
5. Unchanged from here: issue branches only after the plan is on `develop`.

### The task breakdown (what the new skill teaches)

The plan gets a `## Task breakdown` section before `## Issues to create`:

````markdown
## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order: <which tasks can start at once, which wait, which run in parallel>.

### Task N: `[area] type: title`

**Requirements**

- What must be true when it is done, and the rules it follows (contract, architecture, security, design frame).

**Steps**

1. What to do, in order, naming the files or folders it touches.
2. The tests to add.

**Checklist**

- [ ] Concrete, checkable items: behaviour, tests, evidence, lint and type checks.
````

- **Backend:** one endpoint per task. The checklist names the route and its `ROUTE_ACCESS` level, the migration (up, down, up) when there is one, unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, the hurl file and its output, `docs/api/openapi.json` updated, `ruff`, `mypy` and the full `pytest`.
- **Contract first:** a `docs` task for `docs/api/` and its examples comes before the tasks that use it.
- **Mobile:** mock and integration tasks as in `.claude/workflow/plan.md`; the integration checklist ends with its gate. A screen task's checklist names the design frame, the states, both phone sizes and text scales, keyboard handling for forms, goldens and the `API_MODE=mock` screenshot.
- **Every task:** the build loop and an `## Evidence` section; the table's acceptance criteria are the task's checklist, word for word; `human-merge` on the Phase 2 risk categories.
- **Order line** and **size:** say which tasks start at once and which run in parallel; split a task that would pass about 400 changed lines (not counting generated files, tests and fixtures).

### Files

- New `.claude/skills/task-breakdown/SKILL.md`: the format and rules above, with plan 022 as the example.
- New `.claude/skills/plan-artifact/SKILL.md`: how to write and update a draft plan as an artifact (Vietnamese, the template's sections, the `Plan NNN` title, the `Status: draft` badge, the Figma frames or screenshots it shows, the next-step line with `/approve-plan <NNN>`), and what never goes in it (secrets, tokens, real user data).
- `CLAUDE.md`: the permission table row "Write a plan" becomes "Publish a draft plan as an artifact" (yes, when the user asks for work that needs a plan); the row for the plan branch and PR says they are created by `/approve-plan` (or the old way where the Artifact tool is missing); the Phase 1 gate and "Plans" rule say the draft is an artifact and point to both skills; one line says plans break the work down with `task-breakdown`, one backend endpoint per task.
- `.claude/workflow/plan.md`: Phase 1 steps rewritten as in "The new Phase 1 flow", with the old flow kept for assumptions 6 to 8.
- `docs/plans/README.md`: the flow and the template, with the `## Task breakdown` section and a `Draft:` line.
- `docs/workflow.md`: the Mermaid flow shows the artifact draft before `/approve-plan`; the out-of-date note on `diagrams/phase-flow.svg` is kept.
- `.claude/agents/planner.md`: points to both skills; it never publishes artifacts (it has no Artifact tool), so for a new plan it returns the draft text to the main session.
- `.claude/skills/approve-plan/SKILL.md`: the artifact path in "The new Phase 1 flow" step 4, next to the existing plan-PR path; issue bodies gain `## Requirements` and `## Steps` from the task breakdown; it stops when a task's checklist and its row differ.

### Touches the approval must cover

- **The workflow rules and Claude configuration** (`CLAUDE.md`, `.claude/workflow/plan.md`, two new skills, the planner agent, `/approve-plan`). On GitHub, the Claude workflows read `.claude/` and `CLAUDE.md` from `develop`, so the new rules apply only after these PRs merge.
- **What an approval covers changes**: the user approves a Vietnamese artifact, and the English plan file that the issues and later reviews rely on is written afterwards and merged without a separate review (assumption 4).
- **Plan content leaves the repository before approval**: drafts live as private artifacts on claude.ai, shared only if the user shares them. Plans hold no secrets today; the `plan-artifact` skill forbids them.
- `/approve-plan` creates issues, opens a PR and merges it. Tasks 2 and 3 change it and carry `human-merge`.

## Risks

- **The English file differs from the approved artifact** (a wrong or loose translation), and issues are made from it. Mitigation: the skill translates section for section and adds nothing, keeps code names unchanged, checks that each task's checklist has the same number of items as in the artifact, links the artifact version in the file and the PR, and reports the PR link so the user can read the file; a mistake is fixed by a docs PR before work on the issue starts.
- **The user approves an older version than they think.** Mitigation: assumption 2; the skill names the version it used.
- **A draft is lost** (artifact deleted, session gone). Mitigation: the artifact stays in the user's gallery; `/approve-plan` asks for the link when it is not in the session.
- **No artifact on GitHub.** Mitigation: assumption 7, the old flow.
- **Plans get longer, and the checklist and the table drift apart.** Mitigation: short steps that name files; `/approve-plan` stops when they differ.
- **Too many small backend tasks** for a module with many trivial routes. Accepted by the user's choice; the order line shows what runs in parallel.

## Verification

- Task 1: in a fresh session, ask for a small plan (for example a medals endpoint pair) and check the breakdown has one backend endpoint per task. Paste the result in the evidence.
- Task 2: read `CLAUDE.md`, `.claude/workflow/plan.md`, `docs/plans/README.md`, `docs/workflow.md`, the planner agent and both skills together and check they describe the same flow; in a fresh session, ask for a plan and check Claude publishes an artifact and creates no branch, file or PR.
- Task 3: on a throwaway plan, run `/approve-plan` from an artifact and check the file (English, `Draft:` line, `Status: approved`), the PR, the issue bodies (Requirements, Steps, Acceptance criteria) and the merge; then close the throwaway issues and revert the throwaway plan with a docs PR. If the user does not want throwaway issues in the repository, `Not verified` with a dry run that prints the file and the issue bodies. Check that an old-style plan PR (plan 022) still goes through.
- `.claude/hooks/test-block-forbidden-command.sh` passes after each task, since `.claude/` changes.

## Ticket evidence

Refactor / chore: scope and the behaviour that must stay unchanged are in Approach. `/approve-plan` keeps its approval rule (only the user's own command or message), its checks and its merge rules; it gains a second input (an artifact) and richer issue bodies.

## Task breakdown

One task is one issue. No backend endpoints in this plan.

Order: task 1 first; task 2 after it; task 3 after task 2.

### Task 1: `[infra] chore: task-breakdown skill and plan template`

**Requirements**

- A session that writes a plan loads `task-breakdown` and produces the format in Approach.
- The skill, the template, `plan.md`, the planner agent and `CLAUDE.md` agree; `CLAUDE.md` wins.

**Steps**

1. Write `.claude/skills/task-breakdown/SKILL.md` (frontmatter `name`, and a `description` that says when to use it).
2. Add the `## Task breakdown` section to the template in `docs/plans/README.md`.
3. Update Phase 1 step 2 in `.claude/workflow/plan.md`.
4. Point `.claude/agents/planner.md` Conventions to the skill instead of its own task rules.
5. Add the one line to `CLAUDE.md`.
6. Try it in a fresh session and keep the output for the evidence.

**Checklist**

- [ ] `.claude/skills/task-breakdown/SKILL.md` describes Requirements, Steps and Checklist per task, one backend endpoint per task, the order line, the size limit, and links plan 022 as the example
- [ ] `docs/plans/README.md` template, `.claude/workflow/plan.md` step 2, `.claude/agents/planner.md` and `CLAUDE.md` point to the skill and agree with it
- [ ] A fresh session asked for a small plan produces a task breakdown with one backend endpoint per task; output in the evidence
- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes

### Task 2: `[infra] chore: draft plans as artifacts`

**Requirements**

- The rules say a draft plan is a Vietnamese artifact and nothing reaches git or GitHub before approval; the old flow stays for open plan PRs, for GitHub, and where the Artifact tool is missing (assumptions 6 to 8).
- `CLAUDE.md`, `plan.md`, `docs/plans/README.md`, `docs/workflow.md`, the planner agent and the new skill describe the same flow.

**Steps**

1. Write `.claude/skills/plan-artifact/SKILL.md`: sections, language, title and number, `Status: draft` badge, design frames, next-step line, what never goes in it, and how to update the same artifact.
2. Update the permission table, the Phase 1 gate and the "Plans" rule in `CLAUDE.md`.
3. Rewrite Phase 1 in `.claude/workflow/plan.md` and the flow in `docs/plans/README.md` (with the `Draft:` line in the template).
4. Update the Mermaid flow in `docs/workflow.md`.
5. Update `.claude/agents/planner.md` (returns draft text; never publishes).
6. Try it in a fresh session and keep the output for the evidence.

**Checklist**

- [ ] `.claude/skills/plan-artifact/SKILL.md` describes the Vietnamese draft artifact, its sections, title, number, badge, design frames, next-step line, and forbids secrets and real user data
- [ ] `CLAUDE.md` permission table, Phase 1 gate and "Plans" rule, `.claude/workflow/plan.md` Phase 1, `docs/plans/README.md`, `docs/workflow.md` and `.claude/agents/planner.md` describe the artifact-first flow and keep the old flow for open plan PRs, GitHub and sessions without the Artifact tool
- [ ] A fresh session asked for a plan publishes an artifact and creates no branch, file, PR or issue; output in the evidence
- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes

### Task 3: `[infra] chore: /approve-plan turns the approved artifact into the plan file and issues`

**Requirements**

- From an artifact: the skill writes the English plan file from the live version (assumptions 2 to 5), opens and merges the plan PR, and creates the issues, all in one run.
- From an open plan PR: unchanged, except the issue bodies.
- Issue bodies from a plan with a task breakdown have `## Requirements`, `## Steps` and `## Acceptance criteria`; the skill stops when a task's checklist and its row differ.
- The approval rule, the checks and the merge rules are unchanged.

**Steps**

1. Add the artifact path to `.claude/skills/approve-plan/SKILL.md`: find the artifact, read the live version, check it was not changed after the user's last message about it, check the plan number.
2. Write the file: translation rules (section for section, nothing added, code names unchanged, checklist counts equal), `Status: approved`, `Approved:` with the user's words, `Draft:` with the link and version.
3. Branch, commit only the file, push, open the plan PR with the artifact link and version in its body.
4. Extend the issue body template and the checklist-against-row check.
5. Keep the existing plan-PR path; merge and report as today, with the PR link so the user can read the file.
6. Verify on a throwaway plan as in Verification, and on plan 022's open PR path with a dry run.

**Checklist**

- [ ] `/approve-plan <NNN>` on an artifact draft writes `docs/plans/NNN-<name>.md` in English with `Status: approved`, the `Approved:` line and `Draft: <link>, version <id>`, opens the plan PR, creates the issues and merges, in one run
- [ ] It stops when the artifact changed after the user's last message about it, and takes the next free number when `<NNN>` is taken, saying so
- [ ] Issue bodies have `## Requirements`, `## Steps` and `## Acceptance criteria` from the task; it stops and names the task when a checklist and its row differ
- [ ] An open plan PR (the old flow) still goes through; approval rule, checks and merge are unchanged
- [ ] Evidence: the file, PR and issue bodies from the throwaway plan, or `Not verified` with a dry run

## Issues to create

The acceptance criteria are each task's checklist above.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| #113 | `[infra] chore: task-breakdown skill and plan template` | chore, area:infra | - [ ] `.claude/skills/task-breakdown/SKILL.md` describes Requirements, Steps and Checklist per task, one backend endpoint per task, the order line, the size limit, and links plan 022 as the example<br>- [ ] `docs/plans/README.md` template, `.claude/workflow/plan.md` step 2, `.claude/agents/planner.md` and `CLAUDE.md` point to the skill and agree with it<br>- [ ] A fresh session asked for a small plan produces a task breakdown with one backend endpoint per task; output in the evidence<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes | none |
| #114 | `[infra] chore: draft plans as artifacts` | chore, area:infra, human-merge | - [ ] `.claude/skills/plan-artifact/SKILL.md` describes the Vietnamese draft artifact, its sections, title, number, badge, design frames, next-step line, and forbids secrets and real user data<br>- [ ] `CLAUDE.md` permission table, Phase 1 gate and "Plans" rule, `.claude/workflow/plan.md` Phase 1, `docs/plans/README.md`, `docs/workflow.md` and `.claude/agents/planner.md` describe the artifact-first flow and keep the old flow for open plan PRs, GitHub and sessions without the Artifact tool<br>- [ ] A fresh session asked for a plan publishes an artifact and creates no branch, file, PR or issue; output in the evidence<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes | #113 |
| #115 | `[infra] chore: /approve-plan turns the approved artifact into the plan file and issues` | chore, area:infra, human-merge | - [ ] `/approve-plan <NNN>` on an artifact draft writes `docs/plans/NNN-<name>.md` in English with `Status: approved`, the `Approved:` line and `Draft: <link>, version <id>`, opens the plan PR, creates the issues and merges, in one run<br>- [ ] It stops when the artifact changed after the user's last message about it, and takes the next free number when `<NNN>` is taken, saying so<br>- [ ] Issue bodies have `## Requirements`, `## Steps` and `## Acceptance criteria` from the task; it stops and names the task when a checklist and its row differ<br>- [ ] An open plan PR (the old flow) still goes through; approval rule, checks and merge are unchanged<br>- [ ] Evidence: the file, PR and issue bodies from the throwaway plan, or `Not verified` with a dry run | #114 |
