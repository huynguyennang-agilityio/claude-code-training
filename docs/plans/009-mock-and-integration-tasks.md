# Plan 009: Split mobile tasks into mock and integration

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

Mobile (FE) work often waits on the backend: a plan lists one mobile issue per feature, and that issue can't be finished until the endpoints exist. The user wants every mobile feature that needs an endpoint split into two tasks:

- **mock:** the feature is built and tested against fake data, as soon as the API contract is on `develop`;
- **integration:** the feature is wired to the real API, and may only start once the backend endpoints are merged on `develop`.

Today `FakeAuthRemoteDataSource` (`mobile/lib/features/auth/data/datasources/fake_auth_remote_data_source.dart`) exists only for tests, and the running app always calls `AppConfig.apiBaseUrl`. The user wants the fake data to be usable in the running app too, so screens can be seen and screenshotted before the backend exists.

This is a change to the Claude rules and local tooling (Phase 0), so it goes through this plan.

## Open questions and assumptions

- **Mock data in the running app:** yes, selected with `--dart-define=API_MODE=mock` (decided by the user). The default stays `real`.
- **Contract first:** a mock task starts only when the contract (`docs/api/<module>.md`, `docs/api/examples/`, `docs/api/openapi.json`) is on `develop` (decided by the user). The fake returns the documented examples, so mobile and backend build against the same contract in parallel.
- **Assumption:** features with no backend call (pure UI, Health-only reading) stay a single issue.
- **Assumption:** release builds ignore `API_MODE=mock` and always use the real API, like `NetworkSimulation` only applies in debug builds.
- **Assumption:** plans 001 to 008 are not rewritten. The rule applies to plans written after this one is approved.
- **Question for the user:** label names. Proposed: `mock` and `integration`, next to the existing `frontend` label.

## Approach

### The rule

Goes into `CLAUDE.md` (Phase 1 and the verification evidence), `docs/plans/README.md`, `docs/workflow.md`, `.claude/agents/planner.md`, `.claude/agents/flutter-dev.md` and `.claude/skills/flutter-feature/SKILL.md`.

- A mobile feature that calls an endpoint is planned as two issues:

  | Issue | Labels | Depends on | Scope | Evidence |
  | --- | --- | --- | --- | --- |
  | `feat: <feature> (mobile, mock)` | `frontend`, `mock` | the contract issue | domain, presentation, repository, the Dio remote data source written against the contract, and `Fake<Feature>RemoteDataSource` returning the data from `docs/api/examples/` | bloc tests, `pumpScreen` and `expectAccessible`, goldens, a flow test with the fake, `flutter test test/contract`, a screenshot with `API_MODE=mock`. The Integration row is `Not verified: backend not merged` |
  | `feat: <feature> (mobile, integration)` | `frontend`, `integration` | the mock issue and every backend issue for those endpoints | run against the local backend, fix any drift from the contract, error mapping, remote data source tests | the Integration row: the app against the local backend, one success case and each error documented in `docs/api/` |

- **Integration gate:** Claude starts an integration issue only when every backend issue it depends on is closed and its endpoints are in `docs/api/openapi.json` on `develop`. Otherwise it stops and tells the user which backend issue is still open.
- If integration needs a contract change, the existing Phase 2 rule applies: stop and go back to the plan.
- Branch names stay `feat/<issue-id>-<short-name>`; the two issues already have different ids.
- The plan template's "Issues to create" gets an example of the pair with its `Depends on`.
- `docs/workflow.md` gets a small diagram: contract → backend and mobile mock in parallel → mobile integration.

### Selecting fake or real data sources (mobile)

- `AppConfig.apiMode` reads `--dart-define=API_MODE` (`real` by default, or `mock`).
- DI in `lib/core/di/` uses `injectable` environments: the real remote data sources are registered for `real`, the `Fake…RemoteDataSource` classes for `mock`. `FakeAuthRemoteDataSource` moves behind this switch.
- Release builds always use `real`.
- README run instructions show both modes.

Touches: mobile DI and config only. No public API, schema, authentication boundary, production data or cost is affected. The authentication flow itself is unchanged; only which data source answers it in a debug build with `API_MODE=mock`.

## Risks

- **The fake drifts from the backend.** Contained by building the fake from `docs/api/examples/` (already checked by `test/contract`), and by the integration task, which runs against the real backend.
- **A mock build reaches users.** Contained by ignoring `mock` in release builds, with a test.
- **More issues per feature.** Accepted: the mock task unblocks mobile work while the backend is in progress.

## Verification

- Issue 1: the changed docs render, links resolve, and `git grep -n "mock\|integration" CLAUDE.md docs/plans/README.md docs/workflow.md .claude/` shows the rule in each file.
- Issue 2: `flutter analyze` and `flutter test` pass, including tests for both modes and for release builds ignoring `mock`. Run the app with `--dart-define=API_MODE=mock` and against the local backend, or `Not verified: no emulator`.

## Ticket evidence

Both issues are chore / docs: the scope is above, and the behavior that must stay unchanged is that a build without `API_MODE` (and every release build) calls the real API exactly as today. No images needed.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `docs: split mobile tasks into mock and integration` | docs | - [ ] `CLAUDE.md`, `docs/plans/README.md` (template with the pair), `docs/workflow.md` (diagram), the `planner` and `flutter-dev` agents and the `flutter-feature` skill describe the two task types, their evidence and the integration gate<br>- [ ] The GitHub labels `mock` and `integration` exist, or the exact `gh label create` commands are given | none |
| 2 | `chore: select fake or real remote data sources with API_MODE (mobile)` | frontend | - [ ] `AppConfig.apiMode` reads `--dart-define=API_MODE`, `real` by default<br>- [ ] DI registers the `Fake…RemoteDataSource` classes for `mock` and the real ones for `real`; `FakeAuthRemoteDataSource` is behind the switch<br>- [ ] Release builds ignore `mock`, with a test<br>- [ ] Tests for both modes; `flutter analyze` and `flutter test` pass<br>- [ ] README shows how to run each mode | 1 |
