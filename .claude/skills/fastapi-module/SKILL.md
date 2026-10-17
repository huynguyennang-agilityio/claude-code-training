---
name: fastapi-module
description: Step-by-step guide for adding or extending a StrideQuest backend module under backend/app/modules/ (contract, models and Alembic migration, schemas, repository, service, deps, router, mounting and tests), following ADR 0001 and backend/app/core. Use when creating or changing a FastAPI endpoint, service, repository, Pydantic schema, SQLAlchemy model or migration in the backend.
---

# FastAPI module

How to build an endpoint in `backend/app/modules/<module>/` the way ADR 0001 lays it out. The rules themselves live in [`CLAUDE.md`](../../../CLAUDE.md), [`docs/adr/0001-architecture.md`](../../../docs/adr/0001-architecture.md) and [`docs/architecture.md`](../../../docs/architecture.md). This skill shows how to apply them and points to the code that already does. If this file and CLAUDE.md disagree, CLAUDE.md wins; fix this file.

Paths below are relative to `backend/` unless they start with `docs/` or `.claude/`. Examples use the `challenges` module; swap in your own names.

**What exists today.** `app/core/` (config, database, errors), the models and schemas of `challenges`, `medals` and `runs`, `runs/validation.py`, and the test fixtures. No module has a `router.py`, `service.py`, `repository.py` or `deps.py` yet. The patterns for those files come from CLAUDE.md and ADR 0001, not from working code, and are marked as such below. The first module that adds them becomes the reference; update this skill to point to it.

## Before you start

1. Make sure the issue has its ticket evidence (sample request and response for an API ticket) and acceptance criteria (CLAUDE.md, Phase 1).
2. Read or write the API contract in `docs/api/<module>.md`, shaped like `docs/api/auth.md`: endpoints table, request and response bodies, and the error codes each endpoint returns. The contract comes first (CLAUDE.md, Phase 2).
   Every JSON example in it is also a file under `docs/api/examples/<module>/`, marked with `<!-- example: <module>/<file>.json -->` on the line above its ```json block. Add one file per request body, success response and documented error case. `tests/unit/test_api_examples.py` fails if a block and its file differ, if a block has no marker, or if a file is unused; `tests/unit/test_error_contract.py` fails if a row of the "Error codes" table is neither implemented nor listed as pending.
3. Stop for the user's approval before implementing if the change touches a public API or breaking contract, the database schema, auth or another security boundary, the architecture, or real data and costs (CLAUDE.md, Phase 2, step 4). A new table is a schema change.
4. Read the reference files listed under each step below. Copy their shape, not just the snippets here.

## Build order

Build inside out: models and migration, then schemas, repository, service, deps, router, mounting. Add the tests for each layer as you go.

```text
app/modules/challenges/
├── __init__.py
├── models.py        # SQLAlchemy models
├── schemas.py       # Pydantic request and response models
├── repository.py    # Queries; takes an AsyncSession; only flushes
├── service.py       # Business rules, domain exceptions, commit/rollback
├── deps.py          # Depends() factories
└── router.py        # HTTP only: validate, call service, return schema
```

A module may add a file for pure logic, like `runs/validation.py`. There are no barrel imports: import each file directly (`from app.modules.challenges.service import ChallengeService`).

### 1. Models and migration

References: `app/core/database.py`, `app/modules/challenges/models.py`, `app/modules/models.py`, `alembic/versions/`.

**Models** subclass `Base` from `app/core/database.py` and use SQLAlchemy 2 typed mappings (`Mapped[...]`, `mapped_column`).

- `Base.metadata` has a naming convention, so primary keys, foreign keys, unique constraints and indexes are named for you. A `CheckConstraint` must be named in full as `ck_<table>_<rule>`; an unnamed one is an error.
- Timestamps are `DateTime(timezone=True)`.
- Add every new model to `app/modules/models.py` (import and `__all__`). Tests and Alembic load the schema from there; a model missing from it is invisible to `alembic revision --autogenerate`.
- A relationship to another module's model imports that model only under `TYPE_CHECKING`, as `challenges/models.py` does for `Medal` and `Run`. That relationship maps the foreign key. The only read allowed through it is eager-loading for a nested response schema (section 3); anything else goes through the other module's service (see `docs/architecture.md`, "Modules and layers").
- Medal images and other files: store the object storage URL, never the bytes.

**Migration.** Every schema change ships with an Alembic revision in the same MR (CLAUDE.md). Against the local docker-compose database (`docker compose up -d --wait db`, `DATABASE_URL` in `.env`):

```bash
alembic revision --autogenerate -m "add challenge progress"
# review the generated file: autogenerate misses renames and server defaults
alembic upgrade head
alembic downgrade <develop head revision>
alembic upgrade head
alembic check
```

- The file name comes from `alembic.ini` (`YYYY_MM_DD_HHMM-<rev>_<slug>.py`), and the post-write hooks run `ruff check --fix` and `ruff format` on it.
- Write a real `downgrade()`, like `2026_10_16_1000-5c1d2e7a9b40_name_constraints.py`. If the downgrade or the upgrade can lose data (dropping a column, narrowing a type), say so and get approval first.
- Never use `Base.metadata.create_all` outside a throwaway script; tests build the schema from the migrations.

### 2. Schemas

References: `app/modules/challenges/schemas.py`, `app/modules/runs/schemas.py`.

- Pydantic v2 `BaseModel`s. Keep request (`...Create`, `...In`) and response (`...Read`) models separate, even when the fields overlap.
- Response models read from ORM objects with `model_config = ConfigDict(from_attributes=True)`.
- Put field rules in `Field(...)` and other rules in validators. A `ValueError` raised in a validator becomes a `422 validation_error` through the handler in `app/core/errors.py`.
  - A `field_validator` names its field in `fields`. For a rule across fields, put it on the later field and read the earlier one from `ValidationInfo.data`, as below; a field that failed its own validation is missing from `data`.
  - A `model_validator` has no field, so the error is reported as `"field": "body"`. Use one only when no single field is to blame.
  - Raise `ValueError`, never let another exception escape: Pydantic turns only `ValueError` and `AssertionError` into validation errors, and anything else becomes `500 internal_error`.
- Field names are `snake_case`. Request timestamps are `AwareDatetime`, so a timestamp without a timezone is a `422` instead of being stored without one (`docs/api/auth.md` requires ISO 8601 in UTC). Comparing a naive and an aware `datetime` raises `TypeError`, which would be a `500`.

```python
class ChallengeCreate(BaseModel):
    quest_id: int
    title: str = Field(min_length=1, max_length=120)
    target_steps: int = Field(gt=0)
    starts_at: AwareDatetime
    ends_at: AwareDatetime

    @field_validator("ends_at")
    @classmethod
    def ends_after_start(cls, ends_at: AwareDatetime, info: ValidationInfo) -> AwareDatetime:
        starts_at = info.data.get("starts_at")
        if starts_at is not None and ends_at <= starts_at:
            raise ValueError("ends_at must be after starts_at.")
        return ends_at
