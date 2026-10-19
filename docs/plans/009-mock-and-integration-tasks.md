# Plan 009: Split mobile tasks into mock and integration

Status: approved
Approved: 2026-10-19
Issues: #16, #17

## Context

Mobile (FE) work often waits on the backend: a plan lists one mobile issue per feature, and that issue can't be finished until the endpoints exist. The user wants every mobile feature that needs an endpoint split into two tasks:

- **mock:** the feature is built and tested against fake data, as soon as the API contract (`docs/api/<module>.md` and `docs/api/examples/`) is on `develop`;
- **integration:** the feature is wired to the real API, and may only start once the backend endpoints are merged on `develop`.

Today `FakeAuthRemoteDataSource` (`mobile/lib/features/auth/data/datasources/fake_auth_remote_data_source.dart`) exists only for tests, and the running app always calls `AppConfig.apiBaseUrl`. The user wants the fake data to be usable in the running app too, so screens can be seen and screenshotted before the backend exists.

This is a change to the Claude rules and local tooling (Phase 0), so it goes through this plan.

## Open questions and assumptions

- **Mock data in the running app:** yes, selected with `--dart-define=API_MODE=mock` (decided by the user). The default stays `real`.
- **Contract first:** a mock task starts only when the contract is on `develop` (decided by the user). Here the contract means `docs/api/<module>.md` and `docs/api/examples/`. It does not include `docs/api/openapi.json`, because `backend/tests/unit/test_openapi_snapshot.py` requires that file to match the schema the backend serves, so it can only change together with the backend issue that implements the endpoints.
- **Labels:** `mock` and `integration`, next to the existing `frontend` label (decided by the user).
- **Assumption:** features with no backend call (pure UI, Health-only reading) stay a single issue.
- **Assumption:** mock mode only works in debug builds, guarded by `kDebugMode` like the network simulation in `NetworkModule` (`mobile/lib/core/di/network_module.dart`). Profile and release builds always use the real API.
- **Assumption:** until a feature has its own fake, its screens show their error state in mock mode: they still call `AppConfig.apiBaseUrl`, and a real backend rejects the fake's access token. After issue 2 only the auth screens work fully in mock mode; each later mock task adds its feature.
- **Assumption:** plans 001 to 008 are not rewritten. The rule applies to plans written after this one is approved.

## Approach

### The rule

Goes into `CLAUDE.md` (Phase 1 and the verification evidence), `docs/plans/README.md`, `docs/workflow.md`, `.claude/agents/planner.md`, `.claude/agents/flutter-dev.md` and `.claude/skills/flutter-feature/SKILL.md`.

- A mobile feature that calls an endpoint is planned as two issues:

  | Issue | Labels | Depends on | Scope | Evidence |
  | --- | --- | --- | --- | --- |
  | `feat: <feature> (mobile, mock)` | `frontend`, `mock` | the contract issue (`docs/api/<module>.md` and examples) | domain, presentation, repository, the Dio remote data source written against the contract, and `Fake<Feature>RemoteDataSource`. The fake returns Dart fixtures copied from the `docs/api/examples/` files it needs, kept next to the fake in `data/datasources/` | bloc tests, `pumpScreen` and `expectAccessible`, goldens, a flow test with the fake, `flutter test test/contract` including a test that each fixture equals its example file, a screenshot with `API_MODE=mock`. The Integration row is `Not verified: backend not merged` |
  | `feat: <feature> (mobile, integration)` | `frontend`, `integration` | the mock issue and every backend issue for those endpoints | run against the local backend, fix any drift from the contract, error mapping, remote data source tests | the Integration row: the app against the local backend, one success case and each error documented in `docs/api/` |

- **Why fixtures:** the examples live outside `mobile/` and the contract tests read them with `dart:io` (`mobile/test/contract/*_examples_test.dart`), so the app can't bundle them. A fixture copied into Dart, plus a contract test that compares it with the example file, keeps the fake on the contract: if an example changes, `flutter test test/contract` fails.
- **Integration gate:** Claude starts an integration issue only when every backend issue it depends on is closed and its endpoints are in `docs/api/openapi.json` on `develop`, which is the sign that the backend has merged. Otherwise it stops and tells the user which backend issue is still open.
- If integration needs a contract change, the existing Phase 2 rule applies: stop and go back to the plan.
- Branch names stay `feat/<issue-id>-<short-name>`; the two issues already have different ids.
- The plan template's "Issues to create" gets an example of the pair with its `Depends on`.
- `docs/workflow.md` gets a small diagram: contract → backend and mobile mock in parallel → mobile integration.

