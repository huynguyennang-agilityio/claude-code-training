# Plan 003: Active tab, health data access and challenge progress

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

The Active tab is a placeholder. This plan builds it: the user must allow health data before the tab opens, the tab shows today's activity (steps, calories, distance, sleep) with a manual **Refresh data** button that syncs the data to the backend, and a second tab lists the challenges the user has joined and that are in progress, with progress.

This is the first plan that reads **Apple Health** (iOS) and **Health Connect** (Android) and the first that **counts progress** on the backend. Plan 001 left both out. Finishing a challenge and awarding medals (the Medals tab) stay for a later plan.

### Design

There is no Figma frame yet, so the design is part of this plan: [`docs/designs/003-active-tab.html`](../designs/003-active-tab.html) (open it in a browser) and its picture [`docs/designs/003-active-tab.png`](../designs/003-active-tab.png). It shows six frames: the health gate, the Active tab (success, and with optional metrics refused plus a failed sync), My Challenges (list and empty), and the challenge detail before the start (no Pause). It uses only the tokens of the app theme (dark theme, Lime, `AppSpacing`, `AppRadius`). The layout is inspired by three screenshots of another app that the user sent in chat; **they are a layout reference only**, and none of their artwork, copy or colours is reused or committed. If the user prefers the design in Figma, it can be rebuilt there from this file.

### Decided by the user

- Opening the Active tab **requires health access**. Without it the user cannot get past the tab, and a message says that without health data the app cannot track progress for challenges.
- The page has **two tabs**: **Active** and **My Challenges**.
- **Active** shows steps, calories, distance and sleep time. **Steps is mandatory**; the others are optional. At the bottom there is a **Refresh data** button, a manual sync.
- **Steps, calories, distance and sleep time are all sent to the backend** (not only shown on the device).
- **My Challenges** lists the challenges the user has joined and that are in progress. **No History tab.**
- A challenge that is **joined but not started has no Pause**.

## Open questions and assumptions

Each has the answer the plan assumes; say if one is wrong.

