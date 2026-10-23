# Verification evidence

Read this before you report a task as done or write a PR's `## Evidence` section. [`CLAUDE.md`](../../CLAUDE.md#workflow) keeps the rule in short form; if this file and `CLAUDE.md` disagree, `CLAUDE.md` wins.

Verification evidence shows the work was checked. It is not the ticket evidence from Phase 1 ([`plan.md`](plan.md#ticket-evidence-gate)), which is input from the reporter.

- Don't report a task as done without an `## Evidence` section in your report, in the format of the PR template. When the user asks for a PR, the same section goes into its description.
- Map each acceptance criterion to at least one piece of evidence. A change can match several rows below. Every row also includes the lint and type-check results.
- Redact tokens, passwords, `Authorization` headers, cookies and connection strings before pasting anything.
- Attach large logs and screenshots to the PR instead of committing them. Golden test baselines are test fixtures and are committed as usual. Rendering differs between operating systems, so generate and compare goldens on the same platform: baselines are generated on an Apple Silicon Mac (`flutter test --update-goldens --tags golden`) and CI compares them on `macos-15` (the `goldens` job). If the `goldens` job fails, its `golden-failures` artifact holds the diff images.

| Change | Evidence |
| --- | --- |
| Backend service / repository | `pytest` command and result summary; the full log if anything failed |
| Database schema | Run against the local docker-compose database only: `alembic upgrade head`, `alembic downgrade <develop head revision>`, `alembic upgrade head` again, and the resulting table definition (`\d <table>`) |
| API endpoint | Calls against the running server: one success case and each error case documented in `docs/api/`, with request, status code and JSON body. Error bodies match `ErrorResponse`. Keep the calls as a `.hurl` file in `backend/hurl/` and paste the output of `backend/hurl/run.sh`, so a reviewer can replay them. `pytest -m fuzz` (Schemathesis checks every response against the OpenAPI document) must pass |
| Bloc / logic | `flutter test <path>` command and result |
| UI | Screenshot of the running app next to the design reference. A screen has a golden test (`goldenScreen` in `mobile/test/helpers/`), generated on an Apple Silicon Mac and checked in CI by the `goldens` job. Attach the baseline image diff when a golden changes |
| Screen quality | `flutter test <page test>` using `pumpScreen` and `expectAccessible`: both phone sizes, both text scales, no overflow, accessibility guidelines, and each bloc state (loading, empty, error, success) |
| API contract change | The changed files under `docs/api/examples/` and the `docs/api/openapi.json` diff; `pytest tests/unit/test_api_examples.py tests/unit/test_error_contract.py tests/unit/test_openapi_snapshot.py` and `flutter test test/contract` results |
| New or changed route | `pytest tests/unit/test_auth_sweep.py` (the route is declared in `ROUTE_ACCESS` as `public`, `user` or `admin`, with the same requirement in the contract's `Auth` column; an `admin` route answers a signed-in user with `403 forbidden`), plus an ownership test for a user-owned resource: another user gets `404 not_found`. A response that nests rows (for example a quest with its challenges and medals) also needs a query-count test showing a fixed number of statements however many rows there are |
| Bug fix | The reproduction steps and the actual result before the fix; the same steps and the result after it |
| Integration | The flow exercised across components (for example the app against the local backend) and what was observed |
| Chore / docs | The commands run and their results |

If a piece of evidence can't be produced (no simulator, no database), write `Not verified: <reason>` instead. Never leave it out silently.
