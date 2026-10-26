# Plan 022: Profile settings (profile info, email and password)

Status: draft
Approved: <YYYY-MM-DD; /approve-plan adds the user's words after the date>
Issues: <filled in after approval>

## Context

The Profile tab is a placeholder: it shows the display name, the email and **Sign out** (`mobile/lib/features/profile/presentation/pages/profile_page.dart`). This plan builds the account settings the Figma file draws in the **Profile Settings** group:

| Frame | Node | What it shows |
| --- | --- | --- |
| Account - Profile | [`1:64`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-64) | The Profile tab: avatar, **Change Avatar**, and a list with **Profile**, **Email** and **Password** |
| Account - Profile Info | [`1:100`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-100) | A form: First Name, Last Name, Birthday, Country, State, Gender, a **Units** switch (Imperial (US) / Metric), Height, Weight, **Save** |
| Account - Password | [`1:137`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-137) | Current Password, New Password, Confirm Password, **Forgot Password?**, **Save** |
| Account - Email | [`1:163`](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest?node-id=1-163) | An explanation, the email field, **Save** (disabled until the email changes) |

The three sub-screens have a back arrow and no tab bar.

### Decided by the user

- **Avatar is out of this plan.** Uploading one means a user (not an admin) uploads to Cloudinary, which [ADR 0003](../adr/0003-cloudinary-for-images.md) does not allow and which costs quota. The Profile tab shows the user's initials in the avatar circle and no **Change Avatar** button. A later plan, with an ADR, adds the upload.
- **Profile Info keeps every field of the design**, stored on the backend, all optional.
- **Changing the email needs the current password.** The Email screen gets a **Current Password** field that the Figma frame does not have. The change applies at once; there is no verification email (still out of scope for the MVP, `docs/api/auth.md`).
- **The password rule stays as the contract says**: 8 to 128 characters with at least one letter and one digit. The Figma hint "at least 12 characters" becomes "At least 8 characters, with a letter and a digit".

## Open questions and assumptions

Each has the answer the plan assumes; say if one is wrong.

1. **`display_name` stays as it is.** First and last name are new, optional profile fields; `display_name` (set at sign up, shown elsewhere) is not edited by this plan and is not derived from them.
2. **Country** is an ISO 3166-1 alpha-2 code picked from a list shipped in the app. The backend checks only the format (`^[A-Z]{2}$`) and keeps no country list. **State** is free text of at most 100 characters, as a text field. A state picker per country is a later change.
3. **Gender** is one of `female`, `male`, `non_binary`, `prefer_not_to_say`, or empty.
4. **Birthday** is a date picked in a date picker, after 1900-01-01 and not in the future. No minimum age is enforced.
5. **Height and weight are stored in metric** (`height_cm`, `weight_kg`, one decimal) whatever the switch says. **Units** (`imperial` or `metric`, default `metric`) is a preference stored with the profile; the app converts for display (feet and inches, pounds). Limits: height 50.0 to 272.0 cm, weight 20.0 to 400.0 kg.
6. **Save replaces the whole profile** (`PUT`): the form always sends every field, and an empty field clears it.
7. **Changing the password signs out every other device.** All the user's refresh tokens are revoked and the response carries a new token pair for this device. Access tokens already issued elsewhere keep working until they expire (15 minutes by default); there is no access-token deny list.
8. **Changing the email does not revoke sessions**, since the password is unchanged.
9. **A wrong current password counts as a failed sign-in** for the existing rate limit (by email and by IP, `LoginAttempt`), so these routes cannot be used to guess the password. Too many attempts answer `429 rate_limited` with `Retry-After`.
10. **Forgot Password?** is hidden: password reset by email is out of scope for the MVP.
11. **Sign out stays** on the Profile tab, as a row under the list (the Figma frame does not draw it, but the app needs it).
12. The Email frame mentions "Velocity Training"; the copy says **StrideQuest**.

## Approach

### Contract (`docs/api/`)

- New `docs/api/profile.md` with examples under `docs/api/examples/profile/`.
- `docs/api/auth.md` gains the two account routes, their examples under `docs/api/examples/auth/` and one new error code.

| Endpoint | Module | Auth | Purpose |
| --- | --- | --- | --- |
| `GET /api/v1/users/me/profile` | `profile` | access token | The caller's `Profile`. With no row yet, every field is `null` and `unit_system` is `metric` |
| `PUT /api/v1/users/me/profile` | `profile` | access token | Replace the caller's profile; answers `200` with the `Profile`. `422 validation_error` for a field rule |
| `PUT /api/v1/users/me/email` | `auth` | access token | Body `{new_email, current_password}`. Answers `200` with `User`. `403 incorrect_password`, `409 email_taken`, `422 validation_error` (also when the new email equals the current one), `429 rate_limited` |
| `PUT /api/v1/users/me/password` | `auth` | access token | Body `{current_password, new_password}`. Revokes all the user's refresh tokens and answers `200` with a new `TokenPair`. `403 incorrect_password`, `422 validation_error` (password rule, or the new password equals the current one), `429 rate_limited` |

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

