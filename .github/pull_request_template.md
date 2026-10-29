## Summary

<!-- What does this PR change, and why? -->

## Linked issue

Closes #

## Plan

Plan: docs/plans/NNN-name.md

<!-- Where this PR deviates from the approved plan, or "No deviations". A deviation that adds an endpoint, a schema change, a dependency or scope needs the plan updated and approved again first. -->

## Evidence

<!-- For each acceptance criterion and each Verification item of the issue (when it has one): the command run, request/response or screenshot, and the result.
     Redact tokens, passwords, Authorization headers, cookies and connection strings.
     Attach large logs and screenshots here instead of committing them.
     Rows to cover where they apply: screen quality (page tests, sizes, text scales, states), API contract (examples, openapi.json diff), authorization sweep and ownership tests.
     Local review: one line giving, for code-reviewer and for /code-review high, the findings found, fixed and answered; when /code-review is unavailable, code-reviewer's counts and `Not verified: /code-review unavailable`. See Phase 4 point 6 in .claude/workflow/pr-review.md.
     Write `Not verified: <reason>` for anything you couldn't check. See .claude/workflow/evidence.md. -->

## Review checklist

Comment `@claude review` after your last push, before asking for a merge.

Review in this order. Tick an item only after checking it.

- [ ] **Correctness:** the change does what the issue asks and handles edge cases and errors.
- [ ] **Tests:** new logic has tests, and lint and tests pass locally.
- [ ] **Readability:** clear names, short functions, no duplicated code.
- [ ] **Security basics:** no leaked secrets, input is validated, authorization is checked.
- [ ] **Scope:** this PR covers exactly one issue with no unrelated changes.
