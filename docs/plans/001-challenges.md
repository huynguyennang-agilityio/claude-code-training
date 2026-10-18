# Plan 001: Challenge list, challenge detail and Join

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

The signed-in app has four tabs (Challenges, Active, Medals, Profile) whose contents are placeholders. This plan builds the first slice of the Challenges journey: **browse the challenges, open one, and join it**. Doing a challenge (progress from health data, finishing, earning medals, the Active and Medals tabs) is **another plan, made later**.

Reference: five screenshots of another app (a challenge list with search and filter chips, a challenge detail with banner, dates, terms, goal, "About", medals and a join button), sent by the user in chat. They are a **layout reference only**. They show a third party's events, artwork and copy, so none of it is reused or committed; our screens get our own content and styling (the Figma file's dark theme with Lime).

What the user asked for:

- Challenges are **solo** only for now.
- Three types: **run**, **swim**, **cycle**.
- A user can have **one challenge per type at a time**. Joining a second one of the same type is refused with a message that the current one must be **finished** first.
- A challenge can be joined **only while its end date has not passed**.
- A challenge can carry a **landmark and a city**.
- Each challenge shows **three checkpoints** with a medal each (bronze, silver, gold), as in the screenshots.
- The list and the detail screen look like the screenshots, with **one Join button**.
- Images are stored in **Cloudinary**; the user configures the account, so this plan lists the steps.

Out of scope here, planned later: how progress is counted (steps for run, device workouts for swim and cycle), finishing a challenge, awarding medals, pause and resume, the Active and Medals tabs, health permissions.

## Open questions and assumptions

Each has a recommendation. Approving the plan approves the recommendation unless you change it in the review.

1. **A joined challenge that nobody finishes.** Finishing does not exist until the later plan, so an `active` enrollment could block its type forever. *Recommendation:* an enrollment whose challenge has ended no longer blocks: when a user joins, their stale enrollments of that type (challenge ended, not finished) are first set to `expired` in the same transaction. Until finishing exists, a user with a running (not ended) challenge of a type cannot join another of that type; that is the rule as asked.
2. **Join window.** *Recommendation:* the user can join while `now < ends_at`, including before `starts_at`.
3. **Joining twice.** *Recommendation:* joining a challenge the user is already in is `409 already_joined`.
4. **What the list shows.** *Recommendation:* type chips (All, Run, Swim, Cycle) and a search field as in the screenshots, both filtered on the server. They are cheap, and the screenshots have them; say so in the review if you want them cut.
5. **Checkpoint medals on the detail screen** are display only now: the three tiers (bronze, silver, gold) with their image, name and threshold, so the data model has tiers from the start. Nothing is awarded yet.
6. **Units.** *Recommendation:* run is a step goal; swim and cycle are a distance goal, stored in metres and shown in km (miles when the Units setting of the Account screens says so; that setting is wired later).
7. **Cloudinary replaces S3/SeaweedFS** for all images (covers and medals). *Recommendation:* yes, remove the S3 settings and the SeaweedFS service, and record it in an ADR. This changes a core technology: the approval covers it.
8. **Quests.** The existing `quests` table groups challenges. *Recommendation:* keep it, hidden from the UI (a default quest holds all challenges), so nothing is thrown away.
9. **Naming.** The `runs` module owns "a user's attempt at a challenge" for all three types. *Recommendation:* keep the module and the `runs` table, add a status and the challenge type, and document that "run" here means an attempt. A rename is a later chore.
10. **Admin.** There is no admin app. *Recommendation:* challenges are created by a seed script (a JSON file plus images uploaded to Cloudinary), not through the app.
11. **Design first.** The list and detail screens are drawn in Figma (issue 1) and approved by the user before any screen is coded. English only, as now.

## Approach

### Data model (backend `challenges`, `medals`, `runs`)

Two Alembic migrations, each data-preserving (existing rows get `type = run`, `metric = steps`) and tested up, down, up. The tables hold no real data yet.

