# Backend decisions and gotchas

Loaded through `backend/CLAUDE.md` whenever Claude works on files under `backend/` ([plan 019](../docs/plans/019-area-autopilot.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. A large decision is an ADR in `docs/adr/`; the entry only links to it.
- Keep this file under 4 KB. Remove an entry once a test or lint enforces it.
- Claude never edits this file while `/run-tasks` issues are in progress. It proposes entries in the PR description, and Claude picks them after the run.

## Entries

- **2026-10-23, skill `fastapi-module`.** A response schema that reads a relationship the query didn't `selectinload` fails with `MissingGreenlet`. After `commit`, reload the row through the repository's eager-loading query before validating it.
- **2026-10-23, skill `fastapi-module`.** A new model missing from `app/modules/models.py` makes Alembic autogenerate an empty migration. Name every `CheckConstraint`; never hard-code a name PostgreSQL chose.
- **2026-10-23, skill `fastapi-module`.** Don't map every `IntegrityError` to one error code: a later constraint would come back with the wrong code. Check business rules through the repository first; map an `IntegrityError` only after checking which constraint failed.
- **2026-10-23, plan 004.** Two overlapping joins at once deadlocked (`DeadlockDetectedError`, a `500`). `join` and `resume` take a per-user `pg_advisory_xact_lock` first, then row locks. Keep that lock order in new write paths on enrollments.
- **2026-10-23, CLAUDE.md.** `docs/api/openapi.json` changes with the backend issue that changes the endpoints, not with the contract issue: `tests/unit/test_openapi_snapshot.py` compares it with the schema the app serves.
- **2026-10-23, skill `fastapi-module`.** A Pydantic validator raises `ValueError` only. Any other exception escapes validation and becomes `500 internal_error`.
- **2026-10-26, #120.** A contract may document an error code before any route serves it: list it in `DOCUMENTED_NOT_YET_SERVED_ERROR_CODES` (`tests/api_docs.py`). The task that adds the route moves it into `AUTH_MODULE_ERROR_CODES` and empties the set; `test_codes_not_yet_served_have_no_route_yet` fails until it does.
- **2026-10-29, #189.** A flow that deletes or changes a user takes the enrollment advisory lock (`RunService.lock_user_enrollments`), then the refresh-token lock, then row locks (admins `ORDER BY id FOR UPDATE` before counting), and re-reads the password hash under the lock, or it races `join` or another delete.
- **2026-10-29, #189.** A service that needs another module's service gets its provider from that module's `deps.py` (`get_run_service`), so no repository or model import crosses modules.
- **2026-10-29, #192.** To reach `409 last_admin` locally, run the backend against a fresh database (`stridequest_i<issue>_dev`, `alembic upgrade head`): the shared dev database may hold other admins.
