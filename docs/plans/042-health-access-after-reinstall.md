# Plan 042: Ask Health access again after an iOS reinstall

Status: approved
Approved: 2026-11-12, by the user in chat: "/approve-plan 042"
Issues: #293
Draft: https://claude.ai/artifact/3CwVVuNYjCuDwEwpzGjNg1, version 1794469997-bcdc

## Context

Areas: area:health · 1 task · bug.

Related: plan 030 (`docs/plans/030-health-sync-single-session.md`) (assumptions 12, 16), issues #263, #265, #266. No new design: the existing gate and banner are used.

### Prerequisites

- **Before `/run-tasks`:** nothing. The task needs no new key, secret or account.
- **Before the manual check:** an iOS Simulator with the Health app (Xcode installed), or an iPhone plugged into the machine. Result: a device that `flutter run` can run on.

### The bug

After uninstalling the app and installing it again (from TestFlight), the app **does not ask again for permission to read Apple Health**. The Active tab shows the Steps, Calories, Distance and Sleep time tiles empty, with the error line `Could not read your health data. Try again.`; tapping *Refresh data* does not help.

The cause (read from the code on `develop`):

```text
First install ── asks for access ──► keychain: health_permission_asked = 1
Uninstall     ── iOS removes the app's HealthKit access, the keychain IS KEPT
Reinstall     ── checkAccess(): allowedMetrics() == null (iOS), asked = 1
              ──► HealthAccess(granted, confirmed: false)
              ──► no gate, no banner, requestAuthorization never called
Reading data  ── HealthKit: access not determined ──► HealthFailure
              ──► "Could not read your health data. Try again."
```