1. **Which challenges count progress now?** Assumed: **run** challenges (steps) only. Swim and cycle count distance from workouts, which needs workout reading, another health permission and a second kind of sample. Their cards show "Progress for swim comes soon" and no percentage. A later plan adds them.
2. **Does a pause stop counting?** Assumed yes. A new nullable column `runs.counting_from` is set on join and on resume; samples that start before it are ignored, so samples taken while paused never count, even if synced later.
3. **When does a sync run?** Assumed: when the Active tab opens and when the user taps **Refresh data**. No background sync yet.
4. **What exactly is sent?** Two kinds of data, both only for metrics the user allowed: (a) **step samples** (one per health record) that count toward challenges, and (b) a **daily summary** per day (steps, calories, distance in metres, sleep in minutes). The summary is for the last 7 days at most per request. Sleep is sent as the total asleep for the night that ends on that day.
5. **What is in My Challenges?** The user's `active` and `paused` enrollments, including a challenge that **has not started yet** (card shows "Starts &lt;date&gt;" and no progress). A challenge the user left is not listed.
6. **"No Pause before the start" is enforced by the backend too**, not only hidden in the app: `POST /challenges/{id}/pause` before `starts_at` answers `409 challenge_not_started`. This adds an error code to an existing route of plan 001 (see Approach).
7. **Manual entries:** Apple Health and Health Connect let a person type steps by hand. Assumed: the app **ignores manual entries** when the plugin reports the recording method. Real anti-cheat (issue #6) is separate.
8. **A new dependency:** the `health` package (Flutter) for both platforms.

## Approach

### Health access and the gate (mobile)

- `features/runs/data/datasources/health_data_source.dart` is the only place that touches the plugin, behind a domain interface `HealthRepository` in `features/runs/domain`. Everything else (bloc, tests) uses the interface, so tests never need a device.
- Permissions: **steps** (required), **calories, distance, sleep** (optional), asked in one request.
- Gate states on the Active tab: `unknown` (checking, spinner), `granted` (the tabs), `denied` (full-page message and **Allow access**), `permanentlyDenied` (the message and **Open settings**), `unavailable` (Health Connect missing or not supported: the message and **Install Health Connect**). The message says that without health data the app cannot track progress for challenges. The gate also says plainly that steps, calories, distance and sleep time are **sent to StrideQuest**, and that this can be changed in Settings; that is the user's consent for sending health data.
- **iOS cannot tell whether a read permission was refused** (HealthKit hides it). The plugin only reports that the request was shown. The app treats a user with no readable steps as `denied` only after a check read; a user who really has 0 steps today is `granted`. This is a known limit and Verification says what is and is not checked.
- Android: Health Connect permissions in the manifest, the privacy-rationale activity Health Connect requires, and the minimum SDK the plugin needs. iOS: the HealthKit capability and the usage-description strings in `Info.plist`.

### Mobile screens (`features/runs`; the Active page moves out of `features/challenges`)

- **Active page** (`/active`, a top-level tab as today): a tab bar with **Active** and **My Challenges**. Blocs are created in the route's `BlocProvider`: `HealthAccessBloc` (the gate, the readings, the refresh and the sync) and `MyChallengesBloc` (the list). Neither touches `AuthBloc`.
- **Active tab:** 2×2 tiles (Steps, Calories, Distance, Sleep) with icon, value, unit and "Today at hh:mm". A refused optional metric shows "Not allowed" and is not sent. **Refresh data** is fixed at the bottom; while it works it reads "Syncing…" and takes the disabled style; on failure a banner says what failed and the old values stay.
- **My Challenges tab:** a card per challenge: cover, type tag, title, dates, and: for a run challenge in progress a bar, "Goal n%" and the amount; for one not started "Starts &lt;date&gt;"; for swim and cycle the note from question 1; **Paused** when paused. A card opens `/challenges/:id`. States: loading, empty ("No challenge in progress", with **Browse challenges**), error with **Try again**, success; cursor paging.
- **Challenge detail:** the action bar shows **Leave** only, with the line "You joined. Steps count from &lt;date&gt;.", while `now < startsAt`. From the start on it is **Pause** and **Leave** as before.
- Colours, text styles, spacing and radii come from the theme and `app_tokens.dart`; a value the scale lacks is added there.

### Backend (`runs` module, and one rule in `challenges`/`runs` enrollments)

Contract in a new `docs/api/runs.md` with examples under `docs/api/examples/runs/`; the pause error is added to `docs/api/challenges.md`.

| Endpoint | Who | Purpose |
| --- | --- | --- |
| `POST /api/v1/runs/steps` | user | Body: up to 500 step samples `{health_record_id, start_time, end_time, steps}`. For each of the caller's **active run** enrollments whose window and `counting_from` the sample fits, the sample is stored once (unique `(run_id, health_record_id)`, already in the schema) and `total_steps` is updated. Answers with how many samples were accepted and the caller's progress per enrollment. `422 validation_error` for a bad body |
| `PUT /api/v1/runs/daily-activity` | user | Body: 1 to 7 daily summaries `{date, steps, calories_kcal, distance_m, sleep_minutes}`; each field except `date` is optional (a refused metric is left out). Replaces the caller's row for each date (idempotent). `422` for a bad body, a future date or a negative value |
| `GET /api/v1/runs` | user | The caller's `active` and `paused` enrollments, soonest start first, with the challenge card fields and `progress` (`current_value`, `target_value`, `percent` 0 to 100, `tracked`: false for swim and cycle, `started`). Cursor paging as the challenges list |
| `POST /api/v1/challenges/{id}/pause` | user | Existing route; now also `409 challenge_not_started` before `starts_at` |

Rules, in the `runs` service:

- A step sample counts for an enrollment when the enrollment is `active`, `start_time >= counting_from`, `start_time >= challenge.starts_at` and `end_time <= min(challenge.ends_at, now + 5 minutes)`. The upper bound uses the server clock so a device with a wrong clock cannot count steps from the future.
- `steps` is 1 to 100,000 per sample, `end_time >= start_time`, and a sample longer than 24 hours is refused. A sample sent twice counts once per enrollment. Only run challenges count in this plan, and the database forbids two active run challenges with overlapping windows, so a sample counts for at most one enrollment today.
- The daily summary has limits: `steps` up to 200,000, `calories_kcal` up to 50,000, `distance_m` up to 500,000, `sleep_minutes` up to 1,440, and a `date` not after the server's today plus one day (time zones).
- The `challenges` module keeps reading enrollments through `RunReads`; `runs` does not import another module's repository. A response that nests rows has a fixed query count (a test shows it).

### Schema (one Alembic migration, data-preserving, tested up, down, up)

- `runs.counting_from` (`timestamptz`, nullable; existing rows are set to `joined_at`). Join and resume set it to now; pause and leave do not.
- New table `daily_activity`: `user_id` (UUID, FK to `users.id`, `ON DELETE CASCADE`), `day` (date), `steps`, `calories_kcal`, `distance_m`, `sleep_minutes` (integers, all nullable because a refused metric is left out, each with a `>= 0` check), `updated_at`; primary key `(user_id, day)`.
- An index on `step_samples (run_id, start_time)` if the progress query needs it (checked with `EXPLAIN` in the issue).

### Touches the approval must cover

- **A new dependency:** `health` (Flutter), plus iOS and Android platform configuration for health data.
- **A public API change:** three new routes, and a new error on an existing route (`challenge_not_started` on pause).
- **A schema change:** a column, a table and an index.
- **Privacy and security:** this plan sends **health data** (steps, calories, distance, sleep) to the backend. It is stored per user in `daily_activity` and `step_samples`, only for metrics the user allowed, behind the user's JWT, never logged, deleted with the user (cascade), and the gate tells the user it is sent. Sleep and calories are sensitive; if the user does not want them stored, say so and they come out of the plan. The routes are `user`-level and declared in `ROUTE_ACCESS`.

## Risks

- **iOS hides read denial** (above). The user could be treated as allowed with no data. Mitigation: the check read, a clear empty state, and re-checking the gate every time the tab opens.
- **Manual or duplicated steps** inflate progress. Mitigation: ignore manual entries when the plugin says so, count a record once, window and sanity limits on the server. Not full anti-cheat (issue #6).
- **Sensitive data stored.** Mitigation: only allowed metrics are sent, cascade delete, no logging of the bodies, explicit consent text on the gate. A retention rule and a way to export or delete one's data are not in this plan; they need their own plan before any release.
- **Health Connect is not on every Android phone** (a separate app before Android 14). The `unavailable` state handles it.
- **Many samples per day** make large uploads. Mitigation: hourly-bucketed steps, requests of at most 500, and reading only from the earliest `counting_from` of the user's active run enrollments.
- **Clock skew or a changed time zone.** Mitigation: all sample times are UTC instants and the server bounds them with its own clock; daily summaries use the device's local date and are accepted up to one day ahead.
- **Cannot be checked without a real phone:** real sensor accuracy, Apple Watch and other sources, background delivery and the real permission dialogs on each Android maker. See Verification.

## Verification

- **Backend:** unit tests for the counting rules (window, `counting_from`, duplicates, the future bound, paused, left, wrong type) and the daily-summary limits; integration tests for the routes including the ownership case (another user's data never appears) and the query count; the pause-before-start error with a test per state; `pytest tests/unit/test_auth_sweep.py` with the new routes declared `user`; contract, example and OpenAPI snapshot tests; `pytest -m fuzz`; `backend/hurl/runs.hurl` with its `run.sh` output; migration up, down, up with `\d runs` and `\d daily_activity`.
- **Mobile logic:** bloc tests for every gate state, the refresh and both syncs (steps and daily summary) with a fake `HealthRepository`; a repository test with a fake HTTP adapter; the contract test over the new examples; a test that a refused metric is not sent.
- **Mobile screens:** page tests with `pumpScreen` and `expectAccessible` (375×667 and 430×932, text scale 1.0 and 2.0) for each state: the gate (denied, permanently denied, unavailable), Active (loading, success, partial permissions, sync error), My Challenges (loading, empty, error, success, not started, paused, swim without progress), and the detail action bar before and after the start. Goldens with `goldenScreen`, compared with `docs/designs/003-active-tab.png`.
- **Integration:** `integration_test` against the local backend with a **fake health source**: join a run challenge, open Active, Refresh data, see the progress rise in My Challenges.
- **iOS Simulator:** it has HealthKit and the Health app, so a step sample can be added there by hand and the real plugin path (permission request, read, sync) exercised; screenshots attached. **Android emulator** with Health Connect (API 34 and later) in the same way, if one is available.
- **Not verified, and said so in the MR:** real sensor accuracy, Apple Watch and multi-source de-duplication, background delivery, and the permission dialogs on real devices. The user runs a short checklist on a real phone once (written into the last issue): allow, deny, deny for good then Open settings, revoke in Settings and reopen the tab, walk and refresh.

## Ticket evidence

- `ui` and feature-with-UI issues: the design in this plan (`docs/designs/003-active-tab.html` and `.png`), the states and sizes listed under Verification. The three reference screenshots were sent in chat and are not committed.
- Backend issues: sample requests and responses are in `docs/api/runs.md` and in the `hurl` file.
- No bug issues in this plan.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `feat: step sync and enrollment progress API (backend)` | backend | - [ ] `docs/api/runs.md`, examples and `openapi.json` describe `POST /api/v1/runs/steps` and `GET /api/v1/runs`<br>- [ ] Migration adds `runs.counting_from` (set on join and resume) and the index; up, down, up verified<br>- [ ] The counting rules of this plan hold: window, `counting_from`, the future bound, duplicates, status, type<br>- [ ] Both routes are `user` in `ROUTE_ACCESS`; another user's enrollment never appears; fixed query count<br>- [ ] Unit and integration tests, contract tests, `pytest -m fuzz`, `backend/hurl/runs.hurl` and its output<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | none |
| 2 | `feat: daily activity sync API (backend)` | backend | - [ ] `docs/api/runs.md`, examples and `openapi.json` describe `PUT /api/v1/runs/daily-activity`<br>- [ ] Migration adds `daily_activity` (cascade on user delete); up, down, up verified, with `\d daily_activity`<br>- [ ] A day is replaced, not added to; a metric left out stays empty; limits and the future-date rule are enforced with `422`<br>- [ ] The route is `user` in `ROUTE_ACCESS`; one user cannot read or change another's rows; bodies are never logged<br>- [ ] Unit and integration tests, contract tests, `pytest -m fuzz`, `backend/hurl/runs.hurl` extended and its output<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | 1 |
| 3 | `feat: no Pause before a challenge starts (backend and mobile)` | backend, frontend | - [ ] `POST /challenges/{id}/pause` before `starts_at` answers `409 challenge_not_started`; documented in `docs/api/challenges.md` with an example; `openapi.json` and the contract tests updated<br>- [ ] The challenge detail action bar shows **Leave** only, with "You joined. Steps count from &lt;date&gt;.", while `now < startsAt`; Pause and Leave from the start on<br>- [ ] Backend tests per state; page and golden tests for the bar at both phone sizes and text scales<br>- [ ] `pytest -m fuzz`, `flutter analyze` and both full test suites pass | none |
| 4 | `feat: health data access and the gate (mobile)` | frontend | - [ ] `health` dependency added; iOS HealthKit and Android Health Connect configured<br>- [ ] `HealthRepository` interface in `domain`, plugin implementation in `data`, a fake for tests<br>- [ ] Gate states (unknown, granted, denied, permanently denied, unavailable) with the message about tracking challenges, the statement that the data is sent to StrideQuest, and the Allow access, Open settings and Install actions<br>- [ ] The gate is re-checked each time the Active tab opens<br>- [ ] Bloc tests for every state; page tests at both phone sizes and text scales; golden for each gate state<br>- [ ] `flutter analyze` and `flutter test` pass | none |
| 5 | `feat: Active tab with activity tiles and Refresh data (mobile)` | frontend | - [ ] Active and My Challenges tabs on the Active page; the placeholder is gone<br>- [ ] Steps, calories, distance and sleep tiles with "Today at hh:mm"; a refused optional metric shows "Not allowed" and is not sent<br>- [ ] **Refresh data** reads, then syncs the step samples (`POST /api/v1/runs/steps`, at most 500 per request) and the daily summaries (`PUT /api/v1/runs/daily-activity`); busy and error states keep the old values<br>- [ ] Manual entries are left out when the plugin reports them<br>- [ ] Page, bloc, repository and golden tests; both phone sizes and text scales; `flutter analyze` and `flutter test` pass | 1, 2, 4 |
| 6 | `feat: My Challenges tab with progress (mobile)` | frontend | - [ ] Lists active and paused enrollments, including a challenge not started ("Starts &lt;date&gt;", no progress); no History tab<br>- [ ] Run cards show the bar, "Goal n%" and the amount; swim and cycle cards show the note and no percentage; Paused pill<br>- [ ] Loading, empty (with **Browse challenges**), error with retry and success states; paging<br>- [ ] A card opens `/challenges/:id`; the list refreshes after a sync<br>- [ ] Page, bloc, repository and golden tests; both phone sizes and text scales; contract test over the new examples; `flutter analyze` and `flutter test` pass | 1, 5 |
| 7 | `test: Active tab flow against the local backend and the real-device checklist` | frontend | - [ ] `integration_test` with a fake health source: join, open Active, Refresh data, progress rises in My Challenges, and the daily summary is stored<br>- [ ] The iOS Simulator run with sample Health data, with screenshots, and the Android emulator run if available<br>- [ ] The real-device checklist is written in `docs/` and the items not verified are listed | 5, 6 |
