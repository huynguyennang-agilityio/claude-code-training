# Plan 003: Active tab, health data access and challenge progress

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

The Active tab is a placeholder. This plan builds it: the user must allow health data before the tab opens, the tab shows today's activity (steps, calories, distance, sleep) with a manual **Refresh data** button that also syncs the steps to the backend, and a second tab lists the challenges the user has joined, with progress.

This is the first plan that reads **Apple Health** (iOS) and **Health Connect** (Android) and the first that **counts progress** on the backend. Plan 001 left both out. Finishing a challenge and awarding medals (the Medals tab) stay for a later plan.

Reference: three screenshots of another app (the activity tiles with a Sync Your Device row, and a My Challenges list with Ongoing and History tabs), sent by the user in chat. As in plan 001 they are a **layout reference only**; their artwork, copy and colours are not reused. Our screens use the dark theme with Lime from the Figma file.

### Decided by the user

- Opening the Active tab **requires health access**. Without it the user cannot get past the tab, and a message says that without health data the app cannot track progress for challenges.
- The page has **two tabs**: **Active** and **My Challenges**.
- **Active** shows steps, calories, distance and sleep time. **Steps is mandatory**; the others are optional. At the bottom there is a **Refresh data** button, a manual sync.
- **My Challenges** lists the challenges the user has joined and that are in progress.

## Open questions and assumptions

Questions for the user. Each has the answer the plan assumes; say if one is wrong.

