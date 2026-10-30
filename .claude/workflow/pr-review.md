# Verification gate, PR, review and merge (Phases 4 to 6)

Read this before you open a PR, review one, or merge one. It holds the full rules of Phases 4 to 6 and how to review a pull request. [`CLAUDE.md`](../../CLAUDE.md#workflow) keeps the gates in short form and the permission table; if this file and `CLAUDE.md` disagree, `CLAUDE.md` wins.

Every Claude workflow on GitHub reads `.claude/workflow/` from the PR's base branch (`develop`, or `main` for a release PR), never from the PR it runs on: the action restores `.claude/` and `CLAUDE.md` from the base branch before Claude starts ([plan 020](../../docs/plans/020-protect-workflow-rules.md)).

## Phase 4: Verification gate

Before opening a PR, confirm the points below. An issue without `## Verification` (the old format) keeps its required checks in its acceptance criteria and is checked as before.

1. **Acceptance criteria and Verification:** each acceptance criterion and each Verification item of the issue (when it has one) is met, and you can say how it was checked.
2. **Regression:** the full test suite passes.
3. **Security:** no leaked secrets, inputs are validated and authorization checks are in place. Every `security-guidance` finding in this branch's sessions is fixed or answered.
4. **Git diff:** `git diff develop...HEAD` contains only changes for this issue.
5. **Evidence:** the drafted `## Evidence` section covers each acceptance criterion and each Verification item of the issue (when it has one), with evidence or a `Not verified: <reason>` line ([`evidence.md`](evidence.md)).
6. **Local review:** once, after points 1 to 5 pass and before the first push of a branch for a PR (also the first push when rerunning a stopped issue), review the branch locally so the review on GitHub usually approves on the first try ([plan 036](../../docs/plans/036-local-review-before-push.md)). Skip it before the pushes of review fix rounds, and for plan PRs (`docs/plan-*`).
   - Run two reviewers in parallel on `git diff origin/develop...HEAD`, both report-only (no `--fix`): a fresh `code-reviewer` subagent, given the issue number and the plan path, reviewing by the five steps of [Reviewing pull requests](#reviewing-pull-requests); and `/code-review high <branch>`, with the level stated so it does not reuse the level typed last. `/code-review` diffs a branch against its upstream, so first check that `git rev-parse --abbrev-ref @{upstream}` prints `origin/develop`; if it prints anything else or fails (for example `origin/<branch>` on a rerun branch, or no upstream), run `git branch --set-upstream-to=origin/develop` first, and that the diff it reviews is not empty.
   - Fix every finding in one pass, or answer it in the drafted PR description when it is wrong or out of scope. Then run points 1 to 5 again. There is no second local review.
   - Record a "Local review" line in `## Evidence`: for each reviewer, the number of findings found, fixed and answered. The line is a record, not a merge condition; `claude-review` on GitHub stays the merge gate.
   - Where `/code-review` is not available (for example `@claude` on GitHub), or it cannot review the branch diff, run `code-reviewer` alone and write `Not verified: /code-review unavailable` (or the exact reason) in `## Evidence`, never a count of 0 findings.

## Phase 5: PR and review

1. When the user asks (running `/run-tasks` with the issue counts), push the branch and open a PR into `develop` using `.github/pull_request_template.md`, link the issue with `Closes #<id>`, and name the plan (`Plan: docs/plans/NNN-<short-name>.md`). Say where the work deviates from the plan, or write "No deviations".
2. The `claude-review.yml` workflow reviews each PR into `develop` when it opens, is marked ready for review or is reopened, and again when a collaborator comments `@claude review`. It runs the `code-reviewer` subagent, following [Reviewing pull requests](#reviewing-pull-requests), and posts one comment that later runs edit. New commits do not start a review: comment `@claude review` after the last push. Claude runs the `code-reviewer` subagent locally in the local review pass of Phase 4 (point 6), when the user asks, or when the workflow did not run: a PR from a fork, a draft, a missing secret, a failed workflow, or a PR into another branch. Each subagent's model is set in the `model:` line of `.claude/agents/<name>.md`; a hard task can override it for one call. Next to it, `claude-security-scan.yml` scans the same PRs for security issues against `.claude/claude-security-guidance.md` from `develop` ([plan 017](../../docs/plans/017-security-guidance-and-scan.md)). It skips docs-only PRs, posts its own single comment, and is advisory: it never fails on findings. Comment `@claude security` to scan again after the last push.
3. The user reviews the PR (under `/run-tasks`, `claude-review` and the merge conditions in its skill stand in for this).
4. Address the review comments, and fix or answer in the PR every high-severity finding in the `claude-security-scan` comment. Then repeat Phases 3 and 4.

## Phase 6: Merge and close

1. The user approves the PR (except under `/run-tasks`, see step 2).
2. Claude merges only after the user explicitly authorizes merging that PR. Approving a plan, or an earlier "go ahead", is not that authorization. There are two exceptions, each started by the user's own words: `/approve-plan <NNN>` merges the plan PR it approves; and `/run-tasks <issues>` merges the PR of each issue it names once every merge condition in [its skill](../skills/run-tasks/SKILL.md) holds. DECISIONS entries ride in that issue's PR, so they need no PR of their own ([plan 037](../../docs/plans/037-decisions-per-area.md)). Approving a plan never authorizes merging a PR for one of its issues.
3. Verify `develop` after the merge:
   - the PR shows as merged into `develop`;
   - the merge commit and diff on `develop` contain the change;
   - the relevant local checks pass again on `develop`, when feasible.
   - remind the user to mirror the merge to GitLab ([GitLab mirror](../../README.md#gitlab-mirror)).
4. Report the CI result: the `backend` and `mobile` runs for the merge commit on `develop` (`gh run list --branch develop --event push`). If a run failed or did not run, say so.
5. Close the issue if `Closes #<id>` did not close it.

## Reviewing pull requests

When asked to review a PR, walk these five steps in order and report findings under each step's heading. Write "No issues found" for a step with nothing to report. Don't skip ahead: a correctness problem matters more than a naming nit.

1. **Correctness:** does the change do what the linked issue asks? Check edge cases, error handling, and each acceptance criterion and each Verification item of the issue (when it has one). Check that the PR links its issue (`Closes #<id>`) and names its plan (`Plan: docs/plans/NNN-<short-name>.md`), and that it lists its deviations from the plan or says "No deviations".
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Compare the tests with the contract in `docs/api/` and with each acceptance criterion and each Verification item of the issue (when it has one), not only with the code, and flag an assertion that was changed to make a test pass. Do lint and tests pass, locally or in CI? Does the PR's `## Evidence` section cover each acceptance criterion and each Verification item of the issue (when it has one), or say `Not verified: <reason>`?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure in [`CLAUDE.md`](../../CLAUDE.md#architecture-rules)?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the PR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
