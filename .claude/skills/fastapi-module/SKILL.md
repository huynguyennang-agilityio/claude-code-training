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
- A relationship to another module's model imports that model only under `TYPE_CHECKING`, as `challenges/models.py` does for `Medal` and `Run`. That relationship maps the foreign key. Don't use it to read or change another module's data instead of calling its service (see `docs/architecture.md`, "Modules talk to each other only through services").
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
- Put field rules in `Field(...)` and cross-field rules in validators. A `ValueError` raised in a validator becomes a `422 validation_error` with the field named, through the handler in `app/core/errors.py`.
- Field names are `snake_case`, timestamps are timezone-aware `datetime`s, as `docs/api/auth.md` requires.

```python
class ChallengeCreate(BaseModel):
    quest_id: int
    title: str = Field(min_length=1, max_length=120)
    target_steps: int = Field(gt=0)
    starts_at: datetime
    ends_at: datetime

    @model_validator(mode="after")
    def window_is_valid(self) -> Self:
        if self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at.")
        return self
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

    async def add(self, challenge: Challenge) -> Challenge:
        self._session.add(challenge)
        await self._session.flush()  # assigns challenge.id; the service commits
        return challenge
```

- Queries only this module's models. Data owned by another module comes from that module's service.
- Eager-load every relationship the response schema reads (`selectinload`). An async session can't lazy-load: touching an unloaded relationship raises `MissingGreenlet` during serialization. Loading the existing `Challenge.medal` relationship for `ChallengeRead.medal` is the read-only foreign-key mapping that `docs/architecture.md` accepts; anything beyond reading it goes through `medals.service`.
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
        challenge = Challenge(**data.model_dump())
        try:
            await self._repository.add(challenge)
        except IntegrityError as exc:
            await self._session.rollback()
            raise QuestNotFoundError(f"Quest {data.quest_id} does not exist.") from exc
        await self._session.commit()
        return await self.get(challenge.id)  # reload what ChallengeRead needs
```

- The global handler turns a `DomainError` into `ErrorResponse` with its `status_code`; the message is for logs and may change. Never raise `HTTPException` from a service or router, and never return error dicts.
- Commit once, after the last write of the use case. A `DomainError` raised before the commit needs no rollback: `get_session` closes the session, and uncommitted work is discarded. Roll back explicitly when you catch a database error and carry on, as above.
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

### 7. Tests

`backend/tests/` has `unit/` and `integration/`. Every feature needs tests (CLAUDE.md), and error paths count as much as success paths. Async tests are marked `@pytest.mark.anyio`; the `anyio_backend` fixture in `tests/conftest.py` runs them on asyncio. Don't add `pytest-asyncio`.

| Test | Pattern | Reference |
| --- | --- | --- |
| Service (`tests/unit/test_<module>_service.py`) | `AsyncMock(spec=ChallengeRepository)` and `AsyncMock(spec=AsyncSession)`; assert the result, each raised `DomainError` subclass, and whether `commit`/`rollback` were awaited. No database | `tests/unit/test_run_validation.py` for style |
| Pure logic | Plain function tests | `tests/unit/test_run_validation.py` |
| Routes (`tests/integration/test_<module>_api.py`) | The `client` fixture against PostgreSQL; one success case and every error code in the contract, asserting the status and the full `ErrorResponse` body | `tests/integration/test_health.py`, `tests/unit/test_errors.py` |
| Repository and model | The `session` fixture: constraints, eager loading, `flush` assigning ids | `tests/integration/test_models.py` |
| Migration | Covered by the session fixture building the schema with `alembic upgrade head`; add a check when a migration moves data | `tests/integration/test_migrations.py` |

```python
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
    service = ChallengeService(session, repository)

    created = await service.create(challenge_create())

    assert created is repository.get.return_value
    repository.add.assert_awaited_once()
    session.commit.assert_awaited_once()
    session.rollback.assert_not_awaited()
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
pytest tests/unit
pytest
```

There is no type checker configured yet, so the type-check step is `Not verified: no type checker configured`. Don't invent one. Then record the verification evidence (CLAUDE.md, Phase 3) using the rows that apply:

- **Backend service / repository:** the `pytest` commands and their summaries.
- **Database schema:** the Alembic round trip from step 1 and `\d <table>`, against the local docker-compose database only.
- **API endpoint:** calls against the running server (`uvicorn app.main:app --reload`): one success case and every documented error case, with request, status and JSON body. Redact tokens and connection strings.

If the database or server can't be run, write `Not verified: <reason>`.

## Common pitfalls

- `HTTPException` in a router or service instead of a `DomainError` subclass. The global handler would still produce an `ErrorResponse`, but with the generic `http_error` code the client can't branch on.
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
- [ ] Unit tests cover the service with `AsyncMock` repositories; integration tests cover the success case and every documented error code.
- [ ] `ruff check`, `ruff format --check` and `pytest` pass.
- [ ] The `## Evidence` section is drafted.
