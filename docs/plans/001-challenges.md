# Plan 001: Challenges, join rules, progress and medals

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

The signed-in app has four tabs (Challenges, Active, Medals, Profile) whose contents are placeholders. This plan builds the core journey behind them: browse challenges, join one, track progress from the device's health data, and earn medals.

Reference: five screenshots of another app (a challenge list with search and filter chips, a challenge detail with banner, dates, terms, goal, "About", medals and a join button), sent by the user in chat. They are a **layout reference only**. They show a third party's events, artwork and copy, so none of it is reused or committed; our screens get our own content and styling (the Figma file's dark theme with Lime).

What the user asked for:

- Challenges, **solo only** for now.
- Three types: **run**, **swim**, **cycle**.
- A user may be in **one challenge per type at a time**: for example three at once, but of different types. A new one of the same type only after the current one is finished or paused.
- Run counts the user's **steps** from health data. Swim and cycle come from **workouts** on the device.
- A challenge can carry a **landmark and a city**.
- Each challenge has **three checkpoints**, each with a medal: bronze, silver, gold.
- Each challenge has a **Join** button, and a detail screen like the screenshots.
- Images are stored in **Cloudinary**; the user configures the account, so this plan lists the steps.

## Open questions and assumptions

Each has a recommendation. Approving the plan approves the recommendation unless you change it in the review.

1. **What does "finished" mean?** *Recommendation:* the user reaches the last checkpoint (gold). The gold threshold equals the challenge target. When the window ends first, the enrollment is `expired` and the medals already earned stay.
2. **What does pause do?** *Recommendation:* a paused enrollment stops counting; data recorded while paused is not counted, even after resume. Resume is allowed until the window ends, and only if the user has no other active challenge of that type.
3. **What counts, and from when?** *Recommendation:* only data recorded after the user joins and inside the challenge window. This stops people joining late and claiming old workouts.
4. **Join before the challenge starts?** *Recommendation:* yes, while it is open for joining (`now < ends_at`). Counting starts at `max(starts_at, joined_at)`.
5. **Checkpoint thresholds.** *Recommendation:* set per challenge as explicit values (for example 50,000 and 100,000 steps), not fixed percentages. Three tiers (bronze, silver, gold) per challenge; fewer are allowed.
6. **Units.** *Recommendation:* run = steps; swim and cycle = distance, stored in metres and shown in km or miles (the Units setting of the Account screens). No time-based targets for now.
7. **Cheating.** *Recommendation:* count only samples from the device's health store; skip entries the user typed in by hand where the platform says so (HealthKit "user entered", Health Connect manual recording); dedupe by the record id; reject implausible values (for example cycling faster than 60 km/h, more than 250 steps a minute). The limits are settings, not constants.
8. **Cloudinary replaces S3/SeaweedFS** for all images (covers and medals). *Recommendation:* yes, remove the S3 settings and the SeaweedFS service, and record it in an ADR. This changes a core technology: the approval covers it.
9. **Quests.** The existing `quests` table groups challenges. *Recommendation:* keep it, hidden from the UI (a default quest holds all challenges), so nothing is thrown away; revisit when themed groups are wanted.
10. **Naming.** The `runs` module owns "a user's attempt at a challenge" for all three types. *Recommendation:* keep the module and the `runs` table (no rename, no new module), add a `status` and the challenge type, and document that "run" means an attempt, not only running. A rename is a later chore.
11. **Admin.** There is no admin app. *Recommendation:* challenges are created by a seed script (JSON file plus images uploaded to Cloudinary), not through the app, until an admin tool is planned.
12. **Language and design.** English only, as now. The Challenges list and detail screens are drawn in Figma first (issue 1) and the user approves them before any screen is coded.

## Approach

### Proposals beyond what was asked

- **Switch in one tap:** when a join is refused because the user has an active challenge of that type, the app offers "Pause *X* and join this one".
- **Progress on the detail screen** and on the Active tab (a bar toward the next checkpoint).
- **Pre-permission screen** that says why health access is wanted, before the system dialog (read only, steps and workouts).
- **About and Terms as Markdown**, rendered without HTML, so a challenge's text cannot inject markup.
- **Search and type filter on the server** (`q`, `type`), with cursor paging, so the list scales.
- **Upcoming, open and ended** states on a card; an ended challenge is read-only.
- **Participant count** on the card and detail (a count, no names).
- Left out on purpose, although the screenshots show them: paid entry, prizes and lucky draw, team, rank and points filters, share. They need product decisions of their own.

### Data model (backend, `challenges`, `medals`, `runs`)

One Alembic migration per step, data-preserving (existing rows get `type = run`, `metric = steps`). Tables hold no real data yet.