Code involved: `mobile/lib/features/runs/data/repositories/health_repository_impl.dart` (`checkAccess`) and `mobile/lib/features/runs/data/datasources/health_prompt_store.dart` (`SecureHealthPromptStore`, stored in the keychain). The gotcha that the keychain survives an uninstall is already recorded in `mobile/decisions/runs.md` (#265), but nobody has handled the reinstall case.

Today the user cannot fix it themselves: signing out does not clear the counter, and Settings → Health no longer lists the app.

## Open questions and assumptions

1. **Assumption:** uninstalling the app on iOS removes the app's HealthKit access, so on the next install HealthKit shows the dialog again. This matches what you saw on TestFlight; the task checks it again on the Simulator.
2. **Assumption:** the read error comes from HealthKit access being "not determined" (`HKError.errorAuthorizationNotDetermined`). This is only inferred from the screenshot, there is no log yet; the task records the log before the fix.
3. **Proposed decision:** ask HealthKit directly with `HKHealthStore.getRequestStatusForAuthorization(toShare:read:)` through a method channel, instead of trusting the counter in the keychain. No package is added. The alternative (moving the counter to `shared_preferences`, which is removed on uninstall) needs a new dependency and is still only a guess, so it is not chosen.
4. **Assumption:** Android does not have this bug, because Health Connect says exactly which permissions are granted (`allowedMetrics()`). Android does not change.
5. **Assumption:** when the status cannot be read (a channel error, HealthKit returns `unknown`), the app keeps the old behaviour (based on the counter). The bug is no worse than today.
6. **Out of scope:** the existing keychain data (`health_permission_asked`, `health_explainer_shown_at`) is not deleted or moved; it is still used for Android and for the explainer's interval.

## Approach

- **Native iOS** (`mobile/ios/Runner/AppDelegate.swift`): add the channel `stridequest/health`, method `requestStatus`, which takes a list of HealthKit identifiers (the read types: step count, active energy, distance walking/running, sleep analysis). It calls `getRequestStatusForAuthorization(toShare: [], read: types)` and returns `"shouldRequest"`, `"unnecessary"` or `"unknown"`.
- **Data source** (`health_data_source.dart`): add `Future<bool?> requestNeeded()` to `HealthDataSource`.
  - iOS: `true` when it returns `shouldRequest`, `false` when it returns `unnecessary`.
  - `null` on `unknown`, on a channel error, and on Android.
  - The list of identifiers is taken from the same place as `_types`, so there is a single source.
- **Repository** (`HealthRepositoryImpl.checkAccess`), the `allowedMetrics() == null` branch:
  - `requestNeeded() == true` → `HealthAccess.denied()`, whatever `askedCount()` is.
  - `false` → `granted`, `confirmed: false`.
  - `null` → the old logic.

  From there, `HealthGateBloc` shows the gate, `GetHealthNotice` returns `askable` (the banner shows), and `HealthSyncService` skips reading. Nothing changes in presentation.
- **Tests:** extend `health_repository_impl_test.dart` (fake data source) and `health_data_source_test.dart` (mocked method channel).

### Changes the approval must cover (Phase 2 risk categories)

- Public API or contract: **no**. Schema or migration: **no**. Auth or a security boundary: **no**. Dependency or core technology: **no** (uses the existing HealthKit, adds no package). Real data, production or costs: **no**.
- A new native iOS method channel is added (`stridequest/health`), next to the existing `stridequest/settings` channel.

## Risks

- **`getRequestStatusForAuthorization` returns `unnecessary` even when the user refused:** this is Apple's design. That case still follows plan 030's `noSteps` flow, as it does today.
- **The list of data types on the native side drifts from Dart:** Dart passes the identifiers to native, so there is a single source; a test checks the list that is sent.
- **One more native call each time access is checked:** the call is light and shows no UI. Access checks only run on app open, on resume and when a screen opens.
- **The channel fails on an old iOS version:** it returns `null` and the old logic stays (assumption 5).

## Verification

- Unit tests: `flutter test test/features/runs/data/` with the three branches `true` / `false` / `null` and the case `askedCount() > 0`.
- `flutter analyze` and the full `flutter test` pass.
- Manual check on an iOS Simulator:
  1. `flutter run`, grant Health access.
  2. Uninstall the app. Do not reset the keychain.
  3. `flutter run` again.
  4. Expected: the Active tab shows the "Turn on Apple Health" gate and the My Challenges banner shows.
  5. Tap the gate: the system dialog shows. Choose Allow: the figures show, the error line is gone.

  Record the read error log before the fix (assumption 2).
- Not verifiable in the task: the TestFlight build. You check it in the next build.

## Ticket evidence

- **Type:** `bug`.
- **Steps to reproduce:**
  1. Install the app.
  2. Grant Health access.
  3. Uninstall the app.
  4. Reinstall from TestFlight.
  5. Open the Active tab.
- **Expected:** the app asks again for Health read access (the gate or banner, then the system dialog).
- **Actual:** no dialog. The figure tiles are empty and the line `Could not read your health data. Try again.` shows.
- **Screenshot:** sent by you in chat on 2026-11-12, at 14:48 on an iPhone. The screenshot has a personal device name, so it is not embedded in the page.

## Task breakdown

One task is one issue.

### Phase 1: Ask for Health access again after a reinstall

#### Task 1: `[health] fix: ask Health access again after an iOS reinstall (mobile)`

**Description:** On iOS, `HealthRepositoryImpl.checkAccess()` treats access as granted only when HealthKit itself says there is no need to ask again, not based on the counter in the keychain (because the keychain survives an uninstall). Order of work:

1. Reproduce the bug on the Simulator and record the read error log.
2. Add the channel `stridequest/health` / `requestStatus` in `AppDelegate.swift`, calling `getRequestStatusForAuthorization(toShare: [], read:)`.
3. Add `requestNeeded()` to `HealthDataSource` and `PluginHealthDataSource`. Return `null` on Android, on `unknown` and on a channel error. The identifiers come from the same source as `_types`.
4. Use `requestNeeded()` in the iOS branch of `checkAccess()` as in the Approach section.
5. Write the tests, then check by hand as in the Verification section.

No change to presentation, domain or Android.

**Acceptance criteria:**
- [ ] On iOS, when HealthKit's request status for the read types is `shouldRequest`, `HealthRepositoryImpl.checkAccess()` returns `denied` even when `HealthPromptStore.askedCount()` is above 0, so after a reinstall the Active tab shows the health gate and My Challenges shows the health notice banner
- [ ] After a reinstall, tapping the gate's action shows the system Health dialog, and once access is allowed the Active tab shows the figures without `Could not read your health data. Try again.`
- [ ] When the request status is `unnecessary`, `unknown` or cannot be read, and on Android, `checkAccess()` returns what it returns today

**Verification:**
- [ ] Tests pass: `flutter test test/features/runs/data/health_repository_impl_test.dart test/features/runs/data/health_data_source_test.dart`, then the full `flutter test`
- [ ] Lint and type checks: `flutter analyze`
- [ ] Manual check on an iOS Simulator: grant access, uninstall without resetting the keychain, reinstall; the gate and banner show, the system dialog opens from the gate, figures show after Allow; the read error log from before the fix is recorded
- [ ] Evidence section filled in, with `Not verified: TestFlight build`

**Dependencies:** None

**Files likely touched:**
- `mobile/ios/Runner/AppDelegate.swift`
- `mobile/lib/features/runs/data/datasources/health_data_source.dart`
- `mobile/lib/features/runs/data/repositories/health_repository_impl.dart`
- `mobile/test/features/runs/data/health_data_source_test.dart`
- `mobile/test/features/runs/data/health_repository_impl_test.dart`

**Estimated scope:** M: 3 code files, about 150 lines (plus tests)

#### Checkpoint: Health access asked again after reinstall
- [ ] Tests pass, lint and type checks clean
- [ ] On an iOS Simulator, a reinstalled app shows the gate and asks for Health access again
- [ ] The user reviews before the next TestFlight build

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[health] fix: ask Health access again after an iOS reinstall (mobile)` | frontend, area:health | - [ ] On iOS, when HealthKit's request status for the read types is `shouldRequest`, `HealthRepositoryImpl.checkAccess()` returns `denied` even when `HealthPromptStore.askedCount()` is above 0, so after a reinstall the Active tab shows the health gate and My Challenges shows the health notice banner<br>- [ ] After a reinstall, tapping the gate's action shows the system Health dialog, and once access is allowed the Active tab shows the figures without `Could not read your health data. Try again.`<br>- [ ] When the request status is `unnecessary`, `unknown` or cannot be read, and on Android, `checkAccess()` returns what it returns today | none |