### Selecting fake or real data sources (mobile)

- `AppConfig.apiMode` reads `--dart-define=API_MODE` (`real` by default, or `mock`) and calls a pure function, `ApiMode resolveApiMode(String raw, {required bool isDebug})`, with `kDebugMode`. It returns `mock` only for `raw: 'mock'` and `isDebug: true`. `kDebugMode` is a compile-time constant that is always true under `flutter test`, so the function is what makes the non-debug case testable.
- No `injectable` environments exist yet: every data source is a plain `@LazySingleton(as: ...)`. This issue adds a `real` and a `mock` environment in `lib/core/di/`, and passes the selected one to `configureDependencies`.
- Only a remote data source that has a fake is split by environment: its real class is registered for `real` and its fake for `mock`. Today that is auth only. `FakeAuthRemoteDataSource` is a stateful in-memory backend and its class stays free of DI annotations, because injectable can't resolve its optional `DateTime Function()? now` parameter. A DI module in `lib/core/di/` registers it for `mock` with `@Environment('mock')`, built as `FakeAuthRemoteDataSource(latency: ...)`. Challenges and runs keep their real data sources in both modes until their own mock task adds a fake.
- README run instructions show both modes.

Touches: mobile DI and config only. No public API, schema, authentication boundary, production data or cost is affected. The authentication flow itself is unchanged; only which data source answers it in a debug build with `API_MODE=mock`.

## Risks

- **The fake drifts from the backend.** For new fakes, contained by the fixture contract test (a fixture that differs from its `docs/api/examples/` file fails `flutter test test/contract`). The auth fake has no fixtures and relies on its existing `fake_auth_remote_data_source_test.dart`. In every case the integration task runs against the real backend.
- **A mock build reaches users.** Contained by the `kDebugMode` guard, with a test.
- **A screen can't resolve its dependencies in mock mode.** Contained by a test that builds the DI graph in `mock` and resolves every repository.
- **More issues per feature.** Accepted: the mock task unblocks mobile work while the backend is in progress.

## Verification

- Issue 1: the changed docs render and links resolve. `git grep -n "(mobile, mock)\|Integration gate" CLAUDE.md docs/plans/README.md docs/workflow.md .claude/agents/planner.md .claude/agents/flutter-dev.md .claude/skills/flutter-feature/SKILL.md` finds at least one line in each file (neither string exists today).
- Issue 2: `flutter analyze` and `flutter test` pass, including tests of `resolveApiMode` (`isDebug: false` with `mock` gives `real`), for both modes, and for every repository resolving in `mock`. Run the app with `--dart-define=API_MODE=mock` through the auth flow only (sign up, sign in, sign out), and against the local backend, or `Not verified: no emulator`.

## Ticket evidence

Both issues are chore / docs: the scope is above, and the behavior that must stay unchanged is that a build without `API_MODE` (and every profile or release build) calls the real API exactly as today. No images needed.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `docs: split mobile tasks into mock and integration` | docs | - [ ] `CLAUDE.md`, `docs/plans/README.md` (template with the pair), `docs/workflow.md` (diagram), the `planner` and `flutter-dev` agents and the `flutter-feature` skill describe the two task types, the contract without `openapi.json`, the fixture contract test, their evidence and the integration gate<br>- [ ] The GitHub labels `mock` and `integration` exist, or the exact `gh label create` commands are given | none |
| 2 | `chore: select fake or real remote data sources with API_MODE (mobile)` | frontend | - [ ] `AppConfig.apiMode` reads `--dart-define=API_MODE`, `real` by default, through `resolveApiMode(raw, isDebug: kDebugMode)`; a test shows `isDebug: false` with `mock` gives `real`<br>- [ ] `real` and `mock` `injectable` environments in `lib/core/di/`; `FakeAuthRemoteDataSource` is registered for `mock` from a DI module (the class has no annotations) and the real auth data source for `real`; challenges and runs use their real data sources in both<br>- [ ] A test builds the DI graph in `mock` and resolves every repository<br>- [ ] Tests for both modes; `flutter analyze` and `flutter test` pass<br>- [ ] README shows how to run each mode | 1 |
