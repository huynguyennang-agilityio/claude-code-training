# StrideQuest architecture

This is the target architecture agreed in [ADR 0001](adr/0001-architecture.md). Existing code is being moved to it in follow-up issues, so some folders below don't exist yet.

The Mermaid blocks in this file are the source for the diagrams. Exported SVG copies of the key diagrams are in [`diagrams/`](diagrams/).

## 1. System context

The app reads steps on the device and syncs them to one FastAPI app, which validates runs and awards medals. Challenge cover and medal images are stored in Cloudinary; the database only stores their delivery URLs. Presentation copy: [`diagrams/system-context.svg`](diagrams/system-context.svg).

```mermaid
flowchart LR
    HK["Apple Health / Health Connect"] -->|steps| APP["Flutter app"]
    APP -->|"HTTPS + JWT, /api/v1"| API["FastAPI modular monolith"]
    API --> DB[("PostgreSQL")]
    IMG[("Cloudinary<br/>images")] -->|"cover and medal images by URL"| APP
    subgraph API_MODULES["Backend modules"]
        AUTH["auth"]
        CH["challenges"]
        RUNS["runs"]
        MED["medals"]
    end
    API --- API_MODULES
```

## 2. Mobile app

### Folder structure

```text
mobile/lib/
├── core/                  # App-wide setup, no feature logic
│   ├── config/            # Env, constants
│   ├── di/                # get_it + injectable setup
│   ├── error/             # Failure and exception types
│   ├── network/           # Dio client, auth and refresh interceptors
│   ├── router/            # GoRouter, redirect, GoRouterRefreshStream adapter
│   └── theme/             # Colors, typography, AppTheme
├── shared/                # Widgets, extensions and utils used by several features
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/   # Remote (Dio) and local (secure storage)
│   │   │   ├── models/        # Freezed DTOs with toEntity()
│   │   │   └── repositories/  # Implements the domain interface
│   │   ├── domain/            # Pure Dart
│   │   │   ├── entities/
│   │   │   ├── repositories/  # Abstract interfaces
│   │   │   └── usecases/      # Optional
│   │   └── presentation/
│   │       ├── bloc/
│   │       ├── pages/
│   │       └── widgets/
│   ├── challenges/        # Same three layers
│   ├── runs/              # Same, plus data/datasources/health_data_source.dart
│   └── medals/            # Same three layers
└── main.dart
```

### Layers and dependency direction

Arrows point from the caller to what it depends on. The domain layer depends on nothing: data implements its interfaces, and presentation calls them. Presentation copy: [`diagrams/flutter-layers.svg`](diagrams/flutter-layers.svg).

```mermaid
flowchart TB
    subgraph PRES["presentation"]
        PAGE["Pages and widgets"] --> BLOC["Bloc"]
    end
    subgraph DOM["domain (pure Dart)"]
        UC["Use cases (optional)"]
        REPO_I["Repository interfaces"]
        ENT["Entities"]
        UC --> REPO_I
        REPO_I --> ENT
    end
    subgraph DATA["data"]
        REPO_IMPL["Repository impl"] --> DS["Data sources"]
        DS --> DTO["Freezed models"]
    end
    BLOC --> UC
    BLOC --> REPO_I
    REPO_IMPL -.implements.-> REPO_I
    DS --> DIO["Dio"]
    DS --> HEALTH["Health plugin"]
    DS --> SECURE["Secure storage"]
    CORE["core: di, router, network, error"] -.wires.-> PRES
    CORE -.wires.-> DATA
```

### Feature map

```mermaid
flowchart LR
    subgraph AUTH["auth"]
        A1["SignInPage"] --> A3["SignInBloc"]
        A4["SignUpPage"] --> A5["SignUpBloc"]
        A3 --> A6["AuthRepository"]
        A5 --> A6
        A6 -->|"sessionStarted, sessionExpired"| A2["AuthBloc (session)"]
    end
    subgraph CHAL["challenges"]
        C1["ChallengeListPage, ChallengeDetailPage"] --> C2["ChallengeListBloc, ChallengeDetailBloc"]
    end
    subgraph RUNS["runs"]
        R1["RunProgressPage"] --> R2["RunBloc"]
        R2 --> R3["HealthDataSource"]
    end
    subgraph MEDALS["medals"]
        M1["AchievementsPage, MedalDetailPage"] --> M2["MedalsBloc"]
    end
    A2 -->|"auth state"| ROUTER["core/router"]
```