```

### 3. Repository (pattern from CLAUDE.md and ADR 0001)

A plain class that takes an `AsyncSession`. It only builds queries, adds objects and `flush`es. It never calls `commit()` or `rollback()`, and holds no business rules.

```python
class ChallengeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, challenge_id: int) -> Challenge | None:
        return await self._session.scalar(
            select(Challenge)
            .where(Challenge.id == challenge_id)
            .options(selectinload(Challenge.medal))
        )

    async def quest_exists(self, quest_id: int) -> bool:
        return await self._session.scalar(select(exists().where(Quest.id == quest_id)))

    async def add(self, challenge: Challenge) -> Challenge:
        self._session.add(challenge)
        await self._session.flush()  # assigns challenge.id; the service commits
        return challenge
```

- Queries only this module's models. Data owned by another module comes from that module's service, except the read-only nesting below.
- Eager-load every relationship the response schema reads (`selectinload`). An async session can't lazy-load: touching an unloaded relationship raises `MissingGreenlet` during serialization.
- **Another module's rows in a response.** A repository may eager-load them through an existing relationship only to nest them, read-only, in a response schema: the example loads `Challenge.medal` because `ChallengeRead` nests `MedalRead`. Filtering or sorting by another module's columns, writing its rows, business rules on its data, and data it transforms or restricts on read go through that module's service. Don't add a new cross-module relationship without the user's approval. The `all, delete-orphan` cascade on `Challenge.medal` is not a write path: create and change medals only through `medals.service`, never by assigning or clearing `challenge.medal`. Deleting a challenge may remove its medal, as the foreign key's `ON DELETE CASCADE` already does. Rule and reasons: `docs/architecture.md` ("Modules and layers") and [ADR 0002](../../../docs/adr/0002-cross-module-reads.md).
- Return ORM objects or `None`. Raising "not found" is the service's decision.
- No abstract base class or `I`-prefixed interface: unit tests replace the class with `AsyncMock(spec=ChallengeRepository)`.

### 4. Service (pattern from CLAUDE.md and ADR 0001)

References: `app/core/errors.py`, `tests/unit/test_errors.py`.

The service holds the business rules, raises typed domain exceptions and decides the transaction. It gets the request's session only to `commit()` or `rollback()`; every query goes through a repository.

**Domain exceptions** subclass `DomainError` from `app/core/errors.py`. Each sets a `code` listed in the module's API contract and, when it isn't 400, a `status_code`. `DomainError` refuses a subclass without a string `code`. Define them at the top of the module's `service.py`, next to the code that raises them.

```python
class ChallengeNotFoundError(DomainError):
    status_code = 404
    code = "challenge_not_found"


