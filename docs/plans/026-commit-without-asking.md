# Plan 026: Commit finished work without asking

Status: approved
Approved: 2026-10-27, by the user in chat: "/approve-plan 026"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/Ci8QQzLQxQfhzY2tyKzbDi, version 1793083437-6a54

## Context

On 2026-10-27, after the `quest_id` fix (commit `fe32d64`), the user asked: "sau này commit thì không cần hỏi tôi" (from now on, don't ask me before committing). `CLAUDE.md` currently says "Don't commit unless asked", and the permission table allows a commit "Only when the user asks". A local memory has recorded the new request, but the memory exists only on this machine. The Claude workflows on GitHub and other sessions read only `CLAUDE.md`, so the rule must change in that file for the two to match.

### Decided by the user

- Commit without asking (message of 2026-10-27).
- Write a small plan to change the Commit rule in `CLAUDE.md` to match the memory.

## Open questions and assumptions

1. **A hook that blocks commits on `develop`/`main`:** assumed *not* added in this plan. The current hook already blocks pushes to those two branches, so an accidental commit there cannot reach GitHub. To add it, reply "change 1".
2. **Scope:** only `git commit` is relaxed. Push, opening a PR, merging and closing an issue stay as in the current table.
3. **When to commit:** only when the task is finished and lint, type checks and tests all pass. Unfinished or failing work is not committed; report it to the user instead.
4. **Subagents** (`fastapi-backend`, `flutter-dev`) still don't commit. The main session commits after reading their results, the way `/run-tasks` already does.
5. **The plan gate does not change:** with no approved plan there is no code, so nothing to commit.

## Approach

Only docs and Claude configuration change. No backend or mobile code changes.

`CLAUDE.md`, Workflow, general rules:

```diff
- Don't commit unless asked. After each task, suggest a short commit message.
+ Commit a finished task without asking once lint, type checks and tests pass, on its own
+   branch, never on `develop` or `main`, and report the commit hash. Don't commit unfinished
+   or failing work; say what is left instead.
```

`CLAUDE.md`, Git and GitHub permissions:

```diff
- | Commit | Only when the user asks. Running `/approve-plan` counts for the plan PR, and running `/run-tasks` counts for the issues it names |
- | Push, open a PR | Only when the user asks or the task explicitly includes it. `/approve-plan` and `/run-tasks` count, as for Commit |
+ | Commit | Yes, for a finished task whose lint, type checks and tests pass, on a branch other than `develop`/`main`. `/approve-plan` commits the plan PR, and `/run-tasks` the issues it names |
+ | Push, open a PR | Only when the user asks or the task explicitly includes it. Running `/approve-plan` counts for the plan PR, and running `/run-tasks` counts for the issues it names |
```

`.claude/agents/fastapi-backend.md`, `.claude/agents/flutter-dev.md`:

```diff
- - **No commits unless explicitly asked.** When a task is done, stop and suggest a short commit message instead of committing.
+ - **Don't commit or push.** The main session commits your work once its checks pass. When a task is done, stop and suggest a short commit message.
```

The line "A grant such as … covers only the tasks or the session the user named" stays as it is: committing is now a standing rule, no longer a one-off grant.

After the merge, the `commit-without-asking` memory drops the sentence "CLAUDE.md still says…", since the two then match.

**Phase 2 items:** none. No public API, schema, auth or security boundary, architecture, real data, production or cost changes. This is a change to Claude's working rules (Phase 0).

## Risks

- **Committing something that should not be committed** (temp files, logs, secrets). Contained by `git add`-ing only the task's own files, never `git add -A`. The review hook on `git commit` (`.claude/workflow/implement.md`) still runs.
- **A commit on `develop`/`main`:** the rule forbids it. If one happens by mistake, the hook and the GitHub ruleset still block the push. See question 1.
- **The workflow on GitHub** (`claude.yml`) reads `CLAUDE.md` from `develop`. There a commit without a push has no effect, and a push still needs the user to ask, so the actual behavior on GitHub does not change.
- **The user wants to see the diff before the commit:** an unpushed commit can still be changed (`git commit --amend`, or a new commit), so the risk is low.

## Verification

- `grep -rn "Don't commit unless asked\|No commits unless explicitly asked" CLAUDE.md .claude/` finds nothing.
- Reread the permission table: the Push, PR, Merge and Never rows keep their meaning.
- `.claude/hooks/test-block-forbidden-command.sh` still passes (the hook does not change).
- Cannot be checked: whether the workflow on GitHub behaves correctly. That shows only after the merge, at the next `@claude` run.

## Ticket evidence

Type chore (Claude configuration). The gate requires the scope and the behavior that must stay unchanged. Scope: two lines in `CLAUDE.md` and one line in each subagent file. Unchanged: the push, PR, merge and issue-closing rules, the plan gate, and the Never actions.

## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order: one task, no dependencies.

### Task 1: `[infra] docs: commit finished work without asking`

**Requirements**

- Claude commits a finished task without asking when lint, type checks and tests all pass, on a branch other than `develop`/`main`, and reports the commit hash.
- Push, opening a PR, merging, closing an issue and the Never rows stay as they are.
- Subagents don't commit; the main session commits.

**Steps**

1. In `CLAUDE.md`, replace the line "Don't commit unless asked…" in Workflow and the Commit and Push rows of the "Git and GitHub permissions" table as in Approach.
2. In `.claude/agents/fastapi-backend.md` and `.claude/agents/flutter-dev.md`, replace the line "No commits unless explicitly asked" as in Approach.
3. Run the grep and `.claude/hooks/test-block-forbidden-command.sh` from Verification.
4. After the merge, update the `commit-without-asking` memory.

**Checklist**

- [ ] `CLAUDE.md` Workflow: Claude commits a finished task without asking once lint, type checks and tests pass, never on `develop`/`main`, and reports the commit hash
- [ ] `CLAUDE.md` permission table: the Commit row allows it; the Push/PR, Merge and Never rows keep their meaning
- [ ] `.claude/agents/fastapi-backend.md` and `.claude/agents/flutter-dev.md`: the subagent doesn't commit or push; the main session commits
- [ ] `grep -rn "Don't commit unless asked\|No commits unless explicitly asked" CLAUDE.md .claude/` finds nothing
- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] docs: commit finished work without asking` | docs, area:infra | - [ ] `CLAUDE.md` Workflow: Claude commits a finished task without asking once lint, type checks and tests pass, never on `develop`/`main`, and reports the commit hash<br>- [ ] `CLAUDE.md` permission table: the Commit row allows it; the Push/PR, Merge and Never rows keep their meaning<br>- [ ] `.claude/agents/fastapi-backend.md` and `.claude/agents/flutter-dev.md`: the subagent doesn't commit or push; the main session commits<br>- [ ] `grep -rn "Don't commit unless asked\|No commits unless explicitly asked" CLAUDE.md .claude/` finds nothing<br>- [ ] `.claude/hooks/test-block-forbidden-command.sh` passes | none |