### Auth redirect

Screens never navigate on sign-in or sign-out themselves. The router listens to `AuthBloc`, which owns only the session, and redirects. The sign-in and sign-up forms each have their own bloc; after a success, the repository announces the session on `sessionStarted` and `AuthBloc` picks it up. `GoRouterRefreshStream` is a small `ChangeNotifier` adapter we write in `core/router`; go_router does not ship it.

```mermaid
sequenceDiagram
    participant UI as Any page
    participant AB as AuthBloc
    participant AD as GoRouterRefreshStream
    participant GR as GoRouter
    UI->>AB: SignOutRequested
    AB-->>AD: emits Unauthenticated
    AD->>GR: notifyListeners()
    GR->>GR: redirect(state)
    GR-->>UI: go to /sign-in
```

### Routing rules

- Routes carry IDs only, for example `/challenges/:id`. The page's bloc fetches the data. Don't pass objects through `state.extra`.
- Blocs are registered with `registerFactory` and created in the route's `BlocProvider(create: ...)`, so they close when the route is popped.
- One bloc per flow (`SignInBloc`, `SignUpBloc`, and one for each later auth flow).
- Exception: `AuthBloc` is an app-wide `@lazySingleton`, provided once above `MaterialApp.router`, because the router's `redirect` and every screen read the same auth state. It owns only the session and lives as long as the app.

## 3. Backend

### Folder structure

```text
backend/
├── alembic/                   # Migrations
├── app/
│   ├── core/
│   │   ├── config.py          # Pydantic settings
│   │   ├── database.py        # Async engine, session dependency
│   │   ├── security.py        # JWT, password hashing (pwdlib)
│   │   ├── storage.py         # Cloudinary client (signed uploads), URL helper
│   │   └── errors.py          # Domain exceptions, ErrorResponse, handlers
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── router.py      # HTTP only: validate, call service, return schema
│   │   │   ├── schemas.py     # Pydantic request and response models
│   │   │   ├── models.py      # SQLAlchemy models
│   │   │   ├── repository.py  # Queries, takes an AsyncSession
│   │   │   ├── service.py     # Business rules, raises domain exceptions
│   │   │   └── deps.py        # Depends() factories, get_current_user
│   │   ├── challenges/        # Same files
│   │   ├── runs/              # Same files, plus validation.py (validate_run)
│   │   ├── medals/            # Same files
│   │   └── models.py          # Imports every module's models for Base.metadata
│   ├── api/
│   │   └── v1/
│   │       ├── router.py      # Mounts every module router under /api/v1
│   │       └── health.py      # GET /api/v1/health
│   └── main.py                # App factory, exception handlers
├── tests/
│   ├── conftest.py            # anyio backend, model registry
│   ├── unit/                  # No database: services with AsyncMock repositories, pure logic
│   └── integration/
│       ├── conftest.py        # PostgreSQL test DB from migrations, rollback per test, client
│       └── test_*.py          # Models, migrations and HTTP routes against the test DB
└── pyproject.toml
```

### Modules and layers

Modules talk to each other only through services, never through another module's repository or models. One accepted exception: the existing ORM relationships between models (`Run.challenge`, `Challenge.medals`, `Challenge.runs`) cross modules, with the import under `TYPE_CHECKING`. They map the foreign keys; don't use them to reach into another module instead of calling its service.

Reading through those relationships is allowed in one case ([ADR 0002](adr/0002-cross-module-reads.md)): a repository may eager-load another module's rows (`selectinload(Challenge.medals)`) only to nest them, read-only, in a response schema, as `ChallengeRead` nests `MedalRead`. These go through the owning module's service instead:

- filtering or sorting by another module's columns;
- writing another module's rows;
- business rules on another module's data;
- data the owning module transforms or restricts on read (for example signed URLs or hidden rows).

Adding a new cross-module relationship needs the user's approval.

