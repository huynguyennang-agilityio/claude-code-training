# CLAUDE.md

Guidance for Claude when working in this repository.

## Project

StrideQuest is a running app where every run is a quest: runners complete challenges to unlock medals. See `README.md` for the MVP scope.

The architecture is described, with diagrams, in [`docs/architecture.md`](docs/architecture.md); the decisions and their reasons are in [`docs/adr/0001-architecture.md`](docs/adr/0001-architecture.md). Existing code is still being moved to this layout, so follow the target layout for new code and don't copy older patterns.

- **Mobile:** Flutter (Dart), feature-first Clean Architecture, `go_router` for navigation, `flutter_bloc` for state, `get_it` + `injectable` for DI (`lib/core/di/`), `dio` for HTTP, `freezed` + `json_serializable` for models (regenerate with `dart run build_runner build --force-jit` and commit the generated files), `flutter_secure_storage` for tokens, `health` for Apple Health and Health Connect (behind `HealthRepository`, so tests never need a device). Tests use `flutter_test`, `bloc_test` and `mocktail`.
- **Backend:** FastAPI on Python 3.12 as a modular monolith (modules `auth`, `challenges`, `runs`, `medals`). Async throughout: use `httpx.AsyncClient`, never block the event loop. Pydantic schemas for requests and responses, SQLAlchemy 2 async, Alembic migrations in `backend/alembic/` (every schema change ships with a migration). Errors use the typed `ErrorResponse` from `docs/api/`, not free-form strings. Tests use `pytest` with the anyio plugin: `backend/tests/unit/` mock repositories and need no database; `backend/tests/integration/` run against a PostgreSQL test database from `docker compose` (`TEST_DATABASE_URL`), built from the migrations and rolled back after each test.
- **Data:** PostgreSQL. Challenge cover and medal images are stored in Cloudinary, uploaded by the backend only; the database stores only their delivery URLs ([ADR 0003](docs/adr/0003-cloudinary-for-images.md)).
- **Health data:** the app reads steps from Apple Health or Health Connect on the device and syncs them to the backend.

## Planned structure

```text
mobile/lib/core/                                     DI, router, network, error, theme, config
mobile/lib/shared/                                   widgets and utils used by several features
mobile/lib/features/<feature>/{data,domain,presentation}
mobile/test/                                         mirrors lib/
backend/app/core/                                    config, database, security, storage, errors
backend/app/modules/<module>/                        router, schemas, models, repository, service, deps
backend/app/api/v1/router.py                         mounts module routers under /api/v1
backend/alembic/                                     migrations
backend/tests/{unit,integration}/                    pytest tests
```

## Architecture rules

- **Mobile dependency direction:** presentation → domain ← data. `domain/` is pure Dart: no Flutter, Dio or storage imports (`equatable` and `freezed_annotation` are allowed).
- **Mobile use cases** are optional. Add one only when logic spans several repositories or is reused; otherwise a bloc calls the repository interface.
- **Mobile styling:** colors and text styles come from `Theme.of(context)` (`colorScheme`, `textTheme`); spacing and corner radii from `AppSpacing` and `AppRadius` in `lib/core/theme/app_tokens.dart`. Outside `lib/core/theme/`, `test/core/theme/theme_tokens_guard_test.dart` fails on hex colors (`Color(0x…)`, `MaterialColor(0x…)`), `Color.from…` constructors, `Colors.*` and `CupertinoColors.*` (except `Colors.transparent`), and on any numeric literal in `EdgeInsets*` arguments, `SizedBox` `width`/`height`/`dimension`/`size`, `Radius`/`BorderRadius*` `.circular`/`.elliptical`, or `fontSize`, including arithmetic such as `AppSpacing.md * 2`. The guard reads source text, so it misses a raw value passed through a variable; the rule still applies. A value the scale lacks goes into `app_tokens.dart`, not inline.
- **Navigation:** sign-in and sign-out redirects come from the `GoRouter` `redirect`, driven by `AuthBloc` through a `refreshListenable` adapter. Routes pass IDs only, never objects through `state.extra`.
- **Blocs** are registered with `registerFactory` and created in the route's `BlocProvider`, so they close with the route. One bloc per flow: sign in, sign up and every later auth flow (forgot password, ...) each have their own (`SignInBloc`, `SignUpBloc`). The one exception is `AuthBloc`: an app-wide `@lazySingleton` that owns only the session (signed in or not), because the router redirect and every screen need the same auth state. The form blocs never touch it: they call the repository, which announces a new session on `sessionStarted`, and `AuthBloc` listens. Don't add other app-wide blocs without the user's approval.
- **Backend layers:** router → service → repository.
  - Routers never touch the database session.
  - Repositories only query and `flush`. The service, or the session dependency, commits or rolls back.
