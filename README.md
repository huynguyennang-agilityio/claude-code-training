# StrideQuest

StrideQuest is a running app where every run is a quest. Runners pick a challenge, go for a run, and unlock digital medals when they complete it.

## MVP scope

The first version focuses on one complete user journey rather than many features.

1. **Discover challenges:** browse available running quests, with their distances, requirements and rewards.
2. **Start a run:** read the step count from Apple Health (iOS) or Health Connect (Android).
3. **Track progress:** show progress toward the challenge target.
4. **Complete a challenge:** validate the recorded run against the challenge rules.
5. **Unlock a medal:** award a digital medal and add it to the user's collection.
6. **View achievements:** review completed challenges and earned medals.

## Tech stack

| Part | Technology |
| --- | --- |
| Mobile app | Flutter (Dart), feature-first Clean Architecture |
| Mobile state and DI | `flutter_bloc`, `get_it` + `injectable` |
| Mobile networking and models | `dio`, `freezed` + `json_serializable` (generated with `build_runner`) |
| Mobile navigation | `go_router` |
| Backend | FastAPI on Python 3.12 as a modular monolith, async throughout, Pydantic schemas |
| Backend data access | SQLAlchemy 2 (async) with Alembic migrations |
| Database | PostgreSQL |
| Medal images | S3-compatible object storage (AWS S3 in production, SeaweedFS locally) |
| Health data | Apple Health (iOS) and Health Connect (Android), read on the device |

## Architecture

StrideQuest is a modular monolith: one FastAPI app split into the modules `auth`, `challenges`, `runs` and `medals`, which share one PostgreSQL database. The Flutter app is organised by the same features.

![StrideQuest system context](docs/diagrams/system-context.svg)

The Mermaid source of this diagram, and the other architecture diagrams, are in [`docs/architecture.md`](docs/architecture.md).

- The app reads step data on the device and syncs it to the backend.
- Protected routes need a JWT access token. Sign up, sign in, refresh, sign out and `/api/v1/health` don't; see [`docs/api/auth.md`](docs/api/auth.md).
- The `runs` module validates a run against the challenge rules from `challenges` and gets the medal from `medals` when the run passes.
- Medal images are static files in object storage; PostgreSQL stores only their URLs.

More detail:
- [`docs/architecture.md`](docs/architecture.md): layers, module diagrams, request and run-sync flows, data model and test strategy.
- [ADR 0001](docs/adr/0001-architecture.md): why we chose this architecture.
- Issue #6: run validation, deduplication and anti-cheat.

## Project structure (planned)

Some folders below don't exist yet; existing code is being moved to this layout.

```text
backend/                    FastAPI app
  alembic/                  Database migrations
  app/
    core/                   Config, database, security, storage, errors
    modules/
      auth/                 router, schemas, models, repository, service, deps
      challenges/           Same files
      runs/                 Same files
      medals/               Same files
    api/v1/router.py        Mounts module routers under /api/v1
    main.py                 App factory and exception handlers
  tests/
    unit/                   Services with mocked repositories
    integration/            Routes against a PostgreSQL test database
mobile/                     Flutter app
  lib/
    core/                   DI, router, network, error, theme, config
    shared/                 Widgets and utils used by several features
    features/
      auth/                 data/, domain/, presentation/
      challenges/           Same layers
      runs/                 Same layers, plus the health data source
      medals/               Same layers
  test/                     Mirrors lib/
docs/                       Architecture, workflow, ADRs, API contracts, diagrams
docker-compose.yml          Local PostgreSQL and SeaweedFS (S3-compatible storage)
```

## Getting started

> **Status:** the code is not in the repository yet. The steps below describe the planned setup and will be confirmed as issues #2 to #5 land.

### Prerequisites

| Tool | Version |
| --- | --- |
| Python | 3.12.x |
| Flutter SDK | 3.47.7 (stable channel, Dart 3.13.5) |
| Docker and Docker Compose | Docker 24 or newer, Compose v2 |
| Xcode (iOS builds) | Latest stable release from the Mac App Store |
| Android Studio (Android builds) | Latest stable release |

Supported platforms:

| Platform | Minimum version | Health data source |
| --- | --- | --- |
| iOS | iOS 15.0 | Apple Health (HealthKit) |
| Android | Android 9 (API level 28) | Health Connect |

### Run the backend (planned)

```bash
cp .env.example .env
docker compose up -d --wait
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

The API will be available at http://localhost:8000, with interactive docs at http://localhost:8000/docs and a health check at `GET /api/v1/health`. Every API route is under `/api/v1`.

### Database migrations

The schema is managed by Alembic in `backend/alembic/`. The database URL comes from `DATABASE_URL` (via `DatabaseSettings` in `app/core/config.py`), never from `alembic.ini`. Migrations need only `DATABASE_URL`: the S3 and JWT settings are not required, so a migration job in CI or a deploy doesn't need them. Run these from `backend/` with the virtual environment active:

```bash
alembic upgrade head
```

```bash
alembic revision --autogenerate -m "add medal awards table"
```

```bash
alembic check
```

- **Every schema change ships with a migration in the same merge request.** Review the generated file before committing: autogenerate misses some changes, such as renames.
- **`alembic check` must report no new operations** before you open the merge request.

**One-time reset for databases created before Alembic.** If your local database was created before migrations existed, recreate it instead of stamping it.

This **deletes all local database data** (the `db-data` volume). It keeps the medal images in object storage (the `storage-data` volume), so don't use `docker compose down -v`, which deletes both.

1. Stop and remove the database container:

   ```bash
   docker compose rm --stop --force db
   ```

2. Find the database volume. Its name starts with the Compose project name, which is this folder's name by default, for example `source-code_db-data`:

   ```bash
   docker volume ls --filter name=db-data
   ```

3. Delete that volume, using the exact name from the previous step:

   ```bash
   docker volume rm source-code_db-data
   ```

4. Start an empty database and wait until it is healthy:

   ```bash
   docker compose up -d --wait db
   ```

5. Create the schema:

   ```bash
   cd backend && alembic upgrade head
   ```

### Run the mobile app (planned)

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1/
```

