# StrideQuest architecture

This is the target architecture agreed in [ADR 0001](adr/0001-architecture.md). Existing code is being moved to it in follow-up issues, so some folders below don't exist yet.

The Mermaid blocks in this file are the source for the diagrams. Exported SVG copies of the key diagrams are in [`diagrams/`](diagrams/).

## 1. System context

The app reads steps on the device and syncs them to one FastAPI app, which validates runs and awards medals. Medal images are static files in object storage; the database only stores their URLs. Presentation copy: [`diagrams/system-context.svg`](diagrams/system-context.svg).

```mermaid
flowchart LR
    HK["Apple Health / Health Connect"] -->|steps| APP["Flutter app"]
    APP -->|"HTTPS + JWT, /api/v1"| API["FastAPI modular monolith"]
    API --> DB[("PostgreSQL")]
    S3[("Object storage<br/>S3 / SeaweedFS")] -->|"medal images by URL"| APP
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
│   ├── router/            # GoRouter, redirect, AuthBloc listenable adapter
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
        A1["SignInPage, SignUpPage"] --> A2["AuthBloc"]
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

Screens never navigate on sign-in or sign-out themselves. The router listens to `AuthBloc` and redirects.

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
│   │   ├── storage.py         # S3 / SeaweedFS client
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
│   │   ├── runs/              # Same files
│   │   └── medals/            # Same files
│   ├── api/
│   │   └── v1/router.py       # Mounts every module router under /api/v1
│   └── main.py                # App factory, exception handlers, health route
├── tests/
│   ├── conftest.py            # PostgreSQL test DB, AsyncClient, dependency_overrides
│   ├── unit/                  # Services with AsyncMock repositories
│   └── integration/           # HTTP routes against the test DB
└── pyproject.toml
```

### Modules and layers

Modules talk to each other only through services, never through another module's repository or models. Presentation copy: [`diagrams/backend-modules.svg`](diagrams/backend-modules.svg).

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
    RB->>API: POST /api/v1/runs/{id}/samples
    API->>RS: add_samples(run_id, samples)
    RS->>DB: insert, skip duplicate health_record_id
    RS->>CS: get rules (target_steps, window)
    RS->>RS: total steps in window >= target?
    opt challenge completed
        RS->>DB: mark run completed
        RS->>MS: medal_for(challenge)
        MS-->>RS: medal (name, image_url)
    end
    RS->>DB: commit
    API-->>RB: run progress + medal (image_url)
    RB-->>RB: emit RunCompleted, show medal
```

### Data model

These are the current tables in `backend/app/models`. `users` is planned by the [auth contract](api/auth.md) and doesn't exist yet. `runs.user_id` will reference it.

```mermaid
erDiagram
    QUESTS ||--o{ CHALLENGES : groups
    CHALLENGES ||--o| MEDALS : awards
    CHALLENGES ||--o{ RUNS : "attempted by"
    RUNS ||--o{ STEP_SAMPLES : "built from"
    USERS ||--o{ RUNS : runs

    QUESTS {
        int id PK
        string title
        text description
    }
    CHALLENGES {
        int id PK
        int quest_id FK
        string title
        int target_steps "greater than 0"
        datetime starts_at
        datetime ends_at "after starts_at"
    }
    MEDALS {
        int id PK
        int challenge_id FK "unique"
        string name
        string image_url "object storage URL"
    }
    RUNS {
        int id PK
        string user_id
        int challenge_id FK
        datetime started_at
        int total_steps
        bool completed
    }
    STEP_SAMPLES {
        int id PK
        int run_id FK
        string health_record_id "unique per run"
        datetime start_time
        datetime end_time
        int steps "0 or more"
    }
    USERS {
        uuid id PK "planned"
        string email "unique, lowercase"
        string display_name
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
| Backend unit | `pytest`, `pytest-asyncio`, `AsyncMock` | Service rules and raised error codes, with no database. |
| Backend integration | `pytest`, `httpx.AsyncClient`, PostgreSQL from `docker compose` | Request, response and error contract against a real database. |

UI tests don't prove the screen matches the design, and backend tests don't prove the app-to-API flow works. See the verification rules in [`CLAUDE.md`](../CLAUDE.md).
