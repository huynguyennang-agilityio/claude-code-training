# CLAUDE.md

Guidance for Claude when working in this repository.

## Project

StrideQuest is a running app where every run is a quest: runners complete challenges to unlock medals. See `README.md` for the MVP scope and the architecture diagram.

- **Mobile:** Flutter (Dart), layered architecture (UI, logic, data), `go_router` for navigation, `flutter_test` for tests.
- **Backend:** FastAPI on Python 3.12, async throughout (use `httpx.AsyncClient`, never block the event loop), Pydantic models for request and response schemas, errors returned as typed fields rather than free-form strings, `pytest` for tests.
- **Data:** PostgreSQL. Medal images are static files in object storage (S3 or MinIO); the database stores only their URLs.
- **Health data:** the app reads steps from Apple Health or Health Connect on the device and syncs them to the backend.

## Planned structure

```text
backend/app/{api,models,schemas,services}   FastAPI app
backend/tests/                              pytest tests
mobile/lib/{ui,logic,data}                  Flutter app layers
mobile/test/                                flutter_test tests
```

## Language

- Explain things to the user in Vietnamese.
- Write all code, comments, docs, commit messages and MR text in English.

## Workflow

- Work on one GitLab issue at a time, on its own branch named `<type>/<issue-id>-<short-name>` (for example `feat/1-readme`, `fix/12-step-sync`).
- Never push directly to `main`. Open a merge request into `main` using the default template in `.gitlab/merge_request_templates/Default.md`, and link the issue with `Closes #<id>`.
- Add tests with every feature.
- Don't commit unless asked. After each task, suggest a short commit message.

## Reviewing merge requests

When asked to review an MR, walk these five steps in order and report findings under each step's heading. Write "No issues found" for a step with nothing to report. Don't skip ahead: a correctness problem matters more than a naming nit.

1. **Correctness:** does the change do what the linked issue asks? Check edge cases, error handling and the issue's acceptance criteria.
2. **Tests:** is new logic covered by tests, and do the tests check behavior rather than implementation? Is CI green?
3. **Readability:** are names clear, functions short and code free of duplication? Does it follow the layered structure above?
4. **Security basics:** are there leaked secrets, unvalidated inputs or missing authorization checks?
5. **Scope:** does the MR cover exactly one issue? Flag unrelated changes.

For each finding, give the file and line, what is wrong, and a suggested fix. End with a verdict: approve, approve with nits, or request changes.
