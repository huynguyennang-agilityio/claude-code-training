# Plan 040: Plan 030 fixes, the broad session_replaced rule and a fixed clock in the challenges flow test

Status: approved
Approved: 2026-11-02, by the user in chat: "/approve-plan 040"
Issues: #270, #271
Draft: https://claude.ai/artifact/BEprBHS6sVo7EpgaAqNJwJ, version 1793589730-03b1

## Context

Areas: area:auth, area:challenges · 2 tasks.

Based on: [plan 030](https://claude.ai/artifact/LKcS1jRj4Mq8V1zwMVhTNC) (`docs/plans/030-health-sync-single-session.md`), [the run report of 2026-11-02](https://claude.ai/artifact/PSjeC5emKVks5naUcVatnh), [PR #267](https://github.com/huynguyennang-agilityio/claude-code-training/pull/267), [PR #268](https://github.com/huynguyennang-agilityio/claude-code-training/pull/268), issue #253.

The run `/run-tasks 250 251 252 253 254 255` of 2026-11-02 stopped all 6 issues, for two reasons:

- **Plan 030 contradicts itself.** Plan 030's Approach uses the check "the refresh token was revoked and `created_at < users.session_started_at`" to return `401 session_replaced`. But the criterion of task 4 (#253) promises `401 invalid_refresh_token` for an "unknown, expired, used or signed-out" token. That check cannot tell a token revoked by a newer sign-in from one that was used or signed out before a later sign-in. PR #267 (#250) documented the broad rule, and `claude-review` requested changes because the PR said "No deviations".
- **The required `mobile` check is red on `develop` since 2026-11-01.** The `challenge()` fixture ends on 2026-10-31. `challenges_flow_test.dart` opens `ChallengeDetailPage` through the router with the default `clock`, `DateTime.now`, so 3 joining tests fail. Every PR is blocked.

### Decided by the user

- Rule **(a)**: keep the broad rule that PR #267 documents, and reword task 4's criterion (2026-11-02, in chat: "Use rule (a): keep the broad session_replaced rule that PR #267 documents and reword task 4's criterion.").

## Open questions and assumptions

1. **The refresh rule (as in PR #267):** `401 session_replaced` when the refresh token was revoked and was issued before the account's latest sign-in (`RefreshToken.created_at < users.session_started_at`), whatever revoked it. `401 invalid_refresh_token` when the token is unknown, expired, or revoked with no sign-in since it was issued (used by a refresh, signed out, or revoked by a password change).
2. **An accepted consequence:** an old token that was used or signed out, sent again after a newer sign-in, gets `session_replaced` instead of `invalid_refresh_token`. Both codes are 401, and both clear the tokens and go to the Sign in screen. Only the message differs, and no new token is issued.
3. **Plan 030 on `develop` stays as it is** (an approved file is not edited, so its approval is not reset). Plan 040 replaces the `refresh` item of plan 030's Approach, its assumption 8 and task 4's criterion. Everywhere else, plan 030 remains the source.
4. **Issue #253 is replaced by a new issue** (task 2 below), because an issue's body is the spec a child session reads, and Claude does not edit issue bodies. After `/approve-plan 040`, #253 is to be closed with the comment `Superseded by #<task 2> (plan 040)`. By CLAUDE.md, closing needs the user's own authorization for #253. Issue #261 (`(mobile, integration)`) now depends on #253: that dependency is read as a dependency on the new issue, and `/approve-plan` writes a comment saying so on #261, so the integration gate does not open early when #253 is closed.
5. **PR #267 keeps its current content.** When #250 is rerun, the child edits the PR description: a deviation "rule follows plan 040, assumption 1" instead of "No deviations". No file on the branch needs to change.
6. **The clock fix is test-only:** no production behaviour changes. `ChallengeDetailPage` already has a `clock` parameter, so the test passes a fixed clock (or moves the fixture's dates relative to that clock). No date depends on the real time.
7. **Out of scope:** an automatic guard that catches every test reading the real clock against a fixture with fixed dates (the run's process lesson). That needs its own `area:infra` plan.

## Approach

- **Mobile test (task 1):** `mobile/test/features/challenges/presentation/challenges_flow_test.dart` builds the app with a fixed clock, passed to `ChallengeDetailPage` and `CountdownCard` through their existing `clock` parameter. How it is passed: through the test's route builder, or through a test-only override. The `challenge()` fixture can keep its old dates if the fixed clock is before `endsAt`. If a `clock` injection point has to be added to a route in `lib/`, its default stays `DateTime.now`.
- **Backend (task 2), replacing #253:** as plan 030 task 4, except for the rule:
  - `SessionReplacedError` (401 `session_replaced`) in `backend/app/modules/auth/service.py`, mapped to `ErrorResponse` by the global handler;
  - a query in `repository.py` that reads the revoked token with its owner's `session_started_at` (the repository only queries);
  - `refresh` raises `SessionReplacedError` when the token was revoked and `created_at < session_started_at`; every other case stays `InvalidRefreshTokenError`;
  - the error is added to the route's `responses` in `router.py`.

  Locking stays as it is now.
- **Contract:** add the `session_replaced` row to the "Error codes" table of `docs/api/auth.md`, and reword the `invalid_refresh_token` row ("unknown, expired, or revoked with no sign-in since it was issued") to match the refresh section that PR #267 wrote. Add `"session_replaced"` to `AUTH_MODULE_ERROR_CODES` and to the `produced` set of `test_auth_api.py`. Line 19 of `.claude/claude-security-guidance.md` ("a used, expired or revoked one fails with `invalid_refresh_token`") is changed to mention `session_replaced`.
- **No schema change** (`users.session_started_at` is added by #252). No new route.

### Changes the approval must cover (Phase 2 risk categories)

- **Public API:** the meaning of `session_replaced` and `invalid_refresh_token` on `POST /api/v1/auth/refresh` differs from plan 030 task 4. This is not a breaking change, because both are 401 and the app handles them the same way (only the message differs).
- **Auth / security boundary:** a used token sent again (possibly a stolen token) after a newer sign-in gets the message "signed in on another device". Security behaviour does not change: no token is issued, and there is no separate reuse detection. That was already the case before this plan.
- No schema, real data or cost is touched.

## Risks

- **The message hides token reuse.** This is the risk noted in assumption 2. Contained: that token is still refused. Reuse tracking can come later in its own plan if needed.
- **#261's integration gate opens early when #253 is closed.** Contained by the comment on #261 (assumption 4), and because the child session reads the new issue's state from the run's brief.
- **A fixed clock hides real time bugs.** Contained: the test only needs a moment inside the fixture's range; `format_test.dart` and the countdown tests already use fixed dates.

## Verification

- Task 1: `flutter test test/features/challenges/presentation/challenges_flow_test.dart` passes; the full `flutter test` and `flutter analyze` are clean; the `mobile` and `goldens` checks are green on the PR; the result does not change with the system clock after 2026-10-31 (which it already is).
- Task 2: integration tests for each case (a second sign-in → the old token returns `session_replaced`; a used or signed-out token with no newer sign-in → `invalid_refresh_token`; a used token followed by a newer sign-in → `session_replaced`; unknown/expired → `invalid_refresh_token`); unit tests for the service; contract tests, the auth sweep, the OpenAPI snapshot, `pytest -m fuzz`; the output of `backend/hurl/auth.hurl`.
- Not checkable here: behaviour on a real device (it belongs to plan 030's mobile tasks #260/#261).

## Ticket evidence

- Task 1 (bug): reproduce by running `flutter test test/features/challenges/presentation/challenges_flow_test.dart` on `develop`. Since 2026-11-01, 3 joining tests fail (CI logs of PR #267 and #268).
- Task 2 (backend feature): the contract is the refresh section of `docs/api/auth.md` on PR #267, with the example `docs/api/examples/auth/error_session_replaced.json`.

## Task breakdown

One task is one issue. Each backend endpoint is its own task.

### Phase 1: CI green again

#### Task 1: `[challenges] test: fixed clock in the challenges flow test (mobile)`

**Description:** Give `challenges_flow_test.dart` a fixed clock, so the joining tests do not depend on the real date. Pass the clock through the existing `clock` parameter of `ChallengeDetailPage` (through the test's route builder, or through an injection point whose default is `DateTime.now`). The dates of the `challenge()` fixture may move relative to that clock. No production behaviour changes.

**Acceptance criteria:**
- [ ] `challenges_flow_test.dart` runs every challenge with a fixed clock and passes no matter the real date (also with a system date after the fixture's `endsAt`)
- [ ] No test in `mobile/test/features/challenges/` reads `DateTime.now` for a challenge built from a fixture with fixed dates
- [ ] The default clock of `ChallengeDetailPage` in the app stays `DateTime.now`; no production behaviour changes
- [ ] `flutter analyze` and `flutter test` pass; the `mobile` and `goldens` checks are green on the PR

**Verification:**
- [ ] Tests pass: `flutter test` in `mobile/`
- [ ] Lint and type checks: `flutter analyze`
- [ ] Manual check: `git grep -n "DateTime.now" -- mobile/test/features/challenges/` finds no use next to a fixed-date fixture
- [ ] Evidence section filled in

**Dependencies:** None

**Files likely touched:**
- `mobile/test/features/challenges/presentation/challenges_flow_test.dart`
- `mobile/test/features/challenges/` fixture file holding `challenge()` (only if its dates move)
- `mobile/lib/core/router/` challenge detail route (only if a clock injection point is needed)
- `mobile/PROGRESS.md`

**Estimated scope:** XS: 1–3 files, about 30 lines

#### Checkpoint: CI green on `develop`
- [ ] The `mobile` check is green on `develop` after the merge
- [ ] Suggested batch: `/run-tasks <task 1>`
- [ ] The user reviews before phase 2 starts

### Phase 2: session_replaced by rule (a)

#### Task 2: `[auth] feat: session_replaced on POST /api/v1/auth/refresh, broad rule (backend)`

**Description:** Replaces #253 (plan 030 task 4), by the rule of assumption 1. **High risk**: touches auth and refresh tokens. Steps:

1. `SessionReplacedError` in `service.py`; a query in `repository.py` that reads the revoked token with its owner's `session_started_at`; `refresh` raises the error when `created_at < session_started_at`, every other case keeps `invalid_refresh_token`; locking stays as it is.
2. Add the error to the route's `responses` in `router.py`.
3. In the "Error codes" table of `docs/api/auth.md`: add the `session_replaced` row, reword the `invalid_refresh_token` row. Add the code to `AUTH_MODULE_ERROR_CODES` and to the `produced` set of `test_auth_api.py` (with the name of the test that produces it). Reword the refresh token line in `.claude/claude-security-guidance.md`.
4. Unit tests, integration tests, `backend/hurl/auth.hurl`, `docs/api/openapi.json`.

**Acceptance criteria:**
- [ ] `POST /api/v1/auth/refresh` returns `401 session_replaced` for a revoked refresh token issued before the account's latest sign-in (`created_at < users.session_started_at`), whatever revoked it, and `401 invalid_refresh_token` for an unknown or expired token, or one revoked with no sign-in since it was issued (used, signed out or revoked by a password change)
- [ ] The response body equals `docs/api/examples/auth/error_session_replaced.json` in shape; `session_replaced` is a row of the "Error codes" table in `docs/api/auth.md`, in `AUTH_MODULE_ERROR_CODES`, and in the `produced` set of `test_auth_api.py`; the `invalid_refresh_token` row and `.claude/claude-security-guidance.md` match the rule
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence
- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass

**Verification:**
- [ ] Tests pass: `.venv/bin/pytest` (unit and integration) and `.venv/bin/pytest -m fuzz` in `backend/`
- [ ] Lint and type checks: `ruff check .`, `ruff format --check .`, `mypy`
- [ ] Manual check: `hurl --test backend/hurl/auth.hurl` against the local backend; `git grep -n "invalid_refresh_token"` and `git grep -n "already revoked"` show no text that contradicts the rule in the files below
- [ ] Evidence section filled in

**Dependencies:** #250, #252

**Files likely touched:**
- `backend/app/modules/auth/service.py`, `repository.py`, `router.py`
- `docs/api/auth.md`, `docs/api/openapi.json`
- `backend/tests/api_docs.py`, `backend/tests/integration/test_auth_api.py`, `backend/tests/unit/` auth tests
- `backend/hurl/auth.hurl`
- `.claude/claude-security-guidance.md`
- `backend/PROGRESS.md`

Other files found by `git grep -n "invalid_refresh_token"` keep their text: `mobile/README.md`, `auth_token_handler.dart`, `auth_failure.dart` and their tests only map the code, and mobile handling of `session_replaced` belongs to plan 030's #260/#261. `docs/plans/002-*.md` and `030-*.md` are history.

**Estimated scope:** M: about 9 files, about 220 lines

#### Checkpoint: plan 030 rerun
- [ ] `/run-tasks 250 251 252 <task 2> 254 255` merged, `develop` checks green
- [ ] PR #267 records the deviation per plan 040 (assumption 5)
- [ ] #253 closed with a "Superseded" comment (when the user authorizes it)

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[challenges] test: fixed clock in the challenges flow test (mobile)` | frontend, area:challenges | - [ ] `challenges_flow_test.dart` runs every challenge with a fixed clock and passes no matter the real date (also with a system date after the fixture's `endsAt`)<br>- [ ] No test in `mobile/test/features/challenges/` reads `DateTime.now` for a challenge built from a fixture with fixed dates<br>- [ ] The default clock of `ChallengeDetailPage` in the app stays `DateTime.now`; no production behaviour changes<br>- [ ] `flutter analyze` and `flutter test` pass; the `mobile` and `goldens` checks are green on the PR | none |
| 2 | `[auth] feat: session_replaced on POST /api/v1/auth/refresh, broad rule (backend)` | backend, area:auth | - [ ] `POST /api/v1/auth/refresh` returns `401 session_replaced` for a revoked refresh token issued before the account's latest sign-in (`created_at < users.session_started_at`), whatever revoked it, and `401 invalid_refresh_token` for an unknown or expired token, or one revoked with no sign-in since it was issued (used, signed out or revoked by a password change)<br>- [ ] The response body equals `docs/api/examples/auth/error_session_replaced.json` in shape; `session_replaced` is a row of the "Error codes" table in `docs/api/auth.md`, in `AUTH_MODULE_ERROR_CODES`, and in the `produced` set of `test_auth_api.py`; the `invalid_refresh_token` row and `.claude/claude-security-guidance.md` match the rule<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence<br>- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass | #250, #252 |
