---
name: plan-artifact
description: Write or update a StrideQuest draft plan as a Vietnamese artifact (a private claude.ai page) for the user to review, before anything reaches git or GitHub. Use when the user asks for work that needs a plan (Phase 1), or asks to change a draft plan that is still an artifact.
---

# Draft plans as artifacts

A draft plan is an **artifact**, not a file on a branch ([plan 023](../../../docs/plans/023-task-breakdown-skill.md)). The user reads and comments on it in chat; nothing reaches git or GitHub until they run `/approve-plan <NNN>`, which turns the approved artifact into `docs/plans/NNN-<name>.md` in English, opens and merges the plan PR, and creates the issues.

The rules of Phase 1 are in [`.claude/workflow/plan.md`](../../workflow/plan.md); the plan template is in [`docs/plans/README.md`](../../../docs/plans/README.md#template). If this file and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix this file.

## When not to use it

Write the plan the old way (a file on a `docs/plan-NNN-<name>` branch with its own PR, `.claude/workflow/plan.md`) when:

- the session has no Artifact tool (for example `@claude` on GitHub);
- the plan already exists as an open plan PR (a plan written before this skill, like plan 022): keep editing that file.

The planner subagent has no Artifact tool either, but it does **not** use the old way for a new plan: it returns the draft text to the main session, which publishes it with this skill (`.claude/agents/planner.md`).

## Before you write

1. Classify the ticket and check its evidence (`.claude/workflow/plan.md`, ticket evidence gate). Ask for what is missing; don't guess.
2. Ask the user the decisions that change the plan (with the question tool when there are several), before writing it.
3. Take the **number**: the highest `NNN` of `docs/plans/` on `develop` and of the open `docs/plan-*` branches (`git ls-remote --heads origin 'docs/plan-*'`), plus one. `/approve-plan` checks it again.

## What goes in it

- **Language:** Vietnamese, because `CLAUDE.md` says to explain things to the user in Vietnamese. Keep in English, unchanged, everything that will be copied into code or GitHub: file paths, code names, routes, error codes, labels, branch names, and the **issue titles** (`[area] type: ...`).
- **Title:** `Plan NNN: <title>` as the page heading, and a short `<title>` such as `Plan NNN <short name>`.
- **Header:** a `Status: draft` badge, the area labels, the number of tasks, and the links it rests on (Figma nodes, issues, earlier plans).
- **Sections, in the template's order,** each heading in Vietnamese with the template's English section name next to it (for example "Rủi ro (Risks)"), so `/approve-plan` maps each one to its section. The draft is the whole plan, not a summary of a file: `/approve-plan` stops on a page that calls itself a summary or lacks a section. The sections: context (with "Decided by the user" when the user has answered questions), open questions and assumptions (numbered, so the user can answer "change 3"), approach, the changes the approval must cover (Phase 2 risk categories), risks, verification, ticket evidence, task breakdown, issues to create.
- **Task breakdown** with the [`task-breakdown`](../task-breakdown/SKILL.md) skill: per task Yêu cầu (Requirements), Làm gì (Steps) and Checklist, one backend endpoint per task, the order line. The checklist items are written so they translate one to one, with the same detail the English file needs (routes, error codes, file paths in full). The **"Issues to create" table is required**: one row per task with the English title, labels, the acceptance criteria (the task's checklist) and dependencies.
- **Design:** show the design it follows. For Figma, embed the frame screenshots (as `data:` images; the artifact cannot load remote images) with a link to each node.
- **Next step,** at the end: "Nếu đồng ý, chạy `/approve-plan NNN`", and that changes go through chat.

Never put in it: secrets, tokens, passwords, connection strings, real user data, or anything the user marked as private. The artifact is private, but the user may share it.

## Publishing and updating

- Follow the Artifact tool's page rules (the `artifact-design` guidance it loads): a plain, readable page; both themes; phone width.
- Publish once, give the user the link, and **stop**. Create no branch, file, commit, PR or issue.
- For each change the user asks for, edit the same file and publish to the **same link** (a new version). Say in one line what changed.
- Don't republish between asking for approval and the user's `/approve-plan`. `/approve-plan` takes the version that is live when it runs and stops when it is newer than the version you last showed the user (with its link or a "what changed" line) before the command. Republishing in reply to the user's change request, and saying what changed, is fine.
- Keep the artifact's source file in the session's scratchpad. `/approve-plan` reads the published version, not the file.

## After approval

`/approve-plan <NNN>` does the rest ([`.claude/skills/approve-plan/`](../approve-plan/SKILL.md)). Don't write the plan file, branch or PR yourself, and don't create issues outside it.
