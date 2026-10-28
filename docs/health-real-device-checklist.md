# Health data: real-device checklist

The automated tests and the simulator cannot show everything about health data. The simulator's Health app can only be filled by hand (and hand entries are not counted toward challenges), there is no Apple Watch, and Health Connect needs an Android phone. Run this list once on a real phone before a release, and again when the health code changes. Write what you saw in the **Result** column of a copy of the table (in the pull request or the release notes), never in this file.

What the tests already cover, so you do not repeat it: the rules of counting steps (`backend/tests/unit/test_progress_service.py`), the sync requests and their limits, every screen state at both phone sizes and text scales, and the whole flow with a fake health source (`mobile/integration_test/active_flow_test.dart`). Plan: [`docs/plans/003-active-tab.md`](plans/003-active-tab.md).

## Before you start

- **iPhone:** a build signed with a profile that has the HealthKit capability (the entitlement is in `ios/Runner/Runner.entitlements`; the team enables it), on a phone with some step history in Health.
- **Android:** a phone with Health Connect (built in from Android 14, an app from the Play Store before that) and some step history, from a build whose `minSdk` is 26.
- The app against a backend you can read: the local one (`docker compose up -d --wait db`, then the API) or staging. You need the database or the API logs to check what was stored.
- A signed-in test user and a **run** challenge that has started (see "Demo challenges" in the README). Join it before the checks that need progress.

## Checks

| # | What to do | What you should see | Result |
| --- | --- | --- | --- |
| 1 | Open the Active tab for the first time. | The health gate: "Allow health access", the four figures with Steps marked Required, the note that the data is sent to StrideQuest. The tab bar still works. | |
| 2 | Tap **Allow access** and allow everything. | The system dialog; then the Active tab with today's steps, calories, distance and sleep matching the Health app, "Today at hh:mm", and "Synced to StrideQuest at hh:mm". | |
| 3 | Check the backend: the row of today and yesterday in `daily_activity` for the user. | Both days, with the figures of the app. | |
| 4 | Android: allow **only steps** (turn the others off in the dialog). | Calories, Distance and Sleep time show "Not allowed", a note says they are not sent, and the stored rows have those columns empty. | |
| 5 | Android: refuse the dialog. Tap **Allow access** again and refuse. | After the first refusal the gate stays ("Allow health access"); after the second it says "Health access is off" with **Open settings**. | |
| 6 | Tap **Open settings**, turn Steps on, return to the app. | iOS: the Settings page of the app. Android: Health Connect settings. Back in the app the tab opens by itself, without a restart. | |
| 7 | Turn Steps off in the system settings while the app is in the background, then return. | Android: the gate comes back. iOS: HealthKit does not say, so the tab stays open and steps read 0 (a known limit; see the plan). | |
| 8 | iOS: allow nothing in the system dialog ("Don't Allow"). | The tab opens (HealthKit hides the refusal) and every figure reads 0. Progress cannot count. | |
| 9 | Android without Health Connect (an older phone, or uninstall it). | "Health Connect needed" and **Install Health Connect**, which opens the store. | |
| 10 | Walk about 200 steps, then tap **Refresh data**. | The Steps tile goes up by about that much. | |
| 11 | In My Challenges, look at the run challenge you joined before walking. | Its "Goal n%" and "x / target steps" went up by the same steps, and match the Health app (not counting hand entries). | |
| 12 | Add 1,000 steps **by hand** in the Health app, then **Refresh data**. | The Steps tile includes them. The challenge progress does **not** (manual entries are left out). | |
| 13 | With an Apple Watch or a second step source: compare. | The tile equals the Health app's total (it removes duplicates); the challenge progress equals the sum of the non-manual records. Note any gap. | |
| 14 | Pause the challenge, walk, resume, walk, **Refresh data**. | Only the steps taken after resuming count. | |
| 15 | Set the phone clock one hour ahead, walk, **Refresh data**; set it back. | Steps from "the future" are ignored by the backend; no error. | |
| 16 | Join a challenge that has not started. | The card says "Starts <date>" with no progress, the detail has no **Pause**, only **Leave**. | |
| 17 | Turn on airplane mode, tap **Refresh data**. | A banner "Cannot reach StrideQuest. Check your connection."; the old figures stay; no "Synced" line. | |
| 18 | A challenge started 30 days ago, with a lot of history: **Refresh data**. | It finishes; the progress matches the Health app; the app sent the records in several requests (500 each). | |
| 19 | Switch the Active tab away and back, and the app to the background and back. | The gate is checked again each time; no spinner flash when access is already granted. | |
| 20 | Set the text size to the largest in the system settings. | Every screen above scrolls and nothing is cut off; Refresh data stays reachable. | |

## What is not covered, even by this list

- Background sync: there is none yet (a later plan).
- Swim and cycle progress: not counted yet; their cards say "Progress for swim comes soon".
- Retention and export or deletion of a user's health data: needs its own plan before any release (see the plan's risks).
