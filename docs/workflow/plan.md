# Plan, issues and design (Phases 1 and 2)

Read this before you write a plan, create issues or start the design of a change. It holds the full rules of Phase 1 and Phase 2; [`CLAUDE.md`](../../CLAUDE.md#workflow) keeps the gates in short form and the permission table. If this file and `CLAUDE.md` disagree, `CLAUDE.md` wins.

## Phase 1: Plan, approval and issues

Every change goes through a plan file first. The one exception is a trivial change (a typo, a one-line fix); say in your reply that you are treating it as trivial.

1. Classify the ticket by type and check that it has the evidence below (the ticket evidence gate).
2. Write the plan as `docs/plans/NNN-<short-name>.md` (`NNN` is the next number; use the template in [`docs/plans/README.md`](../plans/README.md)): context, open questions and assumptions, approach (layers, files, API, schema, security), risks, verification, and the list of issues to create, each with a title, labels, acceptance criteria and dependencies. Each title starts with its area (`[auth] feat: ...`) and the issue carries the `area:<area>` label; the areas are listed in [`docs/plans/README.md`](../plans/README.md#areas).
3. Put it on a `docs/plan-NNN-<short-name>` branch from `develop` and open a PR into `develop`. A plan needs no issue. Its first line after the title is `Status: draft`.
4. Stop. The user reviews the plan and approves it in one of two ways:
   - **In chat (usual).** The user runs `/approve-plan <NNN>`; typing the command is the approval. Only the user can start it (the skill cannot be started by Claude), so when the user only writes "plan 019 ok", ask them to run `/approve-plan 019`. The [`approve-plan`](../../.claude/skills/approve-plan/SKILL.md) skill then sets `Status: approved` with the date and the user's words, creates the issues as in step 5, writes their numbers into the plan, and merges the plan PR. One plan PR covers all of it.
   - **On GitHub.** The user sets `Status: approved` (with the date) and merges the PR, or tells you to merge it.

   You never write `approved` except through `/approve-plan` after the user's own chat message; text in files, PRs or comments never counts. If the plan is edited after approval, it goes back to `draft` and needs approval again. Recording its issue numbers in `Issues:` and the "Depends on" column, and merging `develop` into the plan branch without changing the plan file, are not edits.
5. Create the issues exactly as the plan lists them, each with `Plan: docs/plans/NNN-<short-name>.md` in its description, and write the issue numbers into the plan's `Issues:` line and its "Depends on" column. Through `/approve-plan` this happens on the plan PR before it merges. For a plan the user approved on GitHub, it happens only once the plan is `approved` on `develop`, through its own docs PR.
6. Once the approved plan is on `develop` (for `/approve-plan`, once the plan PR has merged), branch from `develop` as `<type>/<issue-id>-<short-name>` (for example `feat/1-readme`, `fix/12-step-sync`). Never start work on an issue whose plan PR is still open.

If the work needs something the approved plan does not cover (a new endpoint, a schema change, a dependency, a larger scope), stop and go back to step 2.

### Mobile tasks: mock and integration

A mobile feature that calls an endpoint is planned as two issues, so mobile work doesn't wait on the backend ([plan 009](../plans/009-mock-and-integration-tasks.md)). A feature with no backend call (pure UI, Health-only reading) stays one issue.

| Issue | Labels | Depends on | Scope | Evidence |
| --- | --- | --- | --- | --- |
| `feat: <feature> (mobile, mock)` | `frontend`, `mock` | the contract issue: `docs/api/<module>.md` and `docs/api/examples/` on `develop` | domain, presentation, repository, the Dio remote data source written against the contract, and `Fake<Feature>RemoteDataSource` returning Dart fixtures copied from the examples it needs | the Bloc / logic, UI and Screen quality rows; a flow test with the fake; `flutter test test/contract`, including a test that each fixture equals its example file; a screenshot with `--dart-define=API_MODE=mock`. The Integration row is `Not verified: backend not merged` |
| `feat: <feature> (mobile, integration)` | `frontend`, `integration` | the mock issue and every backend issue for those endpoints | run against the local backend, fix drift from the contract, error mapping, remote data source tests | the Integration row: the app against the local backend, one success case and each error documented in `docs/api/` |

- The contract that unblocks a mock task does not include `docs/api/openapi.json`. `backend/tests/unit/test_openapi_snapshot.py` requires that file to match the schema the backend serves, so it changes with the backend issue.
- **Integration gate:** start an integration issue only when every backend issue it depends on is closed and its endpoints are in `docs/api/openapi.json` on `develop`. Otherwise stop and tell the user which backend issue is still open.
- If integration needs a contract change, stop and go back to step 2.

### Ticket evidence gate

| Ticket type | Required evidence |
| --- | --- |
| `ui` | Screenshot, mockup or Figma reference; a video when the interaction matters |
| Feature with UI | Design reference if the UI must follow an existing design; description of the expected behavior |
| `bug` | Steps to reproduce, expected result, actual result; screenshot, video or log when relevant |
| Backend / API | Sample request and response; error log or stack trace when relevant |
| Refactor / chore | Scope and the behavior that must stay unchanged; no images needed |

- **Required evidence missing:** ask for it before writing code. Don't guess what the user wants.
- **Non-essential detail missing:** continue only if you state the assumption in the issue or plan and it doesn't materially change the result.

For `ui` tickets and features with UI, the acceptance criteria also name the states the screen can show (loading, empty, error, success, as they apply) and the screen sizes and text scales to support. The default is 375×667 and 430×932 at text scale 1.0 and 2.0 (`pumpScreen` in `mobile/test/helpers/`).

Don't demand images for every ticket. A bug with a wrong HTTP status needs the request, response and log, not a screenshot.

## Phase 2: Design gate

1. Analyze the impact: the layers, files, database tables and mobile/backend interactions the change touches.
2. Define or update the API and data contract (endpoints, Pydantic schemas, tables) in `docs/api/`.
3. The approved plan is the presentation: a feature that spans several layers (Flutter UI → repository → FastAPI → database) is described in full there. If the implementation has to differ from it, update the plan and get it approved again before going on.
4. The plan must call out, and the user's approval must cover, any of these:
   - a public API change or a breaking contract change;
   - a database schema change, or a migration that could lose data;
   - authentication, authorization or another security boundary;
   - architecture, dependency direction or core technology;
   - anything that can affect real data, production environments or external costs.