New error code: `403 incorrect_password`, "the current password is wrong". It is not `401`, so the app's refresh-and-retry logic (which reacts to `401 token_expired` and `invalid_token`) never fires for it.

### Backend

- **New module `profile`** (`backend/app/modules/profile/`: `models.py`, `schemas.py`, `repository.py`, `service.py`, `deps.py`, `router.py`), mounted in `app/api/v1/router.py` and imported in `app/modules/models.py`. Its routes are `user` in `ROUTE_ACCESS`. It reads the caller from the existing current-user dependency and does not import the `auth` repository or models; the foreign key to `users.id` is the only link (no ORM relationship).
- **Table `user_profiles`** (one Alembic migration, new table only, so no existing data is touched; tested up, down, up): `user_id` (UUID, primary key, FK to `users.id` `ON DELETE CASCADE`), `first_name` and `last_name` (`varchar(50)`, nullable), `birthday` (`date`, nullable), `country` (`char(2)`, nullable), `state` (`varchar(100)`, nullable), `gender` (`varchar(20)`, nullable, check on the four values), `unit_system` (`varchar(10)`, not null, default `metric`, check), `height_cm` and `weight_kg` (`numeric(4,1)`, nullable, range checks), `updated_at`. `PUT` is an upsert; the repository flushes, the service commits.
- **`auth` module:** `change_email` and `change_password` in `AuthService`. Both check the current password with the existing hasher, record a failed attempt and enforce the sign-in rate limit on a wrong one, and raise typed `DomainError`s (`IncorrectPasswordError` → `incorrect_password`). `change_email` lowercases and checks uniqueness (`email_taken`, also on the unique-constraint race). `change_password` re-hashes, revokes every refresh token of the user and issues a new pair. Neither logs a password or a token.

### Mobile

- **Routes** (IDs only, no `state.extra`): `/profile` stays the tab; `/profile/info`, `/profile/email` and `/profile/password` are pushed on the root navigator (`parentNavigatorKey`), so they cover the tab bar as in the design, with a back button.
- **Profile tab** (`features/profile/presentation`): avatar circle with initials from the `AuthBloc` user, the list (Profile, Email, Password) as one rounded surface with dividers and chevrons, and **Sign out** under it. It reads `AuthBloc` only, as today.
- **Profile info** (`features/profile/{domain,data,presentation}`): `Profile` entity and `ProfileRepository` interface in `domain`; `ProfileRemoteDataSource` (Dio) and `FakeProfileRemoteDataSource` with fixtures equal to the examples in `data`; `ProfileInfoBloc` (load, edit, save) created in the route's `BlocProvider`. Pickers for Birthday (date picker), Country (searchable list) and Gender (bottom sheet); the Units switch converts the shown Height (ft/in) and Weight (lbs) without losing precision. States: loading, load error with **Try again**, form, saving (Save disabled with a spinner), save error banner, saved (a snackbar and back).
- **Email and Password** are auth flows, so they live in `features/auth/presentation` with their own blocs, `ChangeEmailBloc` and `ChangePasswordBloc`, as the rule "one bloc per flow" says. They call `AuthRepository`, which gains `changeEmail` and `changePassword`. Neither bloc touches `AuthBloc`:
  - `changeEmail` returns the updated user and the repository announces it on a new `userUpdated` stream; `AuthBloc` listens and replaces the user in `AuthAuthenticated`.
  - `changePassword` stores the new token pair in secure storage before it returns.
  - Email screen: the explanation, New email, Current Password, **Save** enabled only when the email differs and both fields are valid. Password screen: Current, New, Confirm (must match), show/hide toggles, the hint from "Decided by the user". Errors: `incorrect_password` under Current Password, `email_taken` under the email, `rate_limited` as a banner with the wait time, field errors from `validation_error`.
- **Keyboard handling** (Profile info, Email and Password), with Flutter's own tools and no new dependency. The three forms share one layout, `SettingsFormLayout` in `lib/shared/widgets/`, built like `AuthFormLayout`:
  - The keyboard never covers the focused field, an error under it, or **Save**. The `Scaffold` resizes for the keyboard (`resizeToAvoidBottomInset`), the form scrolls, and a focused field scrolls into view with room for its error line. **Save** sits at the bottom of the content as in the design and moves up with the content when the keyboard opens, so it can always be reached by scrolling; it is never pinned under the keyboard.
  - **Next** on the keyboard moves to the next text field; **Done** on the last one closes the keyboard and saves when the form is valid.
  - Tapping outside a field or dragging the form closes the keyboard (`keyboardDismissBehavior: onDrag`).
  - Opening a picker (Birthday, Country, Gender) closes the keyboard first, so the picker and the keyboard never show together.
  - Nothing overflows with the keyboard open at 375×667 and text scale 2.0.
