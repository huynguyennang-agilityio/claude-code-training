# Plan 030: Health sync on app open, health access that doesn't block the app, and one sign-in session per account

Status: approved
Approved: 2026-11-02, by the user in chat: "/approve-plan 030"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/LKcS1jRj4Mq8V1zwMVhTNC, version 1793586367-8df2

## Context

Areas: area:runs, area:auth, area:health, area:challenges · 17 tasks.

Based on: [plan 003 Active tab](https://claude.ai/artifact/JpPAkKN7HnJJuYRny76M99), `docs/api/runs.md`, `docs/api/auth.md`, the idea-refine / interview-me session of 2026-10-28, and the interview-me session about health access of 2026-10-30.

Today the app syncs health data only while the user is on the Active tab (`active_challenges_page.dart`). There are three problems:

- **Missed data:** daily figures are sent for 2 days only (`SyncActivity.daysSent = 2`). A user who leaves the app for 3 days or more loses the older days.
- **Double counting:** step sync sends each record. When an iPhone and an Apple Watch (or two apps on Android) write the same period, the records have different `health_record_id` values, so the backend adds both.
- **Several devices:** one account can be signed in on several devices, and each device pushes its own data.
- **Health access blocks the whole Active tab:** without access to read steps, `ActiveChallengesPage` shows only `HealthGateView`, even the list of joined challenges. The app asks for access as soon as the tab opens, without context, and says nothing on the challenge screens when steps are not counted.

This plan does four things:

- **Hourly step sync:** the app sends the total steps of each hour, which the operating system has already merged across sources. The backend overwrites by hour, so sending again never counts twice.
- **Sync on app open and resume:** runs on every screen, catching up from the last sync, at most 30 days back.
- **One sign-in session per account:** signing in on a new device signs the old device out, and each hour belongs to the device that was signed in at that time.
- **Health access doesn't block the app:** a user who does not grant access can still use the app and join challenges. The app asks for access at the first challenge join, with an explainer screen, and afterwards only reminds passively with a banner. Turning access on later still catches up steps for at most 30 days thanks to the sync above.

### Decided by the user

- Neither kind of data may be missed: steps for challenges and daily figures.
- Catch up from the last sync, at most 30 days back.
- Sync on app open and when the app comes back from the background. No background sync yet.
- Double counting must be prevented when several sources write.
- Option B: hourly buckets, backend upsert, the watermark only as an optimization, sync running app-wide.
- The MVP supports phones only, with no separate Watch support.
- The newly signed-in device becomes the syncing device. The old device is signed out for good.
- A window of at most 15 minutes (the access token lifetime) for the old device to push its last data is accepted.
- Each hour belongs to the device signed in at that time. The new device writes only the hours from the moment it signed in.
- **Health access (2026-10-30):** access does not block the app and does not block joining a challenge; it only decides whether there is progress. A joined challenge without access shows "steps not tracked yet" with how to turn access on.
- Ask for access the first time at the first challenge join. The app's explainer screen has a **Continue** button (opens the system dialog) and **Not now** (still joins, not tracked yet).
- Passive reminders only: a banner on the card and the detail screen of a joined challenge. The explainer opens again by itself when joining a new challenge, at most once every 7 days. When asking is no longer possible, the banner leads to the Settings instructions. No push notification about access.
- On iOS, reading 0 steps for 3 days in a row while there is a challenge switches the banner to "Check access in Settings".
- Out of scope: entering steps by hand, push reminders about access, blocking the join without access, background sync, reading new kinds of data.
- Merge the health access part into plan 030, not a separate plan.
- **Steps in daily figures (2026-10-30):** the day's steps on the Active tab also leave out manual entries, like the steps counted for challenges. The `daily-activity` and `step-hours` routes stay separate.

### Prerequisites

**Before `/run-tasks`:** nothing. The plan has no new secret or key.

**Before task 7 and the integration tasks (a real device is needed):**

- **An iPhone with Apple Health, with step data for the last few days.** This is the plan's only real device. Expected result: the app's hourly step sum matches the day's total in the Health app.
- **The iOS Simulator on the Mac** plays the second device in task 12. Switching devices needs only a sign-in, no Health data.
- **Tasks 14–17 (health access) on the real iPhone:** delete the app and install it again so the iOS access dialog shows again from the start. Then try both the "Not now" and "Don't Allow" branches.

**Not verified in this plan** (recorded in the Evidence, does not block a task):

- **Android and Health Connect:** record `Not verified: no Android device`. The Android read path is checked only by tests with a fake `Health`.
- **Apple Watch and several sources on iOS:** record `Not verified: no Apple Watch`.

## Open questions and assumptions

You can answer by number, for example "change 1".

1. **Cutover, assumed to freeze the old numbers.** Each active enrollment gets `runs.hours_from`, equal to the next whole hour after the migration. Steps already counted from `step_samples` stay as they are. Hourly buckets count only from `hours_from` on. So nobody drops or is counted twice. The other way is to recompute everything from buckets, but that loses the steps of challenges that have run for more than 30 days.
2. **Hours in UTC.** `hour_start` is the start of a UTC hour. The app reads each range `[hour_start, hour_start + 1h)`. Half-hour time zones (for example +05:30) still add up correctly, they just don't line up with the "hours" in the Health app.
3. **Plausibility limit: more than 15,000 steps in one hour is ignored** (running fast at 200 steps per minute is only about 12,000).
4. **Read window:** from `watermark − 48h`, but not earlier than `now − 30 days` and not earlier than the earliest challenge join (`earliestRunJoin`). With no watermark yet (a new device, a reinstalled app), the app reads 30 days; the backend ignores the hours before `session_started_at` and `hours_from` by itself.
5. **Daily figures on a new device:** the backend does not filter the days before the sign-in. The app limits them itself by storing `firstSyncAt` per user on the device, and sends no day before it. Consequence: the first time after the app update, daily figures cannot catch up the days before the update. These figures don't count toward challenges.
6. **How to read by hour, needs a spike on a real device (task 7):**
   - iOS: use HealthKit's total (`getTotalStepsInInterval` with `includeManualEntry: false`). Apple has already merged the sources in priority order.
   - Android: Health Connect's aggregate cannot filter out manual entries. So the app reads the records that are not manual entries, sums them per source within each hour, and takes the **largest source**. This can undercount if the user switches devices in the middle of an hour, but never counts twice.

   If the spike shows the iOS way does not leave out manual entries, use the Android way on both platforms.
7. **The old endpoint `POST /api/v1/runs/steps`** stays for older app versions, but from `hours_from` on its samples are ignored (`ignored`). Removing this endpoint is left for a later plan.
8. **Telling the old device:** `POST /api/v1/auth/refresh` returns `401 session_replaced` when the refresh token was revoked by a newer sign-in (the token was created before `users.session_started_at`). The app shows "Your account was signed in on another device" on the Sign in screen. The old device reads the new error code like any other refresh error, so older app versions still work correctly.
9. **`session_started_at`** is set on sign up and sign in. Changing the password (`change_password`) and refresh don't change it, since it is still the same device.
10. **App-wide sync is a service, not a bloc.** `HealthSyncService` is a `@lazySingleton` that listens to `AppLifecycleListener` and `AuthRepository.sessionStarted`. No app-wide bloc is added, so the rule "only `AuthBloc` is app-wide" is not touched.
11. **5-minute throttle, one run at a time** (single-flight). The watermark advances only when every request succeeded.
12. **The reminder state is a `HealthNotice` enum** (`none`, `askable`, `settings`, `install`, `noSteps`), computed by the `GetHealthNotice` use case from `HealthRepository` and `RunsRepository`. It is a use case because it uses two repositories. `askable` means the system dialog can still show: iOS has never asked, or Android has asked fewer than 2 times (`HealthRepositoryImpl.androidDialogLimit`).
13. **The explainer says exactly what the app asks for.** The app asks for 4 kinds: steps (required), calories, distance, sleep (optional). So the explainer reuses the `_MetricList` list and `healthConsentNote` of `HealthGateView`, rather than saying "reads steps only". `Info.plist` (`NSHealthShareUsageDescription`) and the Health Connect rationale screen in `AndroidManifest.xml` already exist and don't change.
14. **Banner texts:** `askable` and `settings`: "Steps aren't tracked yet. Turn on Apple Health" (Android: "Health Connect"). `install`: "Install Health Connect to track your steps". `noSteps`: "No steps from Apple Health. Check access in Settings". The app's texts stay in English like the existing screens.
15. **"Shown at most once every 7 days"** stores the time the explainer was last shown in `HealthPromptStore` (secure storage, per device, not per user). Only a join opens this screen by itself; tapping the banner can always open it.
16. **`noSteps` applies only when the platform does not reveal access** (iOS after asking). `HealthAccess` gets a `confirmed` flag, false in that case. Condition: an active enrollment has counted steps for at least 3 days, and the last 3 days all read 0 steps.
17. **The challenges screens use widgets of the runs feature.** `HealthNoticeBanner` and `showHealthExplainer` live in `features/runs/presentation/`; `features/challenges` imports them, the way `home_shell.dart` imports runs today. They don't move to `lib/shared/`, because `shared` must not depend on a feature.
18. **Steps in daily figures are read by the same rule as `step-hours`.** Today `readDays` calls `getTotalStepsInInterval(from, to)`, which counts manual entries by default. After task 7, `readDays` reads steps without manual entries by assumption 6 (iOS: `includeManualEntry: false`; Android: the largest source of the records that are not manual entries). Result:
    - `daily_activity` never adds to progress: `progress.py` reads only `step_hours`, and `daily_activity` is for display only. So there is no double counting.
    - A day fully inside a challenge's period, with no steps before the join, shows on the Active tab the same number the challenge grew by that day, except for differences from UTC hour boundaries (assumption 2).
    - The number on the Active tab can be lower than in the Health app when the user enters steps by hand. Accepted.
    - No API or schema change. Calories, distance and sleep keep the same way of reading (still including manual entries). The day's figure is not computed from `step_hours` on the backend.

## Approach

### Backend

- **`app/modules/auth`:**
  - Add the column `users.session_started_at` (`timestamptz NOT NULL`, backfilled from `created_at`).
  - `AuthService.sign_in` reuses the refresh token lock it already takes in `_password_unchanged_after_lock` (calling `lock_user_refresh_tokens`, already on `develop`; no new lock), then calls `revoke_all_refresh_tokens`, sets `session_started_at = now`, and only then issues the new token pair.
  - `sign_up` sets `session_started_at = now`.
  - `refresh` tells apart a token revoked by a newer sign-in (`RefreshToken.created_at < users.session_started_at`) to raise `SessionReplacedError` (401 `session_replaced`).
- **`app/modules/runs`:**
  - New table `step_hours` (`run_id`, `hour_start`, `steps`, `updated_at`; unique `(run_id, hour_start)`).
  - Column `runs.hours_from` (nullable; the migration sets it for active and paused enrollments, a new enrollment sets it to the join time).
  - Route `PUT /api/v1/runs/step-hours` upserts each hour (`on_conflict_do_update`) and updates `runs.total_steps += new − old`.
  - The router passes `user.session_started_at` (from `CurrentUserDep`) to the service as a `datetime`. The runs module does not read the auth repository or models.
- **Layers:** router → service → repository. Repositories only query and `flush`; the service commits.

### Mobile

- **`features/runs/domain`:**
  - Add the `StepHour` entity.
  - `HealthRepository.readStepHours({from, to})`.
  - `RunsRepository.syncStepHours(List<StepHour>)`, sending at most 744 hours per request (31 days).
  - Rewrite `SyncActivity` to compute the window from the watermark, and send hourly buckets and daily figures in chunks of 7 days.
- **`features/runs/data`:** `SyncWatermarkStore` (per user id, in `shared_preferences` or the feature's existing storage), the remote data source, and the fake.
- **`features/runs/data/datasources/health_data_source.dart`:** read by hour as in assumption 6.
- **`HealthSyncService`:** the app-wide trigger. The Active tab calls this service instead of calling `SyncActivity` directly.
- **`features/auth`:** `sessionExpired` carries a reason (`expired` or `replaced`), and the Sign in screen shows the matching message.
- **Health access (tasks 13–17), mobile only, no API change:**
  - `features/runs/domain`: the `HealthNotice` enum, the `HealthAccess.confirmed` flag, `HealthRepository.explainerDue()` / `recordExplainerShown()`, the `GetHealthNotice` use case.
  - `features/runs/presentation`: `HealthNoticeBloc` (factory, created in the route's `BlocProvider`), `HealthNoticeBanner`, `HealthExplainerSheet`, `HealthSettingsSheet`, and the function `showHealthExplainer`. When access has just been granted, the bloc has `HealthSyncService` sync at once (skipping the throttle).
  - `features/challenges/presentation`: after a successful join, call `showHealthExplainer`; the card and detail screen of a joined challenge show the banner.
  - `ActiveChallengesPage`: remove the gate that blocks the whole tab. The My challenges tab always opens and has the banner; the Activity tab shows the content of `HealthGateView` in place of the figures.
  - No app-wide bloc is added. `HealthGateBloc` is still used for the Activity tab.

### API contract

- `docs/api/runs.md`: add `PUT /api/v1/runs/step-hours` and the examples `step_hours_request.json`, `step_hours_result.json`. Note that `POST /runs/steps` ignores samples from `hours_from` on.
- `docs/api/auth.md`: sign in revokes every other session; new error `401 session_replaced` on refresh, with the example `error_session_replaced.json`. This code's row in the "Error codes" table comes with task 4 (the task that serves the code), because the error contract tests require every row of the table to have a route that returns it.

### Changes the approval must cover (Phase 2 risk categories)

- **Public API:** add the route `PUT /api/v1/runs/step-hours`. The behaviour of `POST /api/v1/runs/steps` changes (samples after `hours_from` are ignored). Add the error code `session_replaced`. No breaking change for older app versions.
- **Schema:** add the columns `users.session_started_at` and `runs.hours_from`, add the table `step_hours`. No data is deleted. The downgrade drops the new columns and table.
- **Auth and security boundary:** sign in revokes every other refresh token of the user. Users signed in on several devices are signed out on the other devices.
- **Real data:** how challenge progress is counted changes from samples to hourly buckets, from `hours_from` on.
- **Health access (tasks 13–17):** does not touch the API, the schema or auth. It is a behaviour change in mobile that affects App Review (Guideline 5.1.1, HealthKit 2.5.1) and the Google Play Health Connect policy.

## Risks

- **Health Connect has no way to leave manual entries out of an aggregate.** Containment: take the largest source of the records that are not manual entries (assumption 6), with tests using a fake `Health`. There is no Android device to try it for real yet, so the Android path may be off on a real device. This risk is accepted until a device is available.
- **Reading 720 hours on cold start may be slow.** Containment: run in the background after the first screen shows. The first time can read by day first, then read by hour only the days that have steps. Task 7 measures the time on a real device.
- **Users signed in on two devices will be signed out on one after the deploy**, as soon as they sign in again on one device. This is the wanted behaviour but may surprise them. The `session_replaced` message explains why.
- **A race between sign in and refresh on the old device.** Containment: `sign_in` and `refresh` take the same lock on the user's refresh tokens, like `change_password` today.
- **The old device could overwrite the new device's hours during the 15 minutes.** It doesn't happen: the backend ignores the hours before `session_started_at`. The hours after that which the old device writes are the old device's real data, and the new device's next sync overwrites them.
- **A gap between `total_steps` and the sum of `step_hours`.** Containment: update by the difference `new − old` in the same transaction, with an integration test comparing the sums.
- **Rejection for forcing access.** Containment: no screen is blocked behind health access, the explainer always has **Not now**, no popup opens by itself outside a join (at most once every 7 days), and no push. If the reviewer still asks, a note for the reviewer explains that steps are the data that counts challenge progress.
- **`noSteps` reports wrongly** for someone who really didn't walk for 3 days. Containment: soft wording ("Check access"), only a banner, no popup; it disappears as soon as steps are read.
- **On iOS, a user who taps "Don't Allow" in the system dialog is still treated as `granted`** (HealthKit does not tell). The `noSteps` banner shows only after 3 days. This is an iOS limit, accepted.

## Verification

- **Backend:**
  - Unit tests (service with a mocked repository) and integration tests on PostgreSQL: upserting the same hour twice; hours before `session_started_at`, `hours_from` or outside the challenge window; an hour above 15,000 steps; the right progress total.
  - A second sign-in revokes the first one's tokens; the old refresh token returns `session_replaced`.
  - Migration up, down, up.
  - The hurl files `backend/hurl/runs.hurl` and `backend/hurl/auth.hurl`.
  - `ruff`, `mypy` and the full `pytest` (including `-m fuzz`).
- **Mobile:**
  - `flutter test` for `SyncActivity` (window from the watermark, 7-day chunks, the watermark doesn't advance on an error) and `HealthSyncService` (cold start, resume, throttle, single-flight, doesn't run when signed out).
  - The hourly data source with a fake `Health`.
  - `test/contract` for the fixtures.
  - `GetHealthNotice` for every state; the 7-day cadence with a fake clock; bloc tests for `HealthNoticeBloc`; widget tests for the join flow (Continue, Not now); goldens for the banner, both sheets, and the Active tab without access.
- **Real device (one iPhone):**
  - Compare the hourly sum with the Health app.
  - Set the watermark back 3 days, open the app again and see daily figures for all 3 days.
  - Sign in on the iOS Simulator and see the iPhone signed out with the message.
  - Install the app fresh, join a first challenge: the explainer shows. Tap "Not now": still joined, the banner shows. Tap the banner then "Continue", grant access: the banner disappears and steps are caught up.
- **Cannot be verified:** Android and Health Connect (`Not verified: no Android device`), Apple Watch and several sources on iOS (`Not verified: no Apple Watch`), the Watch's real delay (48 hours assumed to be enough), and users with several unusual apps writing steps.

## Ticket evidence

- **Backend / API (tasks 1–6):** sample requests and responses are in `docs/api/examples/runs/` and `docs/api/examples/auth/`, written by tasks 1 and 2.
- **Feature with UI (task 11):** no new design. The message uses the same existing `sessionExpired` banner on `sign_in_page.dart`, with different text only.
- **Health (task 7):** behaviour described in assumption 6; the evidence is the measurement on a real device.
- **App-wide sync (task 9):** no new UI. The behaviour is described in assumptions 4, 10 and 11.
- **Health access (tasks 13–17, feature with UI):** no Figma. The banner and both sheets follow the presentation of the existing `HealthGateView` (colors from the theme, `AppSpacing`, `AppRadius`). Behaviour described under "Decided by the user" and assumptions 12–17. The evidence is goldens and screenshots on the iPhone.

## Task breakdown

One task is one issue. Each backend endpoint is its own task.

Order:

```text
Start together: 1, 2, 7
1 → 3 → 4            (auth backend)
2, 3 → 5 → 6         (runs backend)
2, 7 → 8 → 9         (mobile sync, mock)
1 → 11               (mobile auth, mock)
Integration: 10 waits for 5 and 8; 12 waits for 4 and 11
13 → 14 → 15, 16     (health access; 14 also waits for 9; 15 and 16 both edit challenge_detail_page.dart, so run them one after the other)
9, 14 → 17           (Active tab without the gate)
In parallel: the auth chain (3, 4, 11, 12) and the runs chain (5, 6, 8, 9, 10); 13 can start at once
```

### Task 1: `[auth] docs: single session contract`

**Requirements**

- `docs/api/auth.md` describes that sign in revokes every other refresh token, and the `401 session_replaced` error of refresh, told apart from `invalid_refresh_token`.
- The "Error codes" table of `docs/api/auth.md` stays unchanged in this task; task 4 adds the `session_replaced` row. Reason: `test_every_documented_code_is_tested_here_or_in_the_auth_api_tests` requires every row of the table to be in `AUTH_MODULE_ERROR_CODES`. `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` cannot be used either, because `/api/v1/auth/refresh` already has a route (`test_codes_not_yet_served_have_no_route_yet`).

**Steps**

1. Edit `docs/api/auth.md`: the `POST /api/v1/auth/signin` and `POST /api/v1/auth/refresh` sections (including that section's error line) and the "Rotation" paragraph. Don't edit the "Error codes" table.
2. Add `docs/api/examples/auth/error_session_replaced.json`, shown in a block with the marker `<!-- example: auth/error_session_replaced.json -->` in the refresh section.

**Checklist**

- [ ] `docs/api/auth.md` says sign in revokes every other refresh token of the user and that other devices are signed out when their access token expires (15 minutes by default)
- [ ] The `POST /api/v1/auth/refresh` section of `docs/api/auth.md` lists `401 session_replaced` when the token was revoked by a newer sign-in, and the app shows "signed in on another device"; the "Error codes" table is unchanged (task 4 adds the row), so the backend contract tests still pass
- [ ] `docs/api/examples/auth/error_session_replaced.json` added, in a marked block of the refresh section

### Task 2: `[runs] docs: step-hours contract`

**Requirements**

- The contract of `PUT /api/v1/runs/step-hours` is as in assumptions 1–4: UTC hours, upsert, the ignore rules, at most 744 hours per request.

**Steps**

1. Add a `PUT /api/v1/runs/step-hours` section to `docs/api/runs.md`: the fields (`hour_start` is the start of a UTC hour, `steps` from 0 to 15,000 after ignoring), the counting rules (active enrollment, run, `hour_start ≥ max(starts_at, counting_from, hours_from, session_started_at)`, `hour_start + 1h ≤ ends_at` rounded up, not in the future), the response (`accepted`, `ignored`, `enrollments` as in step sync).
2. Note in the `POST /api/v1/runs/steps` section: samples with `start_time ≥ hours_from` are ignored.
3. Add `docs/api/examples/runs/step_hours_request.json` and `step_hours_result.json`.

**Checklist**

- [ ] `docs/api/runs.md` documents `PUT /api/v1/runs/step-hours`: fields, the counting rules, upsert by hour, at most 744 hours per request, `422 validation_error`
- [ ] `docs/api/runs.md` says `POST /api/v1/runs/steps` ignores samples starting at or after the enrollment's `hours_from`
- [ ] `docs/api/examples/runs/step_hours_request.json` and `step_hours_result.json` added

### Task 3: `[auth] feat: single session on POST /api/v1/auth/signin (backend)`

**Requirements**

- Sign in revokes every refresh token of the user before issuing a new pair, and sets `users.session_started_at`. Sign up sets `session_started_at` to the creation time.
- Lock in the same order as `change_password`, so a sign in and a refresh running together let no token slip through. `sign_in` already takes the `lock_user_refresh_tokens` lock in `_password_unchanged_after_lock`; revoking and setting `session_started_at` run after that lock, in the same transaction, with no new lock.

**Steps**

1. Migration in `backend/alembic/versions/`: add `users.session_started_at timestamptz NOT NULL`, backfilled from `created_at`.
2. Add the column to `backend/app/modules/auth/models.py`; update `AuthService.sign_up` and `AuthService.sign_in` in `service.py`.
3. Unit tests in `backend/tests/unit/` and integration tests in `backend/tests/integration/`: a second sign-in makes the first one's refresh token return `401`.
4. Update `backend/hurl/auth.hurl`.

**Checklist**

- [ ] Migration adds `users.session_started_at` (backfilled from `created_at`); up, down, up pass and `\d users` shows the column
- [ ] `POST /api/v1/auth/signin` revokes every other refresh token of the user and sets `session_started_at`; sign up sets it on creation; refresh and change password leave it unchanged
- [ ] Integration test: after a second sign-in, the first refresh token is rejected
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence
- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass

### Task 4: `[auth] feat: session_replaced on POST /api/v1/auth/refresh (backend)`

**Requirements**

- A refresh token that was revoked and has `created_at < users.session_started_at` returns `401 session_replaced`. Every other case keeps `invalid_refresh_token`. The error goes through `ErrorResponse` and the global handler.

**Steps**

1. Add `SessionReplacedError` to `backend/app/modules/auth/service.py`, and a query in `repository.py` that reads the revoked token with its owner's `session_started_at`.
2. Add the error to the route's `responses` in `router.py`.
3. Add the row ``| 401 | `session_replaced` | ... |`` to the "Error codes" table of `docs/api/auth.md`; add `"session_replaced"` to `AUTH_MODULE_ERROR_CODES` (`backend/tests/api_docs.py`) and to the `produced` set of `test_the_error_codes_this_file_produces_are_the_documented_ones` (`backend/tests/integration/test_auth_api.py`), with the name of the integration test that produces this code.
4. Unit tests, integration tests and `backend/hurl/auth.hurl`.

**Checklist**

- [ ] `POST /api/v1/auth/refresh` returns `401 session_replaced` for a token revoked by a newer sign-in, and `401 invalid_refresh_token` for an unknown, expired, used or signed-out token
- [ ] The response body equals `docs/api/examples/auth/error_session_replaced.json` in shape; `session_replaced` is a row of the "Error codes" table in `docs/api/auth.md`, in `AUTH_MODULE_ERROR_CODES`, and in the `produced` set of `test_auth_api.py`
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence
- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass

### Task 5: `[runs] feat: PUT /api/v1/runs/step-hours (backend)`

**Requirements**

- As in the contract of task 2. Upsert by `(run_id, hour_start)`; `runs.total_steps` changes by exactly `new − old` in the same transaction.
- The runs module gets `session_started_at` from the router (taken from `CurrentUserDep`), and does not read the auth repository or models.

**Steps**

1. Migration: the `step_hours` table (unique `uq_step_hours_run_hour`), the `runs.hours_from` column. Active and paused enrollments get the next whole hour after the migration. `EnrollmentService.join` sets `hours_from` to the join time.
2. `backend/app/modules/runs/`: the `StepHour` model, the schema in `schemas.py`, the rules in `validation.py`, the upsert in `repository.py`, `ProgressService.sync_step_hours` in `progress.py`, the route in `progress_router.py` with its access level in `ROUTE_ACCESS`.
3. Unit tests for the rules; integration tests for upserting twice, the ignored hours, and the `total_steps` sum.
4. Update `backend/hurl/runs.hurl`.

**Checklist**

- [ ] Migration adds `step_hours` and `runs.hours_from` (set for active and paused enrollments); up, down, up pass and `\d step_hours` shows the unique constraint
- [ ] `PUT /api/v1/runs/step-hours` is in `ROUTE_ACCESS` as an access-token route and follows `docs/api/runs.md`
- [ ] Sending the same hour twice counts it once; a higher value later replaces it and `total_steps` changes by the difference
- [ ] Hours before `session_started_at`, `hours_from`, `counting_from` or `starts_at`, after `ends_at`, in the future, or above 15,000 steps are ignored
- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/runs.hurl` updated and its output in the evidence
- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass

### Task 6: `[runs] fix: POST /api/v1/runs/steps stops counting after hours_from (backend)`

**Requirements**

- Older app versions can still call this route, but samples with `start_time ≥ hours_from` are counted as `ignored`, so they are not counted twice with the hourly buckets.

**Steps**

1. Add `hours_from` to `ChallengeRule` in `backend/app/modules/runs/validation.py`, and pass it in from `ProgressService.sync_steps`.
2. Unit tests for the new rule; integration test: one sample before and one sample after `hours_from`.
3. Update `backend/hurl/runs.hurl`.

**Checklist**

- [ ] `POST /api/v1/runs/steps` ignores a sample whose `start_time` is at or after the enrollment's `hours_from`, and still counts one before it
- [ ] Unit and integration tests, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes
- [ ] `backend/hurl/runs.hurl` updated and its output in the evidence
- [ ] `ruff`, `mypy` and the full `pytest` pass

### Task 7: `[health] feat: read hourly steps without duplicates (mobile)`

**Requirements**

- `HealthRepository.readStepHours({required DateTime from, required DateTime to})` returns one `StepHour` for each UTC hour with steps. No manual entries; several sources writing the same hour are not counted twice (assumption 6).
- `HealthRepository.readDays` reads steps by the same rule, without manual entries (assumption 18). Calories, distance and sleep don't change.
- The `domain/` layer stays pure Dart.

**Steps**

1. Add the `StepHour` entity to `mobile/lib/features/runs/domain/entities/activity.dart`, and the method to `health_repository.dart`.
2. Implement in `health_data_source.dart`: iOS uses the hourly total without manual entries; Android uses the largest source of the records that are not manual entries. Wrap errors as `HealthFailure` in `health_repository_impl.dart`. Switch the steps read path of `readDays` (`total(HealthMetric.steps, …)`) to the same way.
3. Tests with a fake `Health` in `mobile/test/features/runs/data/`: two overlapping sources, manual entries, empty hours, UTC boundaries.
4. Spike on a real iPhone: compare a day's total with the Health app, and measure the time to read 30 days. Android records `Not verified: no Android device`.

**Checklist**

- [ ] `HealthRepository.readStepHours` returns one `StepHour` per UTC hour with steps, without manual entries
- [ ] Test: two overlapping sources in one hour give the larger source's total, not the sum
- [ ] `HealthRepository.readDays` counts steps without manual entries, by the same rule as `readStepHours`: a test day with a manual entry gives the same steps as the sum of that day's `readStepHours` (whole-hour time zone); calories, distance and sleep are unchanged
- [ ] Evidence: on a real iPhone, the day's hourly sum matches the Health app's daily total, and reading 30 days takes under 3 s; Android: `Not verified: no Android device`
- [ ] `flutter analyze` and `flutter test` pass

### Task 8: `[runs] feat: catch-up step-hour sync (mobile, mock)`

**Requirements**

- The read window is computed by assumption 4. Daily figures are limited by `firstSyncAt` (assumption 5) and sent in chunks of 7 days. The watermark advances only when every request succeeded.
- Remove `SyncActivity.daysSent` and the per-record `syncSteps` send path.

**Steps**

1. Add `RunsRepository.syncStepHours`; implement it in `runs_remote_data_source.dart` by `docs/api/runs.md`, split into requests of at most 744 hours.
2. Add `SyncWatermarkStore` (the watermark and `firstSyncAt` per user id) in `mobile/lib/features/runs/data/datasources/`.
3. Rewrite `mobile/lib/features/runs/domain/usecases/sync_activity.dart`.
4. Fixtures in `FakeRunsRemoteDataSource` copied from `step_hours_request.json` and `step_hours_result.json`.
5. Tests for `SyncActivity`: app left for 3 days, no watermark, an error on the second request, more than 30 days. Add a contract test in `mobile/test/contract/`.

**Checklist**

- [ ] `SyncActivity` reads from `watermark − 48h`, at most 30 days back and not before the earliest run join; with no watermark it reads 30 days
- [ ] Daily figures cover every day from the window start (not before `firstSyncAt`) to today, sent in requests of at most 7 days
- [ ] The watermark advances only when every request succeeded
- [ ] `FakeRunsRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`
- [ ] Screenshot of the Active tab with `API_MODE=mock`; Integration row `Not verified: backend not merged`
- [ ] `flutter analyze` and `flutter test` pass

### Task 9: `[runs] feat: sync health data on app open and resume (mobile)`

**Requirements**

- `HealthSyncService` is a `@lazySingleton`, not a bloc. It runs `SyncActivity` on cold start (once there is a session), when the app comes back to the foreground, and when `sessionStarted` emits. It runs only when signed in and allowed to read steps. One run at a time, with a 5-minute throttle. The Active tab shares this service.

**Steps**

1. Add `mobile/lib/features/runs/data/health_sync_service.dart`, using `AppLifecycleListener`, `HealthRepository.checkAccess` and `AuthRepository.sessionStarted`; register it in `lib/core/di/`.
2. Start the service in `main.dart` or `app.dart`; change `active_challenges_page.dart` and `activity_bloc.dart` to use the service and listen to its result.
3. Tests with a fake clock: cold start, resume within 5 minutes (skipped), resume after 5 minutes (runs), two triggers at once (runs once), signed out (doesn't run).

**Checklist**

- [ ] `HealthSyncService` runs a sync on cold start, on resume and on `sessionStarted`, only when signed in with steps allowed
- [ ] Test: two triggers at once run one sync; a trigger within 5 minutes of a finished sync does nothing
- [ ] The Active tab no longer starts its own sync; it shows the service's result
- [ ] No new app-wide bloc; `HealthSyncService` is registered as `@lazySingleton`
- [ ] `flutter analyze` and `flutter test` pass

### Task 10: `[runs] feat: catch-up step-hour sync (mobile, integration)`

**Requirements**

- The app runs against the local backend, on a real device with Health data.

**Steps**

1. Run the app against the local backend; fix contract mismatches and the error mapping in `runs_remote_data_source.dart`.
2. Tests for the remote data source.
3. Try it: set the watermark back 3 days, open the app, then check `step_hours` and `daily_activity` in the database.

**Checklist**

- [ ] The app against the local backend: one success case (3 missed days synced, a second open sends nothing new to count) and `422 validation_error`
- [ ] Remote data source tests pass; `flutter analyze` and `flutter test` pass
- [ ] Integration gate: 5 is closed and `PUT /api/v1/runs/step-hours` is in `docs/api/openapi.json` on `develop`

### Task 11: `[auth] feat: signed in on another device message (mobile, mock)`

**Requirements**

- A refresh answered with `401 session_replaced` ends the session with the reason `replaced`. The Sign in screen shows "Your account was signed in on another device." in the existing banner. The `expired` reason keeps the current message. Colors and spacing come from the theme and `AppSpacing`.

**Steps**

1. Change `AuthRepository.sessionExpired` to a stream carrying a reason (`SessionEndReason`); update `auth_repository_impl.dart`, `auth_bloc.dart` (`AuthUnauthenticated`) and `sign_in_page.dart`.
2. Map `session_replaced` in `auth_remote_data_source.dart`; add a fixture to `FakeAuthRemoteDataSource`.
3. Bloc, widget and golden tests of the Sign in screen with the new banner, at 375×667 and 430×932 with text scale 1.0 and 2.0.

**Checklist**

- [ ] A refresh answered with `401 session_replaced` ends the session with reason `replaced` and the Sign in screen shows the "signed in on another device" message; other refresh errors keep the current message
- [ ] Goldens of the Sign in screen with the new message at 375×667 and 430×932, text scale 1.0 and 2.0
- [ ] `FakeAuthRemoteDataSource` fixture equal to `error_session_replaced.json`, checked in `test/contract`
- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`
- [ ] `flutter analyze` and `flutter test` pass

### Task 12: `[auth] feat: signed in on another device message (mobile, integration)`

**Requirements**

- A real iPhone (device A) and the iOS Simulator (device B) against the local backend: signing in on device B signs device A out with the message, within the access token lifetime.

**Steps**

1. Run the app on the iPhone and on the iOS Simulator against the local backend; `ACCESS_TOKEN_TTL_MINUTES=1` can be set to try it quickly.
2. Fix contract mismatches; add tests for the remote data source.

**Checklist**

- [ ] The app against the local backend: signing in on device B signs device A out with the "signed in on another device" message, and `invalid_refresh_token` still shows the current message
- [ ] Remote data source tests pass; `flutter analyze` and `flutter test` pass
- [ ] Integration gate: 4 is closed and `session_replaced` is in `docs/api/openapi.json` on `develop`

### Task 13: `[health] feat: health notice for challenges (mobile)`

**Requirements**

- The `GetHealthNotice` use case returns a `HealthNotice` by assumptions 12 and 16, using `HealthRepository` and `RunsRepository`.
- The explainer's 7-day cadence by assumption 15, stored in `HealthPromptStore`.
- The `domain/` layer stays pure Dart. No UI.

**Steps**

1. Add `HealthNotice` and the `confirmed` flag to `mobile/lib/features/runs/domain/entities/health_access.dart`; add `explainerDue()` and `recordExplainerShown()` to `health_repository.dart`.
2. Implement in `health_repository_impl.dart` (set `confirmed` to false in the `allowed == null` branch) and `health_prompt_store.dart` (add a key that stores the time).
3. Add `mobile/lib/features/runs/domain/usecases/get_health_notice.dart`.
4. Tests with a fake clock and fake repositories: every state, the 3-day boundary, the 7-day boundary, an app restart.

**Checklist**

- [ ] `GetHealthNotice` returns `askable` when steps are not allowed and the system dialog can still be shown, `settings` when it cannot, `install` when Health Connect is missing or too old, and `none` when steps are allowed
- [ ] When the platform cannot confirm access (iOS after the dialog was shown), it returns `noSteps` if an active enrollment has counted steps for at least 3 days and each of the last 3 days read 0 steps
- [ ] `HealthRepository.explainerDue()` is true at most once every 7 days after `recordExplainerShown()`, and the time survives an app restart
- [ ] `domain/` stays pure Dart; `flutter analyze` and `flutter test` pass

### Task 14: `[health] feat: health notice banner (mobile)`

**Requirements**

- `HealthNoticeBanner` and `HealthNoticeBloc` (`@injectable`, created in the route's `BlocProvider`) by assumption 14, with `HealthExplainerSheet`, `HealthSettingsSheet` and the function `showHealthExplainer` for task 15 to reuse.
- The explainer reuses `_MetricList` and `healthConsentNote` (assumption 13). Colors, text and spacing come from the theme, `AppSpacing` and `AppRadius`.
- When access has just been granted, `HealthSyncService` syncs at once, without waiting for the 5-minute throttle.

**Steps**

1. Add `mobile/lib/features/runs/presentation/bloc/health_notice_bloc.dart` (with its event and state).
2. Add `health_notice_banner.dart` and `health_sheets.dart` (`HealthExplainerSheet`, `HealthSettingsSheet`, `showHealthExplainer`) in `mobile/lib/features/runs/presentation/widgets/`; move `_MetricList` out of `health_gate_view.dart` as `HealthMetricList` so both places share it.
3. Add `syncNow()` (skips the throttle, still single-flight) to `health_sync_service.dart`.
4. Bloc tests, widget tests and goldens.

**Checklist**

- [ ] `HealthNoticeBanner` shows nothing for `none`, and one line with an action for `askable`, `settings`, `install` and `noSteps`, with the texts of assumption 14
- [ ] For `askable` it opens `HealthExplainerSheet` (why, the four metrics with steps required, **Continue** and **Not now**); **Continue** shows the system dialog, and once steps are allowed the banner disappears and `HealthSyncService` syncs at once
- [ ] For `settings` and `noSteps` it opens `HealthSettingsSheet` with **Open settings**; for `install` it opens the Health Connect store page; the banner checks again when the app resumes
- [ ] Goldens of the banner and both sheets at 375×667 and 430×932, text scale 1.0 and 2.0
- [ ] `flutter analyze` and `flutter test` pass

### Task 15: `[challenges] feat: health explainer on first join (mobile)`

**Requirements**

- After a successful join (from the card or the detail screen), call `showHealthExplainer` from task 14. The screen opens by itself only when the notice is `askable` and `explainerDue()` is true.
- The join never waits for or depends on the answer about access.

**Steps**

1. In `mobile/lib/features/challenges/presentation/pages/challenges_page.dart` and `challenge_detail_page.dart`, add a listener for a successful join that calls `showHealthExplainer`.
2. Call `recordExplainerShown()` every time the sheet opens, whichever button is tapped.
3. Widget tests: a join when `askable` (both buttons), a join with access already granted, a second join within 7 days.

**Checklist**

- [ ] After a join succeeds from a challenge card or the detail screen, `HealthExplainerSheet` opens when the notice is `askable` and `explainerDue()` is true; otherwise nothing opens
- [ ] **Not now** closes the sheet and the user stays joined; **Continue** shows the system dialog; either way the sheet does not open by itself again for 7 days
- [ ] The join request never waits for, or depends on, the health answer
- [ ] `flutter analyze` and `flutter test` pass

### Task 16: `[challenges] feat: health notice on joined challenges (mobile)`

**Requirements**

- The card of a joined challenge (Joined or Paused) and its detail screen show `HealthNoticeBanner` when the notice is not `none`. A challenge that is not joined shows no banner.

**Steps**

1. Add the banner to `mobile/lib/features/challenges/presentation/widgets/challenge_card.dart` and `pages/challenge_detail_page.dart`; provide `HealthNoticeBloc` in the route's `BlocProvider`.
2. Widget tests and goldens.

**Checklist**

- [ ] A joined or paused challenge's card and its detail screen show `HealthNoticeBanner` when the notice is not `none`; a challenge the user has not joined shows no banner
- [ ] Goldens of a joined card and the detail screen with the banner at 375×667 and 430×932, text scale 1.0 and 2.0
- [ ] `flutter analyze` and `flutter test` pass

### Task 17: `[runs] feat: Active tab opens without health access (mobile)`

**Requirements**

- `ActiveChallengesPage` no longer blocks the whole tab. The My challenges tab always opens, with `HealthNoticeBanner` above the list.
- The Activity tab shows the content of `HealthGateView` (without its own `Scaffold`) until steps can be read. `HealthGateBloc` stays as it is.

**Steps**

1. Edit `mobile/lib/features/runs/presentation/pages/active_challenges_page.dart`, `widgets/active_tabs.dart`, `widgets/activity_tab.dart`, `widgets/my_challenges_tab.dart` and `widgets/health_gate_view.dart`.
2. Widget tests: opening the tab without access, coming back from Settings with access. Goldens of both tabs without access.

**Checklist**

- [ ] The Active tab opens whatever the health access; **My challenges** lists the user's challenges with `HealthNoticeBanner` above the list when the notice is not `none`
- [ ] The **Activity** tab shows the health gate (title, message, metric list, one button) in place of the figures until steps are allowed
- [ ] Coming back from Settings with steps allowed shows the figures without leaving the tab
- [ ] Goldens of both tabs without health access at 375×667 and 430×932, text scale 1.0 and 2.0
- [ ] `flutter analyze` and `flutter test` pass

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[auth] docs: single session contract` | docs, area:auth | - [ ] `docs/api/auth.md` says sign in revokes every other refresh token of the user and that other devices are signed out when their access token expires (15 minutes by default)<br>- [ ] The `POST /api/v1/auth/refresh` section of `docs/api/auth.md` lists `401 session_replaced` when the token was revoked by a newer sign-in, and the app shows "signed in on another device"; the "Error codes" table is unchanged (task 4 adds the row), so the backend contract tests still pass<br>- [ ] `docs/api/examples/auth/error_session_replaced.json` added, in a marked block of the refresh section | none |
| 2 | `[runs] docs: step-hours contract` | docs, area:runs | - [ ] `docs/api/runs.md` documents `PUT /api/v1/runs/step-hours`: fields, the counting rules, upsert by hour, at most 744 hours per request, `422 validation_error`<br>- [ ] `docs/api/runs.md` says `POST /api/v1/runs/steps` ignores samples starting at or after the enrollment's `hours_from`<br>- [ ] `docs/api/examples/runs/step_hours_request.json` and `step_hours_result.json` added | none |
| 3 | `[auth] feat: single session on POST /api/v1/auth/signin (backend)` | backend, area:auth | - [ ] Migration adds `users.session_started_at` (backfilled from `created_at`); up, down, up pass and `\d users` shows the column<br>- [ ] `POST /api/v1/auth/signin` revokes every other refresh token of the user and sets `session_started_at`; sign up sets it on creation; refresh and change password leave it unchanged<br>- [ ] Integration test: after a second sign-in, the first refresh token is rejected<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence<br>- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass | 1 |
| 4 | `[auth] feat: session_replaced on POST /api/v1/auth/refresh (backend)` | backend, area:auth | - [ ] `POST /api/v1/auth/refresh` returns `401 session_replaced` for a token revoked by a newer sign-in, and `401 invalid_refresh_token` for an unknown, expired, used or signed-out token<br>- [ ] The response body equals `docs/api/examples/auth/error_session_replaced.json` in shape; `session_replaced` is a row of the "Error codes" table in `docs/api/auth.md`, in `AUTH_MODULE_ERROR_CODES`, and in the `produced` set of `test_auth_api.py`<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/auth.hurl` updated and its output in the evidence<br>- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass | 1, 3 |
| 5 | `[runs] feat: PUT /api/v1/runs/step-hours (backend)` | backend, area:runs | - [ ] Migration adds `step_hours` and `runs.hours_from` (set for active and paused enrollments); up, down, up pass and `\d step_hours` shows the unique constraint<br>- [ ] `PUT /api/v1/runs/step-hours` is in `ROUTE_ACCESS` as an access-token route and follows `docs/api/runs.md`<br>- [ ] Sending the same hour twice counts it once; a higher value later replaces it and `total_steps` changes by the difference<br>- [ ] Hours before `session_started_at`, `hours_from`, `counting_from` or `starts_at`, after `ends_at`, in the future, or above 15,000 steps are ignored<br>- [ ] Unit and integration tests, auth sweep, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/runs.hurl` updated and its output in the evidence<br>- [ ] `docs/api/openapi.json` updated; `ruff`, `mypy` and the full `pytest` pass | 2, 3 |
| 6 | `[runs] fix: POST /api/v1/runs/steps stops counting after hours_from (backend)` | backend, area:runs | - [ ] `POST /api/v1/runs/steps` ignores a sample whose `start_time` is at or after the enrollment's `hours_from`, and still counts one before it<br>- [ ] Unit and integration tests, contract and OpenAPI snapshot tests pass; `pytest -m fuzz` passes<br>- [ ] `backend/hurl/runs.hurl` updated and its output in the evidence<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | 5 |
| 7 | `[health] feat: read hourly steps without duplicates (mobile)` | frontend, area:health | - [ ] `HealthRepository.readStepHours` returns one `StepHour` per UTC hour with steps, without manual entries<br>- [ ] Test: two overlapping sources in one hour give the larger source's total, not the sum<br>- [ ] `HealthRepository.readDays` counts steps without manual entries, by the same rule as `readStepHours`: a test day with a manual entry gives the same steps as the sum of that day's `readStepHours` (whole-hour time zone); calories, distance and sleep are unchanged<br>- [ ] Evidence: on a real iPhone, the day's hourly sum matches the Health app's daily total, and reading 30 days takes under 3 s; Android: `Not verified: no Android device`<br>- [ ] `flutter analyze` and `flutter test` pass | none |
| 8 | `[runs] feat: catch-up step-hour sync (mobile, mock)` | frontend, mock, area:runs | - [ ] `SyncActivity` reads from `watermark − 48h`, at most 30 days back and not before the earliest run join; with no watermark it reads 30 days<br>- [ ] Daily figures cover every day from the window start (not before `firstSyncAt`) to today, sent in requests of at most 7 days<br>- [ ] The watermark advances only when every request succeeded<br>- [ ] `FakeRunsRemoteDataSource` with fixtures equal to the examples, checked in `test/contract`<br>- [ ] Screenshot of the Active tab with `API_MODE=mock`; Integration row `Not verified: backend not merged`<br>- [ ] `flutter analyze` and `flutter test` pass | 2, 7 |
| 9 | `[runs] feat: sync health data on app open and resume (mobile)` | frontend, area:runs | - [ ] `HealthSyncService` runs a sync on cold start, on resume and on `sessionStarted`, only when signed in with steps allowed<br>- [ ] Test: two triggers at once run one sync; a trigger within 5 minutes of a finished sync does nothing<br>- [ ] The Active tab no longer starts its own sync; it shows the service's result<br>- [ ] No new app-wide bloc; `HealthSyncService` is registered as `@lazySingleton`<br>- [ ] `flutter analyze` and `flutter test` pass | 8 |
| 10 | `[runs] feat: catch-up step-hour sync (mobile, integration)` | frontend, integration, area:runs | - [ ] The app against the local backend: one success case (3 missed days synced, a second open sends nothing new to count) and `422 validation_error`<br>- [ ] Remote data source tests pass; `flutter analyze` and `flutter test` pass<br>- [ ] Integration gate: 5 is closed and `PUT /api/v1/runs/step-hours` is in `docs/api/openapi.json` on `develop` | 5, 8 |
| 11 | `[auth] feat: signed in on another device message (mobile, mock)` | frontend, mock, area:auth | - [ ] A refresh answered with `401 session_replaced` ends the session with reason `replaced` and the Sign in screen shows the "signed in on another device" message; other refresh errors keep the current message<br>- [ ] Goldens of the Sign in screen with the new message at 375×667 and 430×932, text scale 1.0 and 2.0<br>- [ ] `FakeAuthRemoteDataSource` fixture equal to `error_session_replaced.json`, checked in `test/contract`<br>- [ ] Screenshot with `API_MODE=mock`; Integration row `Not verified: backend not merged`<br>- [ ] `flutter analyze` and `flutter test` pass | 1 |
| 12 | `[auth] feat: signed in on another device message (mobile, integration)` | frontend, integration, area:auth | - [ ] The app against the local backend: signing in on device B signs device A out with the "signed in on another device" message, and `invalid_refresh_token` still shows the current message<br>- [ ] Remote data source tests pass; `flutter analyze` and `flutter test` pass<br>- [ ] Integration gate: 4 is closed and `session_replaced` is in `docs/api/openapi.json` on `develop` | 4, 11 |
| 13 | `[health] feat: health notice for challenges (mobile)` | frontend, area:health | - [ ] `GetHealthNotice` returns `askable` when steps are not allowed and the system dialog can still be shown, `settings` when it cannot, `install` when Health Connect is missing or too old, and `none` when steps are allowed<br>- [ ] When the platform cannot confirm access (iOS after the dialog was shown), it returns `noSteps` if an active enrollment has counted steps for at least 3 days and each of the last 3 days read 0 steps<br>- [ ] `HealthRepository.explainerDue()` is true at most once every 7 days after `recordExplainerShown()`, and the time survives an app restart<br>- [ ] `domain/` stays pure Dart; `flutter analyze` and `flutter test` pass | none |
| 14 | `[health] feat: health notice banner (mobile)` | frontend, area:health | - [ ] `HealthNoticeBanner` shows nothing for `none`, and one line with an action for `askable`, `settings`, `install` and `noSteps`, with the texts of assumption 14<br>- [ ] For `askable` it opens `HealthExplainerSheet` (why, the four metrics with steps required, **Continue** and **Not now**); **Continue** shows the system dialog, and once steps are allowed the banner disappears and `HealthSyncService` syncs at once<br>- [ ] For `settings` and `noSteps` it opens `HealthSettingsSheet` with **Open settings**; for `install` it opens the Health Connect store page; the banner checks again when the app resumes<br>- [ ] Goldens of the banner and both sheets at 375×667 and 430×932, text scale 1.0 and 2.0<br>- [ ] `flutter analyze` and `flutter test` pass | 9, 13 |
| 15 | `[challenges] feat: health explainer on first join (mobile)` | frontend, area:challenges | - [ ] After a join succeeds from a challenge card or the detail screen, `HealthExplainerSheet` opens when the notice is `askable` and `explainerDue()` is true; otherwise nothing opens<br>- [ ] **Not now** closes the sheet and the user stays joined; **Continue** shows the system dialog; either way the sheet does not open by itself again for 7 days<br>- [ ] The join request never waits for, or depends on, the health answer<br>- [ ] `flutter analyze` and `flutter test` pass | 14 |
| 16 | `[challenges] feat: health notice on joined challenges (mobile)` | frontend, area:challenges | - [ ] A joined or paused challenge's card and its detail screen show `HealthNoticeBanner` when the notice is not `none`; a challenge the user has not joined shows no banner<br>- [ ] Goldens of a joined card and the detail screen with the banner at 375×667 and 430×932, text scale 1.0 and 2.0<br>- [ ] `flutter analyze` and `flutter test` pass | 14 |
| 17 | `[runs] feat: Active tab opens without health access (mobile)` | frontend, area:runs | - [ ] The Active tab opens whatever the health access; **My challenges** lists the user's challenges with `HealthNoticeBanner` above the list when the notice is not `none`<br>- [ ] The **Activity** tab shows the health gate (title, message, metric list, one button) in place of the figures until steps are allowed<br>- [ ] Coming back from Settings with steps allowed shows the figures without leaving the tab<br>- [ ] Goldens of both tabs without health access at 375×667 and 430×932, text scale 1.0 and 2.0<br>- [ ] `flutter analyze` and `flutter test` pass | 9, 14 |
