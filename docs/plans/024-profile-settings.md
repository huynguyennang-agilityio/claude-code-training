# Plan 024: Profile Settings (profile info, email and password)

Status: approved
Approved: 2026-10-26, by the user in chat: "/approve-plan 024"
Issues: #120, #121, #122, #123, #124, #125, #126, #127, #128, #129, #130, #131
Draft: https://claude.ai/artifact/BFyp349KGBzXZzUQMsNSWE, version 1793022340-8008

## Context

The Profile tab is a placeholder: it shows the display name, the email and the **Sign out** button (`mobile/lib/features/profile/presentation/pages/profile_page.dart`). This plan builds the account settings of the **Profile Settings** group in Figma. Plan 022 (PR #111) described the same work in the old flow and was closed to be rewritten in the new flow; the content keeps the user's decisions.

| Frame | Node | Content |
| --- | --- | --- |
| Account - Profile | [`1:64`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-64) | The Profile tab: avatar, **Change Avatar**, a list with **Profile**, **Email**, **Password** |
| Account - Profile Info | [`1:100`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-100) | Form: First Name, Last Name, Birthday, Country, State, Gender, a **Units** switch (Imperial (US) / Metric), Height, Weight, **Save** |
| Account - Password | [`1:137`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-137) | Current Password, New Password, Confirm Password, **Forgot Password?**, **Save** |
| Account - Email | [`1:163`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-163) | An explanation, the email field, **Save** (disabled until the email changes) |

The draft shows a screenshot of each frame (the email value in the Email frame is masked). The three sub-screens have a back button and no tab bar.

### Decided by the user

- **Avatar is left for a later plan.** Uploading an avatar means a user (not an admin) uploads to Cloudinary, which [ADR 0003](../adr/0003-cloudinary-for-images.md) does not allow yet and which costs quota. The Profile tab shows the user's initials in the avatar circle and no **Change Avatar** button. A later plan, with an ADR, adds the upload.
- **Profile Info keeps every field of the design**, stored on the backend, all optional.
- **Changing the email needs the current password.** The Email screen gets a **Current Password** field that the Figma frame does not have. The change applies at once; there is no verification email (still out of scope for the MVP, `docs/api/auth.md`).
- **The password rule stays as the contract says**: 8 to 128 characters, with at least one letter and one digit. The Figma hint "at least 12 characters" becomes "At least 8 characters, with a letter and a digit".
- **Keyboard handling for the forms**, so the keyboard does not cover content (see "Approach").

## Open questions and assumptions

Each has the answer the plan assumes; name its number to change it.

1. **`display_name` stays as it is.** First name and last name are two new, optional profile fields; this plan does not edit `display_name` (set at sign up, used elsewhere) and does not derive it from them.
2. **Country** is an ISO 3166-1 alpha-2 code picked from a list shipped in the app. The backend checks only the format (`^[A-Z]{2}$`) and keeps no country list. **State** is free text of at most 100 characters, entered in a text field. A state picker per country is for later.
3. **Gender** is one of `female`, `male`, `non_binary`, `prefer_not_to_say`, or empty.
4. **Birthday** is picked with a date picker, after 1900-01-01 and not in the future. No minimum age is enforced.
5. **Height and weight are stored in metric** (`height_cm`, `weight_kg`, one decimal) whatever the switch says. **Units** (`imperial` or `metric`, default `metric`) is a preference stored with the profile; the app converts for display (feet and inches, pounds). Limits: height 50.0 to 272.0 cm, weight 20.0 to 400.0 kg.
6. **Save replaces the whole profile** (`PUT`): the form always sends every field, and an empty field clears its value.
7. **Changing the password signs out every other device.** Every refresh token of the user is revoked and the response carries a new token pair for the device in use. Access tokens already issued elsewhere keep working until they expire (15 minutes by default); there is no access-token deny list.
8. **Changing the email does not revoke sessions**, since the password does not change.
9. **A wrong current password counts as a failed sign-in** for the existing rate limit (by email and by IP, `LoginAttempt`), so these routes cannot be used to guess the password. Too many attempts answer `429 rate_limited` with `Retry-After`.
10. **Forgot Password?** is hidden: password reset by email is out of scope for the MVP.
11. **Sign out stays** on the Profile tab, as a row under the list (the Figma frame does not draw it, but the app needs it).
12. The Email frame says "Velocity Training"; the app says **StrideQuest**.

## Approach

### Contract (`docs/api/`)

- A new `docs/api/profile.md` with examples under `docs/api/examples/profile/`.
- `docs/api/auth.md` gains the two account routes, their examples under `docs/api/examples/auth/` and one new error code.

| Endpoint | Module | Auth | Purpose |
| --- | --- | --- | --- |
| `GET /api/v1/users/me/profile` | profile | access token | The caller's `Profile`. With no row, every field is `null` and `unit_system` is `metric` |
| `PUT /api/v1/users/me/profile` | profile | access token | Replace the caller's profile; answers `200` with the `Profile`. `422 validation_error` for a field rule |
| `PUT /api/v1/users/me/email` | auth | access token | Body `{new_email, current_password}`. Answers `200` with `User`. `403 incorrect_password`, `409 email_taken`, `422 validation_error` (also when the new email equals the current one), `429 rate_limited` |
| `PUT /api/v1/users/me/password` | auth | access token | Body `{current_password, new_password}`. Revokes every refresh token of the user and answers `200` with a new `TokenPair`. `403 incorrect_password`, `422 validation_error` (a broken rule, or the new password equals the current one), `429 rate_limited` |

`Profile`:

```json
{
  "first_name": "Max",
  "last_name": "Darsonval",
  "birthday": "1991-06-24",
  "country": "US",
  "state": "California",
  "gender": "male",
  "unit_system": "imperial",
  "height_cm": 180.3,
  "weight_kg": 84.4
}
```

New error code: `403 incorrect_password`, "the current password is wrong". It is not `401`, so the app's refresh-and-retry logic (which reacts to `401 token_expired` and `invalid_token`) never runs for it.

### Backend

- **A new module `profile`** (`backend/app/modules/profile/`: `models.py`, `schemas.py`, `repository.py`, `service.py`, `deps.py`, `router.py`), mounted in `app/api/v1/router.py` and imported in `app/modules/models.py`. Its routes are `user` in `ROUTE_ACCESS`. The module reads the caller through the existing current-user dependency and does not import the `auth` repository or models; the foreign key to `users.id` is the only link (no ORM relationship).
- **Table `user_profiles`** (one Alembic migration that only adds a new table, so no existing data is touched; checked up, down, up): `user_id` (UUID, primary key, FK to `users.id` `ON DELETE CASCADE`), `first_name` and `last_name` (`varchar(50)`, nullable), `birthday` (`date`, nullable), `country` (`char(2)`, nullable), `state` (`varchar(100)`, nullable), `gender` (`varchar(20)`, nullable, a check on the four values), `unit_system` (`varchar(10)`, not null, default `metric`, check), `height_cm` and `weight_kg` (`numeric(4,1)`, nullable, range checks), `updated_at`. `PUT` is an upsert; the repository flushes, the service commits.
- **The `auth` module:** `change_email` and `change_password` in `AuthService`. Both check the current password with the existing hasher, record a failed attempt and enforce the sign-in rate limit on a wrong one, and raise typed `DomainError`s (`IncorrectPasswordError` → `incorrect_password`). `change_email` lowercases and checks uniqueness (`email_taken`, also on a unique-constraint race). `change_password` re-hashes, revokes every refresh token of the user and issues a new pair. No password or token is logged.

### Mobile

- **Routes** (IDs only, no `state.extra`): `/profile` stays the tab; `/profile/info`, `/profile/email` and `/profile/password` are pushed on the root navigator (`parentNavigatorKey`), so they cover the tab bar as in the design, with a back button.
- **Profile tab** (`features/profile/presentation`): an avatar circle with the initials of the `AuthBloc` user, the list (Profile, Email, Password) as one rounded block with dividers and chevrons, **Sign out** under it. It reads only `AuthBloc`, as today.
- **Profile info** (`features/profile/{domain,data,presentation}`): `Profile` entity and `ProfileRepository` interface in `domain`; `ProfileRemoteDataSource` (Dio) and `FakeProfileRemoteDataSource` with fixtures equal to the examples in `data`; `ProfileInfoBloc` (load, edit, save) created in the route's `BlocProvider`. Pickers for Birthday (date picker), Country (searchable list) and Gender (bottom sheet); the Units switch converts the shown Height (ft/in) and Weight (lbs) without losing precision. States: loading, a load error with **Try again**, form, saving (Save disabled with a spinner), a save error banner, saved (a snackbar, then back).
- **Email and Password** are auth flows, so they live in `features/auth/presentation` with their own blocs, `ChangeEmailBloc` and `ChangePasswordBloc`, following the "one bloc per flow" rule. They call `AuthRepository`, which gains `changeEmail` and `changePassword`. Neither bloc touches `AuthBloc`: `changeEmail` returns the updated user and the repository announces it on a new `userUpdated` stream, which `AuthBloc` listens to and uses to replace the user in `AuthAuthenticated`; `changePassword` stores the new token pair in secure storage before it returns.
- **Email screen:** the explanation, the new email, Current Password, **Save** enabled only when the email differs and both fields are valid. **Password screen:** Current, New, Confirm (must match), show/hide toggles, the hint as in "Decided by the user". Errors: `incorrect_password` under Current Password, `email_taken` under the email field, `rate_limited` as a banner with the wait time, field errors from `validation_error`.
- **Keyboard handling** (Profile info, Email, Password), with Flutter's own tools only and no new dependency. The three forms share one layout, `SettingsFormLayout` in `lib/shared/widgets/`, built like `AuthFormLayout`:
  - The keyboard never covers the focused field, its error line, or **Save**. The `Scaffold` resizes for the keyboard (`resizeToAvoidBottomInset`), the form scrolls, and the focused field is scrolled into view with room for its error line. **Save** sits at the bottom of the content as in the design and moves up with the content when the keyboard opens, always reachable by scrolling; it is never pinned under the keyboard.
  - **Next** on the keyboard moves to the next text field; **Done** on the last one closes the keyboard and saves when the form is valid.
  - Tapping outside a field or dragging the form closes the keyboard (`keyboardDismissBehavior: onDrag`).
  - Opening a picker (Birthday, Country, Gender) closes the keyboard first, so the picker and the keyboard never show together.
  - Nothing overflows with the keyboard open at 375×667 and text scale 2.0.
- Colours and text styles come from `Theme.of(context)`, spacing and radii from `AppSpacing` and `AppRadius`; a value the scale lacks goes into `app_tokens.dart`.

### Touches the approval must cover

- **A public API change:** four new routes and one new error code (`incorrect_password`). No existing route changes.
- **A schema change:** a new table `user_profiles`. Nothing existing is altered or dropped.
- **Architecture:** a new backend module `profile` (today: `auth`, `challenges`, `runs`, `medals`), so `CLAUDE.md` and `docs/architecture.md` list it.
- **Authentication and a security boundary:** changing the email (the sign-in identifier) and the password, revoking refresh tokens, and the rate limit on the current password. These tasks carry the `human-merge` label.
- **Personal data:** birthday, gender, country, height and weight are stored per user, behind the user's JWT, never logged, deleted with the user (cascade). Exporting or deleting one's data is not in this plan.

## Risks

- **Account takeover through an open, unlocked phone.** Both account routes need the current password, and wrong guesses count toward the sign-in rate limit.
- **A typo in the new email locks the user out.** The email is checked on the form and the success message shows the new address; a verified email change is a later plan that needs email sending.
- **Other devices keep access for up to 15 minutes after a password change.** Access tokens cannot be revoked. Accepted for the MVP and stated in the contract.
- **Unit conversion rounding changes a value on every save.** Storage is metric with one decimal; the app converts only for display and sends back the metric value it loaded when the field was not edited; tests cover both systems.
- **Personal data stored.** All optional, deleted with the user, bodies never logged.
- **Two forms in the auth area make `AuthRepository` grow.** Only two methods and one stream are added; `AuthBloc` stays the only owner of the session.

## Verification

- **Backend:** unit tests for `ProfileService` (rules, upsert, empty profile) and for `change_email` / `change_password` (a wrong password records a failed attempt, rate limit, email already in use, same email, same password, revocation of every refresh token and a working new pair); integration tests against the test database for the four routes, including that a user never reads or changes another's profile and that an old refresh token is refused after a password change; `pytest tests/unit/test_auth_sweep.py` with the routes declared; contract, example and OpenAPI snapshot tests; `pytest -m fuzz`; the hurl files `backend/hurl/profile.hurl` and an extended `auth.hurl` with their output; migration up, down, up with `\d user_profiles`; `ruff`, `mypy`.
- **Mobile logic:** bloc tests for `ProfileInfoBloc`, `ChangeEmailBloc`, `ChangePasswordBloc` and `AuthBloc`'s reaction to `userUpdated`; repository tests with a fake HTTP adapter (the new token pair is stored); unit tests for the ft/in and lbs conversions; `flutter test test/contract` with the new fixtures.
- **Mobile screens:** page tests with `pumpScreen` and `expectAccessible` at 375×667 and 430×932, text scale 1.0 and 2.0, for every state: the Profile tab; Profile info (loading, error, form in imperial and metric, saving, save error); Email (Save disabled, enabled, `incorrect_password`, `email_taken`, `rate_limited`); Password (mismatch, rule error, `incorrect_password`, success). Goldens compared by eye with the Figma frames. Screenshots with `--dart-define=API_MODE=mock`.
- **Keyboard:** page tests that open the keyboard by setting `tester.view.viewInsets` (a 300 logical-pixel inset) at 375×667 and text scale 1.0 and 2.0, on each form: no overflow, the focused field (the last one included) and its error inside the visible area, **Save** reachable by scrolling, **Next** and **Done** moving the focus as described, tapping outside closing the keyboard, and a picker closing it. A screenshot of each form with the keyboard open on the iOS Simulator.
- **Integration:** the app against the local backend: edit and save the profile and reopen it; change the email and sign in with the new one; change the password, then sign in with the new one and see that the old refresh token is refused.
- **Not verified, and said so in the PRs:** behaviour on real devices with other sessions open is checked only through the backend tests (no second device).

## Ticket evidence

- Tasks with UI: the Figma frames in "Context", the states and sizes in "Verification", and the deviations from the design in "Decided by the user" and assumptions 10 to 12.
- Backend tasks: the sample requests and responses in `docs/api/profile.md` and `docs/api/auth.md` (task 1), and the hurl output.
- No bug tasks.

## Task breakdown

One task is one issue. **Each backend endpoint is its own task.** Every task has three parts: Requirements, Steps and Checklist. The checklist is the issue's acceptance criteria, word for word the same as its row in "Issues to create". Every task follows the build loop in `CLAUDE.md` (lint and type checks after each step) and writes an `## Evidence` section (`.claude/workflow/evidence.md`) in its PR. Backend tasks follow the `fastapi-module` skill; mobile tasks follow the `flutter-feature` skill.

Order: 1 and 6 can start at once. After 1: 2 → 3 and 4 → 5. 7, 8 and 9 run in parallel after 1 and 6. Each integration task waits for its own backend tasks: 10 waits for 2, 3 and 7; 11 for 4 and 8; 12 for 5 and 9, and each starts only when its backend task is closed and its endpoint is in `docs/api/openapi.json` on `develop`.

### Task 1: `[profile] docs: profile, email and password contract`

**Requirements**

- The contract is complete enough for the backend tasks and the mobile mock tasks to start without asking: every field rule, response and error code in "Approach".
- The example files are valid JSON and match the schemas the backend will serve.

**Steps**

1. Write `docs/api/profile.md`: the `Profile` shape, field rules (assumptions 2 to 6), `GET` and `PUT /api/v1/users/me/profile` with their responses and errors.
2. Add examples under `docs/api/examples/profile/`: `profile.json`, `profile_empty.json`, `profile_put_request.json`, `error_validation.json`.
3. In `docs/api/auth.md`, add `PUT /api/v1/users/me/email` and `PUT /api/v1/users/me/password`, the error code `403 incorrect_password`, the rate-limit rule (assumption 9) and the token revocation (assumption 7).
4. Add their examples under `docs/api/examples/auth/`: `change_email_request.json`, `change_password_request.json`, `error_incorrect_password.json`.
5. Add the `profile` module to `docs/architecture.md` and `CLAUDE.md`.
6. Run the contract example tests.

**Checklist**

- [ ] `docs/api/profile.md` and `docs/api/examples/profile/` describe `GET` and `PUT /api/v1/users/me/profile`, the field rules and errors
- [ ] `docs/api/auth.md` and `docs/api/examples/auth/` describe `PUT /api/v1/users/me/email` and `PUT /api/v1/users/me/password`, `incorrect_password`, the rate limit and the token revocation
- [ ] `docs/architecture.md` and `CLAUDE.md` list the `profile` module
- [ ] The contract example tests pass

### Task 2: `[profile] feat: GET /users/me/profile (backend)`

**Requirements**

- A new module `profile` with the layers router → service → repository; it does not import the `auth` repository or models.
- The table `user_profiles` is created by one migration that only adds the new table.
- A user with no row gets an empty profile (every field `null`, `unit_system` `metric`), not a `404`.

**Steps**

1. Create `backend/app/modules/profile/` (`models.py`, `schemas.py`, `repository.py`, `service.py`, `deps.py`, `router.py`); import the model in `app/modules/models.py`.
2. Model `UserProfile` and an Alembic migration for `user_profiles` with the columns and checks in "Approach"; run up, down, up.
3. `ProfileRepository.get(user_id)`, `ProfileService.get(user_id)` returning the empty profile when there is no row, `ProfileRead` schema.
4. `GET /api/v1/users/me/profile` in the router, mounted in `app/api/v1/router.py`, declared `user` in `ROUTE_ACCESS`.
5. Unit tests for the service (row and no row), integration tests for the route (own profile, empty profile, `401` without a token).
6. Update `docs/api/openapi.json`; run the contract and snapshot tests; add `backend/hurl/profile.hurl` for `GET`.

**Checklist**

- [ ] Module `profile` and `GET /api/v1/users/me/profile` as in the contract; the route is `user` in `ROUTE_ACCESS`
- [ ] Migration adds `user_profiles` (cascade on user delete, checks); up, down, up verified with `\d user_profiles`
- [ ] A user with no row gets the empty profile; another user's row never appears
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/profile.hurl` and its output; `docs/api/openapi.json` updated
- [ ] `ruff`, `mypy` and the full `pytest` pass

### Task 3: `[profile] feat: PUT /users/me/profile (backend)`

**Requirements**

- `PUT` replaces the whole profile (assumption 6) and is an upsert: the first save creates the row.
- Every field rule is checked by the Pydantic schema and answered with `422 validation_error` and its `fields`.
- The repository only flushes; the service commits. Request bodies are never logged.

**Steps**

1. `ProfileWrite` schema with the field rules: names 1 to 50 characters after trimming, birthday after 1900-01-01 and not in the future, `country` `^[A-Z]{2}$`, `state` up to 100, `gender` and `unit_system` enums, height and weight ranges with one decimal.
2. `ProfileRepository.upsert(user_id, data)` (`INSERT ... ON CONFLICT (user_id) DO UPDATE`), then `flush`.
3. `ProfileService.replace(user_id, data)` sets `updated_at` and commits.
4. `PUT /api/v1/users/me/profile` answering `200` with `ProfileRead`; `user` in `ROUTE_ACCESS`.
5. Unit tests for each field rule; integration tests for create, replace, clearing a field with `null`, and one user never changing another's row.
6. Update `docs/api/openapi.json`; extend `profile.hurl`; run the fuzz tests.

**Checklist**

- [ ] `PUT /api/v1/users/me/profile` as in the contract; the route is `user` in `ROUTE_ACCESS`
- [ ] The first save creates the row, later saves replace it; a `null` field clears the value
- [ ] Each field rule answers `422 validation_error` with its field; a user never changes another's profile; bodies are never logged
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/profile.hurl` extended and its output; `docs/api/openapi.json` updated
- [ ] `ruff`, `mypy` and the full `pytest` pass

### Task 4: `[auth] feat: PUT /users/me/email (backend)`

**Requirements**

- The current password is checked with the existing hasher. A wrong one answers `403 incorrect_password` and is recorded as a failed sign-in, so the existing limit (by email and by IP) answers `429 rate_limited` with `Retry-After`.
- The new email is lowercased, must differ from the current one (`422`) and must be free (`409 email_taken`, also when the unique constraint fails in a race).
- Sessions are not revoked (assumption 8). No password or token is logged.

**Steps**

1. `IncorrectPasswordError` (`DomainError`, `403`, `incorrect_password`) in the `auth` module, mapped by the global handler.
2. A private `AuthService._verify_current_password(user, password, ip, now)`: enforces the rate limit, checks the hash and records a failed attempt on a wrong one. Task 5 reuses it.
3. `ChangeEmailRequest` schema; `AuthService.change_email(...)`; a repository method that updates the email and flushes.
4. `PUT /api/v1/users/me/email` answering `200` with `UserRead`; `user` in `ROUTE_ACCESS`.
5. Unit tests: success, wrong password (attempt recorded), rate limited, same email, email already in use. Integration tests: success then sign in with the new email; the unique-constraint race.
6. Update `docs/api/openapi.json`; extend `backend/hurl/auth.hurl`; run the fuzz tests.

**Checklist**

- [ ] `PUT /api/v1/users/me/email` as in the contract; the route is `user` in `ROUTE_ACCESS`
- [ ] A wrong current password answers `403 incorrect_password`, records one failed attempt and counts toward `429 rate_limited`
- [ ] The same email answers `422`; an email already in use answers `409 email_taken`, also on the unique-constraint race; sign-in works with the new email
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/auth.hurl` extended and its output; `docs/api/openapi.json` updated
- [ ] `ruff`, `mypy` and the full `pytest` pass

### Task 5: `[auth] feat: PUT /users/me/password (backend)`

**Requirements**

- The current password is checked with `_verify_current_password` from task 4 (same `403` and `429`).
- The new password follows the contract rule and differs from the current one (`422`).
- Every refresh token of the user is revoked, and the response is a new `TokenPair` for this device. No password or token is logged.

**Steps**

1. `ChangePasswordRequest` schema with the password rule.
2. `AuthService.change_password(...)`: verify, re-hash, revoke every refresh token of the user (a repository method that sets `revoked_at` and flushes), issue a new pair, commit.
3. `PUT /api/v1/users/me/password` answering `200` with `TokenPair`; `user` in `ROUTE_ACCESS`.
4. Unit tests: success, wrong password, rate limited, rule broken, same password. Integration tests: an old refresh token fails after the change, the new pair works, sign-in works with the new password only.
5. Update `docs/api/openapi.json`; extend `auth.hurl`; run the fuzz tests.

**Checklist**

- [ ] `PUT /api/v1/users/me/password` as in the contract; the route is `user` in `ROUTE_ACCESS`
- [ ] A wrong current password answers `403 incorrect_password` and counts toward `429 rate_limited`; a broken rule or the same password answers `422`
- [ ] Every refresh token of the user is revoked and a new pair is returned; an old refresh token then fails; sign-in works with the new password only
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/auth.hurl` extended and its output; `docs/api/openapi.json` updated
- [ ] `ruff`, `mypy` and the full `pytest` pass

### Task 6: `[profile] feat: Profile tab and settings form layout (mobile)`

**Requirements**

- The Profile tab matches Figma `1:64`, with initials instead of a photo and no Change Avatar (decided by the user), and Sign out under the list (assumption 11).
- The three sub-routes exist and are pushed on the root navigator, so they cover the tab bar.
- `SettingsFormLayout` gives tasks 7, 8 and 9 the keyboard handling, so they do not depend on each other.

**Steps**

1. Rebuild `mobile/lib/features/profile/presentation/pages/profile_page.dart`: initials avatar, the rounded list (Profile, Email, Password) with dividers and chevrons, Sign out.
2. Add `/profile/info`, `/profile/email`, `/profile/password` in `mobile/lib/core/router/app_router.dart` with `parentNavigatorKey`, placeholder pages with a back button.
3. Write `mobile/lib/shared/widgets/settings_form_layout.dart`: app bar with back, a body that scrolls and resizes for the keyboard, the focused field and its error scrolled into view, Save at the bottom of the content, `keyboardDismissBehavior: onDrag`, tap outside to close the keyboard.
4. Page and golden tests for the Profile tab; keyboard tests for the layout on a sample form (inset of 300, both phone sizes, text scales 1.0 and 2.0); navigation tests for the three routes.

**Checklist**

- [ ] The Profile tab as in Figma `1:64`: initials avatar, no Change Avatar, the three rows Profile, Email, Password, Sign out below
- [ ] Routes `/profile/info`, `/profile/email`, `/profile/password` on the root navigator with a back button (placeholder pages until tasks 7 to 9)
- [ ] `SettingsFormLayout` in `mobile/lib/shared/widgets/` with the keyboard handling of "Approach" (resize for the keyboard, scroll the focused field and its error into view, Save reachable by scrolling, tap outside and drag close the keyboard), with keyboard tests on a sample form as in "Verification"
- [ ] Page and golden tests at both phone sizes and both text scales; `flutter analyze` and `flutter test` pass

### Task 7: `[profile] feat: profile info (mobile, mock)`

**Requirements**

- The form matches Figma `1:100`, inside `SettingsFormLayout`.
- `domain/` stays pure Dart. Units only change the display; values stay metric (assumption 5).
- Works without a backend through `FakeProfileRemoteDataSource` (`API_MODE=mock`).

**Steps**

1. `domain`: `Profile` entity, `UnitSystem` and `Gender` enums, `ProfileRepository` interface, failures.
2. `data`: `ProfileModel` (`freezed` + `json_serializable`, regenerate and commit), `ProfileRemoteDataSource` (Dio) against the contract, `FakeProfileRemoteDataSource` with fixtures equal to the examples, `ProfileRepositoryImpl`; DI registration.
3. Unit conversions (cm ↔ ft/in, kg ↔ lbs) as pure functions, with tests.
4. `ProfileInfoBloc` (`registerFactory`, created in the route's `BlocProvider`): load, edit, toggle units, save.
5. `ProfileInfoPage`: fields with Next and Done, a date picker for Birthday, a searchable Country list, a Gender bottom sheet, the Units switch; pickers close the keyboard first; loading, error, saving, save error and saved states.
6. Bloc, repository, page, golden and keyboard tests; contract test for the fixtures; screenshot with `API_MODE=mock`.

**Checklist**

- [ ] The form as in Figma `1:100`, with the pickers, the Units switch and conversions
- [ ] `ProfileRepository`, `ProfileRemoteDataSource` against the contract, `FakeProfileRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`
- [ ] `ProfileInfoBloc` with loading, error, form, saving, save error and saved states; bloc, page, golden and conversion tests at both phone sizes and both text scales
- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside and drag close it; each picker closes it first. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open
- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`

### Task 8: `[auth] feat: change email (mobile, mock)`

**Requirements**

- The screen matches Figma `1:163`, plus a Current Password field (decided by the user), with StrideQuest copy.
- `ChangeEmailBloc` never touches `AuthBloc`; the repository announces the new user on `userUpdated` and `AuthBloc` listens to that stream.

**Steps**

1. `AuthRepository.changeEmail` and the `userUpdated` stream; a data source method and the fake with fixtures equal to the examples.
2. `AuthBloc` listens to `userUpdated` and replaces the user in `AuthAuthenticated`.
3. `ChangeEmailBloc` and `ChangeEmailPage` in `mobile/lib/features/auth/presentation`, using `SettingsFormLayout`: Save enabled only when the email changed, is valid and a password is entered; errors under the right field or as a banner.
4. Bloc, repository, page, golden and keyboard tests; screenshot with `API_MODE=mock`.

**Checklist**

- [ ] The Email screen as in Figma `1:163` plus Current Password; Save enabled only when the email changed, is valid and a password is entered; StrideQuest copy
- [ ] `ChangeEmailBloc`; `AuthRepository.changeEmail` and the `userUpdated` stream; `AuthBloc` shows the new email
- [ ] `incorrect_password`, `email_taken`, `rate_limited` and field errors shown; the fake data source fixtures equal the examples
- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open
- [ ] Bloc, repository, page and golden tests at both phone sizes and both text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`

### Task 9: `[auth] feat: change password (mobile, mock)`

**Requirements**

- The screen matches Figma `1:137`, without Forgot Password? (assumption 10), with the contract's rule as the hint.
- The new token pair is stored before the bloc reports success, so the next request uses it.

**Steps**

1. `AuthRepository.changePassword` storing the new pair in secure storage; a data source method and the fake with fixtures equal to the examples.
2. `ChangePasswordBloc` and `ChangePasswordPage` in `mobile/lib/features/auth/presentation`, using `SettingsFormLayout`: Current, New, Confirm (must match), show/hide toggles, Next and Done.
3. Bloc, repository (pair stored), page, golden and keyboard tests; screenshot with `API_MODE=mock`.

**Checklist**

- [ ] The Password screen as in Figma `1:137`, without Forgot Password?, with the contract's rule as the hint, matching confirmation and show/hide toggles
- [ ] `ChangePasswordBloc`; `AuthRepository.changePassword` stores the new token pair
- [ ] `incorrect_password`, `rate_limited` and field errors shown; the fake data source fixtures equal the examples
- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open
- [ ] Bloc, repository, page and golden tests at both phone sizes and both text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`

### Task 10: `[profile] feat: profile info (mobile, integration)`

**Requirements**

- Integration gate: tasks 2 and 3 are closed and their endpoints are in `docs/api/openapi.json` on `develop`. Otherwise stop and name the open task.

**Steps**

1. Run the app against the local backend; fix any drift from the contract in the data source.
2. Check the error mapping for each documented error; add remote data source tests for them.
3. Fill the Integration row of the evidence.

**Checklist**

- [ ] The app against the local backend: load an empty profile, save every field, reopen and see them, in both unit systems; each documented error shown. Integration gate: 2 and 3 are closed and their endpoints are in `docs/api/openapi.json` on `develop`

### Task 11: `[auth] feat: change email (mobile, integration)`

**Requirements**

- Integration gate: task 4 is closed and its endpoint is in `docs/api/openapi.json` on `develop`.

**Steps**

1. Run the app against the local backend; change the email; sign out and sign in with the new one.
2. Trigger `incorrect_password`, `email_taken` and `rate_limited`; check the messages; add remote data source tests.
3. Fill the Integration row of the evidence.

**Checklist**

- [ ] The app against the local backend: change the email and sign in with it; `incorrect_password`, `email_taken`, `rate_limited` and a field error shown. Integration gate: 4 is closed and its endpoint is in `docs/api/openapi.json` on `develop`

### Task 12: `[auth] feat: change password (mobile, integration)`

**Requirements**

- Integration gate: task 5 is closed and its endpoint is in `docs/api/openapi.json` on `develop`.

**Steps**

1. Run the app against the local backend; change the password; keep using the app (the new pair works); sign out and sign in with the new password.
2. Trigger `incorrect_password`, `rate_limited` and a rule error; add remote data source tests.
3. Fill the Integration row of the evidence.

**Checklist**

- [ ] The app against the local backend: change the password, keep working on this device, sign in with the new password; `incorrect_password`, `rate_limited` and a field error shown. Integration gate: 5 is closed and its endpoint is in `docs/api/openapi.json` on `develop`

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| #120 | `[profile] docs: profile, email and password contract` | docs, area:profile | - [ ] `docs/api/profile.md` and `docs/api/examples/profile/` describe `GET` and `PUT /api/v1/users/me/profile`, the field rules and errors<br>- [ ] `docs/api/auth.md` and `docs/api/examples/auth/` describe `PUT /api/v1/users/me/email` and `PUT /api/v1/users/me/password`, `incorrect_password`, the rate limit and the token revocation<br>- [ ] `docs/architecture.md` and `CLAUDE.md` list the `profile` module<br>- [ ] The contract example tests pass | none |
| #121 | `[profile] feat: GET /users/me/profile (backend)` | backend, area:profile | - [ ] Module `profile` and `GET /api/v1/users/me/profile` as in the contract; the route is `user` in `ROUTE_ACCESS`<br>- [ ] Migration adds `user_profiles` (cascade on user delete, checks); up, down, up verified with `\d user_profiles`<br>- [ ] A user with no row gets the empty profile; another user's row never appears<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/profile.hurl` and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | #120 |
| #122 | `[profile] feat: PUT /users/me/profile (backend)` | backend, area:profile | - [ ] `PUT /api/v1/users/me/profile` as in the contract; the route is `user` in `ROUTE_ACCESS`<br>- [ ] The first save creates the row, later saves replace it; a `null` field clears the value<br>- [ ] Each field rule answers `422 validation_error` with its field; a user never changes another's profile; bodies are never logged<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/profile.hurl` extended and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | #121 |
| #123 | `[auth] feat: PUT /users/me/email (backend)` | backend, area:auth, human-merge | - [ ] `PUT /api/v1/users/me/email` as in the contract; the route is `user` in `ROUTE_ACCESS`<br>- [ ] A wrong current password answers `403 incorrect_password`, records one failed attempt and counts toward `429 rate_limited`<br>- [ ] The same email answers `422`; an email already in use answers `409 email_taken`, also on the unique-constraint race; sign-in works with the new email<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/auth.hurl` extended and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | #120 |
| #124 | `[auth] feat: PUT /users/me/password (backend)` | backend, area:auth, human-merge | - [ ] `PUT /api/v1/users/me/password` as in the contract; the route is `user` in `ROUTE_ACCESS`<br>- [ ] A wrong current password answers `403 incorrect_password` and counts toward `429 rate_limited`; a broken rule or the same password answers `422`<br>- [ ] Every refresh token of the user is revoked and a new pair is returned; an old refresh token then fails; sign-in works with the new password only<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/auth.hurl` extended and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | #123 |
| #125 | `[profile] feat: Profile tab and settings form layout (mobile)` | frontend, area:profile | - [ ] The Profile tab as in Figma `1:64`: initials avatar, no Change Avatar, the three rows Profile, Email, Password, Sign out below<br>- [ ] Routes `/profile/info`, `/profile/email`, `/profile/password` on the root navigator with a back button (placeholder pages until tasks 7 to 9)<br>- [ ] `SettingsFormLayout` in `mobile/lib/shared/widgets/` with the keyboard handling of "Approach" (resize for the keyboard, scroll the focused field and its error into view, Save reachable by scrolling, tap outside and drag close the keyboard), with keyboard tests on a sample form as in "Verification"<br>- [ ] Page and golden tests at both phone sizes and both text scales; `flutter analyze` and `flutter test` pass | none |
| #126 | `[profile] feat: profile info (mobile, mock)` | frontend, mock, area:profile | - [ ] The form as in Figma `1:100`, with the pickers, the Units switch and conversions<br>- [ ] `ProfileRepository`, `ProfileRemoteDataSource` against the contract, `FakeProfileRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`<br>- [ ] `ProfileInfoBloc` with loading, error, form, saving, save error and saved states; bloc, page, golden and conversion tests at both phone sizes and both text scales<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside and drag close it; each picker closes it first. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open<br>- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | #120, #125 |
| #127 | `[auth] feat: change email (mobile, mock)` | frontend, mock, area:auth, human-merge | - [ ] The Email screen as in Figma `1:163` plus Current Password; Save enabled only when the email changed, is valid and a password is entered; StrideQuest copy<br>- [ ] `ChangeEmailBloc`; `AuthRepository.changeEmail` and the `userUpdated` stream; `AuthBloc` shows the new email<br>- [ ] `incorrect_password`, `email_taken`, `rate_limited` and field errors shown; the fake data source fixtures equal the examples<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open<br>- [ ] Bloc, repository, page and golden tests at both phone sizes and both text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | #120, #125 |
| #128 | `[auth] feat: change password (mobile, mock)` | frontend, mock, area:auth, human-merge | - [ ] The Password screen as in Figma `1:137`, without Forgot Password?, with the contract's rule as the hint, matching confirmation and show/hide toggles<br>- [ ] `ChangePasswordBloc`; `AuthRepository.changePassword` stores the new token pair<br>- [ ] `incorrect_password`, `rate_limited` and field errors shown; the fake data source fixtures equal the examples<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard tests as in "Verification", and a Simulator screenshot with the keyboard open<br>- [ ] Bloc, repository, page and golden tests at both phone sizes and both text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | #120, #125 |
| #129 | `[profile] feat: profile info (mobile, integration)` | frontend, integration, area:profile | - [ ] The app against the local backend: load an empty profile, save every field, reopen and see them, in both unit systems; each documented error shown. Integration gate: 2 and 3 are closed and their endpoints are in `docs/api/openapi.json` on `develop` | #121, #122, #126 |
| #130 | `[auth] feat: change email (mobile, integration)` | frontend, integration, area:auth, human-merge | - [ ] The app against the local backend: change the email and sign in with it; `incorrect_password`, `email_taken`, `rate_limited` and a field error shown. Integration gate: 4 is closed and its endpoint is in `docs/api/openapi.json` on `develop` | #123, #127 |
| #131 | `[auth] feat: change password (mobile, integration)` | frontend, integration, area:auth, human-merge | - [ ] The app against the local backend: change the password, keep working on this device, sign in with the new password; `incorrect_password`, `rate_limited` and a field error shown. Integration gate: 5 is closed and its endpoint is in `docs/api/openapi.json` on `develop` | #124, #128 |