class QuestNotFoundError(DomainError):
    status_code = 404
    code = "quest_not_found"


class ChallengeService:
    def __init__(self, session: AsyncSession, repository: ChallengeRepository) -> None:
        self._session = session
        self._repository = repository

    async def get(self, challenge_id: int) -> Challenge:
        challenge = await self._repository.get(challenge_id)
        if challenge is None:
            raise ChallengeNotFoundError(f"Challenge {challenge_id} does not exist.")
        return challenge

    async def create(self, data: ChallengeCreate) -> Challenge:
        if not await self._repository.quest_exists(data.quest_id):
            raise QuestNotFoundError(f"Quest {data.quest_id} does not exist.")
        challenge = Challenge(**data.model_dump())
        await self._repository.add(challenge)
        await self._session.commit()
        return await self.get(challenge.id)  # reload what ChallengeRead needs
```

- The global handler turns a `DomainError` into `ErrorResponse` with its `status_code`; the message is for logs and may change. Never raise `HTTPException` from a service or router, and never return error dicts.
- Commit once, after the last write of the use case. A `DomainError` raised before the commit needs no rollback: `get_session` closes the session, and uncommitted work is discarded.
- Check business rules (the quest exists, the name is free) through the repository before writing, and raise the matching `DomainError`. Don't map every `IntegrityError` to one code: once the table gets another constraint, every violation would come back with the wrong code. If you must catch one (a race between check and insert), roll back explicitly and map it only after checking which constraint failed; otherwise let it become a `500`.
- `get_session` builds the session with `expire_on_commit=False`, so a new object's columns are still readable after the commit. Its relationships were never loaded, though, and `ChallengeRead.model_validate` on it fails with `MissingGreenlet` when it reads `medal`. That is why `create` reloads the row through the repository's eager-loading query.
- Don't catch broad exceptions. Anything that isn't a `DomainError` becomes `500 internal_error` with a generic message, which is what you want for bugs.

**Calling another module.** Take the other module's service as a constructor argument and call its methods. Never import its repository or query its models.

- FastAPI caches `get_session` per request, so both services share one session and one transaction.
- The service the router calls owns that transaction. A method another module calls only writes through its repository (flush) and doesn't commit, so the caller commits once for the whole use case.
- A service method that both the router and another module call needs to be split, or documented as committing.

**Outbound HTTP** uses `httpx.AsyncClient`, never `requests` or another blocking call, with a timeout. No module does this yet. Inject the client through `deps.py` so tests can pass one built on `httpx.MockTransport`. Don't create a client on every call.

### 5. deps.py (pattern from CLAUDE.md and ADR 0001)

Plain FastAPI `Depends` factories that build the repository and service for one request. No dependency-injection library.

```python
def get_challenge_repository(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ChallengeRepository:
    return ChallengeRepository(session)


def get_challenge_service(
    session: Annotated[AsyncSession, Depends(get_session)],
    repository: Annotated[ChallengeRepository, Depends(get_challenge_repository)],
) -> ChallengeService:
    return ChallengeService(session, repository)


ChallengeServiceDep = Annotated[ChallengeService, Depends(get_challenge_service)]
```

- `get_session` comes from `app/core/database.py`. Only `deps.py` touches it; routers never do.
- To use another module's service, depend on that module's factory: `runs/deps.py` can import `get_challenge_service` from `challenges/deps.py`. Importing another module's `deps.py` and `service.py` is fine; its `repository.py` and `models.py` are not.
- Auth isn't built yet. When it is, `auth/deps.py` will provide the current-user dependency, built on the auth service. Don't decode tokens in another module.

### 6. Router and mounting (pattern from CLAUDE.md and ADR 0001)

References: `app/api/v1/health.py`, `app/api/v1/router.py`.

The router is HTTP only: FastAPI validates the input against the schema, the router calls one service method and returns a response schema.

```python
router = APIRouter(prefix="/challenges", tags=["challenges"])

_NOT_FOUND = {404: {"model": ErrorResponse}}


@router.get("/{challenge_id}", responses=_NOT_FOUND)
async def get_challenge(challenge_id: int, service: ChallengeServiceDep) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.get(challenge_id))