- Colours and text styles from `Theme.of(context)`, spacing and radii from `AppSpacing` and `AppRadius`; a value the scale lacks goes into `app_tokens.dart`.

### Touches the approval must cover

- **A public API change:** four new routes and one new error code (`incorrect_password`). No existing route changes.
- **A schema change:** a new table `user_profiles`. Nothing existing is altered or dropped.
- **Architecture:** a new backend module `profile` (the modules are `auth`, `challenges`, `runs`, `medals` today), so `CLAUDE.md` and `docs/architecture.md` list it.
- **Authentication and a security boundary:** changing the email (the sign-in identifier) and the password, revoking refresh tokens, and the rate limit on the current password. These issues carry `human-merge`.
- **Personal data:** birthday, gender, country, height and weight are stored per user, behind the user's JWT, never logged, deleted with the user (cascade). A way to export or delete one's data is not in this plan.

## Risks

- **Account takeover through an open, unlocked phone.** Mitigation: both account routes need the current password, and wrong guesses hit the sign-in rate limit.
- **A typo in the new email locks the user out**, since there is no verification. Mitigation: the email is checked on the form and the success message shows the new address; a verified change is a later plan with email sending.
- **Other devices keep access for up to 15 minutes after a password change** (access tokens are not revocable). Accepted for the MVP and stated in the contract.
- **Unit conversion rounding** changes a value on every save. Mitigation: storage is metric with one decimal, the app converts only for display and sends the metric value it loaded unless the user edited the field; a test round-trips both systems.
- **Personal data stored.** Mitigation: all optional, cascade delete, no logging of bodies.
- **Two forms in one auth area** grow `AuthRepository`. Mitigation: two methods and one stream only; `AuthBloc` still owns the session alone.

## Verification

- **Backend:** unit tests for `ProfileService` (rules, upsert, empty profile) and for `change_email` / `change_password` (wrong password records an attempt, rate limit, duplicate email, same email, same password, revocation of every refresh token and a working new pair); integration tests against the test database for the four routes, including that a user never reads or changes another's profile and that an old refresh token fails after a password change; `pytest tests/unit/test_auth_sweep.py` with the routes declared; contract, example and OpenAPI snapshot tests; `pytest -m fuzz`; hurl files `backend/hurl/profile.hurl` and an extended `auth.hurl` with their output; migration up, down, up with `\d user_profiles`; `ruff`, `mypy`.
- **Mobile logic:** bloc tests for `ProfileInfoBloc`, `ChangeEmailBloc`, `ChangePasswordBloc` and the `AuthBloc` reaction to `userUpdated`; repository tests with a fake HTTP adapter (the new token pair is stored); unit tests for the ft/in and lbs conversions; `flutter test test/contract` with the new fixtures.
- **Mobile screens:** page tests with `pumpScreen` and `expectAccessible` at 375×667 and 430×932, text scale 1.0 and 2.0, for every state: Profile tab; Profile info (loading, error, form imperial and metric, saving, save error); Email (disabled Save, enabled, `incorrect_password`, `email_taken`, `rate_limited`); Password (mismatch, rule error, `incorrect_password`, success). Goldens compared by eye with the Figma frames. Screenshots with `--dart-define=API_MODE=mock`.
- **Keyboard:** page tests that open the keyboard by setting `tester.view.viewInsets` (a 300 logical-pixel inset) at 375×667 and text scale 1.0 and 2.0, on each form: no overflow, the focused field (the last one included) and its error are inside the visible area, **Save** can be reached by scrolling, **Next** and **Done** move the focus as described, tapping outside closes the keyboard, and a picker closes it. A screenshot of each form with the keyboard open on the iOS Simulator.
- **Integration:** the app against the local backend: edit and save the profile and reopen it; change the email and sign in with the new one; change the password, then sign in with the new one and see that the old refresh token is refused.
- **Not verified, and said so in the PRs:** behaviour on real devices with other sessions open is checked only through the backend tests (no second device).

## Ticket evidence

