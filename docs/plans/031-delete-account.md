# Plan 031: Delete account

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 031"
Issues: #188, #189, #190, #191, #192
Draft: https://claude.ai/artifact/2W9eonAAPhrb43KZtphSMx, version 1793179291-78f6

## Context

Based on: [Figma `1:163` Account - Email](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-163) (reference layout) · plan 024 (Profile Settings) · `docs/api/auth.md` · [App Store Review Guideline 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#5.1.1) · `backend/DECISIONS.md` (plan 004, lock order)

The app lets people create an account, so the App Store (guideline 5.1.1(v)) and Google Play require a way to **delete the account inside the app**. Today the Profile tab (`mobile/lib/features/profile/presentation/pages/profile_page.dart`) has the Profile / Email / Password list and the **Sign out** button, but no way to delete. The backend has no delete endpoint either.

What the code check found:

- Every table that references `users.id` has `ON DELETE CASCADE`: `user_profiles`, `refresh_tokens`, `runs` (and with it `step_samples`), `daily_activity`. Deleting a `users` row deletes all of the user's data, including the steps and activity synced from Apple Health / Health Connect. **No migration is needed.**
- `login_attempts` stores the email and IP, and has **no** FK to the user.
- `AuthService.authenticate` already returns `401 invalid_token` ("The account no longer exists.") when the user is gone. Other devices sign out on their next request, because the refresh fails too.
- `AuthService._verify_current_password` already has the rate limit shared with sign in (`403 incorrect_password`, `429 rate_limited`), so it can be reused.

### Prerequisites

- **Before `/run-tasks`:** none. No new key, secret or device is needed.
- **Before submitting to Google Play (outside this plan):** Play Console requires a web link where people can ask to delete their account without the app. This plan does not do that part (see assumption 11).

### Decided by the user

- **Reason:** meet the App Store and Google Play requirements.
- **Delete for good right away**, with no grace period and no restore.
- **Confirm with the current password.**
- **Success** means passing App Review and few people deleting by mistake.
- **Direction D1:** a separate screen (not a dialog), saying clearly that data synced from Apple Health / Health Connect is deleted too, while the data on the phone is kept.
- **Endpoint:** `POST /api/v1/users/me/delete`.
- The Phase 2 assumptions are accepted: throttle shared with sign in, advisory lock per user, blocking the last admin.

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **There is no Figma frame for this screen.** The layout follows the Account - Email screen (`1:163`) and `AuthFormLayout`, as in the wireframe below. If you have a frame, send the node.
2. **The endpoint** is `POST /api/v1/users/me/delete`, body `{"current_password": "..."}`, returning `204` with no body. Not `DELETE` with a body, because that body has no standard meaning (RFC 9110) and proxies may drop it.
3. **Delete for good in one transaction**, through the existing cascade. No `deleted_at` column, no migration.
4. **`login_attempts`:** when the delete succeeds, the failed attempts of that email are deleted too, as when sign in succeeds. The rows by IP of other emails are kept, because they are a security log and expire with the 15-minute window.
5. **The last admin cannot delete themselves:** returns `409 last_admin`. The admin rows are locked (`FOR UPDATE`) before counting, so the last two admins cannot both delete at the same time.
6. **No extra confirmation dialog** after entering the password. The delete button is disabled until the password field has content.
7. **After the delete,** the app goes to the sign-in screen and shows the banner "Your account has been deleted."
8. **Other devices** get `401 invalid_token` at their next request, the refresh fails, and they show the existing "session expired" message, not a "deleted" message. Accepted.
9. **The data in Apple Health / Health Connect on the phone is not touched.** The app stops syncing because the session has ended. If plan 030 (health sync, still a draft) adds background sync, that sync must stop on `AuthUnauthenticated`.
10. **The area is `auth`**, because most of the code is in `features/auth` and `modules/auth`. The new row on the Profile tab is only a small change in `features/profile`.
11. **The web link for deleting the account for Google Play** is not part of this plan. It is a small separate plan, done before submitting Android.

## Approach

### Screen design

Wireframe (in the draft artifact): a screen titled **Delete Account** with a back button; the explanation text; a note box about Apple Health / Health Connect; a **Current Password** field; and a **Delete account** button at the bottom in the error color.

- **Profile tab:** add a **Delete account** row (text in `colorScheme.error`) under the Sign out button. Tapping it pushes `/profile/delete-account` on the root navigator: with a back button, without the tab bar.
- **Delete Account screen:** uses `AuthFormLayout` like the Change Email screen. Colors come from `Theme.of(context)`, spacing from `AppSpacing` / `AppRadius`.

**States**

- **Idle:** the button is disabled while the password field is empty.
- **Submitting:** the button shows a spinner, the field is locked.
- **Error:** `AuthBanner` shows the error `incorrect_password`, `rate_limited` (with the seconds to wait), `last_admin`, or a network error.
- **Success:** the router redirects to sign in, which shows the banner "Your account has been deleted."

**Copy (English, kept as is in the code)**

| Place | Text |
| --- | --- |
| Row on Profile, delete button | `Delete account` |
| Screen title | `Delete Account` |
| Explanation | `This permanently deletes your StrideQuest account: your profile, the challenges you joined, your runs, medals, and the steps and activity synced from Apple Health or Health Connect. This can't be undone.` |
| Health note | `Your data in Apple Health or Health Connect stays on your phone. We only delete our copy.` |
| Field | `Current Password` |
| `last_admin` error | `You're the only admin. Make another account an admin before deleting yours.` |
| Banner on sign in | `Your account has been deleted.` |

### Contract (`docs/api/auth.md`)

```text
POST /api/v1/users/me/delete
Authorization: Bearer <access token>
{ "current_password": "run4medals" }

204 No Content
```

- **Order of checks:** field rules (`422 validation_error`), rate limit (`429 rate_limited` with `Retry-After`), password (`403 incorrect_password`), last admin (`409 last_admin`). This is the order of `PUT /users/me/email` and `/password`, plus the admin step.
- A wrong password counts as a failed sign in (by email and IP), as on the two routes above.
- Token errors stay as they are: `401 token_expired` and `401 invalid_token`.
- New error code: `409 last_admin`.

### Backend (`backend/app/modules/auth/`)

- `router.py`: route `POST /me/delete` in `users_router`, `status_code=204`, using `CurrentUserDep`. The path has no user id, so a user can only delete themselves.
- `service.py`: add `AuthService.delete_account(user, data, ip)`, with these steps:
  1. `_verify_current_password` (the 429 and 403 steps);
  2. take the user's enrollment lock through **`RunsService.lock_user_enrollments(user_id)`**, a new public method wrapping `RunRepository.lock_user_enrollments`;
  3. take the refresh token lock (`lock_user_refresh_tokens`);
  4. if the user is an admin: lock the admin rows, count them, and if only one is left raise `LastAdminError` (409);
  5. `repository.delete_user(user_id)` (DELETE + `flush`);
  6. `clear_login_attempts(email)`;
  7. commit.
- **The lock order** is the enrollment advisory lock first, then the refresh token lock, then the row lock. This order matches `join` / `resume` (DECISIONS.md, plan 004), so a delete running at the same time as a join waits instead of deadlocking. No other flow holds both advisory locks, so no wait cycle is created.
- **Cross-module calls:** auth calls runs **only through `RunsService`**, never runs' repository or models. `runs/service.py` does not import auth, so there is no import cycle. `RunsService` is passed into `AuthService` through `get_auth_service` in `auth/deps.py`.
- `LastAdminError` is a typed domain exception, mapped to `ErrorResponse` by the global handler.
- No new model, no migration.

### Mobile

- `features/auth/domain/repositories/auth_repository.dart`: add `Future<void> deleteAccount({required String currentPassword})` and `Stream<void> get accountDeleted`.
- `features/auth/data/`: the remote data source calls `POST /users/me/delete`. The repository impl clears the local session (`AuthLocalDataSource`) and then emits `accountDeleted`. `FakeAuthRemoteDataSource` succeeds when the password equals the fixture and returns `incorrect_password` when it is wrong.
- `AuthFailureCode.lastAdmin('last_admin', ...)`.
- `AuthBloc` listens to `accountDeleted` and moves to `AuthUnauthenticated(accountDeleted: true)`. The existing router redirect takes the user to sign in, and `SignInPage` shows the banner. `DeleteAccountBloc` does not touch `AuthBloc`.
- `features/auth/presentation/`: `DeleteAccountBloc` (registered with `registerFactory`, created in the route's `BlocProvider`) and `pages/delete_account_page.dart` (`static const path = '/profile/delete-account'`). Add the route to `core/router/app_router.dart`.
- `features/profile/presentation/pages/profile_page.dart`: add the Delete account row.

### Changes the approval must cover (Phase 2)

| Kind | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | Yes, not breaking | Adds the endpoint `POST /api/v1/users/me/delete` and the error code `last_admin`. |
| Schema / migration that loses data | No | No schema change. Only the existing cascade is used. |
| Auth / security boundary | **Yes** | A destructive route that needs the password, shares the sign-in rate limit, and acts only on the caller. |
| Architecture | **Yes** | The first time the `auth` module calls `runs` (through `RunsService`), to keep the lock order. |
| Real data / production / cost | **Yes** | Permanently deletes a user's real data in production. No extra cost. |

## Risks

- **Deleting the wrong user:** the route takes no id and uses only `CurrentUserDep`. An integration test checks that another user stays intact.
- **The route used to guess passwords:** it shares the sign-in rate limit. A test checks that the 6th wrong attempt gets `429`, even with the right password.
- **Deadlock when running at the same time as join / resume:** keep the lock order in the Approach. A test runs both operations in parallel.
- **A half-done delete:** everything is in one transaction, and PostgreSQL does the cascade. A test counts 0 rows in each table after the delete.
- **Losing the admin:** the `last_admin` check, with the admin rows locked.
- **Data outside PostgreSQL later** (for example an avatar on Cloudinary): none today. A later avatar plan must extend the delete flow.
- **Users deleting by mistake:** they must enter the password, and the screen says clearly what will be lost. No undo, as you chose.

## Verification

- **Backend:** `ruff check .`, `ruff format --check .`, strict `mypy`, `pytest` (unit, and integration with `TEST_DATABASE_URL`), `pytest -m fuzz`, hurl `backend/hurl/auth.hurl` run against the local backend.
- **Mobile:** `flutter analyze`, `flutter test` (bloc, widget, golden, keyboard, contract), and screenshots with `--dart-define=API_MODE=mock`.
- **Integration:** run the app against the local backend, with one success case and each error in the contract (`403`, `409`, `429`, `422`).
- **Cannot be verified in this plan:** whether App Review actually accepts it. That shows when submitting.

## Ticket evidence

- **Task 1 (docs):** the sample request and response above, which become `docs/api/examples/auth/delete_account_request.json` and `error_last_admin.json`.
- **Task 2 (backend):** the sample request and response from task 1's contract.
- **Tasks 3, 4 and 5 (feature with UI):** no Figma frame. The reference is the Account - Email frame `1:163`, with the wireframe and the copy table above (assumption 1). The states and screen sizes are listed in the checklists.

## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order: 1 goes first. Then 2 and 3 run in parallel (both depend on 1). Task 4 comes after 3. Task 5 waits for 2, 3 and 4, and starts only when 2 is closed and the endpoint is in `docs/api/openapi.json` on `develop`. Task 2 has the highest risk (locks, rate limit, clean delete), so it is done early, in parallel with mobile.

**Checkpoints**

- **After task 2:** the integration tests for the locks, the rate limit and the clean delete pass, with the hurl output. You look at the backend PR before mobile connects to it.
- **After task 4:** you look at the mock screenshots and the copy. This is when changing words is still cheap, before the integration.
- **After task 5:** try it end to end on the simulator with two devices signed in. The plan is then done, but submitting Android still needs the web link (assumption 11).

| Task | Estimated scope |
| --- | --- |
| 1 | S: 4 docs and test files, about 80 lines |
| 2 | M: 6 code files, about 200 lines, plus tests, hurl and `openapi.json` |
| 3 | M: 8 files with small changes, about 150 lines |
| 4 | M: 5 files (bloc, page, router, DI, profile), about 250 lines |
| 5 | S: 1 to 2 files, plus tests |

### Task 1: `[auth] docs: delete account contract`

**Requirements**

- The contract for `POST /api/v1/users/me/delete` as in the Approach: body, `204`, the order of checks, the error codes, and the shared rate limit.
- State clearly what is deleted (profile, refresh tokens, runs and step samples, daily activity), how the email's `login_attempts` are handled, and that access tokens already issued get `401 invalid_token`.
- `docs/api/openapi.json` does not change yet, because that file goes with the backend task.

**Steps**

1. `docs/api/auth.md`: add a row to the Endpoints table, a section `## POST /api/v1/users/me/delete`, and a `409 last_admin` row to the Error codes table.
2. Add `docs/api/examples/auth/delete_account_request.json` and `docs/api/examples/auth/error_last_admin.json`.
3. Add `last_admin` to `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` in `backend/tests/api_docs.py`.
4. Run the backend docs and contract tests.

**Checklist**

- [ ] `docs/api/auth.md` has the `POST /api/v1/users/me/delete` row, section and the `409 last_admin` error code
- [ ] The section states the order of checks (422, 429, 403, 409), the shared sign-in rate limit, the deleted data and the `401 invalid_token` for tokens issued before
- [ ] `docs/api/examples/auth/delete_account_request.json` and `docs/api/examples/auth/error_last_admin.json` exist and match the section
- [ ] `last_admin` is in `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` in `backend/tests/api_docs.py`
- [ ] `docs/api/openapi.json` unchanged; `ruff`, `mypy` and the full `pytest` pass
- [ ] Evidence section filled in

### Task 2: `[auth] feat: POST /api/v1/users/me/delete (backend)`

**Requirements**

- Route and service exactly as in the Approach, including the lock order, the call to `RunsService` (not runs' repository), and the typed `LastAdminError`.
- The router does not touch the DB session. The repository only queries and `flush`es. The service commits.
- No migration.

**Steps**

1. `backend/app/modules/runs/service.py`: add `RunsService.lock_user_enrollments(user_id)`.
2. `backend/app/modules/auth/repository.py`: add `delete_user(user_id)` and a query that locks and counts the admins.
3. `backend/app/modules/auth/service.py`: add `LastAdminError` and `delete_account`. Change `auth/deps.py` to pass `RunsService` in.
4. `backend/app/modules/auth/router.py`: add the route in `users_router`, with `responses` for 403, 409, 422, 429.
5. Add it to `ROUTE_ACCESS` (`backend/tests/unit/test_auth_sweep.py`) with level `user`. Move `last_admin` from `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` to `AUTH_MODULE_ERROR_CODES`.
6. Unit tests in `backend/tests/unit/` and integration tests in `backend/tests/integration/test_auth_api.py`.
7. Update `backend/hurl/auth.hurl` and `docs/api/openapi.json`.

**Checklist**

- [ ] `POST /api/v1/users/me/delete` returns `204` as in `docs/api/auth.md`, with level `user` in `ROUTE_ACCESS`
- [ ] Unit tests: `403 incorrect_password`, `429 rate_limited`, `409 last_admin`, and success deletes the user and clears the email's login attempts
- [ ] Integration test: after `204` no rows of the user remain in `users`, `user_profiles`, `refresh_tokens`, `runs`, `step_samples` and `daily_activity`; another user's rows are untouched
- [ ] Integration test: the old access token gets `401 invalid_token` and the old refresh token is refused
- [ ] Integration test: a wrong password counts toward the sign-in rate limit, and the route answers `429` with `Retry-After` once the limit is reached, even with the right password
- [ ] Integration test: the only admin gets `409 last_admin`; with two admins, one can delete their account
- [ ] Integration test: a delete and a join of the same user running at once finish without `DeadlockDetectedError`
- [ ] The lock is taken through `RunsService.lock_user_enrollments`; auth imports no runs repository or model
- [ ] `last_admin` moved to `AUTH_MODULE_ERROR_CODES` and `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` is empty
- [ ] Auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/auth.hurl` covers the route, and its output is in the evidence
- [ ] `docs/api/openapi.json` updated
- [ ] `ruff check .`, `ruff format --check .`, `mypy` and the full `pytest` pass
- [ ] Evidence section filled in

### Task 3: `[auth] feat: delete account session handling (mobile, mock)`

**Requirements**

- Repository, data source and `AuthBloc` as in the Approach. This task does not build the delete screen yet.
- The repository clears the local session only after the backend returns `204`. On an error it clears nothing.
- `domain/` stays pure Dart. The banner uses the existing `AuthBanner`, with colors from the theme.

**Steps**

1. Domain: add `deleteAccount` and `accountDeleted` to `mobile/lib/features/auth/domain/repositories/auth_repository.dart`, and `AuthFailureCode.lastAdmin` to `domain/failures/auth_failure.dart`.
2. Data: add the new method to `auth_remote_data_source.dart`, `fake_auth_remote_data_source.dart` (fixtures taken from the examples) and `auth_repository_impl.dart`.
3. Presentation: `auth_bloc.dart` listens to `accountDeleted`; add `AuthUnauthenticated(accountDeleted:)` in `auth_state.dart`; add the banner in `sign_in_page.dart`.
4. Tests: repository impl test, bloc test for `AuthBloc`, page test and golden for the banner on sign in, and `test/contract`.

**Checklist**

- [ ] `AuthRepository.deleteAccount` and `accountDeleted` added; `domain/` imports no Flutter, Dio or storage
- [ ] `AuthRepositoryImpl.deleteAccount` clears the local session and then emits `accountDeleted`; on an error nothing is cleared
- [ ] `AuthFailureCode.lastAdmin` maps `last_admin`
- [ ] `AuthBloc` turns `accountDeleted` into `AuthUnauthenticated(accountDeleted: true)`, and the sign-in page shows "Your account has been deleted." (goldens at 375×667 and 430×932, text scale 1.0 and 2.0)
- [ ] `FakeAuthRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`
- [ ] Integration row `Not verified: backend not merged`; the `API_MODE=mock` screenshot comes with task 4, which adds the screen
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Evidence section filled in

### Task 4: `[auth] feat: delete account screen (mobile, mock)`

**Requirements**

- Screen, states and copy as in the Approach. The layout follows frame `1:163` and `AuthFormLayout`.
- `DeleteAccountBloc` is registered with `registerFactory` and created in the route's `BlocProvider`. It calls `AuthRepository.deleteAccount` (task 3) and does not touch `AuthBloc`.
- Colors and spacing come from the theme and `app_tokens.dart`, with no numeric values inline.

**Steps**

1. Add `mobile/lib/features/auth/presentation/bloc/delete_account_bloc.dart`, `delete_account_event.dart` and `delete_account_state.dart`.
2. Add `mobile/lib/features/auth/presentation/pages/delete_account_page.dart` (`path = '/profile/delete-account'`).
3. Add the route to `mobile/lib/core/router/app_router.dart`, register the DI, and add the Delete account row in `mobile/lib/features/profile/presentation/pages/profile_page.dart`.
4. Tests: bloc test for `DeleteAccountBloc`, page test, keyboard test, golden, and a flow test with the fake (Profile, delete, back to sign in with the banner).
5. Take screenshots with `API_MODE=mock`.

**Checklist**

- [ ] Profile tab shows a Delete account row that pushes `/profile/delete-account` with a back button and no tab bar
- [ ] The screen follows Figma `1:163` and the plan's wireframe and copy, including the Apple Health / Health Connect note
- [ ] States: idle (button disabled while the password is empty), submitting, error (`incorrect_password`, `rate_limited` with the wait, `last_admin`, network), success (redirect to sign in with "Your account has been deleted.")
- [ ] 375×667 and 430×932 at text scale 1.0 and 2.0; the keyboard does not cover the field or the button
- [ ] Goldens for the screen
- [ ] `DeleteAccountBloc` is a `registerFactory` created in the route's `BlocProvider` and does not use `AuthBloc`
- [ ] A flow test with the fake goes from the Profile tab through deletion to sign in with the banner
- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Evidence section filled in

### Task 5: `[auth] feat: delete account (mobile, integration)`

**Requirements**

- Run the app against the local backend. Fix any mismatch with the contract and map each error correctly.
- **Gate:** task 2 is closed and the endpoint is in `docs/api/openapi.json` on `develop`.

**Steps**

1. Run the local backend (`docker compose`) and run the app without `API_MODE=mock`.
2. Try one success case and each error in the contract. Fix `auth_remote_data_source.dart` if it does not match.
3. Add tests for the remote data source (`204` response, mapping of `403`, `409`, `422`, `429`).

**Checklist**

- [ ] The app against the local backend: one success case (the account is gone and the app shows sign in with the banner) and each documented error (`403 incorrect_password`, `409 last_admin`, `422 validation_error`, `429 rate_limited`)
- [ ] A second signed-in device is signed out at its next request
- [ ] Remote data source tests for `204` and each error code
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Evidence section filled in
- [ ] Integration gate: 2 is closed and its endpoint is in `openapi.json` on `develop`

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[auth] docs: delete account contract` | docs, area:auth | - [ ] `docs/api/auth.md` has the `POST /api/v1/users/me/delete` row, section and the `409 last_admin` error code<br>- [ ] The section states the order of checks (422, 429, 403, 409), the shared sign-in rate limit, the deleted data and the `401 invalid_token` for tokens issued before<br>- [ ] `docs/api/examples/auth/delete_account_request.json` and `docs/api/examples/auth/error_last_admin.json` exist and match the section<br>- [ ] `last_admin` is in `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` in `backend/tests/api_docs.py`<br>- [ ] `docs/api/openapi.json` unchanged; `ruff`, `mypy` and the full `pytest` pass<br>- [ ] Evidence section filled in | none |
| 2 | `[auth] feat: POST /api/v1/users/me/delete (backend)` | backend, area:auth | - [ ] `POST /api/v1/users/me/delete` returns `204` as in `docs/api/auth.md`, with level `user` in `ROUTE_ACCESS`<br>- [ ] Unit tests: `403 incorrect_password`, `429 rate_limited`, `409 last_admin`, and success deletes the user and clears the email's login attempts<br>- [ ] Integration test: after `204` no rows of the user remain in `users`, `user_profiles`, `refresh_tokens`, `runs`, `step_samples` and `daily_activity`; another user's rows are untouched<br>- [ ] Integration test: the old access token gets `401 invalid_token` and the old refresh token is refused<br>- [ ] Integration test: a wrong password counts toward the sign-in rate limit, and the route answers `429` with `Retry-After` once the limit is reached, even with the right password<br>- [ ] Integration test: the only admin gets `409 last_admin`; with two admins, one can delete their account<br>- [ ] Integration test: a delete and a join of the same user running at once finish without `DeadlockDetectedError`<br>- [ ] The lock is taken through `RunsService.lock_user_enrollments`; auth imports no runs repository or model<br>- [ ] `last_admin` moved to `AUTH_MODULE_ERROR_CODES` and `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` is empty<br>- [ ] Auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/auth.hurl` covers the route, and its output is in the evidence<br>- [ ] `docs/api/openapi.json` updated<br>- [ ] `ruff check .`, `ruff format --check .`, `mypy` and the full `pytest` pass<br>- [ ] Evidence section filled in | #188 |
| 3 | `[auth] feat: delete account session handling (mobile, mock)` | frontend, mock, area:auth | - [ ] `AuthRepository.deleteAccount` and `accountDeleted` added; `domain/` imports no Flutter, Dio or storage<br>- [ ] `AuthRepositoryImpl.deleteAccount` clears the local session and then emits `accountDeleted`; on an error nothing is cleared<br>- [ ] `AuthFailureCode.lastAdmin` maps `last_admin`<br>- [ ] `AuthBloc` turns `accountDeleted` into `AuthUnauthenticated(accountDeleted: true)`, and the sign-in page shows "Your account has been deleted." (goldens at 375×667 and 430×932, text scale 1.0 and 2.0)<br>- [ ] `FakeAuthRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`<br>- [ ] Integration row `Not verified: backend not merged`; the `API_MODE=mock` screenshot comes with task 4, which adds the screen<br>- [ ] `flutter analyze` and `flutter test` pass<br>- [ ] Evidence section filled in | #188 |
| 4 | `[auth] feat: delete account screen (mobile, mock)` | frontend, mock, area:auth | - [ ] Profile tab shows a Delete account row that pushes `/profile/delete-account` with a back button and no tab bar<br>- [ ] The screen follows Figma `1:163` and the plan's wireframe and copy, including the Apple Health / Health Connect note<br>- [ ] States: idle (button disabled while the password is empty), submitting, error (`incorrect_password`, `rate_limited` with the wait, `last_admin`, network), success (redirect to sign in with "Your account has been deleted.")<br>- [ ] 375×667 and 430×932 at text scale 1.0 and 2.0; the keyboard does not cover the field or the button<br>- [ ] Goldens for the screen<br>- [ ] `DeleteAccountBloc` is a `registerFactory` created in the route's `BlocProvider` and does not use `AuthBloc`<br>- [ ] A flow test with the fake goes from the Profile tab through deletion to sign in with the banner<br>- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`<br>- [ ] `flutter analyze` and `flutter test` pass<br>- [ ] Evidence section filled in | #190 |
| 5 | `[auth] feat: delete account (mobile, integration)` | frontend, integration, area:auth | - [ ] The app against the local backend: one success case (the account is gone and the app shows sign in with the banner) and each documented error (`403 incorrect_password`, `409 last_admin`, `422 validation_error`, `429 rate_limited`)<br>- [ ] A second signed-in device is signed out at its next request<br>- [ ] Remote data source tests for `204` and each error code<br>- [ ] `flutter analyze` and `flutter test` pass<br>- [ ] Evidence section filled in<br>- [ ] Integration gate: 2 is closed and its endpoint is in `openapi.json` on `develop` | #189, #190, #191 |