@router.post("", status_code=201, responses=_NOT_FOUND)
async def create_challenge(body: ChallengeCreate, service: ChallengeServiceDep) -> ChallengeRead:
    return ChallengeRead.model_validate(await service.create(body))
```

- Every handler is `async def` and is annotated with its response schema; FastAPI uses the return type as the response model.
- No `AsyncSession`, no `select`, no `try`/`except`, no `HTTPException`. Errors come from the service as `DomainError`s.
- Set `status_code` for non-200 successes (201 on create, 204 on delete). List the documented error statuses in `responses=` with `ErrorResponse` so the OpenAPI docs show them; `422` is added by FastAPI.
- Paths are relative to the module prefix and match the contract; the `/api/v1` prefix comes from the parent router.

Mount the router in `app/api/v1/router.py`:

```python
from app.modules.challenges.router import router as challenges_router

router.include_router(challenges_router)
```

Mounting a new path changes the public API. The contract in `docs/api/` must already list it.

Every route requires authentication unless it is in `PUBLIC_ROUTES` in `tests/unit/test_auth_sweep.py`. That test calls each route without a token and fails unless it gets `401 not_authenticated`. Add a route to the allowlist only when the endpoints table in `docs/api/<module>.md` lists it with `none` in the `Auth` column, and say so in the MR. `GET /api/v1/health` is the one exception: an infrastructure probe with no contract. Declare the auth dependency before any dependency that needs a session (FastAPI resolves them in order); the sweep reports a session-first route as `500`. A websocket or mounted app fails the sweep's `test_every_route_is_an_api_route` until it has its own auth test.

### 7. Tests

`backend/tests/` has `unit/` and `integration/`. Every feature needs tests (CLAUDE.md), and error paths count as much as success paths. Async tests are marked `@pytest.mark.anyio`; the `anyio_backend` fixture in `tests/conftest.py` runs them on asyncio. Don't add `pytest-asyncio`.

| Test | Pattern | Reference |
| --- | --- | --- |
| Service (`tests/unit/test_<module>_service.py`) | `AsyncMock(spec=ChallengeRepository)` and `AsyncMock(spec=AsyncSession)`; assert the result, each raised `DomainError` subclass, and whether `commit`/`rollback` were awaited. No database | `tests/unit/test_run_validation.py` for style |
| Pure logic | Plain function tests | `tests/unit/test_run_validation.py` |
| Routes (`tests/integration/test_<module>_api.py`) | The `client` fixture against PostgreSQL; one success case and every error code in the contract, asserting the status and the full `ErrorResponse` body. Load the expected body with `tests.api_docs.load_example("<module>/<file>.json")` and compare it, treating generated values (ids, tokens, timestamps) by type | `tests/integration/test_health.py`, `tests/unit/test_errors.py` |
| Ownership (`tests/integration/test_<module>_api.py`) | For every endpoint that reads or changes a user-owned resource: user B asks for user A's resource and gets `404 not_found` (not `403`, so existence isn't leaked), and A's row is unchanged | (none yet; the first module with user-owned data adds one) |
| Repository and model | The `session` fixture: constraints, eager loading, `flush` assigning ids | `tests/integration/test_models.py` |
| Migration | Covered by the session-scoped `database_url` fixture building the schema with `alembic upgrade head`; add a check when a migration moves data | `tests/integration/test_migrations.py` |

```python
def challenge_create() -> ChallengeCreate:
    return ChallengeCreate(
        quest_id=1,
        title="5k",
        target_steps=5000,
        starts_at=datetime(2026, 1, 1, tzinfo=UTC),
        ends_at=datetime(2026, 1, 2, tzinfo=UTC),
    )


@pytest.mark.anyio
async def test_get_raises_not_found_for_unknown_id() -> None:
    repository = AsyncMock(spec=ChallengeRepository)
    repository.get.return_value = None
    service = ChallengeService(AsyncMock(spec=AsyncSession), repository)

    with pytest.raises(ChallengeNotFoundError):
        await service.get(42)


@pytest.mark.anyio
async def test_create_commits_once() -> None:
    session = AsyncMock(spec=AsyncSession)
    repository = AsyncMock(spec=ChallengeRepository)
    repository.quest_exists.return_value = True
    service = ChallengeService(session, repository)

    created = await service.create(challenge_create())

    assert created is repository.get.return_value
    repository.add.assert_awaited_once()
    session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_create_rejects_unknown_quest_without_writing() -> None:
    session = AsyncMock(spec=AsyncSession)
    repository = AsyncMock(spec=ChallengeRepository)
    repository.quest_exists.return_value = False
    service = ChallengeService(session, repository)

    with pytest.raises(QuestNotFoundError):
        await service.create(challenge_create())

    repository.add.assert_not_awaited()
    session.commit.assert_not_awaited()
