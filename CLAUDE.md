# CLAUDE.md

Guidance for Claude when working in this repository.

## Project

StrideQuest is a running app where every run is a quest: runners complete challenges to unlock medals. See `README.md` for the MVP scope.

The architecture is described, with diagrams, in [`docs/architecture.md`](docs/architecture.md); the decisions and their reasons are in [`docs/adr/0001-architecture.md`](docs/adr/0001-architecture.md). Existing code is still being moved to this layout, so follow the target layout for new code and don't copy older patterns.

- **Mobile:** Flutter (Dart), feature-first Clean Architecture, `go_router` for navigation, `flutter_test` for tests. Target packages, not all installed yet (check `pubspec.yaml`): `flutter_bloc` for state, `get_it` + `injectable` for DI, `dio` for HTTP, `freezed` + `json_serializable` for models, `bloc_test` and `mocktail` for tests.
- **Backend:** FastAPI on Python 3.12 as a modular monolith (modules `auth`, `challenges`, `runs`, `medals`). Async throughout: use `httpx.AsyncClient`, never block the event loop. Pydantic schemas for requests and responses, SQLAlchemy 2 async. Errors use the typed `ErrorResponse` from `docs/api/`, not free-form strings. Tests use `pytest` with the anyio plugin; unit tests mock repositories. Target, not set up yet: Alembic migrations, and integration tests against a PostgreSQL test database from `docker compose` (today's tests use in-memory SQLite).
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
- **Navigation:** sign-in and sign-out redirects come from the `GoRouter` `redirect`, driven by `AuthBloc` through a `refreshListenable` adapter. Routes pass IDs only, never objects through `state.extra`.
- **Blocs** are registered with `registerFactory` and created in the route's `BlocProvider`, so they close with the route.
- **Backend layers:** router → service → repository.
  - Routers never touch the database session.
  - Repositories only query and `flush`. The service, or the session dependency, commits or rolls back.
- **Backend modules** call each other only through services, never another module's repository or models.
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
3. Run lint.
4. Run type checks.

Passing tests don't prove everything works: `flutter_test` doesn't show the UI matches the design, and `pytest` doesn't show the mobile-backend flow works. Also verify by ticket type:

- **UI:** compare a screenshot of the running app with the design reference when the environment allows it.
- **Bug:** reproduce the bug before fixing it when feasible, then repeat the same steps after the fix.
- **API:** check the request, the response and the error contract.
- **Integration:** test the flow across components when it makes sense.
- **All tests:** report the exact commands run and their actual results.

If you can't run the app on an emulator or device, or have no data to reproduce the issue, say so plainly. Never claim the UI or a fix was verified when it wasn't.

### Phase 4: Verification gate

Before opening an MR, confirm:

1. **Acceptance criteria:** each criterion is met, and you can say how it was checked.
2. **Regression:** the full test suite passes.
3. **Security:** no leaked secrets, inputs are validated and authorization checks are in place.
4. **Git diff:** `git diff develop...HEAD` contains only changes for this issue.

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
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Do lint and tests pass locally?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure above?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the MR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