`API_BASE_URL` is the API base including `/api/v1/` (see `docs/api/auth.md`); the value above is also the default. On the Android emulator, use `http://10.0.2.2:8000/api/v1/` to reach the host machine.

To see loading, retry and error states, make the network behave badly (debug builds only; a release build ignores these):

```bash
flutter run --dart-define=SIMULATE_LATENCY_MS=2000                       # every request waits 2 s
flutter run --dart-define=SIMULATE_FAULT=offline                          # every request fails like a lost connection
flutter run --dart-define=SIMULATE_FAULT=timeout                          # every request fails like a connect timeout
flutter run --dart-define=SIMULATE_FAULT=flaky --dart-define=SIMULATE_LATENCY_MS=500   # every 3rd request fails
```

Reading step data needs a real device or a simulator with Apple Health or Health Connect data available.

### Lint and test

Backend (with the virtual environment active):

```bash
cd backend
pip install -r requirements-dev.txt
ruff check .
ruff format --check .
mypy
pytest
```

Backend tests are split in two:

- **`tests/unit/`** needs no database or Docker. Run it alone with `pytest tests/unit`.
- **`tests/integration/`** runs against PostgreSQL, and includes the Schemathesis fuzz test (`pytest -m fuzz` runs only it, `pytest -m "not fuzz"` skips it). Start the database before running `pytest`:

  ```bash
  docker compose up -d --wait db
  ```

  The tests use `TEST_DATABASE_URL` from `.env` (see `.env.example`):
  - the database name must be letters, digits and underscores ending in `_test`, because each run wipes its `public` schema;
  - the database is created if it doesn't exist, migrated with `alembic upgrade head`, and each test is rolled back.

To replay the API calls of a module against a running server (`brew install hurl`; start the database and `uvicorn app.main:app` first):

```bash
backend/hurl/run.sh                          # the auth flow against http://localhost:8000/api/v1
backend/hurl/run.sh http://host:8000/api/v1  # another server
backend/hurl/run.sh --rate-limit             # also the rate limit (uses part of the per-IP budget)
```

Mobile:

```bash
cd mobile
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

To run the sign-in flow in the real app against the real backend, start the database and the API (`uvicorn app.main:app`), boot a simulator, then:

```bash
cd mobile
flutter test integration_test/sign_in_flow_test.dart -d <device id>
```

The test creates its own user through the API, so it can be repeated. It uses the Keychain, so if an earlier run was interrupted while signed in, reset it with `xcrun simctl keychain <device id> reset`.

Ruff and pytest are configured in `backend/pyproject.toml`; Dart lints are configured in `mobile/analysis_options.yaml`.

Regenerate code after changing a Freezed model, a `@JsonKey` or an `@injectable` registration, and commit the generated `*.g.dart`, `*.freezed.dart` and `injection.config.dart` files with the change:

```bash
cd mobile && dart run build_runner build --force-jit
```

`--force-jit` is needed because a dependency uses Dart build hooks, which the default AOT build script does not support.

## Development guidelines

- **Backend:**
  - Async throughout. Use `httpx.AsyncClient` for outgoing calls and never block the event loop.
  - Keep each module's router → service → repository layers separate. Modules talk to each other only through services.
  - Define request and response bodies as Pydantic models, and return errors as the typed `ErrorResponse` rather than free-form strings.
- **Mobile:**
  - Organise code by feature. Each feature has `data/`, `domain/` and `presentation/`; `domain/` stays pure Dart.
  - Use blocs for state and `get_it` for DI.
  - Navigate with `go_router`, passing only IDs in routes.
- **Tests:** add tests with every feature. Backend: `pytest` unit tests for services and integration tests for routes. App: `flutter_test`, `bloc_test` and `mocktail`.
- **Language:** code, comments, docs, commit messages and merge requests are written in English.
- **Secrets:** never commit secrets. Add new settings to `.env.example` with placeholder values.

## Development workflow

1. Pick a GitLab issue and create a branch from `develop` named `<type>/<issue-id>-<short-name>`, for example `feat/1-readme`.
2. Commit small, focused changes with messages such as `feat: add challenge list endpoint`.
3. Run lint and tests locally before pushing.
4. Push the branch and open a merge request into `develop` using the default template. Link the issue with `Closes #<id>`.
5. Review the merge request in this order: correctness, tests, readability, security basics, scope.
6. Address review comments, make sure lint and tests pass locally, then merge.

`develop` is the default branch and collects finished work. `main` holds released code and is updated only by merging `develop` into it. Both branches are protected, so changes land only through merge requests.

The full workflow, with its gates, is in [`CLAUDE.md`](CLAUDE.md#workflow) and drawn in [`docs/workflow.md`](docs/workflow.md).