```

Integration tests need PostgreSQL from `docker compose up -d --wait db` and `TEST_DATABASE_URL` naming a database that ends in `_test` (each session wipes its `public` schema). See the docstring of `tests/integration/conftest.py`:

- `session` runs each test in a transaction that is rolled back; a service's `commit()` only releases a savepoint;
- `client` is an `httpx.AsyncClient` on the app with `get_session` overridden to that session, so data you add through `session` is visible to the request.

```python
@pytest.mark.anyio
async def test_get_unknown_challenge_returns_error_response(client: AsyncClient) -> None:
    response = await client.get("/api/v1/challenges/999999")

    assert response.status_code == 404
    assert response.json() == {
        "error": {"code": "challenge_not_found", "message": ANY, "fields": []}
    }
```

Put shared test data in a helper module next to the tests when a second test file needs it.

### 8. Check and record evidence

From `backend/`, with the project's `.venv`:

```bash
ruff check .
ruff format --check .
mypy
pytest tests/unit
pytest
```

`mypy` runs in strict mode on `app/` with the Pydantic plugin (`[tool.mypy]` in `pyproject.toml`). A `# type: ignore` needs an error code and a comment saying why. Then record the verification evidence (CLAUDE.md, Phase 3) using the rows that apply:

- **Backend service / repository:** the `pytest` commands and their summaries.
- **Database schema:** the Alembic round trip from step 1 and `\d <table>`, against the local docker-compose database only.
- **API endpoint:** calls against the running server (`uvicorn app.main:app --reload`): one success case and every documented error case, with request, status and JSON body. Redact tokens and connection strings.

If the database or server can't be run, write `Not verified: <reason>`.

## Common pitfalls

- `HTTPException` in a router or service instead of a `DomainError` subclass. The global handler would still produce an `ErrorResponse`, but with a generic code (`not_found`, `http_error`, ...) instead of the contract code the client branches on.
- A repository that commits, or a router that takes `AsyncSession`. Both break the transaction rules and make the service impossible to unit test.
- Committing inside a service method that another module calls, so a later failure in the caller leaves half the use case saved.
- Importing another module's `repository.py` or `models.py` (outside `TYPE_CHECKING` relationship hints) to skip its service.
- Lazy loading in async code: a response schema reads a relationship the query didn't `selectinload`, and serialization fails with `MissingGreenlet`.
- A new model missing from `app/modules/models.py`, so autogenerate produces an empty migration.
- An unnamed `CheckConstraint`, or a migration that hard-codes a constraint name PostgreSQL chose.
- Blocking calls in async code: `requests`, `time.sleep`, sync file or database drivers.
- Error codes that aren't in the contract, or `message` text the client is expected to parse.
- Returning ORM objects with fields the response shouldn't expose. The response schema decides what leaves the API.

## Checklist before reporting done

- [ ] The contract in `docs/api/<module>.md` lists the endpoint, bodies and error codes, and the approval gate was respected.
- [ ] New models are in `app/modules/models.py`; the migration has a reviewed `upgrade()` and `downgrade()`, and `alembic check` is clean.
- [ ] The router only validates, calls one service method and returns a schema: no session, no `HTTPException`.
- [ ] The repository only queries and flushes, and eager-loads what the response reads.
- [ ] The service raises `DomainError` subclasses with contract codes and commits once; methods called by other modules don't commit.
- [ ] Modules talk only through services and `deps.py` factories.
- [ ] The router is mounted in `app/api/v1/router.py`.
- [ ] Each request body, success response and error case in the contract has an example file, and the route tests compare responses with it.
- [ ] `docs/api/openapi.json` is regenerated (`python -m app.scripts.export_openapi` from `backend/`) and its diff is in the MR.
- [ ] Unit tests cover the service with `AsyncMock` repositories; integration tests cover the success case and every documented error code.
- [ ] `tests/unit/test_auth_sweep.py` passes; any new public route is in `PUBLIC_ROUTES` and listed with `none` in the `Auth` column of the contract.
- [ ] Each endpoint on a user-owned resource has an ownership test: another user gets `404 not_found`.
- [ ] `ruff check`, `ruff format --check` and `pytest` pass.
- [ ] The `## Evidence` section is drafted.