- **Backend modules** call each other only through services, never another module's repository or models. One exception: a repository may eager-load another module's rows through an existing relationship to nest them, read-only, in a response schema ([ADR 0002](docs/adr/0002-cross-module-reads.md)).
- **Errors:** services raise typed domain exceptions. The global handler maps them to `ErrorResponse`.

## Language

- Explain things to the user in Vietnamese.
- Write all code, comments, docs, commit messages and PR text in English.

## Workflow

Every change goes through the phases below in order. Don't skip a gate. When a gate needs the user's approval, stop and ask. The phases, branching and review flow are drawn in [`docs/workflow.md`](docs/workflow.md); if it disagrees with this file, this file wins.

General rules:

- Every non-trivial change starts from an approved plan file (Phase 1). No plan, no issue and no code.
- Work on one GitHub issue at a time.
- `develop` is the default branch. `main` holds released code and only receives merges from `develop`.
- Never push directly to `develop` or `main`.
- GitHub is the primary repository. GitLab is a read-only mirror that the user updates by hand from a machine on the VPN (see [GitLab mirror](README.md#gitlab-mirror)). Claude never pushes to the `gitlab` remote.
- Don't commit unless asked. After each task, suggest a short commit message.
- A grant such as "go ahead without asking" or "skip the review" covers only the tasks or the session the user named. Don't carry it to new work.

### Git and GitHub permissions

Being able to run a command is not permission to run it.

| Action | Allowed |
| --- | --- |
| Write a plan under `docs/plans/`, push its `docs/plan-NNN-<name>` branch and open its PR | Yes, when the user asks for work that needs a plan |
| Set `Status: approved` on a plan | Never. Only the user does |
| Create an issue | Only from a plan whose `Status:` is `approved` on `develop`, exactly as the plan lists it |
| Create a branch and edit files for an issue from an approved plan | Yes |
| Commit | Only when the user asks |
| Push, open a PR | Only when the user asks or the task explicitly includes it |
| Merge a PR, close an issue | Only when the user explicitly authorizes that PR or issue |
| Push to `develop`/`main`, force-push, delete branches | Never |
| Push to the `gitlab` remote | Never. The user mirrors GitLab by hand |

A `PreToolUse` hook (`.claude/hooks/block-forbidden-command.sh`, set up in `.claude/settings.json`) refuses the rows marked Never that are git commands: pushing to `develop`/`main`, force-pushing, deleting branches and pushing to `gitlab`. It is a best-effort guard, not a replacement for this rule. Its tests are in `.claude/hooks/test-block-forbidden-command.sh`.

The Claude workflows on GitHub (`claude-review.yml`, `claude.yml`, see [CI and Claude on GitHub](README.md#ci-and-claude-on-github)) follow the same table. On GitHub a ruleset backs it: `develop` and `main` refuse direct pushes, force-pushes and deletion for everyone, with no bypass, so changes reach them only through a pull request.

If a GitHub action isn't possible in the current session (no `gh`, no network, tool not permitted), say so and give the user the exact content to do it themselves: issue text, PR title and description, or commands.

### Phase 0: Project foundation

Set these up once and update them when they change: architecture, tech stack, repo layout, Claude rules (this file) and local tooling (Docker Compose, linters, formatters, test runners).

### Phase 1: Plan, approval and issues

Every change goes through a plan file first. The one exception is a trivial change (a typo, a one-line fix); say in your reply that you are treating it as trivial.

1. Classify the ticket by type and check that it has the evidence below (the ticket evidence gate).
2. Write the plan as `docs/plans/NNN-<short-name>.md` (`NNN` is the next number; use the template in [`docs/plans/README.md`](docs/plans/README.md)): context, open questions and assumptions, approach (layers, files, API, schema, security), risks, verification, and the list of issues to create, each with a title, labels, acceptance criteria and dependencies.
3. Put it on a `docs/plan-NNN-<short-name>` branch from `develop` and open a PR into `develop`. A plan needs no issue. Its first line after the title is `Status: draft`.
4. Stop. The user reviews the plan and, when they agree, sets `Status: approved` (with the date) and merges the PR, or tells you to. You never write `approved` yourself. If the plan is edited after approval, it goes back to `draft` and needs approval again.
5. Only when the plan is `approved` on `develop`: create the issues exactly as the plan lists them, each with `Plan: docs/plans/NNN-<short-name>.md` in its description, and write the issue numbers back into the plan's `Issues:` line (a docs change through its own PR).
6. Branch from `develop` as `<type>/<issue-id>-<short-name>` (for example `feat/1-readme`, `fix/12-step-sync`).

If the work needs something the approved plan does not cover (a new endpoint, a schema change, a dependency, a larger scope), stop and go back to step 2.

**Mobile tasks: mock and integration**

A mobile feature that calls an endpoint is planned as two issues, so mobile work doesn't wait on the backend ([plan 009](docs/plans/009-mock-and-integration-tasks.md)). A feature with no backend call (pure UI, Health-only reading) stays one issue.

| Issue | Labels | Depends on | Scope | Evidence |
| --- | --- | --- | --- | --- |
| `feat: <feature> (mobile, mock)` | `frontend`, `mock` | the contract issue: `docs/api/<module>.md` and `docs/api/examples/` on `develop` | domain, presentation, repository, the Dio remote data source written against the contract, and `Fake<Feature>RemoteDataSource` returning Dart fixtures copied from the examples it needs | the Bloc / logic, UI and Screen quality rows; a flow test with the fake; `flutter test test/contract`, including a test that each fixture equals its example file; a screenshot with `--dart-define=API_MODE=mock`. The Integration row is `Not verified: backend not merged` |
| `feat: <feature> (mobile, integration)` | `frontend`, `integration` | the mock issue and every backend issue for those endpoints | run against the local backend, fix drift from the contract, error mapping, remote data source tests | the Integration row: the app against the local backend, one success case and each error documented in `docs/api/` |

- The contract that unblocks a mock task does not include `docs/api/openapi.json`. `backend/tests/unit/test_openapi_snapshot.py` requires that file to match the schema the backend serves, so it changes with the backend issue.
- **Integration gate:** start an integration issue only when every backend issue it depends on is closed and its endpoints are in `docs/api/openapi.json` on `develop`. Otherwise stop and tell the user which backend issue is still open.
- If integration needs a contract change, stop and go back to step 2.

**Ticket evidence gate**

| Ticket type | Required evidence |
| --- | --- |
| `ui` | Screenshot, mockup or Figma reference; a video when the interaction matters |
| Feature with UI | Design reference if the UI must follow an existing design; description of the expected behavior |
| `bug` | Steps to reproduce, expected result, actual result; screenshot, video or log when relevant |
| Backend / API | Sample request and response; error log or stack trace when relevant |
| Refactor / chore | Scope and the behavior that must stay unchanged; no images needed |

- **Required evidence missing:** ask for it before writing code. Don't guess what the user wants.
- **Non-essential detail missing:** continue only if you state the assumption in the issue or plan and it doesn't materially change the result.

For `ui` tickets and features with UI, the acceptance criteria also name the states the screen can show (loading, empty, error, success, as they apply) and the screen sizes and text scales to support. The default is 375×667 and 430×932 at text scale 1.0 and 2.0 (`pumpScreen` in `mobile/test/helpers/`).

Don't demand images for every ticket. A bug with a wrong HTTP status needs the request, response and log, not a screenshot.

### Phase 2: Design gate

1. Analyze the impact: the layers, files, database tables and mobile/backend interactions the change touches.
2. Define or update the API and data contract (endpoints, Pydantic schemas, tables) in `docs/api/`.
3. The approved plan is the presentation: a feature that spans several layers (Flutter UI → repository → FastAPI → database) is described in full there. If the implementation has to differ from it, update the plan and get it approved again before going on.
4. The plan must call out, and the user's approval must cover, any of these:
   - a public API change or a breaking contract change;
   - a database schema change, or a migration that could lose data;
   - authentication, authorization or another security boundary;
   - architecture, dependency direction or core technology;
   - anything that can affect real data, production environments or external costs.

### Phase 3: Implement and test

Build in small steps. For each step:

1. Write the code.
2. Add or update tests. Every feature needs tests.
3. Run lint: `flutter analyze` in `mobile/`; `ruff check .` and `ruff format --check .` in `backend/`.
4. Run type checks: `flutter analyze` covers Dart; `mypy` in `backend/` (strict, configured in `pyproject.toml`).

A `PostToolUse` hook (`.claude/hooks/format-on-edit.sh`, set up in `.claude/settings.json`) formats each Python file under `backend/` (`ruff format`) and each Dart file under `mobile/lib/` or `mobile/test/` (`dart format`) right after you write it with `Edit` or `Write`. Generated Dart files are skipped, and files changed through Bash are not formatted. The `Stop` hook below still checks them. Its tests are in `.claude/hooks/test-format-on-edit.sh`.

A `Stop` hook (`.claude/hooks/check.sh`, set up in `.claude/settings.json`) runs these checks for the files you changed when you try to finish, and blocks until they pass: `flutter analyze` and `flutter test` for `mobile/`; `ruff check`, `ruff format --check`, `mypy` and `pytest tests/unit` for `backend/`. It skips the integration tests, which need Docker, so run those yourself before Phase 4. After 3 failed stops in a row it lets you stop and warns the user. In GitHub Actions (`GITHUB_ACTIONS=true`) it does nothing. Its tests are in `.claude/hooks/test-check.sh`.

CI on GitHub runs the same checks on every PR into `develop` and every push to `develop`, plus the integration tests against PostgreSQL: `.github/workflows/backend-ci.yml` (job `backend`) and `.github/workflows/mobile-ci.yml` (jobs `mobile` and `goldens`). Each job always reports, and runs its checks only when its folder (`backend/**` or `mobile/**`), `docs/api/**` or its own workflow file changed. The golden tests run in the `goldens` job on `macos-15`, because the baselines only match on macOS (Apple Silicon); the `mobile` job on Linux skips them. All three jobs are required checks for merging into `develop`.

A macOS notification (`.claude/hooks/notify.sh`, on the `Stop` and `Notification` events in `.claude/settings.json`) tells the user when you finish or need them. It also appears for a stop that the `Stop` hook above then blocks. Set `STRIDEQUEST_NOTIFY=0` to switch it off. Its tests are in `.claude/hooks/test-notify.sh`.

Passing tests don't prove everything works: `flutter_test` doesn't show the UI matches the design, and `pytest` doesn't show the mobile-backend flow works. Also verify by ticket type:

- **UI:** compare a screenshot of the running app with the design reference when the environment allows it.
- **Bug:** reproduce the bug before fixing it when feasible, then repeat the same steps after the fix.
- **API:** check the request, the response and the error contract.
- **Integration:** test the flow across components when it makes sense.

Record what you ran and what you saw as verification evidence (below). If you can't run the app on an emulator or device, or have no data to reproduce the issue, say so plainly with a `Not verified: <reason>` line. Never claim the UI or a fix was verified when it wasn't.

#### Verification evidence

Verification evidence shows the work was checked. It is not the ticket evidence from Phase 1, which is input from the reporter.

- Don't report a task as done without an `## Evidence` section in your report, in the format of the PR template. When the user asks for a PR, the same section goes into its description.
- Map each acceptance criterion to at least one piece of evidence. A change can match several rows below. Every row also includes the lint and type-check results.
- Redact tokens, passwords, `Authorization` headers, cookies and connection strings before pasting anything.
- Attach large logs and screenshots to the PR instead of committing them. Golden test baselines are test fixtures and are committed as usual. Rendering differs between operating systems, so generate and compare goldens on the same platform: baselines are generated on an Apple Silicon Mac (`flutter test --update-goldens --tags golden`) and CI compares them on `macos-15` (the `goldens` job). If the `goldens` job fails, its `golden-failures` artifact holds the diff images.

| Change | Evidence |
| --- | --- |
| Backend service / repository | `pytest` command and result summary; the full log if anything failed |
| Database schema | Run against the local docker-compose database only: `alembic upgrade head`, `alembic downgrade <develop head revision>`, `alembic upgrade head` again, and the resulting table definition (`\d <table>`) |
| API endpoint | Calls against the running server: one success case and each error case documented in `docs/api/`, with request, status code and JSON body. Error bodies match `ErrorResponse`. Keep the calls as a `.hurl` file in `backend/hurl/` and paste the output of `backend/hurl/run.sh`, so a reviewer can replay them. `pytest -m fuzz` (Schemathesis checks every response against the OpenAPI document) must pass |
| Bloc / logic | `flutter test <path>` command and result |
| UI | Screenshot of the running app next to the design reference. A screen has a golden test (`goldenScreen` in `mobile/test/helpers/`), generated on an Apple Silicon Mac and checked in CI by the `goldens` job. Attach the baseline image diff when a golden changes |
| Screen quality | `flutter test <page test>` using `pumpScreen` and `expectAccessible`: both phone sizes, both text scales, no overflow, accessibility guidelines, and each bloc state (loading, empty, error, success) |
| API contract change | The changed files under `docs/api/examples/` and the `docs/api/openapi.json` diff; `pytest tests/unit/test_api_examples.py tests/unit/test_error_contract.py tests/unit/test_openapi_snapshot.py` and `flutter test test/contract` results |
| New or changed route | `pytest tests/unit/test_auth_sweep.py` (the route is declared in `ROUTE_ACCESS` as `public`, `user` or `admin`, with the same requirement in the contract's `Auth` column; an `admin` route answers a signed-in user with `403 forbidden`), plus an ownership test for a user-owned resource: another user gets `404 not_found`. A response that nests rows (for example a quest with its challenges and medals) also needs a query-count test showing a fixed number of statements however many rows there are |
| Bug fix | The reproduction steps and the actual result before the fix; the same steps and the result after it |
| Integration | The flow exercised across components (for example the app against the local backend) and what was observed |
| Chore / docs | The commands run and their results |

If a piece of evidence can't be produced (no simulator, no database), write `Not verified: <reason>` instead. Never leave it out silently.

### Phase 4: Verification gate

Before opening a PR, confirm:

1. **Acceptance criteria:** each criterion is met, and you can say how it was checked.
2. **Regression:** the full test suite passes.
3. **Security:** no leaked secrets, inputs are validated and authorization checks are in place.
4. **Git diff:** `git diff develop...HEAD` contains only changes for this issue.
5. **Evidence:** the drafted `## Evidence` section covers each acceptance criterion, with evidence or a `Not verified: <reason>` line.

### Phase 5: PR and review

1. When the user asks, push the branch and open a PR into `develop` using `.github/pull_request_template.md`, link the issue with `Closes #<id>`, and name the plan (`Plan: docs/plans/NNN-<short-name>.md`). Say where the work deviates from the plan, or write "No deviations".
2. The `claude-review.yml` workflow reviews each PR into `develop` when it opens, is marked ready for review or is reopened, and again when a collaborator comments `@claude review`. It runs the `code-reviewer` subagent, following [Reviewing pull requests](#reviewing-pull-requests), and posts one comment that later runs edit. New commits do not start a review: comment `@claude review` after the last push. Claude runs the `code-reviewer` subagent locally only when the user asks (for example before pushing), or when the workflow did not run: a PR from a fork, a draft, a missing secret, a failed workflow, or a PR into another branch. Each subagent's model is set in the `model:` line of `.claude/agents/<name>.md`; a hard task can override it for one call.
3. The user reviews the PR.
4. Address the review comments, then repeat Phases 3 and 4.

### Phase 6: Merge and close

1. The user approves the PR.
2. Claude merges only after the user explicitly authorizes merging that PR. Approving a plan, or an earlier "go ahead", is not that authorization.
3. Verify `develop` after the merge:
   - the PR shows as merged into `develop`;
   - the merge commit and diff on `develop` contain the change;
   - the relevant local checks pass again on `develop`, when feasible.
   - remind the user to mirror the merge to GitLab ([GitLab mirror](README.md#gitlab-mirror)).
4. Report the CI result: the `backend` and `mobile` runs for the merge commit on `develop` (`gh run list --branch develop --event push`). If a run failed or did not run, say so.
5. Close the issue if `Closes #<id>` did not close it.

## Reviewing pull requests

When asked to review a PR, walk these five steps in order and report findings under each step's heading. Write "No issues found" for a step with nothing to report. Don't skip ahead: a correctness problem matters more than a naming nit.

1. **Correctness:** does the change do what the linked issue asks? Check edge cases, error handling and the issue's acceptance criteria. Check that the PR links its issue (`Closes #<id>`) and names its plan (`Plan: docs/plans/NNN-<short-name>.md`), and that it lists its deviations from the plan or says "No deviations".
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Compare the tests with the contract in `docs/api/` and the issue's acceptance criteria, not only with the code, and flag an assertion that was changed to make a test pass. Do lint and tests pass, locally or in CI? Does the PR's `## Evidence` section cover each acceptance criterion of the linked issue, or say `Not verified: <reason>`?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure above?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the PR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