The ORM cascade on `Challenge.medals` (`all, delete-orphan`) is not a write path: medals are created and changed only through `medals.service`, so don't assign or clear `challenge.medal`. Deleting a challenge may still remove its medal through that cascade, because the `medals.challenge_id` foreign key already has `ON DELETE CASCADE`.

Presentation copy: [`diagrams/backend-modules.svg`](diagrams/backend-modules.svg).

```mermaid
flowchart TB
    MAIN["main.py"] --> V1["api/v1/router"]
    V1 --> AR["auth.router"] & CR["challenges.router"] & RR["runs.router"] & MR["medals.router"]
    AR --> AS["auth.service"]
    CR --> CS["challenges.service"]
    RR --> RS["runs.service"]
    MR --> MS["medals.service"]
    RS -->|"validate against rules"| CS
    RS -->|"award medal"| MS
    AS --> ARP["auth.repository"]
    CS --> CRP["challenges.repository"]
    RS --> RRP["runs.repository"]
    MS --> MRP["medals.repository"]
    ARP & CRP & RRP & MRP --> DB[("PostgreSQL")]
    MS --> STORE["core.storage"]
    subgraph CORE["core"]
        CFG["config"]
        DBM["database"]
        SEC["security"]
        ERR["errors"]
        STORE
    end
```

### Request flow and errors

The router validates input and calls the service. The service applies the rules and decides the transaction. The repository only runs queries and flushes. Errors come back as the typed `ErrorResponse` from [`api/auth.md`](api/auth.md). Presentation copy: [`diagrams/request-flow.svg`](diagrams/request-flow.svg).

```mermaid
sequenceDiagram
    participant C as Client
    participant R as Router
    participant S as Service
    participant P as Repository
    participant D as PostgreSQL
    participant H as Exception handler
    C->>R: HTTP request
    R->>R: validate body (Pydantic schema)
    R->>S: call via Depends()
    S->>P: query / add
    P->>D: SQL, flush
    D-->>P: rows
    P-->>S: ORM objects
    alt rule broken
        S-->>H: raise DomainError(code)
        H-->>C: 4xx {"error": {"code", "message", "fields"}}
    else success
        S->>D: commit
        S-->>R: result
        R-->>C: 2xx response schema
    end
```

### Run sync and medal award

This is the core MVP journey: steps synced from the device complete a challenge and unlock its medal. Presentation copy: [`diagrams/run-to-medal.svg`](diagrams/run-to-medal.svg).

Validation follows `validate_run` in `backend/app/modules/runs/validation.py`:
- it rejects duplicate and out-of-window samples before anything is stored;
- only accepted samples are saved and counted.

