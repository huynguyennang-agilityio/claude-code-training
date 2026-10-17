## Summary

<!-- What does this MR change, and why? -->

## Linked issue

Closes #

## Evidence

<!-- For each acceptance criterion: the command run, request/response or screenshot, and the result.
     Redact tokens, passwords, Authorization headers, cookies and connection strings.
     Attach large logs and screenshots here instead of committing them.
     Rows to cover where they apply: screen quality (page tests, sizes, text scales, states), API contract (examples, openapi.json diff), authorization sweep and ownership tests.
     Write `Not verified: <reason>` for anything you couldn't check. See "Verification evidence" in CLAUDE.md. -->

## Review checklist

Review in this order. Tick an item only after checking it.

- [ ] **Correctness:** the change does what the issue asks and handles edge cases and errors.
- [ ] **Tests:** new logic has tests, and lint and tests pass locally.
- [ ] **Readability:** clear names, short functions, no duplicated code.
- [ ] **Security basics:** no leaked secrets, input is validated, authorization is checked.
- [ ] **Scope:** this MR covers exactly one issue with no unrelated changes.
