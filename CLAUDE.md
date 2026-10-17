# CLAUDE.md

Guidance for Claude when working in this repository.

## Project

StrideQuest is a running app where every run is a quest: runners complete challenges to unlock medals. See `README.md` for the MVP scope.

The architecture is described, with diagrams, in [`docs/architecture.md`](docs/architecture.md); the decisions and their reasons are in [`docs/adr/0001-architecture.md`](docs/adr/0001-architecture.md). Existing code is still being moved to this layout, so follow the target layout for new code and don't copy older patterns.

- **Mobile:** Flutter (Dart), feature-first Clean Architecture, `go_router` for navigation, `flutter_bloc` for state, `get_it` + `injectable` for DI (`lib/core/di/`), `dio` for HTTP, `freezed` + `json_serializable` for models (regenerate with `dart run build_runner build --force-jit` and commit the generated files), `flutter_secure_storage` for tokens. Tests use `flutter_test`, `bloc_test` and `mocktail`.
- **Backend:** FastAPI on Python 3.12 as a modular monolith (modules `auth`, `challenges`, `runs`, `medals`). Async throughout: use `httpx.AsyncClient`, never block the event loop. Pydantic schemas for requests and responses, SQLAlchemy 2 async, Alembic migrations in `backend/alembic/` (every schema change ships with a migration). Errors use the typed `ErrorResponse` from `docs/api/`, not free-form strings. Tests use `pytest` with the anyio plugin: `backend/tests/unit/` mock repositories and need no database; `backend/tests/integration/` run against a PostgreSQL test database from `docker compose` (`TEST_DATABASE_URL`), built from the migrations and rolled back after each test.
- **Data:** PostgreSQL. Medal images are static files in S3-compatible object storage (AWS S3 in production, SeaweedFS locally); the database stores only their URLs.
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
- **Blocs** are registered with `registerFactory` and created in the route's `BlocProvider`, so they close with the route. The one exception is `AuthBloc`: an app-wide `@lazySingleton`, because the router redirect and every screen need the same auth state. Don't add other app-wide blocs without the user's approval.
- **Backend layers:** router → service → repository.
  - Routers never touch the database session.
  - Repositories only query and `flush`. The service, or the session dependency, commits or rolls back.
- **Backend modules** call each other only through services, never another module's repository or models. One exception: a repository may eager-load another module's rows through an existing relationship to nest them, read-only, in a response schema ([ADR 0002](docs/adr/0002-cross-module-reads.md)).
- **Errors:** services raise typed domain exceptions. The global handler maps them to `ErrorResponse`.

## Language

- Explain things to the user in Vietnamese.
- Write all code, comments, docs, commit messages and MR text in English.

## Workflow

Every change goes through the phases below in order. Don't skip a gate. When a gate needs the user's approval, stop and ask. The phases, branching and review flow are drawn in [`docs/workflow.md`](docs/workflow.md); if it disagrees with this file, this file wins.

General rules:

- Work on one GitLab issue at a time.
- `develop` is the default branch. `main` holds released code and only receives merges from `develop`.
- Never push directly to `develop` or `main`.
- Don't commit unless asked. After each task, suggest a short commit message.

### Git and GitLab permissions

Being able to run a command is not permission to run it.

| Action | Allowed |
| --- | --- |
| Create a branch and edit files for an approved task | Yes |
| Commit | Only when the user asks |
| Push, open an MR | Only when the user asks or the task explicitly includes it |
| Create an issue | Only after the user confirms its title and content |
| Merge an MR, close an issue | Only when the user explicitly authorizes that MR or issue |
| Push to `develop`/`main`, force-push, delete branches | Never |

If a GitLab action isn't possible in the current session (no `glab`, no network, tool not permitted), say so and give the user the exact content to do it themselves: issue text, MR title and description, or commands.

### Phase 0: Project foundation

Set these up once and update them when they change: architecture, tech stack, repo layout, Claude rules (this file) and local tooling (Docker Compose, linters, formatters, test runners).

### Phase 1: Plan and issue

1. Classify the ticket by type and check that it has the evidence below (the ticket evidence gate).
2. Analyze the request and list open questions.
3. Write acceptance criteria.
4. Create or pick the GitLab issue, with the acceptance criteria in it.
5. Branch from `develop` as `<type>/<issue-id>-<short-name>` (for example `feat/1-readme`, `fix/12-step-sync`).

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
3. Present the plan before implementing. A feature that spans several layers (Flutter UI → repository → FastAPI → database) must be described in full, but needs no separate approval if it stays within the agreed architecture.
4. Stop and get the user's approval before implementing if the change involves any of:
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

A `Stop` hook (`.claude/hooks/check.sh`, set up in `.claude/settings.json`) runs these checks for the files you changed when you try to finish, and blocks until they pass: `flutter analyze` and `flutter test` for `mobile/`; `ruff check`, `ruff format --check`, `mypy` and `pytest tests/unit` for `backend/`. It skips the integration tests, which need Docker, so run those yourself before Phase 4. After 3 failed stops in a row it lets you stop and warns the user.

Passing tests don't prove everything works: `flutter_test` doesn't show the UI matches the design, and `pytest` doesn't show the mobile-backend flow works. Also verify by ticket type:

- **UI:** compare a screenshot of the running app with the design reference when the environment allows it.
- **Bug:** reproduce the bug before fixing it when feasible, then repeat the same steps after the fix.
- **API:** check the request, the response and the error contract.
- **Integration:** test the flow across components when it makes sense.

Record what you ran and what you saw as verification evidence (below). If you can't run the app on an emulator or device, or have no data to reproduce the issue, say so plainly with a `Not verified: <reason>` line. Never claim the UI or a fix was verified when it wasn't.

#### Verification evidence

Verification evidence shows the work was checked. It is not the ticket evidence from Phase 1, which is input from the reporter.

- Don't report a task as done without an `## Evidence` section in your report, in the format of the MR template. When the user asks for an MR, the same section goes into its description.
- Map each acceptance criterion to at least one piece of evidence. A change can match several rows below. Every row also includes the lint and type-check results.
- Redact tokens, passwords, `Authorization` headers, cookies and connection strings before pasting anything.
- Attach large logs and screenshots to the MR instead of committing them. Golden test baselines are test fixtures and are committed as usual. Font rendering differs between platforms, so generate and compare goldens on the same platform.

| Change | Evidence |
| --- | --- |
| Backend service / repository | `pytest` command and result summary; the full log if anything failed |
| Database schema | Run against the local docker-compose database only: `alembic upgrade head`, `alembic downgrade <develop head revision>`, `alembic upgrade head` again, and the resulting table definition (`\d <table>`) |
| API endpoint | Calls against the running server: one success case and each error case documented in `docs/api/`, with request, status code and JSON body. Error bodies match `ErrorResponse`. Keep the calls as a `.hurl` file in `backend/hurl/` and paste the output of `backend/hurl/run.sh`, so a reviewer can replay them. `pytest -m fuzz` (Schemathesis checks every response against the OpenAPI document) must pass |
| Bloc / logic | `flutter test <path>` command and result |
| UI | Screenshot of the running app next to the design reference. A screen has a golden test (`goldenScreen` in `mobile/test/helpers/`, CI goldens, so the images are the same on every machine). Attach the baseline image diff when a golden changes |
| Screen quality | `flutter test <page test>` using `pumpScreen` and `expectAccessible`: both phone sizes, both text scales, no overflow, accessibility guidelines, and each bloc state (loading, empty, error, success) |
| API contract change | The changed files under `docs/api/examples/` and the `docs/api/openapi.json` diff; `pytest tests/unit/test_api_examples.py tests/unit/test_error_contract.py tests/unit/test_openapi_snapshot.py` and `flutter test test/contract` results |
| New or changed route | `pytest tests/unit/test_auth_sweep.py` (the route is guarded, or listed in `PUBLIC_ROUTES` with `none` in the contract's `Auth` column), plus an ownership test for a user-owned resource: another user gets `404 not_found`. A response that nests rows (for example a quest with its challenges and medals) also needs a query-count test showing a fixed number of statements however many rows there are |
| Bug fix | The reproduction steps and the actual result before the fix; the same steps and the result after it |
| Integration | The flow exercised across components (for example the app against the local backend) and what was observed |
| Chore / docs | The commands run and their results |

If a piece of evidence can't be produced (no simulator, no database), write `Not verified: <reason>` instead. Never leave it out silently.

### Phase 4: Verification gate

Before opening an MR, confirm:

1. **Acceptance criteria:** each criterion is met, and you can say how it was checked.
2. **Regression:** the full test suite passes.
3. **Security:** no leaked secrets, inputs are validated and authorization checks are in place.
4. **Git diff:** `git diff develop...HEAD` contains only changes for this issue.
5. **Evidence:** the drafted `## Evidence` section covers each acceptance criterion, with evidence or a `Not verified: <reason>` line.

### Phase 5: MR and review

1. When the user asks, push the branch and open an MR into `develop` using `.gitlab/merge_request_templates/Default.md`, and link the issue with `Closes #<id>`.
2. As soon as the MR is open, Claude runs the `code-reviewer` subagent on it, following [Reviewing merge requests](#reviewing-merge-requests). This happens automatically — don't wait for the user to ask. This applies whether Claude opened the MR directly or a `fastapi-backend`/`flutter-dev` subagent did.
3. The user reviews the MR.
4. Address the review comments, then repeat Phases 3 and 4.

### Phase 6: Merge and close

1. The user approves the MR.
2. Claude merges only after the user explicitly authorizes merging that MR.
3. Verify `develop` after the merge:
   - the MR shows as merged into `develop`;
   - the merge commit and diff on `develop` contain the change;
   - the relevant local checks pass again on `develop`, when feasible.
4. Report a pipeline result only if a pipeline is configured and actually ran. The repo has no CI right now, so say "no pipeline" instead.
5. Close the issue if `Closes #<id>` did not close it.

## Reviewing merge requests

When asked to review an MR, walk these five steps in order and report findings under each step's heading. Write "No issues found" for a step with nothing to report. Don't skip ahead: a correctness problem matters more than a naming nit.

1. **Correctness:** does the change do what the linked issue asks? Check edge cases, error handling and the issue's acceptance criteria.
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Compare the tests with the contract in `docs/api/` and the issue's acceptance criteria, not only with the code, and flag an assertion that was changed to make a test pass. Do lint and tests pass locally?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure above?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the MR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