The endpoint path is illustrative. Its contract still has to be written in `docs/api/runs.md` before it is built ([`.claude/workflow/plan.md`](../.claude/workflow/plan.md#phase-2-design-gate), Phase 2).

```mermaid
sequenceDiagram
    participant HD as HealthDataSource
    participant RB as RunBloc
    participant API as runs.router
    participant RS as runs.service
    participant CS as challenges.service
    participant MS as medals.service
    participant DB as PostgreSQL
    RB->>HD: read step samples since last sync
    HD-->>RB: samples with health_record_id
    RB->>API: POST /api/v1/runs/steps (docs/api/runs.md)
    API->>RS: add_samples(run_id, samples)
    RS->>CS: get rule (target_value, window)
    CS-->>RS: ChallengeRule
    RS->>DB: read known health_record_ids
    RS->>RS: validate_run: reject duplicates and out-of-window, sum accepted
    RS->>DB: insert accepted samples
    opt passed (counted steps >= target)
        RS->>DB: mark run completed
        RS->>MS: medal_for(challenge)
        MS-->>RS: medal (name, image_url)
    end
    RS->>DB: commit
    API-->>RB: run progress + medal (image_url)
    RB-->>RB: emit RunCompleted, show medal
```

### Data model

These are the current tables, defined in each module's `models.py` under `backend/app/modules/`. The `auth` module owns `users`, `refresh_tokens` and `login_attempts` ([auth contract](api/auth.md)). A row of `runs` is a user's place in a challenge (an enrollment) and `runs.user_id` is a foreign key to `users.id`. `daily_activity` holds the figures the app syncs for each calendar day.

```mermaid
erDiagram
    QUESTS ||--o{ CHALLENGES : groups
    CHALLENGES ||--o| MEDALS : awards
    CHALLENGES ||--o{ RUNS : "attempted by"
    RUNS ||--o{ STEP_SAMPLES : "built from"
    USERS ||--o{ REFRESH_TOKENS : holds
    USERS ||--o{ RUNS : joins
    USERS ||--o{ DAILY_ACTIVITY : syncs

    QUESTS {
        int id PK
        string title
        text description
    }
    CHALLENGES {
        int id PK
        int quest_id FK
        string title
        string type "run, swim or cycle"
        string metric "steps for a run, distance_m otherwise"
        int target_value "greater than 0"
        string mode "solo"
        text description_md
        text terms_md
        string cover_image_url "Cloudinary delivery URL"
        string city
        string landmark
        string status "draft or published"
        datetime starts_at
        datetime ends_at "after starts_at"
    }
    MEDALS {
        int id PK
        int challenge_id FK "unique with tier"
        string tier "bronze, silver or gold"
        int threshold_value "earned at this value"
        string name
        string image_url "Cloudinary delivery URL"
    }
    RUNS {
        int id PK
        uuid user_id FK
        int challenge_id FK
        string status "active, paused or left"
        datetime joined_at
        datetime counting_from "steps count from here"
        int total_steps
        bool completed
    }
    DAILY_ACTIVITY {
        uuid user_id PK
        date day PK
        int steps "nullable"
        int calories_kcal "nullable"
        int distance_m "nullable"
        int sleep_minutes "nullable"
        datetime updated_at
    }
    STEP_SAMPLES {
        int id PK
        int run_id FK
        string health_record_id "unique per run"
        datetime start_time
        datetime end_time "not before start_time"
        int steps "0 or more"
    }
    USERS {
        uuid id PK
        string email "unique, lowercase"
        string password_hash "Argon2"
        string display_name
        datetime created_at
    }
    REFRESH_TOKENS {
        int id PK
        uuid user_id FK
        string token_hash "SHA-256, unique"
        datetime expires_at
        datetime revoked_at "set when used or signed out"
    }
    LOGIN_ATTEMPTS {
        int id PK
        string email
        string ip
        datetime attempted_at "failed sign-ins only"
    }
```

## 4. Test strategy

Each layer is tested on its own, with the layer below it mocked. Integration tests cover the real stack on each side.

```mermaid
flowchart LR
    subgraph MOBILE["Mobile: flutter_test"]
        MU["Unit: blocs and use cases<br/>bloc_test + mocktail repositories"]
        MR["Unit: repositories<br/>mocktail data sources"]
        MW["Widget: pages<br/>mocked blocs"]
        MN["Router: real GoRouter<br/>assert the shown screen"]
    end
    subgraph BACKEND["Backend: pytest"]
        BU["tests/unit: services<br/>AsyncMock repositories, no DB"]
        BI["tests/integration: routes<br/>httpx AsyncClient + PostgreSQL test DB<br/>rollback per test"]
    end
    MOBILE -.->|"shared contract in docs/api"| BACKEND
```

| Test | Tools | What it checks |
| --- | --- | --- |
| Bloc / use case | `bloc_test`, `mocktail` | Events produce the right ordered states, for example loading → success. |
| Widget / router | `flutter_test`, `mocktail` | A page renders each state, and navigation lands on the expected screen. |
| Backend unit | `pytest` with the anyio plugin (`@pytest.mark.anyio`), `AsyncMock` | Service rules and raised error codes, with no database. |
| Backend integration | `pytest`, `httpx.AsyncClient`, PostgreSQL from `docker compose` | Request, response and error contract against a real database. |

UI tests don't prove the screen matches the design, and backend tests don't prove the app-to-API flow works. See the verification rules in [`.claude/workflow/implement.md`](../.claude/workflow/implement.md#verify-by-ticket-type) and [`.claude/workflow/evidence.md`](../.claude/workflow/evidence.md).