- Feature-with-UI issues: the Figma frames in Context, the states and sizes under Verification, and the deviations from the design in "Decided by the user" and assumptions 10 to 12.
- Backend issues: the sample requests and responses in `docs/api/profile.md` and `docs/api/auth.md` (issue 1), and the hurl output.
- No bug issues.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[profile] docs: profile, email and password contract` | docs, area:profile | - [ ] `docs/api/profile.md` and `docs/api/examples/profile/` describe `GET` and `PUT /api/v1/users/me/profile`, the field rules and errors<br>- [ ] `docs/api/auth.md` and `docs/api/examples/auth/` describe `PUT /api/v1/users/me/email` and `PUT /api/v1/users/me/password`, `incorrect_password`, the rate limit and the token revocation<br>- [ ] `docs/architecture.md` and `CLAUDE.md` list the `profile` module<br>- [ ] The contract example tests pass | none |
| 2 | `[profile] feat: profile API (backend)` | backend, area:profile | - [ ] Module `profile` with `GET` and `PUT /api/v1/users/me/profile` as in the contract; routes `user` in `ROUTE_ACCESS`<br>- [ ] Migration adds `user_profiles` (cascade on user delete, checks); up, down, up verified with `\d user_profiles`<br>- [ ] A user never reads or changes another's profile; bodies are never logged<br>- [ ] Unit and integration tests, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/profile.hurl` and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | 1 |
| 3 | `[auth] feat: change email and password API (backend)` | backend, area:auth, human-merge | - [ ] `PUT /api/v1/users/me/email` and `PUT /api/v1/users/me/password` as in the contract<br>- [ ] A wrong current password answers `403 incorrect_password`, records a failed attempt and counts toward `429 rate_limited`<br>- [ ] A password change revokes every refresh token of the user and returns a new pair; an old refresh token then fails<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests, `pytest -m fuzz`, `backend/hurl/auth.hurl` extended and its output; `docs/api/openapi.json` updated<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | 1 |
| 4 | `[profile] feat: Profile tab with account settings list (mobile)` | frontend, area:profile | - [ ] The Profile tab as in Figma `1:64`: initials avatar, no Change Avatar, the Profile, Email and Password rows, Sign out below<br>- [ ] Routes `/profile/info`, `/profile/email`, `/profile/password` on the root navigator with a back button (placeholder pages until issues 5 to 7)<br>- [ ] `SettingsFormLayout` in `lib/shared/widgets/` with the keyboard handling of the Approach (resize, scroll the focused field and its error into view, Save reachable, tap outside and drag close the keyboard), with keyboard page tests on a sample form as in Verification<br>- [ ] Page and golden tests at both phone sizes and text scales; `flutter analyze` and `flutter test` pass | none |
| 5 | `[profile] feat: profile info (mobile, mock)` | frontend, mock, area:profile | - [ ] The form as in Figma `1:100`, with the pickers, the Units switch and conversions<br>- [ ] `ProfileRepository`, `ProfileRemoteDataSource` against the contract, `FakeProfileRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`<br>- [ ] `ProfileInfoBloc` with loading, error, form, saving, save error and saved states; bloc, page, golden and conversion tests at both phone sizes and text scales<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside and drag close it; each picker closes it first. Keyboard page tests as in Verification, and a Simulator screenshot with the keyboard open<br>- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | 1, 4 |
| 6 | `[auth] feat: change email (mobile, mock)` | frontend, mock, area:auth, human-merge | - [ ] The Email screen as in Figma `1:163` plus Current Password; Save enabled only for a changed, valid email and a password; StrideQuest copy<br>- [ ] `ChangeEmailBloc`; `AuthRepository.changeEmail` and the `userUpdated` stream; `AuthBloc` shows the new email<br>- [ ] `incorrect_password`, `email_taken`, `rate_limited` and field errors shown; fake data source fixtures equal to the examples<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard page tests as in Verification, and a Simulator screenshot with the keyboard open<br>- [ ] Bloc, repository, page and golden tests at both phone sizes and text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | 1, 4 |
| 7 | `[auth] feat: change password (mobile, mock)` | frontend, mock, area:auth, human-merge | - [ ] The Password screen as in Figma `1:137`, without Forgot Password?, with the contract's rule as the hint, matching confirmation and show/hide toggles<br>- [ ] `ChangePasswordBloc`; `AuthRepository.changePassword` stores the new token pair<br>- [ ] `incorrect_password`, `rate_limited` and field errors shown; fake data source fixtures equal to the examples<br>- [ ] Uses `SettingsFormLayout`: the keyboard never covers a field, its error or Save; Next and Done; tap outside closes it. Keyboard page tests as in Verification, and a Simulator screenshot with the keyboard open<br>- [ ] Bloc, repository, page and golden tests at both phone sizes and text scales; screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged` | 1, 4 |
| 8 | `[profile] feat: profile info (mobile, integration)` | frontend, integration, area:profile | - [ ] The app against the local backend: load an empty profile, save every field, reopen and see them, in both unit systems; each documented error shown. Integration gate: 2 is closed and its endpoints are in `openapi.json` on `develop` | 2, 5 |
| 9 | `[auth] feat: change email and password (mobile, integration)` | frontend, integration, area:auth, human-merge | - [ ] The app against the local backend: change the email and sign in with it; change the password, keep working on this device, sign in with the new password; each documented error shown. Integration gate: 3 is closed and its endpoints are in `openapi.json` on `develop` | 3, 6, 7 |