| Table | Change |
| --- | --- |
| `challenges` | add `type` (run, swim, cycle), `metric` (steps, distance_m), `target_value` (replaces `target_steps`), `mode` (solo; room for team and rank later), `description_md`, `terms_md`, `cover_image_url`, `city`, `landmark` (nullable), `status` for publishing (draft, published) |
| `medals` | one medal per tier: add `tier` (bronze, silver, gold) and `threshold_value`; unique `(challenge_id, tier)` replaces unique `challenge_id` |
| `runs` (an attempt) | add `status` (`active`, `expired`; `finished` and the rest come with the later plan), `joined_at`, `type` (copied from the challenge); `user_id` becomes a real foreign key to `users.id`; a **partial unique index** on `(user_id, type) where status = 'active'` makes the one-active-per-type rule a database guarantee |

### API (contract in `docs/api/challenges.md`, written with the first backend issue)

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/challenges?type=&q=&cursor=&limit=` | The list: card fields, participant count, and whether the caller has joined |
| `GET /api/v1/challenges/{id}` | Detail: description, terms, the three checkpoints with their medals, participant count, and the caller's enrollment (if any) |
| `POST /api/v1/challenges/{id}/join` | Join. `201` with the enrollment. `409 type_already_active` (carries the blocking challenge's id and title; the message says it must be finished first), `409 challenge_ended`, `409 already_joined`, `404 not_found` |

All routes need a signed-in user. Errors use the typed `ErrorResponse`. A response that nests rows (a challenge with its medals) has a fixed query count. The auth sweep, the fuzz test, the `hurl` files and the OpenAPI snapshot cover the new routes. The join runs in one transaction: expire stale enrollments of the type, check, insert; the partial unique index is the last guard when two joins race, and the loser gets `409 type_already_active`.

### Mobile (`features/challenges`)

- **Challenges tab:** title, search field, type chips, and the list of challenge cards. A card: cover image, type tag, city, title, dates, the goal, and the Join button or a Joined label. States: loading, empty, error with retry, offline. Cursor paging.
- **Detail** (`/challenges/:id`, ID only): cover, participant count, title, type and place, dates, Terms (expandable), goal, About, the three medal checkpoints, and a fixed Join button. When it cannot be used the button shows why: already joined, ended, or "Finish your current *type* challenge to join another".
- **Join:** the button calls the join endpoint; on `409 type_already_active` a message names the blocking challenge. No "switch" or "pause" flow now.
- **About and Terms** are Markdown rendered without HTML, so a challenge's text cannot inject markup.
- **Images** load from Cloudinary URLs that ask for the size and format the screen needs (`f_auto,q_auto,w_<width>`) and are cached on the device.
- The Active, Medals and Profile tabs are unchanged.

### Cloudinary setup (the user does this; nothing needs a code change until issue 3)

1. Create a Cloudinary account (the free plan is enough to start) and note the **cloud name**.
2. Create folders `stridequest/challenges/covers` and `stridequest/challenges/medals`.
3. Use **signed uploads from the backend script only**. The mobile app never uploads, so no unsigned preset is created. Keep the API key and secret on the server.
4. Put the credentials in the root `.env` (never committed): `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`. The repo's `.env.example` gets the names with placeholder values.
5. Strict transformations are optional; without them the on-the-fly `w_`, `f_auto`, `q_auto` parameters work as they are.
6. Check the plan's quota (storage and monthly credits) before the first bulk upload, and keep the originals of every image outside Cloudinary.
7. The database stores the delivery URL (`https://res.cloudinary.com/<cloud>/image/upload/...`), as it did for object storage.

### Documents and rules that change

`docs/architecture.md` (data model, modules, storage), a new ADR for Cloudinary, `docs/adr/0002-cross-module-reads.md` (a challenge now nests a list of medals), `README.md` and `.env.example` (storage), `CLAUDE.md` (the Data bullet that names S3/SeaweedFS), `docker-compose.yml` (drop SeaweedFS).

### Flags for the approval

