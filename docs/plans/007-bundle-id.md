# Plan 007: Sign the app as huynang.stridequest

Status: approved
Approved: 2026-10-19
Issues: <filled in after approval>

## Context

Running the app on a real iPhone failed twice while Xcode created the provisioning profile:

1. With the current entitlements:

   ```text
   Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the HealthKit Access
   (Verifiable Health Records) capability. HealthKit Access (Verifiable Health Records) capability
   needs to be assigned to your team and bundle identifier by Apple in order to be included in a profile.
   ```

   `mobile/ios/Runner/Runner.entitlements` (added in `8a8f67e`, #73 on GitLab) has the key `com.apple.developer.healthkit.access` with an empty array. Xcode reads that key as the "Clinical Health Records" (Verifiable Health Records) capability, which only Apple can grant. The app never reads health records: it reads steps, calories, distance and sleep (`NSHealthShareUsageDescription`), and nothing in `mobile/` uses health records. With the key removed, the profile is created.

2. The bundle ID `com.stridequest.stridequest` can't be registered for your team, so you set `huynang.stridequest` on the `Runner` target in Xcode. The test targets, the Patrol config and Android still use `com.stridequest.stridequest`.

Both changes are already made locally, uncommitted, to check them (see Verification).

## Open questions and assumptions

1. **The new ID is `huynang.stridequest` on every platform (decided by you on 2026-10-19).** iOS targets: `huynang.stridequest`, `huynang.stridequest.RunnerTests`, `huynang.stridequest.RunnerUITests`. Android: `applicationId` and `namespace` are `huynang.stridequest`.
2. **The Apple team is `KHAR8S7L52` (your team) on all three iOS targets.** `RunnerUITests` was still on `7KQ5ATT6B4`, so Patrol could not sign it for a device. Committing a team ID means anyone else who builds for a device must pick their own team in Xcode. Assumed acceptable, since you are the only developer.
3. **Xcode's other edits to `project.pbxproj` and `Info.plist` are kept.** Xcode removed redundant `name =` lines, added empty `inputPaths`/`outputPaths`, and moved `NSHealthShareUsageDescription` within `Info.plist`. None of these changes behaviour. Say if you would rather drop them from the commit.
4. **Plan 005 keeps the old ID in its text.** Plans are history.

## Approach

Mobile only. No backend, API, schema or database change.

- `mobile/ios/Runner/Runner.entitlements`: remove `com.apple.developer.healthkit.access`. Keep `com.apple.developer.healthkit` (true).
- `mobile/ios/Runner.xcodeproj/project.pbxproj`: the bundle IDs and team above, for Debug, Release and Profile.
- `mobile/pubspec.yaml`: `patrol.ios.bundle_id: huynang.stridequest`.
- `mobile/android/app/build.gradle.kts`: `namespace` and `applicationId` become `huynang.stridequest`.
- `mobile/android/app/src/main/kotlin/com/stridequest/stridequest/MainActivity.kt` moves to `kotlin/huynang/stridequest/MainActivity.kt`, with `package huynang.stridequest`.

This touches: a security boundary (an entitlement is removed, so the app asks for less) and the app's identity on both platforms. A new bundle ID is a new app to the OS: an installed copy under the old ID stays as a separate app, its Keychain tokens (`flutter_secure_storage`) are not carried over, so the user signs in again, and Apple Health or Health Connect access is asked again. Nothing is released yet, so no real user is affected. The approval must cover these.

## Risks

- **A health feature needed the removed key.** Contained: `git grep` finds no use of health records, and the key only matters for clinical records. The Active tab flow is checked on a device (Verification).
- **Android breaks after the package move.** Contained by building the APK and starting the app on an emulator.
- **Patrol targets the old ID.** Contained by changing `pubspec.yaml` and running the Patrol test on the simulator.

## Verification

Already checked locally on 2026-10-19:

- With the key removed, Xcode created the provisioning profile (you confirmed).
- `flutter build ios --simulator --debug` passes, and the built app's `CFBundleIdentifier` is `huynang.stridequest`.
- `git grep 'com\.stridequest'` in `mobile/` finds nothing.

To check in the issue:

- `flutter analyze` and the full `flutter test`.
- The app on your iPhone: sign in, allow Apple Health, open the Active tab.
- `flutter build apk --debug`, then start the app on an Android emulator. Not verified yet: the Android NDK on this machine is broken (`NDK at ~/Library/Android/sdk/ndk/28.2.13676358 did not have a source.properties file`). Deleting that folder lets Gradle download it again. That is your call, since it deletes files outside the repo.
- `patrol test --target patrol_test/sign_in_flow_test.dart` on the simulator.

## Ticket evidence

Bug and chore. The Xcode error and its cause are in Context, and the new ID was given by you. No images needed.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `fix: sign the app as huynang.stridequest without the health records entitlement` | frontend | - [ ] `Runner.entitlements` has no `com.apple.developer.healthkit.access` key, and Xcode creates the provisioning profile for a device<br>- [ ] All iOS targets use `huynang.stridequest` (plus `.RunnerTests` and `.RunnerUITests`) and team `KHAR8S7L52`<br>- [ ] Patrol's `bundle_id` and Android's `applicationId` and `namespace` are `huynang.stridequest`, and `MainActivity.kt` is in package `huynang.stridequest`<br>- [ ] `git grep 'com\.stridequest'` finds nothing in `mobile/`<br>- [ ] `flutter analyze` and `flutter test` pass, the iOS simulator build passes, and the Patrol test passes<br>- [ ] On a real iPhone: sign in, allow Apple Health, the Active tab opens<br>- [ ] The Android debug build starts on an emulator, or `Not verified` with the reason | none |
