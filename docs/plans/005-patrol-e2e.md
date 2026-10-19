# Plan 005: Patrol end-to-end tests with native automation

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval; #49 is reused, see Issues to create>

## Context

[#49](https://gitlab.asoft-python.com/huy.nguyennang/claude-code-training/-/work_items/49) asks for `patrol`: mobile end-to-end tests that can also tap native iOS system dialogs. `integration_test` (#48, and the flows added since in `mobile/integration_test/`) drives only the Flutter UI. The app now asks for Apple Health and Health Connect access (plan 003), a native prompt that nothing in the repo can test.

#49 was parked on 2026-10-17 with two blockers and no code. Re-checked on 2026-10-19:

1. **Dependency conflict, still true.** `patrol 4.10.0` (latest) needs `equatable ^2.1.0`; the app uses `equatable ^3.0.0` (the latest, 3.0.0). `flutter pub add --dev patrol` silently picks the obsolete `patrol 1.1.0`.
2. **Native iOS project setup, still true.** `mobile/ios/` has a `RunnerTests` target but no `RunnerUITests` target, and Patrol 4 has no `init` command.

What changed: the Health permission issue (#73) is done, so a real native prompt now exists to prove the bridge. It stays out of scope here (see Open questions).

## Open questions and assumptions

1. **How to resolve the `equatable` conflict? (needs your decision.)**
   - **A. Move the app to `equatable ^2.0.7` (assumed, recommended).** A dry run of `flutter pub add --dev patrol:^4.10.0` with that constraint resolves (adds `patrol`, `patrol_finders`, `patrol_log`, `dispose_scope`, `http`). `equatable` is imported in 12 files under `lib/` and `test/`, in the domain layer where CLAUDE.md allows it. The full `flutter test` suite shows whether 2.x changes any behaviour (value equality, `props`).
   - **B. Keep `equatable ^3.0.0` and add a `dependency_overrides` entry.** Rejected: it forces a version the package does not declare support for and can hide a real incompatibility at run time; the pubspec already carries one override (`device_info_plus`) that we would rather not copy.
   - **C. Defer until `patrol` supports `equatable 3`.** Valid if you would rather not go back a major version; #49 then stays open and nothing changes.
2. **Scope is #49's scope.** iOS simulator only. Android (Gradle runner, an emulator, none here), the Health permission flow test and CI stay out. The Health prompt test is a follow-up plan once this setup works. Assumed.
3. **The existing issue #49 is reused** for the Patrol setup, with its description updated to this plan (dependency decision and a link to the plan). The `equatable` change gets its own small issue first, so it can be reviewed and reverted on its own. Say if you prefer one issue.
4. **Native setup by script.** The `RunnerUITests` target is added with the `xcodeproj` gem (part of CocoaPods) instead of by hand in Xcode; the result is checked by building and by running the tests. Assumed.
5. **`patrol_cli`** is installed globally on this machine (4.8.0); contributors install it with `dart pub global activate patrol_cli`. It is not a project dependency.

## Approach

Mobile only. No backend, API or database change. No change to `docs/api/`.

**Issue 1, dependency (`mobile/pubspec.yaml`, `pubspec.lock`):** set `equatable: ^2.0.7`, run `flutter pub get`. Source changes only if the full test suite shows a difference; none expected.

**Issue 2, Patrol (#49):**

- `pubspec.yaml`: `patrol` as a dev dependency, plus the `patrol:` block (`app_name`, iOS bundle id `com.stridequest.stridequest`).
- `ios/`: a `RunnerUITests` UI test target (`RunnerUITests.m` with `PATROL_INTEGRATION_TEST_IOS_RUNNER`), a Podfile entry for it (`inherit! :complete`), and the `Runner` scheme's test action, so `patrol test` can build and run on a simulator. Edits to `project.pbxproj` come from the `xcodeproj` gem, not by hand.
- `patrol_test/sign_in_flow_test.dart`: the sign-in flow of `integration_test/sign_in_flow_test.dart` with Patrol's `$` finders, against the real backend (the test creates its own user, as the original does), plus one native step: open the iOS Settings app and return to the app.
- `README.md` and the `flutter-feature` skill: how to install `patrol_cli` and run `patrol test`, and when to use Patrol instead of `integration_test` (only when a flow crosses into a native dialog or another app).
- The styling guard (`theme_tokens_guard_test.dart`) is unaffected; the new files hold no UI code.

This touches: a dependency change (issue 1 downgrades a major version of an existing package; issue 2 adds a dev dependency and generated iOS project files). It does not touch authentication, real data, production or cost. The approval covers both dependency changes.

## Risks

- **`equatable 2.x` behaves differently from 3.x in some corner.** Contained by the full suite, the golden tests and `flutter analyze` on issue 1; the change is its own MR and easy to revert.
- **Hand-generated Xcode project edits break the build.** Contained by `flutter build ios --simulator --debug` and the existing tests after the edit; the project file diff is reviewed in the MR.
- **Patrol 4 fails on this simulator or Xcode version.** The acceptance criteria require two green runs in a row; if it cannot run here, the issue says `Not verified` with the reason and stays open rather than claiming success.
- **Little value today:** only one native step exists until the Health prompt test follows. Accepted: the setup is what the follow-up needs.

## Verification

- Issue 1: `flutter pub get` output; `flutter analyze`; `flutter test` (all, including goldens and contract tests); `git diff` on `pubspec.lock` showing only `equatable` and its dependents change.
- Issue 2: `patrol test --target patrol_test/sign_in_flow_test.dart -d <simulator>` against the running backend, twice in a row, with the output; `flutter build ios --simulator --debug`; `flutter analyze`; `flutter test`; the original `flutter test integration_test/sign_in_flow_test.dart -d <simulator>`.
- Not verifiable here: Android, CI, a physical device.

## Ticket evidence

Both are chores: scope and the behaviour that must stay unchanged are in Approach (no app behaviour changes; the existing tests are the guard). No images needed. The two blockers and the dry-run result are in Context and Open questions.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: move equatable to ^2.0.7 so patrol 4 can be added` | frontend | - [ ] `pubspec.yaml` has `equatable: ^2.0.7` and `flutter pub get` resolves<br>- [ ] `flutter analyze` and the full `flutter test` pass with no source or golden changes, or each change is explained<br>- [ ] `pubspec.lock` changes only `equatable` and what depends on it | none |
| 2 | Existing **#49** `test: add a Patrol end-to-end test with native automation`, description updated to this plan | frontend | - [ ] `patrol test --target patrol_test/sign_in_flow_test.dart -d <simulator>` passes against the running backend, twice in a row<br>- [ ] The native step (Settings app and back) passes<br>- [ ] `flutter build ios --simulator --debug`, `flutter analyze` and `flutter test` still pass, and the original `integration_test` still passes<br>- [ ] README and the `flutter-feature` skill describe the setup and when to use Patrol | 1 |
