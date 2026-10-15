# ADR 0001: Feature-first Flutter and modular FastAPI architecture

- **Status:** Accepted
- **Date:** 2026-10-15
- **Issue:** #25

## Context

The first version of the repo described a flat, layer-first layout on both sides: `mobile/lib/{ui,logic,data}` and `backend/app/{api,models,schemas,services}`. That layout is fine for a handful of files, but StrideQuest has four business areas (auth, challenges, runs, medals) that will each grow screens, endpoints, rules and tests. With a layer-first layout, one feature is spread over every top-level folder, and nothing stops one layer from reaching into another.

We want each layer and each feature to be testable in isolation, with dependencies injected so any layer can be replaced by a mock.

The detailed design, with diagrams, is in [`docs/architecture.md`](../architecture.md).

## Decision

| Area | Decision |
| --- | --- |
| Mobile layout | Feature-first Clean Architecture: `lib/core/`, `lib/shared/`, `lib/features/<feature>/{data,domain,presentation}`. |
| Mobile state | `flutter_bloc`. Blocs are registered as factories and scoped to the route that uses them. |
| Mobile DI | `get_it` + `injectable`. |
| Mobile HTTP | `dio`, with interceptors for the access token and the refresh flow in [`docs/api/auth.md`](../api/auth.md). |
| Mobile models | `freezed` + `json_serializable`, generated with `build_runner`. Data models map to domain entities. |
| Mobile navigation | `go_router`. Auth redirects come from `AuthBloc` through a stream-to-`Listenable` adapter passed to `refreshListenable`. Routes pass IDs only. |
| Mobile domain | Pure Dart. It may import `equatable` and `freezed_annotation`, nothing from Flutter or IO. Use cases are optional: add one only when logic spans several repositories or is reused. |
| Backend layout | Modular monolith: `app/core/` for shared infrastructure, `app/modules/{auth,challenges,runs,medals}/` each with `router.py`, `schemas.py`, `models.py`, `repository.py`, `service.py`, `deps.py`, and `app/api/v1/router.py` to mount them. |
| Backend layering | Router → service → repository. Routers never touch the session. Repositories only `flush`. The service, or the request's session dependency, commits or rolls back. Modules call each other only through services. |
| Backend errors | Services raise typed domain exceptions. A global handler maps them to the `ErrorResponse` shape in [`docs/api/auth.md`](../api/auth.md). |
| Backend migrations | Alembic. |
| Password hashing | `pwdlib` (Argon2 or bcrypt), not Passlib. |
| Backend tests | `pytest` with the anyio plugin. `tests/unit/` for services with `AsyncMock` repositories, and `tests/integration/` for routes against a PostgreSQL test database from `docker compose`, rolled back after each test. |
| Mobile tests | `flutter_test`, `bloc_test`, `mocktail`. Router tests build a real `GoRouter` and assert which screen is shown. |
| Diagrams | Mermaid in Markdown is the source. SVG exports of the key diagrams live in `docs/diagrams/`. |

## Alternatives considered

- **Layer-first backend (`app/{api,services,repositories,models,schemas}`).** It is closer to the current code, but it spreads each domain over five folders. It also does not match the "modular monolith" already described in the README.
- **SQLite in-memory for integration tests.** It is faster, but it differs from PostgreSQL in types, constraints, `ON DELETE` behaviour and transaction semantics, so tests could pass while production fails.
- **Keep the `http` package and plain classes for models.** There is less to migrate, but the auth contract needs a refresh-and-retry flow, and Dio interceptors handle that cleanly. Hand-written `fromJson` does not scale past a few models.
- **Mandatory use cases for every action.** This adds a file per action that mostly forwards to a repository, so they are optional instead.

## Consequences

- New mobile dependencies: `flutter_bloc`, `get_it`, `injectable`, `dio`, `freezed`, `freezed_annotation`, `json_serializable`, `equatable`, `build_runner`, `injectable_generator`, `flutter_secure_storage`, `bloc_test`, `mocktail`, and a health data plugin.
- New backend dependencies: `alembic`, `pwdlib`, and a JWT library (to be chosen with the auth implementation).
- Existing code does not follow this layout yet. It will move in follow-up issues:
  - `mobile/lib/data/auth` moves to `features/auth`;
  - the backend models and services move into `app/modules/*`;
  - the test `conftest.py` switches to PostgreSQL.
- Mounting routers under `/api/v1` changes public paths. [`docs/api/auth.md`](../api/auth.md) must be updated in its own merge request before the backend change, as that file requires.