1. **Which challenges count progress now?** Assumed: **run** challenges (steps) only. Swim and cycle count distance from workouts, which needs workout reading, another health permission and a second kind of sample. Their cards show "Progress for swim and cycle comes soon" with no percentage. A later plan adds them.
2. **Does a pause stop counting?** Assumed yes. A new nullable column `runs.counting_from` is set on join and on resume; samples that start before it are ignored. Samples taken while paused therefore never count, even if they are synced later. (Needs a migration; see Approach.)
3. **When does a sync run?** Assumed: when the Active tab opens and when the user taps **Refresh data**. No background sync yet (iOS background delivery and Android background reads are a later plan).
4. **Calories, distance and sleep:** assumed to be **read on the device and shown only**. They are never sent to the backend. Only steps are synced.
5. **My Challenges:** assumed to list **active and paused** enrollments only. The screenshots show an Ongoing and a History tab; History (left or finished challenges) comes with the plan that finishes challenges.
6. **Design:** assumed there is no Figma frame for this screen yet, so it is built from the screenshots' layout and the existing dark theme. If there is a frame, send its link before the mobile issues start (`ui` ticket evidence).
7. **Manual entries:** Apple Health and Health Connect let a person type steps by hand. Assumed: the app **ignores manual entries** when the plugin reports the recording method, and the backend counts only what it is sent. Real anti-cheat (issue #6) is separate; this is a cheap first guard.
8. **A new dependency:** the `health` package (Flutter) for both platforms. It needs the user's approval, below.

## Approach

### Health access and the gate (mobile)

- `features/runs/data/datasources/health_data_source.dart` is the only place that touches the plugin, behind a domain interface `HealthRepository` in `features/runs/domain`. Everything else (bloc, tests) uses the interface, so tests never need a device.
- Permissions: **steps** (required), and **calories, distance, sleep** (optional). The app asks for all four in one request.
- Gate states on the Active tab: `unknown` (checking, spinner), `granted` (the tabs), `denied` (a full-page message and a **Allow access** button), `permanentlyDenied` (the message and **Open settings**), `unavailable` (Health Connect missing or not supported: the message and a link to install it). The message says that without health data the app cannot track progress for challenges.
- **iOS cannot tell whether a read permission was refused**: HealthKit hides it for privacy. The plugin only reports that the request was shown. The app therefore treats "asked, but a steps read returns nothing and the user has never had data" as `denied` only after a check read; a user who really has zero steps today is `granted` with 0. This is a known limit, and the verification below says what is and is not checked.
- Android: Health Connect permission strings in the manifest, the privacy-rationale activity Health Connect requires, and the minimum SDK the plugin needs. iOS: the HealthKit capability and the usage-description strings in `Info.plist`.

### Mobile screens (`features/runs`, the page moves out of `features/challenges`)

- **Active page** (`/active`, route is a top-level tab as today): a tab bar with **Active** and **My Challenges**. Blocs are created in the route's `BlocProvider`: `HealthAccessBloc` (the gate, the readings, the refresh and the sync) and `MyChallengesBloc` (the list). Neither touches `AuthBloc`.
- **Active tab:** 2×2 tiles (Steps, Calories, Distance, Sleep) each with an icon, the value, the unit and "Today at hh:mm" (the time of the last read). A denied optional metric shows "Not allowed" and a hint to enable it in settings. The **Refresh data** button is fixed at the bottom; while it works it shows a progress state and is disabled; on failure a snackbar says what failed and the old values stay.
- **My Challenges tab:** a card per joined challenge: cover, **Solo** and **Goal n%** tags, title, dates, and **Paused** when paused. Tapping a card opens `/challenges/:id` (already built). States: loading, empty ("You have not joined a challenge yet", with a button to the Challenges tab), error with retry, success. For swim and cycle the card shows the note from question 1.
- Colours, text styles, spacing and radii come from the theme and `app_tokens.dart`; a value the scale lacks is added there.

### Backend (`runs` module)

Contract in a new `docs/api/runs.md` with examples under `docs/api/examples/runs/`, written with the first backend issue.

| Endpoint | Who | Purpose |
| --- | --- | --- |
| `POST /api/v1/runs/steps` | user | Body: up to 500 step samples `{health_record_id, start_time, end_time, steps}`. For each of the caller's **active run** enrollments whose window the sample falls in, the sample is stored once (unique `(run_id, health_record_id)`, already in the schema) and `total_steps` is updated. Answers with how many samples were accepted and the caller's progress per enrollment. `422 validation_error` for a bad body |
| `GET /api/v1/runs` | user | The caller's `active` and `paused` enrollments, newest first, with the challenge card fields and `progress` (`current_value`, `target_value`, `percent` 0 to 100, `tracked`: false for swim and cycle). Cursor paging as the challenges list |

Rules, in the `runs` service:

- A sample counts for an enrollment when the enrollment is `active`, `start_time >= counting_from`, `start_time >= challenge.starts_at` and `end_time <= min(challenge.ends_at, now + 5 minutes)`. The upper bound uses the server clock so a device with a wrong clock cannot count steps from the future.
- `steps` is 1 to 100,000 per sample and `end_time >= start_time` (the table already checks the second); a sample longer than 24 hours is refused.
- A sample sent twice, or the same one in a second request, counts once per enrollment. Only run challenges count in this plan, and the database forbids two active run challenges whose windows overlap, so a sample counts for at most one enrollment today.
- The `challenges` module keeps reading enrollments through `RunReads`; `runs` does not import another module's repository.
- A response that nests rows has a fixed query count (a test shows it).

### Schema

- Add `runs.counting_from` (`timestamptz`, nullable; existing rows are set to `joined_at`). Join sets it to now; resume sets it to now; pause and leave leave it. One Alembic migration, data-preserving, tested up, down, up.
- Add an index on `step_samples (run_id, start_time)` if the progress query needs it (checked with `EXPLAIN` during the issue).
- No new table.

### Touches the approval must cover

- **A new dependency:** `health` (Flutter), plus iOS and Android platform configuration for health data.
- **A public API change:** two new routes (no existing route changes).
- **A schema change:** one nullable column and an index.
- **Privacy and security:** health data. Only steps leave the device; they go over the authenticated API, are stored per user, are never logged, and are deleted with the user (cascade). The route is `user`-level and in `ROUTE_ACCESS`.

## Risks

- **iOS hides read denial** (above). The user could be treated as allowed with no data. Mitigation: the check read, a clear empty state, and the gate being re-checked every time the tab opens.
- **Manual or duplicated steps** inflate progress. Mitigation: ignore manual entries when the plugin says so, count a record once, window and sanity limits on the server. Not full anti-cheat (issue #6).
- **Health Connect is not on every Android phone** (a separate app before Android 14). The `unavailable` state handles it.
- **Many samples per day** make large uploads. Mitigation: read hourly-bucketed steps, send in requests of at most 500, and read only from the earliest `counting_from` of the user's active run enrollments.
- **A clock-skewed device** or a user changing the time zone. Mitigation: all times are UTC instants; the server bounds the window with its own clock.
- **Cannot be checked without a real phone:** the accuracy of real sensor data, Apple Watch and other sources, background delivery and the real permission dialogs on each Android maker. See Verification.

## Verification

- **Backend:** unit tests for the counting rules (window, `counting_from`, duplicates, the future bound, paused, left, wrong type); integration tests for both routes including the ownership case (another user's enrollment never appears) and the query count; `pytest tests/unit/test_auth_sweep.py` with both routes declared `user`; contract, example and OpenAPI snapshot tests; `pytest -m fuzz`; `backend/hurl/runs.hurl` with its `run.sh` output; migration up, down, up with `\d runs` and `\d step_samples`.
- **Mobile logic:** bloc tests for every gate state, the refresh and the sync, with a fake `HealthRepository`; a repository test with a fake HTTP adapter for the sync and the list; the contract test over the new examples.
- **Mobile screens:** page tests with `pumpScreen` and `expectAccessible` (375×667 and 430×932, text scale 1.0 and 2.0) for each state: the gate (denied, permanently denied, unavailable), Active (loading, success, partial permissions, refresh error), My Challenges (loading, empty, error, success, paused, swim without progress). Goldens with `goldenScreen`.
- **Integration:** `integration_test` against the local backend with a **fake health source** (steps from a fixture): join a run challenge, open Active, Refresh data, see the progress rise in My Challenges.
- **iOS Simulator:** the Simulator has HealthKit and the Health app, so a step sample can be added there by hand and the real plugin path (permission request, read, sync) can be exercised. I will do this and attach screenshots.
- **Android:** the emulator with Health Connect (API 34 and later) in the same way, if one is available.
- **Not verified, and said so in the MR:** real sensor accuracy, Apple Watch and multi-source de-duplication, background delivery, and the permission dialogs on real devices. The user runs a short checklist on a real phone once (written into the last issue): allow, deny, deny forever then Open settings, revoke in settings and reopen the tab, walk and refresh.

## Ticket evidence

- `ui` and feature-with-UI issues: the three reference screenshots (layout only, sent in chat, not committed), and the states and sizes listed under Verification. A Figma link, if the user has one (question 6), is added to each mobile issue.
- Backend issue: the sample request and response are in `docs/api/runs.md` and in the `hurl` file.
- No bug issues in this plan.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `feat: step sync and enrollment progress API (backend)` | backend | - [ ] `docs/api/runs.md`, examples and `openapi.json` describe `POST /api/v1/runs/steps` and `GET /api/v1/runs`<br>- [ ] Migration adds `runs.counting_from` (set on join and resume) and the index; up, down, up verified<br>- [ ] The counting rules of this plan hold: window, `counting_from`, the future bound, duplicates, status, type<br>- [ ] Both routes are `user` in `ROUTE_ACCESS`; another user's enrollment never appears; fixed query count<br>- [ ] Unit and integration tests, contract tests, `pytest -m fuzz`, `backend/hurl/runs.hurl` and its output<br>- [ ] `ruff`, `mypy` and the full `pytest` pass | none |
| 2 | `feat: health data access and the gate (mobile)` | frontend | - [ ] `health` dependency added; iOS HealthKit and Android Health Connect configured<br>- [ ] `HealthRepository` interface in `domain`, plugin implementation in `data`, a fake for tests<br>- [ ] Gate states (unknown, granted, denied, permanently denied, unavailable) with the message about tracking challenges and the Allow access and Open settings actions<br>- [ ] The gate is re-checked each time the Active tab opens<br>- [ ] Bloc tests for every state; page tests at both phone sizes and text scales; golden for each gate state<br>- [ ] `flutter analyze` and `flutter test` pass | none |
| 3 | `feat: Active tab with activity tiles and Refresh data (mobile)` | frontend | - [ ] Active and My Challenges tabs on the Active page; the placeholder is gone<br>- [ ] Steps, calories, distance and sleep tiles with "Today at hh:mm"; a refused optional metric shows "Not allowed"<br>- [ ] **Refresh data** re-reads, then syncs steps through `POST /api/v1/runs/steps` in requests of at most 500; busy and error states<br>- [ ] Manual entries are left out when the plugin reports them<br>- [ ] Page, bloc, repository and golden tests; both phone sizes and text scales; `flutter analyze` and `flutter test` pass | 1, 2 |
| 4 | `feat: My Challenges tab with progress (mobile)` | frontend | - [ ] Lists active and paused enrollments with Solo and Goal n% tags, dates and Paused<br>- [ ] Loading, empty (with a button to the Challenges tab), error with retry and success states; paging<br>- [ ] Swim and cycle cards show the note and no percentage<br>- [ ] A card opens `/challenges/:id`; the list refreshes after a sync<br>- [ ] Page, bloc, repository and golden tests; both phone sizes and text scales; contract test over the new examples; `flutter analyze` and `flutter test` pass | 1, 3 |
| 5 | `test: Active tab flow against the local backend and the real-device checklist` | frontend | - [ ] `integration_test` with a fake health source: join, open Active, Refresh data, progress rises in My Challenges<br>- [ ] The iOS Simulator run with sample Health data, with screenshots, and the Android emulator run if available<br>- [ ] The real-device checklist is written in `docs/` and the items not verified are listed | 3, 4 |