| Table | Change |
| --- | --- |
| `challenges` | add `type` (run, swim, cycle), `metric` (steps, distance_m), `target_value` (replaces `target_steps`), `mode` (solo; room for team and rank later), `description_md`, `terms_md`, `cover_image_url`, `city`, `landmark` (nullable), `status` for publishing (draft, published) |
| `medals` | one medal per **tier**: add `tier` (bronze, silver, gold) and `threshold_value`; unique `(challenge_id, tier)` replaces unique `challenge_id`; `description`, `image_url` as now |
| `runs` (an attempt) | add `status` (active, paused, finished, expired), `joined_at`, `finished_at`, `progress_value`; **partial unique index** on `(user_id, type) where status = 'active'` makes the one-active-per-type rule a database guarantee; `user_id` becomes a real foreign key to `users.id` |
| `step_samples` | generalized to `activity_samples`: `kind` (steps, workout), `value` (steps or metres), source and the device record id, unique per run as now |
| `user_medals` (new) | `user_id`, `medal_id`, `earned_at`; unique `(user_id, medal_id)` so an award is idempotent |

### API (contract in `docs/api/challenges.md`, written with the first backend issue)

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/challenges?type=&q=&cursor=&limit=` | The list: card fields, and the caller's own enrollment status |
| `GET /api/v1/challenges/{id}` | Detail: description, terms, the three checkpoints with their medals, participant count, the caller's enrollment and progress |
| `POST /api/v1/challenges/{id}/join` | Join. `409 type_already_active` (with the active challenge's id), `409 challenge_ended`, `409 already_joined` |
| `POST /api/v1/runs/{id}/pause`, `/resume` | Pause and resume; resume can also return `409 type_already_active` |
| `GET /api/v1/runs?status=` | The Active tab: the caller's enrollments |
| `POST /api/v1/runs/{id}/samples` | Batch sync of samples from the device; returns the new progress and any medals just earned |
| `GET /api/v1/medals/mine` | The Medals tab: earned and locked medals |

All routes need a signed-in user; another user's enrollment is `404 not_found`. Errors use the typed `ErrorResponse`. Responses that nest rows (a challenge with its medals) get a fixed query count. The auth sweep, the fuzz test, the `hurl` files and the OpenAPI snapshot cover the new routes.

### Mobile (`features/challenges`, `runs`, `medals`)

- **Challenges tab:** title, search field, type chips (All, Run, Swim, Cycle), a horizontal "Open now" list of cards and a "Discover more" list. A card: cover image, type tag, city, title, dates, the goal, and Join or Joined. States: loading, empty, error with retry, offline.
- **Detail** (`/challenges/:id`): cover, joined count, title, type and place, dates, Terms (expandable), goal, About, the three medal checkpoints, and a fixed Join, Pause or Resume button with the reason when it is disabled.
- **Active tab:** the user's enrollments with progress and Pause or Resume.
- **Medals tab:** earned medals and locked ones; a short celebration when a sync earns one.
- **Health** (`HealthDataSource`, the `health` package, behind a domain interface): steps for run; workouts for swim and cycle. Permissions and usage strings on iOS (HealthKit capability, `NSHealthShareUsageDescription`) and Android (Health Connect permissions and privacy-policy declaration). Reading runs on app open, on pull to refresh and after a join; background sync is not in this plan.
- Images are loaded with Cloudinary URLs that ask for the size and format the screen needs (`f_auto,q_auto,w_<width>`), and cached on the device.

### Cloudinary setup (the user does this; nothing here needs a code change until issue 2)

1. Create a Cloudinary account (the free plan is enough to start) and note the **cloud name**.
2. Create folders `stridequest/challenges/covers` and `stridequest/challenges/medals`.
3. Use **signed uploads from the backend script only**. The mobile app never uploads, so no unsigned preset is created. Keep the API key and secret on the server.
4. Put the credentials in the root `.env` (never committed): `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`. The repo's `.env.example` gets the names with placeholder values.
5. Turn on **strict transformations** only if the delivery URLs should be limited to named presets (optional); otherwise the on-the-fly `w_`, `f_auto`, `q_auto` parameters work as they are.
6. Check the plan's quota (storage and monthly credits) before the first bulk upload, and keep the originals of every image outside Cloudinary.
7. The database stores the delivery URL (`https://res.cloudinary.com/<cloud>/image/upload/...`), as it did for object storage.

### Documents and rules that change

`docs/architecture.md` (data model, modules, storage), a new ADR for Cloudinary, `docs/adr/0002-cross-module-reads.md` (a challenge now nests a list of medals), `README.md` and `.env.example` (storage), `CLAUDE.md` (the Data bullet that names S3/SeaweedFS), `docker-compose.yml` (drop SeaweedFS).

### Flags for the approval

This plan **changes the public API and the database schema** (new tables and columns, a partial unique index, a real foreign key), touches **authorization** (ownership of enrollments), changes a **core technology** (images move from S3-compatible storage to Cloudinary) and involves **external costs and third-party data** (Cloudinary plan limits; health data from the device). The approval covers all of these.

## Risks

