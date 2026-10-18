# Plans

Every non-trivial change starts with a plan file here, before any issue, branch or code. The flow is in [`CLAUDE.md`](../../CLAUDE.md#phase-1-plan-approval-and-issues) and drawn in [`../workflow.md`](../workflow.md).

- **Name:** `docs/plans/NNN-<short-name>.md`, where `NNN` is the next number (`001`, `002`, ...).
- **Branch:** `docs/plan-NNN-<short-name>` from `develop`, with its own MR into `develop`. A plan needs no issue.
- **Status:** the first line after the title is `Status: draft` or `Status: approved`. **Only the user sets `approved`**, with the date, and merges the plan MR. Claude never writes `approved`. A plan edited after approval goes back to `draft`.
- **Issues:** Claude creates issues only from a plan that is `approved` on `develop`, exactly as the plan lists them, and writes the numbers into the `Issues:` line.
- **Trivial changes** (a typo, a one-line fix) need no plan.

## Template

Copy this into `docs/plans/NNN-<short-name>.md`.

````markdown
# Plan NNN: <title>

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval, for example #61, #62>

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

What the ticket evidence gate in `CLAUDE.md` requires for each issue, and where it is (design link, sample request and response, reproduction steps).

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `type: short title` | frontend | - [ ] ... | none |
````