This plan **changes the public API and the database schema** (new columns, a partial unique index, a real foreign key), touches **authorization** (the join is the caller's own), changes a **core technology** (images move from S3-compatible storage to Cloudinary) and has an **external cost** (Cloudinary plan limits). The approval covers all of these.

## Risks

- **Two joins at once** could break the one-per-type rule. Mitigation: the partial unique index, not only a check in the service; the loser gets `409`.
- **A stuck `active` enrollment** before finishing exists. Mitigation: question 1, expiry in the join transaction.
- **Clock and time zones:** windows are stored in UTC; screens show local time. "Ended" means `now >= ends_at` on the server clock.
- **Cloudinary lock-in and quota:** URLs in the database point to one vendor. Mitigation: only URLs are stored, keep originals elsewhere, build URLs in one function.
- **Rich text:** Markdown only, no raw HTML, links open outside the app.
- **Migration on a shared model:** two migrations (catalog, then enrollments), each tested up and down.
- **Copyright:** the reference screenshots are not committed and their content is not reused.
- **Later plan:** the status values and the sample tables are left for it, so it will need its own migration.

## Verification

- **Backend:** `pytest` (unit, integration against the docker-compose database), `ruff`, `mypy`; `alembic upgrade head`, `downgrade`, `upgrade` for each migration with the table definition; per route, the calls with request, status and body for the success and each documented error, as a `.hurl` file replayed by `backend/hurl/run.sh`; `pytest -m fuzz`; the auth sweep; query-count tests for the nested responses; a concurrency test (two joins of the same type in parallel: one wins); a test that an ended challenge cannot be joined and that a stale enrollment does not block.
- **Mobile:** widget tests per state at both phone sizes and text scales 1.0 and 2.0 (`pumpScreen`, `expectAccessible`), goldens, bloc tests, router tests, and an `integration_test` against the local backend and a seeded database (browse, open, join, the blocked message).
- **Design:** each screen is compared with its Figma frame on the simulator.

## Ticket evidence

- Screens: the Figma frames drawn in issue 1 and approved by the user. Until then no screen issue starts.
- Backend: the sample requests and responses are in `docs/api/challenges.md` and `docs/api/examples/`, written in issue 4.
- Reference: the five screenshots the user sent in chat (not committed).

## Issues to create

Order and dependencies matter.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `docs: draw the challenge list and detail screens in Figma` | design | - [ ] Frames: list (loading, empty, error), detail (open, joined, ended, blocked by another active challenge of the same type), the Join button states. - [ ] Text and color styles reused. - [ ] The user approves the frames | none |
| 2 | `docs: use Cloudinary for images instead of object storage (ADR)` | docs | - [ ] ADR 0003; `CLAUDE.md`, `architecture.md`, `README.md`, `.env.example` updated. - [ ] S3 settings and SeaweedFS removed from the config and compose. - [ ] The Cloudinary setup checklist is in the README | none |
| 3 | `feat: challenge catalog data model and seed script (backend)` | backend | - [ ] Migration for `challenges` and `medals` (type, metric, target, location, three tiers), up and down tested. - [ ] Seed script reads a JSON file and uploads images to Cloudinary. - [ ] Unit and integration tests; `ruff`, `mypy` | 2 |
| 4 | `feat: challenge list and detail endpoints (backend)` | backend | - [ ] `docs/api/challenges.md`, examples and `openapi.json`. - [ ] `GET /challenges` (type, search, cursor) and `GET /challenges/{id}`. - [ ] Auth sweep, query-count, fuzz and `hurl` evidence | 3 |
| 5 | `feat: join a challenge with one active challenge per type (backend)` | backend | - [ ] Migration for `runs` (status, joined_at, type, real user FK, partial unique index). - [ ] `POST /challenges/{id}/join` with `type_already_active`, `challenge_ended`, `already_joined`; stale enrollments expire in the join. - [ ] Concurrency test; contract, `hurl` and fuzz evidence | 4 |
| 6 | `feat: Challenges tab list and challenge detail (mobile)` | frontend | - [ ] List with search and type chips, cards, all states, paging. - [ ] Detail with the three medal checkpoints, Terms and About. - [ ] Page, golden, bloc and flow tests; both phone sizes and text scales | 1, 4 |
| 7 | `feat: Join button and the blocked message (mobile)` | frontend | - [ ] Join on the card and the detail; Joined state; the reason shown when it cannot be used (already joined, ended, finish the current one first). - [ ] Tests, and an `integration_test` against the local backend | 5, 6 |

## Next plan

A later plan (002), to be written when this one is done, covers doing a challenge: how progress is counted (steps from health data for run; device workouts for swim and cycle), finishing, awarding the three medals, pause and resume, the Active and Medals tabs, health permissions and anti-cheat rules.