- **Health data quality and cheating:** steps and workouts can be typed in or written by other apps. Mitigation: the rules in question 7, server-side validation, limits kept in settings, and the dedupe on the record id.
- **Two joins at once** could break the one-per-type rule. Mitigation: the partial unique index, not only a check in the service; the loser gets `409`.
- **A medal awarded twice** by two syncs. Mitigation: `user_medals` is unique per user and medal, and the award runs in the sync transaction.
- **Platform limits:** HealthKit needs a real device for realistic data and an App Store privacy declaration; Health Connect needs Android 14 or the Health Connect app, and a Play declaration. Mitigation: a device-verification step in the Health issue, and `Not verified` lines where a device is missing.
- **Time zones:** windows are stored in UTC; screens show local time. A month-long challenge ends at an explicit instant, not "end of month".
- **Cloudinary lock-in and quota:** URLs in the database point to one vendor. Mitigation: only URLs are stored, keep originals elsewhere, wrap URL building in one function.
- **Big migration on one branch:** split into steps (catalog, enrollments, samples), each with its own migration, up and down tested.
- **Copyright:** the reference screenshots are not committed and their content is not reused.

## Verification

- **Backend:** `pytest` (unit, integration against the docker-compose database), `ruff`, `mypy`; `alembic upgrade head`, `downgrade`, `upgrade` for each migration with the table definition; per route, the calls with request and status and body for the success and each documented error, as a `.hurl` file replayed by `backend/hurl/run.sh`; `pytest -m fuzz`; the auth sweep and the ownership tests; query-count tests for the nested responses; a concurrency test for the one-active-per-type rule (two joins in parallel, one wins).
- **Mobile:** widget tests per state at both phone sizes and text scales 1.0 and 2.0 (`pumpScreen`, `expectAccessible`), goldens, bloc tests, router tests, and an `integration_test` against the local backend (browse, join, conflict, pause, sync a seeded sample, earn a medal).
- **Health:** a real iPhone (and an Android device when available) with entered test data; steps and a workout reach the backend and move the progress. Where no device is available the evidence says `Not verified: <reason>`.
- **Design:** each screen is compared with its Figma frame on the simulator.

## Ticket evidence

- Screens: the Figma frames drawn in issue 1 and approved by the user. Until then no screen issue starts.
- Backend: the sample requests and responses are in `docs/api/challenges.md` and `docs/api/examples/`, written in issue 3.
- Reference: the five screenshots the user sent in chat (not committed).

## Issues to create

Order and dependencies matter. Milestone A is the catalog, B is joining, C is progress and medals.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `docs: draw the Challenges list, detail and states in Figma` | design | - [ ] Figma frames: list (loading, empty, error), detail (open, joined, ended, blocked by another active challenge), medals section, Active and Medals tabs with data. - [ ] Text and color styles reused; the user approves the frames | none |
| 2 | `docs: use Cloudinary for images instead of object storage (ADR)` | docs | - [ ] ADR 0003; `CLAUDE.md`, `architecture.md`, `README.md`, `.env.example` updated. - [ ] S3 settings and SeaweedFS removed from the config and compose. - [ ] The Cloudinary setup checklist is in the README | none |
| 3 | `feat: challenge catalog data model and seed script (backend)` | backend | - [ ] Migration for `challenges` and `medals` (type, metric, target, location, three tiers), up and down tested. - [ ] Seed script reads a JSON file and uploads images to Cloudinary. - [ ] Unit and integration tests; `ruff`, `mypy` | 2 |
| 4 | `feat: challenge list and detail endpoints (backend)` | backend | - [ ] `docs/api/challenges.md`, examples and `openapi.json`. - [ ] `GET /challenges` (type, search, cursor) and `GET /challenges/{id}`. - [ ] Auth sweep, query-count, fuzz and `hurl` evidence | 3 |
| 5 | `feat: Challenges tab list and challenge detail (mobile)` | frontend | - [ ] List with search and type chips, cards, all states. - [ ] Detail with the three medal checkpoints. - [ ] Page, golden, bloc and flow tests; both phone sizes and text scales | 1, 4 |
| 6 | `feat: join, pause and resume with one active challenge per type (backend)` | backend | - [ ] Migration for `runs` (status, joined_at, finished_at, real user FK, partial unique index). - [ ] The join, pause, resume and list endpoints with the documented errors. - [ ] Concurrency test; ownership `404` | 4 |
| 7 | `feat: join, pause and resume and the Active tab (mobile)` | frontend | - [ ] Join button states on the card and detail, with the reason when blocked. - [ ] "Pause X and join this one" flow. - [ ] The Active tab lists enrollments. - [ ] Tests and `integration_test` | 5, 6 |
| 8 | `feat: sample sync, validation and medal awards (backend)` | backend | - [ ] Migration for `activity_samples` and `user_medals`. - [ ] `POST /runs/{id}/samples` validates (window, joined_at, pause, duplicates, limits) and awards medals once. - [ ] `GET /medals/mine` | 6 |
| 9 | `feat: read steps and workouts from the device and sync (mobile)` | frontend | - [ ] Domain interface and the `health` package behind it; permissions and usage strings on iOS and Android. - [ ] Pre-permission screen. - [ ] Sync on open and pull to refresh; progress on detail and Active. - [ ] Device evidence or `Not verified` | 7, 8 |
| 10 | `feat: Medals tab and the earned-medal moment (mobile)` | frontend | - [ ] Earned and locked medals. - [ ] A celebration when a sync earns one. - [ ] Tests at both sizes and scales | 8, 9 |
