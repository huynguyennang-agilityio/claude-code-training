# Verification gate, PR, review and merge (Phases 4 to 6)

Read this before you open a PR, review one, or merge one. It holds the full rules of Phases 4 to 6 and how to review a pull request. [`CLAUDE.md`](../../CLAUDE.md#workflow) keeps the gates in short form and the permission table; if this file and `CLAUDE.md` disagree, `CLAUDE.md` wins.

The `claude-review.yml` workflow reads `docs/workflow/` from `develop`, never from the PR under review.

## Phase 4: Verification gate

Before opening a PR, confirm:

1. **Acceptance criteria:** each criterion is met, and you can say how it was checked.
2. **Regression:** the full test suite passes.
3. **Security:** no leaked secrets, inputs are validated and authorization checks are in place. Every `security-guidance` finding in this branch's sessions is fixed or answered.
4. **Git diff:** `git diff develop...HEAD` contains only changes for this issue.
5. **Evidence:** the drafted `## Evidence` section covers each acceptance criterion, with evidence or a `Not verified: <reason>` line ([`evidence.md`](evidence.md)).

## Phase 5: PR and review

1. When the user asks, push the branch and open a PR into `develop` using `.github/pull_request_template.md`, link the issue with `Closes #<id>`, and name the plan (`Plan: docs/plans/NNN-<short-name>.md`). Say where the work deviates from the plan, or write "No deviations".
2. The `claude-review.yml` workflow reviews each PR into `develop` when it opens, is marked ready for review or is reopened, and again when a collaborator comments `@claude review`. It runs the `code-reviewer` subagent, following [Reviewing pull requests](#reviewing-pull-requests), and posts one comment that later runs edit. New commits do not start a review: comment `@claude review` after the last push. Claude runs the `code-reviewer` subagent locally only when the user asks (for example before pushing), or when the workflow did not run: a PR from a fork, a draft, a missing secret, a failed workflow, or a PR into another branch. Each subagent's model is set in the `model:` line of `.claude/agents/<name>.md`; a hard task can override it for one call. Next to it, `claude-security-scan.yml` scans the same PRs for security issues against `.claude/claude-security-guidance.md` from `develop` ([plan 017](../../docs/plans/017-security-guidance-and-scan.md)). It skips docs-only PRs, posts its own single comment, and is advisory: it never fails on findings. Comment `@claude security` to scan again after the last push.
3. The user reviews the PR.
4. Address the review comments, and fix or answer in the PR every high-severity finding in the `claude-security-scan` comment. Then repeat Phases 3 and 4.

## Phase 6: Merge and close

1. The user approves the PR.
2. Claude merges only after the user explicitly authorizes merging that PR. Approving a plan, or an earlier "go ahead", is not that authorization.
3. Verify `develop` after the merge:
   - the PR shows as merged into `develop`;
   - the merge commit and diff on `develop` contain the change;
   - the relevant local checks pass again on `develop`, when feasible.
   - remind the user to mirror the merge to GitLab ([GitLab mirror](../../README.md#gitlab-mirror)).
4. Report the CI result: the `backend` and `mobile` runs for the merge commit on `develop` (`gh run list --branch develop --event push`). If a run failed or did not run, say so.
5. Close the issue if `Closes #<id>` did not close it.

## Reviewing pull requests

When asked to review a PR, walk these five steps in order and report findings under each step's heading. Write "No issues found" for a step with nothing to report. Don't skip ahead: a correctness problem matters more than a naming nit.

1. **Correctness:** does the change do what the linked issue asks? Check edge cases, error handling and the issue's acceptance criteria. Check that the PR links its issue (`Closes #<id>`) and names its plan (`Plan: docs/plans/NNN-<short-name>.md`), and that it lists its deviations from the plan or says "No deviations".
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Compare the tests with the contract in `docs/api/` and the issue's acceptance criteria, not only with the code, and flag an assertion that was changed to make a test pass. Do lint and tests pass, locally or in CI? Does the PR's `## Evidence` section cover each acceptance criterion of the linked issue, or say `Not verified: <reason>`?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure in [`CLAUDE.md`](../../CLAUDE.md#architecture-rules)?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the PR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
