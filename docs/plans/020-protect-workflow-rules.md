# Plan 020: Read the workflow procedures from develop in every Claude workflow

Status: approved
Approved: 2026-10-23, by the user in chat: "/approve-plan 020", then "chưa hiểu bạn hãy làm luôn cho tôi"
Issues: #99, #100

## Context

[Plan 019](019-area-autopilot.md) (issue #89, PR #96, merged 2026-10-23) moved the long procedures out of `CLAUDE.md` into `docs/workflow/{plan,implement,evidence,pr-review}.md`. `CLAUDE.md` keeps the permission table and the short gate of each phase, and wins on conflict.

PR #96 recorded a known risk, accepted until a follow-up plan: **`@claude` runs in `.github/workflows/claude.yml` read `docs/workflow/` from the checked-out PR branch, so a PR can edit the procedures its own `@claude` run follows.** For example, a PR could rewrite the evidence rules or the Phase 5 steps in `docs/workflow/pr-review.md`, then ask `@claude` to "finish the PR" under the weakened rules.

Why a step in `claude.yml` cannot fix it today (checked on the pinned `anthropics/claude-code-action` v1.0.244, `58985842b834ed26087302ba27d07bc24ca8697a`):

- In tag mode the action checks out the PR branch itself, after the job's own steps. Anything a job step writes into `docs/workflow/` before the action is overwritten.
- Before Claude starts, the action restores from the base branch only `SENSITIVE_PATHS` in `src/github/operations/restore-config.ts`: `.claude`, `.mcp.json`, `.claude.json`, `.gitmodules`, `.ripgreprc`, `CLAUDE.md`, `CLAUDE.local.md`, `.husky`. It deletes the PR's versions first (so paths the PR added and develop lacks are gone), copies the PR's versions to `.claude-pr/` (git-excluded, never executed) for review, and unstages the restore so it does not leak into commits.

What is already closed:

- `claude-review.yml` restores `docs/workflow/` from `develop` in a job step ("Use the review rules from develop"). That works there because the review checks out the PR head itself, before that step.
- `claude-security-scan.yml` no longer treats `docs/workflow/**` as docs-only, so a PR that changes the procedures is scanned.

This plan closes the remaining gap in `claude.yml` and, if possible, replaces the per-workflow fixes with one mechanism.

## Open questions and assumptions

1. **Which option (the user decides).** The options are compared under Approach. The recommendation is Option 1.
2. **Assumption: the action keeps restoring `.claude` as a whole.** The restore list is a constant in the pinned version, and the action pin changes only through a reviewed PR. A future action upgrade must keep `.claude` in `SENSITIVE_PATHS`; the upgrade PR checks it (Risks).
3. **Assumption: `.claude/workflow/` is not loaded automatically.** Claude Code loads `CLAUDE.md`, settings, agents, skills, commands, hooks and `.claude/rules/`; a `workflow/` folder is plain files read on demand, as `docs/workflow/` is today. The folder must not be `.claude/rules/`, which would load all four files into every session and undo the size saving of plan 019.
4. **Assumption: the procedures are still meant to change only through a reviewed PR into `develop`.** After the move, an `@claude` run on a PR sees `develop`'s procedures, not the PR's. A PR that changes a procedure is edited by hand or locally, as is already true for `CLAUDE.md`, skills and agents. If `@claude` stages its own edit to `.claude/`, the action's restore means it would edit `develop`'s copy (upstream "known limitation" in `restore-config.ts`). This is the intended trade-off.
5. **Local edits prompt.** Claude Code asks before editing files under `.claude/`, even in accept-edits mode. Changing a procedure locally will need one more approval than today. Assumed acceptable, since these files configure Claude.
6. **`docs/workflow.md` (the diagrams) stays in `docs/`.** It is a picture of the flow, not a procedure Claude follows step by step, and `CLAUDE.md` already wins over it. Moving it is out of scope.
7. **Old plans are not edited.** Plans 001 to 019 are records; their `docs/workflow/` links stay as written.

## Approach

Docs, Claude configuration and GitHub workflow files only. Nothing changes in the app, the API, the schema or the data, and no new secrets or costs.

**This plan touches a security boundary and needs the user's explicit approval for it** (Phase 2): it changes which version of the rules Claude follows on GitHub (`develop`'s instead of the PR's), and it changes or removes steps in `claude-review.yml` and `claude-security-scan.yml` that guard that boundary today.

### Options compared

| | Option 1: move to `.claude/workflow/` | Option 2: `develop` copy outside the tree, via `claude_args` | Option 3: back into `CLAUDE.md` | Option 4: accept the risk |
| --- | --- | --- | --- | --- |
| How | `git mv docs/workflow .claude/workflow`; update every reference | A step before the action writes `develop`'s `docs/workflow/` to a folder outside the workspace; `--add-dir <folder>` and `--append-system-prompt "Read the procedures from <folder>, not docs/workflow/"` | Undo the split of plan 019 | Keep PR #96's note |
| Closes the gap in `claude.yml` | Yes, by the action's own restore, enforced before Claude starts | Only by instruction: the PR's `docs/workflow/` is still in the tree, and `CLAUDE.md`, skills and agents link to it | Yes | No |
| Covers all three Claude workflows | Yes, with one mechanism; the review restore step and the scan exclusion become redundant and are removed | Needs its own copy in each workflow (the review keeps its step) | Yes | No |
| Change to `claude.yml` | None | Yes, and it cannot be tested on a PR: the Claude App issues its token only when `claude.yml` matches `develop`, so the first real test is after merge | None | None |
| Cost | About 40 mentions of `docs/workflow` in docs, skills, agents, README, the PR template and two workflows; procedures sit in a hidden folder | Workflow code to maintain in each Claude workflow; the instruction can be ignored or lost in a long run | `CLAUDE.md` grows back to about 7k tokens in every session | None now |
| Depends on | `.claude` staying in the action's restore list | The `--add-dir` and `--append-system-prompt` flags; the folder must not be under `_temp`, which the review denies to `Read` | Nothing | Collaborators noticing a PR that edits the procedures |

Rejected:

- **Option 2.** It leaves the PR's `docs/workflow/` in the working tree, next to links that point at it, and relies on a prompt to win over them. Blocking `Read(docs/workflow/**)` instead would also stop `@claude` from reading the PR's change when asked to work on it. It changes `claude.yml`, which cannot be tested before merge.
- **Option 3.** Reverses the goal of plan 019 (a smaller `CLAUDE.md` loaded every session).
- **Option 4.** The procedures include the evidence and review rules; a PR that can rewrite them for its own `@claude` run is the gap PR #96 promised to close.
- **Fork or upgrade the action to restore extra paths.** The pinned version has no setting for it; a fork is a new dependency to maintain.

### Recommendation: Option 1, in two issues

Two issues, so that the move PR is itself reviewed against procedures read from `develop`. If the move happened in one PR, that PR's `claude-review.yml` run would have neither the old folder (the PR deletes it) nor the new one (the action deletes `.claude/` paths absent on `develop`), and the review would run without `pr-review.md`.

**Issue 1: add `.claude/workflow/` as a copy.** Copy the four files to `.claude/workflow/` unchanged except for their relative links, which gain one level (`../plans/...` becomes `../../docs/plans/...`; `../../CLAUDE.md` and `../../README.md` stay). Nothing reads the copy yet. `docs/workflow/` stays the source until issue 2; a change to the procedures between the two merges is made in both copies.

**Issue 2: switch to `.claude/workflow/` and delete `docs/workflow/`.**

- `CLAUDE.md`: the Workflow intro, the Phases table and the rule lines link `.claude/workflow/...`. Add one sentence: Claude workflows on GitHub read `.claude/` and `CLAUDE.md` from `develop`, so a PR cannot change the rules its own runs follow.
- `.claude/agents/code-reviewer.md`: `.claude/workflow/` comes from `develop` with the rest of `.claude/`; the PR's version is under `.claude-pr/.claude/workflow/`. `planner.md`, `flutter-dev.md`, `.claude/skills/fastapi-module/SKILL.md`, `.claude/skills/flutter-feature/SKILL.md`: update the paths.
- `.github/workflows/claude-review.yml`: remove the "Use the review rules from develop" step; the prompt names `.claude/workflow/pr-review.md` and says the PR's version is under `.claude-pr/`.
- `.github/workflows/claude-security-scan.yml`: remove the `docs/workflow/` clause and its comment; `.claude/**` is already scanned.
- `.claude/workflow/pr-review.md`: the line about `claude-review.yml` reading `docs/workflow/` from `develop` becomes: every Claude workflow reads `.claude/workflow/` from `develop`, because the action restores `.claude/`.
- `README.md` (the Workflow paragraph and the security-scan row), `.github/pull_request_template.md`, `docs/plans/README.md` (three links), `docs/workflow.md`, `docs/architecture.md`, `docs/auth-screens.md`: update the paths and links.
- `git rm -r docs/workflow`.
- `.claude/workflow/plan.md`: no change to the rules.

`claude.yml` does not change.

## Risks

- **A future action upgrade drops `.claude` from its restore list.** The gap would reopen silently. Contained by the pin: an upgrade is a reviewed PR, and it must check that `SENSITIVE_PATHS` still contains `.claude`. Issue 2 records that check in the "CI and Claude on GitHub" section of `README.md` (not as a comment in `claude.yml`, which this plan leaves unchanged).
- **A missed reference.** A link to `docs/workflow/` would point at a deleted file. Contained by the `git grep` check under Verification, and by `claude-review.yml` reviewing issue 2's PR.
- **The two copies drift between the merges of issue 1 and issue 2.** Contained by doing issue 2 right after issue 1, and by issue 2's check that both copies match before `docs/workflow/` is deleted (`diff -r` after undoing the link change).
- **Procedures harder to find for humans** in a hidden folder. Contained by the links in `README.md` and `CLAUDE.md`.
- **`@claude` cannot usefully edit a procedure on a PR branch** (assumption 4). Intended; such PRs are edited by hand or locally.
- **The end-to-end check needs a throwaway PR and an `@claude` comment** (Verification), which only the user posts. If it is not done, the fix is unverified on GitHub and the report says so.

## Verification

- Issue 1: `diff` of each `.claude/workflow/*.md` against `docs/workflow/*.md` shows only the link changes; every relative link in `.claude/workflow/` resolves (a short script or manual check of each `](` target).
- Issue 2:
  - `git grep -n 'docs/workflow/'` outside `docs/plans/0*` returns nothing.
  - Every relative link changed by the PR resolves.
  - `claude-review.yml` on issue 2's own PR: the action log shows `Restoring .claude, ...`, and the review follows the five steps of `.claude/workflow/pr-review.md` (headings in the posted comment).
  - `claude-security-scan.yml`: the gate output for issue 2's PR is `ok=true` (it changes `.claude/**`).
- After issue 2 merges, end to end on GitHub (needs the user to post the comment; Claude's `gh` comments carry the user's name, but posting still needs the user's OK):
  1. A draft PR from a `test/...` branch that changes one line in `.claude/workflow/evidence.md` to a canary text.
  2. A collaborator comments `@claude quote the first rule line of .claude/workflow/evidence.md, and say whether .claude-pr/.claude/workflow/evidence.md differs`.
  3. Expected: `@claude` quotes `develop`'s line and reports the PR's canary only under `.claude-pr/`. The action log shows the restore.
  4. Close the PR without merging; the branch is deleted by the user (Claude never deletes branches).
- Not verifiable before merge: `claude.yml` behaviour on a PR (the App token is issued only for the `develop` version of the file). Option 1 does not change `claude.yml`, so the check above is a check of the action's restore, not of new workflow code.

## Ticket evidence

Both issues are chores. Required: scope and the behaviour that must stay unchanged.

- Scope: the files listed under Approach.
- Unchanged: the text of the four procedures (only links change); `CLAUDE.md`'s gates and permission table; `claude.yml`; who can start each Claude workflow and with which permissions.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| #99 | `[infra] chore: copy the workflow procedures to .claude/workflow` | chore, area:infra | - [ ] `.claude/workflow/{plan,implement,evidence,pr-review}.md` exist and differ from `docs/workflow/` only in relative links, which all resolve<br>- [ ] Nothing references `.claude/workflow/` yet; `docs/workflow/` is unchanged | none |
| #100 | `[infra] chore: read the workflow procedures from .claude/workflow and drop docs/workflow` | chore, area:infra | - [ ] Every reference listed in the plan's Approach points to `.claude/workflow/`; `git grep 'docs/workflow/'` outside `docs/plans/0*` is empty<br>- [ ] `.claude/workflow/` matches `docs/workflow/` (apart from links) before `docs/workflow/` is removed<br>- [ ] `claude-review.yml` has no restore step for the procedures and its prompt names `.claude/workflow/pr-review.md` and `.claude-pr/`; `code-reviewer.md` says the same<br>- [ ] `claude-security-scan.yml` has no `docs/workflow/` clause<br>- [ ] `CLAUDE.md` says Claude workflows on GitHub read `.claude/` and `CLAUDE.md` from `develop`; `README.md` notes that an action upgrade must keep `.claude` in the action's restore list<br>- [ ] `claude.yml` is unchanged<br>- [ ] Evidence: the review and scan of this PR; the end-to-end `@claude` check after merge, or `Not verified: <reason>` | #99 |
