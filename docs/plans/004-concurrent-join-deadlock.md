# Plan 004: Two concurrent joins deadlock instead of answering `overlapping_challenge`

Status: approved
Approved: 2026-10-19
Issues: <filled in after approval>

## Context

`backend/tests/integration/test_enrollments_api.py::test_two_overlapping_joins_at_once_let_exactly_one_win` fails now and then, on `develop` too, with `asyncpg.exceptions.DeadlockDetectedError`. The test is right: it models what the API does when one user joins two overlapping challenges of one type from two requests at once (a double tap, two devices).

`docs/api/challenges.md` says the loser gets `409 overlapping_challenge`. In the failing runs the loser's request raises a raw database error, which the global handler turns into `500 internal_error`.

### Reproduction

Needs the local database (`docker compose up -d --wait db`, `TEST_DATABASE_URL` in `backend/.env`). From `backend/`:

```bash
for i in $(seq 1 16); do
  .venv/bin/python -m pytest \
    "tests/integration/test_enrollments_api.py::test_two_overlapping_joins_at_once_let_exactly_one_win" \
    -q -x -p no:cacheprovider 2>&1 | grep -E "passed|failed"
done
```

Seen on 2026-10-18, PostgreSQL 17 in Docker, on `develop` at `771be72`: **2 failures in 16 runs** (a further run of up to 20 stopped at its first failure). A passing run takes about 0.4 s; a failing one about 1.7 s, because PostgreSQL waits for `deadlock_timeout` (1 s) before it looks for the cycle.

- **Expected:** one request joins (`204`), the other answers `409` with `code: overlapping_challenge`; exactly one `active` row remains for the user.
- **Actual (about 1 run in 8 to 4):** one request joins; the other fails with the error below, which `EnrollmentService._save` does not map (it only catches `IntegrityError`). Through the API this is `500`.

```text
asyncpg.exceptions.DeadlockDetectedError: deadlock detected
DETAIL:  Process 92933 waits for ShareLock on transaction 28641; blocked by process 92932.
         Process 92932 waits for ShareLock on transaction 28643; blocked by process 92933.
sqlalchemy.exc.DBAPIError: (sqlalchemy.dialects.postgresql.asyncpg.Error) deadlock detected
  app/modules/runs/enrollments.py:101  join
  app/modules/runs/enrollments.py:160  _save
  app/modules/runs/repository.py:92    add     (session.flush -> INSERT INTO runs)
```

### Cause

Both requests pass the service's own `find_active_overlap` check, because neither has committed yet. Both then `INSERT` an `active` row. The exclusion constraint `ex_runs_no_overlapping_active_challenges` (user, type, window overlap, `WHERE status = 'active'`) makes each insert find the other's uncommitted row and wait for that transaction to finish. Each now waits for the other, so PostgreSQL aborts one with `40P01 deadlock_detected`. When the timing is less symmetric, one insert simply waits and then fails with the exclusion violation, which is the `IntegrityError` path `_save` already handles. That is why the test passes most of the time. The constraint stays correct either way; the problem is the error the loser gets.

`resume` shares the path (`_refuse_overlap`, then `_save`) and has the same race: two resumes of paused enrollments, or a join racing a resume.

## Open questions and assumptions

1. **Serialize or retry?** Assumed: serialize. Take a per-user lock before the overlap check, so the second request waits, then sees the first one's committed row and answers `overlapping_challenge` from the check it already has (with the other challenge's title in the message). Retrying after a deadlock was considered and rejected: it needs a fresh transaction around a request-scoped session, and it still lets the database abort a request on purpose.
2. **Lock kind.** Assumed: a transaction-level advisory lock, `pg_advisory_xact_lock` on a 64-bit key derived from the user id. It needs no row to exist, is released at commit or rollback, and does not touch another module's table (a `SELECT ... FOR UPDATE` on `users` would reach into the `auth` module, against the rule that modules talk only through services). Say if you prefer another way.
3. **Scope.** Assumed: `join` and `resume`, the only two paths that make a row `active`. `pause` and `leave` only free the slot and cannot deadlock on the constraint.
4. **Backstop.** Assumed: no catch-all mapping of `40P01` to `overlapping_challenge`. With the lock held it cannot be the cause, and a deadlock from anything else should stay a visible 500.

## Approach

Backend only (`backend/app/modules/runs/`). No mobile change.

- `repository.py`: new `lock_user_enrollments(user_id)` that runs `SELECT pg_advisory_xact_lock(:key)`. The key is a stable 64-bit integer from the user's UUID, with a fixed namespace so it cannot collide with another use of advisory locks. It is the only new SQL.
- `enrollments.py`: `join` and `resume` call it first, before the existing row lookup and `_refuse_overlap`. The lock is held until `_save` commits (or an error rolls back), so the check and the insert are one critical section per user. Nothing else in the service changes; the `IntegrityError` mapping stays as the second line of defence.
- Lock order: the user lock is always taken first, then the `runs` row lock (`get_for_user(..., lock=True)`). Syncs lock `runs` rows only and never take the user lock, so no new cycle appears.

Contract (`docs/api/`): **unchanged**. The behaviour already documented (`409 overlapping_challenge`) is what the fix delivers. No schema change, no migration, no new dependency, no authentication change. It does add a database lock to two write paths: the approval covers that. Concurrent requests of different users are not affected; two requests of one user queue for the length of one short transaction.

## Risks

- **Held lock:** a request that stalls inside the transaction blocks the same user's other joins and resumes. The transaction holds only a few statements, and `pause`, `leave`, reads and syncs are not blocked.
- **Flaky proof:** a 1-in-8 failure is not proved fixed by one green run. The verification below uses a large loop and a deterministic test.
- **Key collision:** two users sharing a 64-bit key would only queue behind each other, never fail.

## Verification

- A deterministic test in `tests/integration/`: hold the user's lock from a second connection, start `join`, assert it does not insert until the lock is released, then assert it answers `overlapping_challenge` or joins as the first committed state dictates. This fails on `develop` without relying on timing.
- The existing concurrent test, run in a loop of 100: 0 failures (it fails about 1 in 8 now). Output pasted into the MR.
- A second concurrent test for `resume` against `join` (two paused or fresh enrollments of one user, run at once): exactly one wins, the other gets `overlapping_challenge`.
- API check: two simultaneous `POST /api/v1/challenges/{id}/join` calls for overlapping challenges against the running server (two background `curl`s; a `.hurl` file runs requests one after another, so it cannot replay a race): one `204`, one `409` with a body matching `ErrorResponse`. Repeated 20 times.
- `pytest tests/unit`, `pytest tests/integration`, `pytest -m fuzz`, `ruff check .`, `ruff format --check .`, `mypy`.
- Not verifiable here: behaviour on a production-sized PostgreSQL with other load.

## Ticket evidence

Bug ticket: steps to reproduce, expected and actual results and the log are in **Context** above. Backend/API: error contract in `docs/api/challenges.md`; the failing request pair is described in Reproduction.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `fix: concurrent joins of one user answer overlapping_challenge instead of deadlocking` | bug, backend | - [ ] `join` and `resume` take a per-user transaction advisory lock before the overlap check<br>- [ ] Two concurrent overlapping joins of one user: one succeeds, the other gets `409 overlapping_challenge`, never `500`<br>- [ ] The same holds for a join racing a resume<br>- [ ] A deterministic test fails without the lock and passes with it<br>- [ ] The concurrent join test passes 100 times in a row<br>- [ ] The contract in `docs/api/` is unchanged; `pytest`, `ruff` and `mypy` pass | none |
