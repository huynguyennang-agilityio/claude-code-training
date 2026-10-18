# Plan 001: Challenge list, detail, join, and create-challenge endpoints for admins

Status: approved
Approved: <the user fills in the date>
Issues: #59, #60, #61, #62, #63, #64, #65, #66, #67, #68 (plan issues 1 to 10, in order)

## Context

The signed-in app has four tabs (Challenges, Active, Medals, Profile) whose contents are placeholders. This plan builds the first slice of the Challenges journey: **browse the challenges, open one, join it, and pause or leave it**, and an **admin API** to create the challenges (a web admin comes later). Doing a challenge (progress from health data, finishing, earning medals, the Active and Medals tabs) is **another plan, made later**.

Reference: five screenshots of another app (a challenge list with search and filter chips, a challenge detail with banner, dates, terms, goal, "About", medals and a join button), sent by the user in chat. They are a **layout reference only**. They show a third party's events, artwork and copy, so none of it is reused or committed; our screens get our own content and styling (the Figma file's dark theme with Lime).

### Decided by the user

- Challenges are **solo** only for now. Three types: **run**, **swim**, **cycle**.
- A challenge can carry a **landmark and a city**, and shows **three checkpoints** with a medal each (bronze, silver, gold). The medals are display only in this plan.
- The list keeps the **search field and the type filter**. A joined challenge shows **Joined** in the list.
- The detail screen has **one Join button**. When the user has joined, it becomes **Pause or Leave**.
- A challenge can be joined **only while its end date has not passed**.
- **Overlap, not "one at a time" for ever:** a user cannot be in two challenges of the same type **at the same time**, but a challenge that starts after the other ends is fine. Example: today is 10/9, the user has joined a run challenge that ends on 30/9; they can still join a run challenge that starts in October.
- Challenges are **created through an API**; a web admin is built later.
- **Cloudinary replaces S3/SeaweedFS** completely. The user configures the account (steps below).
- The `quests` table is **kept**.

Out of scope here, planned later: how progress is counted (steps for run, device workouts for swim and cycle), finishing a challenge, awarding medals, what a pause does to progress, the Active and Medals tabs, health permissions, and the web admin.

## Open questions and assumptions

Each has a recommendation. Approving the plan approves the recommendation unless you change it in the review.

1. **Does a paused challenge free the type for another one?** *Recommendation:* yes. Only `active` enrollments count for the overlap rule, so a user can pause a run challenge and join an overlapping run challenge. Resuming is refused (`409 overlapping_challenge`) while another active run challenge overlaps it.
2. **What does Leave do?** *Recommendation:* the user leaves the challenge (status `left`), after a confirmation. The participant count drops. They can join it again while it is still open and does not overlap; that reuses the same enrollment row. Progress is not kept (there is none yet; the later plan decides).
3. **What does the "blocked" message say?** *Recommendation:* "You are already in *X*, which runs at the same time as this challenge. Finish, pause or leave it to join this one." It names the other challenge. On the card the Join tap shows this message; on the detail the button is disabled with it.
4. **Overlap precisely.** *Recommendation:* windows are half-open, `[starts_at, ends_at)`, so a challenge that starts at the instant another ends is allowed. Only `active` enrollments count, and `finished` and `expired` (later plan) never do.
5. **Join window.** *Recommendation:* the user can join while `now < ends_at`, including before `starts_at`.
6. **Admin identity (a new security boundary).** *Recommendation:* a `role` column on `users` (`user` or `admin`, default `user`) and a `require_admin` dependency (an admin is also a normal user in the app). The first admin is made by a command-line script (`python -m app.scripts.create_admin <email>`), not by any public endpoint. A non-admin gets `403 forbidden`. There is **no separate `/admin` path prefix**: the create, edit, publish and delete routes live on the same resources as the public ones (`/challenges`, `/quests`, `/images`) and each is guarded by the role, so one resource has one set of paths. A `/admin/...` prefix is added later only for things that exist for the web admin alone (statistics, participant lists).
7. **What an admin can change.** *Recommendation:* a challenge starts as `draft`; **publish** needs a cover image, a description, a valid window and at least one medal tier (up to three). A draft is editable freely and deletable. A published challenge cannot change `type`, `metric` or its window once anyone has joined; other fields can change.
8. **Images from the API.** *Recommendation:* an admin sends an image to `POST /api/v1/images` (multipart, JPEG, PNG or WebP, at most 5 MB); the backend uploads it to Cloudinary with its secret key and returns the delivery URL, which the admin then puts in the challenge or medal. Direct signed uploads from the web admin can replace this later.
9. **Search.** *Recommendation:* `q` matches the title, city and landmark, case-insensitively; the type filter is `type=run|swim|cycle`; both on the server, with cursor paging.
10. **Quests.** *Recommendation:* kept and hidden from the mobile UI. A challenge's `quest_id` is optional when an admin creates a challenge and falls back to a default quest; `POST /api/v1/quests` (admin) and `GET /api/v1/quests` create and list them.
11. **Naming.** The `runs` module owns "a user's attempt at a challenge" for all three types. *Recommendation:* keep the module and the `runs` table, and document that "run" means an attempt here. A rename is a later chore.
12. **Participants row.** The reference shows participant avatars and "View all". *Recommendation:* for now the row shows only the **count** ("+813 participants") with placeholder avatars: showing other users' names or photos needs avatars, a privacy decision and a participants endpoint, so "View all" is left for a later plan.
13. **Units.** *Recommendation:* run is a step goal; swim and cycle are a distance goal, stored in metres and shown in km (miles when the Units setting of the Account screens says so; wired later).
14. **Design first.** The list and detail screens are drawn in Figma (issue 1) and approved by the user before any screen is coded. English only, as now.

## Approach

### Data model

Migrations are data-preserving (existing rows get `type = run`, `metric = steps`) and tested up, down, up. The tables hold no real data yet.

| Table | Change |
| --- | --- |
| `users` | add `role` (`user`, `admin`), default `user` |
| `challenges` | add `type` (run, swim, cycle), `metric` (steps, distance_m), `target_value` (replaces `target_steps`), `mode` (solo; room for team and rank), `description_md`, `terms_md`, `cover_image_url`, `city`, `landmark` (nullable), `status` (draft, published) |
| `medals` | one medal per tier: add `tier` (bronze, silver, gold) and `threshold_value`; unique `(challenge_id, tier)` replaces unique `challenge_id` |
| `quests` | unchanged |
| `runs` (an attempt) | `user_id` becomes a real foreign key to `users.id`; rename `started_at` to `joined_at`; add `status` (`active`, `paused`, `left`; `finished` and `expired` come with the later plan), and a copy of the challenge's `type`, `starts_at` and `ends_at`; unique `(user_id, challenge_id)`; an **exclusion constraint** `EXCLUDE USING gist (user_id WITH =, type WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status = 'active')` makes the overlap rule a database guarantee (needs `CREATE EXTENSION btree_gist`) |

The copy of `type` and the window lives on the enrollment so the constraint can see it; that is why a published challenge's window and type are frozen once someone has joined (question 7).

### API (contract in `docs/api/challenges.md`, written with the first backend issue that adds a route)

One set of paths per resource. The role decides who may call a route: **user** means any signed-in user (admins included), **admin** means `role = admin`, otherwise `403 forbidden`.

| Endpoint | Who | Purpose |
| --- | --- | --- |
| `GET /api/v1/challenges?type=&q=&cursor=&limit=` | user | The list of published challenges: card fields, participant count, and the caller's enrollment status (joined, paused). An admin can add `status=draft` to see drafts |
| `GET /api/v1/challenges/{id}` | user | Detail: description, terms, the three checkpoints and their medals, participant count, the caller's enrollment, and `blocked_by` (the overlapping challenge that stops a join, if any). A draft is `404 not_found` for a non-admin |
| `POST /api/v1/challenges` | admin | Create a challenge (a draft) with its location and medal tiers |
| `PATCH /api/v1/challenges/{id}` | admin | Edit it; `type`, `metric` and the window are frozen once anyone has joined |
| `DELETE /api/v1/challenges/{id}` | admin | Delete a draft |
| `POST /api/v1/challenges/{id}/publish`, `/unpublish` | admin | Publish (the checks in question 7) or take it down |
| `POST /api/v1/challenges/{id}/join` | user | Join. `409 overlapping_challenge` (carries the other challenge's id and title), `409 challenge_ended`, `409 already_joined`, `404 not_found` |
| `POST /api/v1/challenges/{id}/pause`, `/resume`, `/leave` | user | Act on the caller's own enrollment. `resume`: `409 overlapping_challenge`, `409 challenge_ended`, `409 not_paused`. `pause`: `409 not_active`. All: `404 not_found` when the caller is not enrolled |
| `POST /api/v1/quests`, `GET /api/v1/quests` | admin, user | Create (admin) and list quests |
| `POST /api/v1/images` | admin | Upload an image to Cloudinary; returns its URL |

Errors use the typed `ErrorResponse`. A response that nests rows (a challenge with its medals) has a fixed query count. The auth sweep, the fuzz test, the `hurl` files and the OpenAPI snapshot cover the new routes. Because the guard is on each route and not on a whole `/admin` router, the auth sweep is extended: every route must declare its requirement (public, signed-in user, or admin), a route without a declaration fails the test, and a non-admin gets `403 forbidden` on every admin route. The join runs in one transaction; when two joins race, the exclusion constraint makes the loser fail with `409 overlapping_challenge`.

### Mobile (`features/challenges`)

- **Challenges tab:** title, search field, type chips (All, Run, Swim, Cycle), and the list of challenge cards. A card: cover image, type tag with its icon, city (pin icon), title, dates (calendar icon), the goal (flag icon), the participant count (person icon), and the **Join** button, or **Joined** (or **Paused**) when the user is in it. States: loading, empty, error with retry, offline. Cursor paging.
- **Detail** (`/challenges/:id`, ID only), laid out like the Figma frame `Challenge - Join Challenge - Countdown` (node `20:51` in the StrideQuest file): a full-bleed cover with the back button and a menu on it and a goal badge on its corner; a line with the type (run, swim or cycle icon), the mode (solo) and the place (pin icon); the title in large type; the dates; a countdown card on the dark gradient surface with four tiles (days, hours, minutes, seconds), titled "Challenge starts" before the start date and "Challenge ends in" while it is open (hidden once it has ended); a details card with icon rows (dates, goal as steps or distance, Terms and Conditions that expands); the Participants row; the three medal checkpoints as tiles; the "Challenge rules" card (About, as Markdown); and a fixed action bar: **Join** (disabled, with the reason, when it is blocked or ended); **Pause** and **Leave** when active; **Resume** and **Leave** when paused. Leave asks for confirmation.
- **Icons:** one set of outline icons (type, mode, participants, place, dates, days left, goal, terms, medals) in Lime on the dark surface, used on the card and the detail. They come from Flutter's built-in icons or from SVGs in the design file, so no icon package is added.
- **About and Terms** are Markdown rendered without HTML, so a challenge's text cannot inject markup.
- **Images** load from Cloudinary URLs that ask for the size and format the screen needs (`f_auto,q_auto,w_<width>`) and are cached on the device.
- The Active, Medals and Profile tabs are unchanged.

### Cloudinary (replaces S3 and SeaweedFS)

Code and rules: remove `s3_endpoint_url` and `s3_bucket` from the settings and the S3 variables from `.env.example`; remove the SeaweedFS service from `docker-compose.yml`; add `app/core/storage.py` (the Cloudinary client, run off the event loop) and a function that builds delivery URLs in one place; record the decision in a new ADR; update `CLAUDE.md`, `README.md` and `docs/architecture.md`.

The user's setup, which needs no code change:

1. Create a Cloudinary account (the free plan is enough to start) and note the **cloud name**.
2. Create folders `stridequest/challenges/covers` and `stridequest/challenges/medals`.
3. Uploads are **signed and made by the backend only**; no unsigned preset is created. The mobile app never uploads.
4. Put the credentials in the root `.env` (never committed): `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, and optionally `CLOUDINARY_FOLDER` (the base folder, default `stridequest`). `.env.example` already has these names with placeholder values (added with this plan). The backend settings ignore unknown variables, so the user can fill them in right now without breaking anything; the backend starts reading them in the Cloudinary issue (issue 2).
5. Strict transformations are optional; without them the on-the-fly `w_`, `f_auto`, `q_auto` parameters work as they are.
6. Check the plan's quota (storage and monthly credits) before the first bulk upload, and keep the originals of every image outside Cloudinary.
7. The database stores the delivery URL (`https://res.cloudinary.com/<cloud>/image/upload/...`), as it did for object storage.

### Demo data

So the screens and the join rules can be tried, three challenges with covers and medals (plus an optional fourth that only exists to show the blocked state) are **created through the create API**, not inserted in the database. They are loaded by `backend/hurl/demo_challenges.hurl` (or a small script that calls the same routes) after the user has set the Cloudinary credentials and made an admin; issue 10 builds it. Covers and medal images are **original artwork generated for the project** (gradients, route lines and a type glyph; no third-party images), kept as PNG files under `backend/demo/images/` and uploaded through `POST /images`.

| # | Title | Type, goal | Place | Window | Medals (bronze, silver, gold) |
| --- | --- | --- | --- | --- | --- |
| 1 | Old Quarter 50K Steps | run, 50,000 steps | Hà Nội, Hồ Hoàn Kiếm | 2026-10-01 to 2026-10-31 (open) | 20,000, 35,000, 50,000 steps |
| 2 | Mỹ Khê Bay 20 km | swim, 20 km | Đà Nẵng, Bãi biển Mỹ Khê | 2026-11-01 to 2026-11-30 (upcoming) | 5 km, 12 km, 20 km |
| 3 | Sài Gòn Riverside 100 km Ride | cycle, 100 km | TP. Hồ Chí Minh, Landmark 81 | 2026-10-10 to 2026-12-10 (open) | 30 km, 65 km, 100 km |
| 4 (optional) | Hanoi Autumn 30K Steps | run, 30,000 steps | Hà Nội | 2026-10-15 to 2026-11-15 (overlaps challenge 1) | 10,000, 20,000, 30,000 steps |

The covers and medals are generated by one script, so the demo can be rebuilt and the dates moved when they pass.

### Documents and rules that change

`docs/architecture.md` (data model, modules, storage), a new ADR for Cloudinary, `docs/adr/0002-cross-module-reads.md` (a challenge now nests a list of medals), `README.md`, `.env.example` and `CLAUDE.md` (the Data bullet and the admin role), `docs/api/auth.md` (the `forbidden` code and the role), `docker-compose.yml`.

### Flags for the approval

This plan **changes the public API and the database schema** (new columns and tables, an exclusion constraint, a Postgres extension, a real foreign key), adds **authorization** (an admin role, role-guarded routes on the shared resources, a first-admin script), changes a **core technology** (images move from S3-compatible storage to Cloudinary, and S3 and SeaweedFS are removed) and has an **external cost** (Cloudinary plan limits). The approval covers all of these.

## Risks

- **Overlap races:** two joins at once could both pass a service check. Mitigation: the exclusion constraint is the guard; a concurrency test proves one wins.
- **`btree_gist` in production:** managed PostgreSQL services usually allow it, but it must be checked. Fallback if not: a per-user-and-type advisory lock in the join transaction plus the service check.
- **Frozen windows:** the enrollment holds a copy of the challenge's window, so changing a published challenge's window after someone joined would break the guarantee. The admin API refuses it.
- **Role guards on shared paths:** a privilege escalation or an unguarded write route would be serious, and a guard on each route is easier to forget than one on a whole `/admin` router. Mitigation: no endpoint creates an admin, every route declares its requirement and the auth sweep fails on one that does not, and tests cover 401, 403 and success for each admin route.
- **Uploads:** size, type and content checks on the server, a Cloudinary upload off the event loop, and no secrets in logs.
- **Clock and time zones:** windows are stored in UTC; screens show local time. "Ended" means `now >= ends_at` on the server clock.
- **Cloudinary lock-in and quota:** URLs in the database point to one vendor. Mitigation: only URLs are stored, keep originals elsewhere, build URLs in one function.
- **Rich text:** Markdown only, no raw HTML, links open outside the app.
- **Copyright:** the reference screenshots are not committed and their content is not reused.
- **Later plan:** `finished`, `expired`, progress and the sample tables are left for it, so it will need its own migration.

## Verification

- **Backend:** `pytest` (unit, integration against the docker-compose database), `ruff`, `mypy`; `alembic upgrade head`, `downgrade`, `upgrade` for each migration with the table definition; per route, the calls with request, status and body for the success and each documented error, as a `.hurl` file replayed by `backend/hurl/run.sh`; `pytest -m fuzz`; the auth sweep (every route declares public, user or admin; non-admins get `403` on the admin routes); query-count tests for the nested responses. Overlap tests: a challenge starting after another ends can be joined (the 10/9 example), an overlapping one cannot, a boundary that only touches is allowed, a paused enrollment does not block, resume fails while another overlaps, an ended challenge cannot be joined. A concurrency test: two overlapping joins in parallel, one wins. Cloudinary is mocked in the tests; the real upload is checked by hand once the user has set the credentials, otherwise `Not verified`.
- **Mobile:** widget tests per state at both phone sizes and text scales 1.0 and 2.0 (`pumpScreen`, `expectAccessible`), goldens, bloc tests, router tests, and an `integration_test` against the local backend with challenges created through `POST /challenges` as an admin (browse, search, filter, open, join, Joined in the list, Pause, Resume, Leave, the blocked message).
- **Design:** each screen is compared with its Figma frame on the simulator.

## Ticket evidence

- Screens: the Figma frames drawn in issue 1 and approved by the user. Until then no screen issue starts. The visual reference for the detail screen is the Figma frame `Challenge - Join Challenge - Countdown` (node `20:51`); issue 1 builds the StrideQuest frames from it.
- Backend: the sample requests and responses are in `docs/api/challenges.md` and `docs/api/examples/`, written with issues 5, 6 and 7.
- Reference: the five screenshots the user sent in chat (not committed).

## Issues to create

Order and dependencies matter.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `docs: draw the challenge list and detail screens in Figma` | design | - [ ] Frames: list (loading, empty, error, search and filter), detail (open, joined, paused, ended, blocked by an overlapping challenge), the Leave confirmation. - [ ] Text and color styles reused. - [ ] The user approves the frames | none |
| 2 | `chore: replace S3 and SeaweedFS with Cloudinary` | backend | - [ ] ADR 0003; settings, `.env.example` and `docker-compose.yml` no longer have S3 or SeaweedFS. - [ ] `core/storage.py` and the URL builder, with tests (Cloudinary mocked). - [ ] `CLAUDE.md`, `README.md`, `architecture.md` updated; the setup checklist is in the README | none |
| 3 | `feat: add an admin role and a role guard for routes (backend)` | backend | - [ ] Migration for `users.role`; `require_admin` returns `403 forbidden` for others. - [ ] `python -m app.scripts.create_admin`. - [ ] `docs/api/auth.md` updated. - [ ] The auth sweep makes every route declare public, user or admin, and tests cover 401, 403 and success | none |
| 4 | `feat: challenge catalog data model (backend)` | backend | - [ ] Migration for `challenges` and `medals` (type, metric, target, location, status, three tiers), up and down tested. - [ ] Models, repositories and services with unit and integration tests | none |
| 5 | `feat: create, edit, publish and delete challenges, quests and image upload (backend)` | backend | - [ ] The admin routes of the API table in `docs/api/challenges.md`, examples and `openapi.json`. - [ ] Create, edit (with the frozen fields), delete (drafts), publish and unpublish with the checks of question 7; quests create and list; image upload with size and type limits. - [ ] Non-admins get `403`; auth sweep, fuzz and `hurl` evidence | 2, 3, 4 |
| 6 | `feat: challenge list and detail endpoints (backend)` | backend | - [ ] `docs/api/challenges.md` (the user routes), examples and `openapi.json`. - [ ] `GET /challenges` (type, search, cursor) and `GET /challenges/{id}` with checkpoints, participant count, the caller's enrollment and `blocked_by`; drafts only for admins. - [ ] Auth sweep, query-count, fuzz and `hurl` evidence | 3, 4 |
| 7 | `feat: join, pause, resume and leave with the overlap rule (backend)` | backend | - [ ] Migration for `runs` (status, joined_at, type and window copy, real user FK, unique per user and challenge, exclusion constraint). - [ ] The four endpoints with the documented errors. - [ ] The overlap and concurrency tests of the Verification section; contract, `hurl` and fuzz evidence | 6 |
| 8 | `feat: Challenges tab list and challenge detail (mobile)` | frontend | - [ ] List with search and type chips, cards, Joined or Paused, all states, paging. - [ ] Detail with the three medal checkpoints, Terms and About. - [ ] Page, golden, bloc and flow tests; both phone sizes and text scales | 1, 6 |
| 9 | `feat: Join, Pause, Resume and Leave (mobile)` | frontend | - [ ] The action bar states and the blocked reason; Leave confirmation; the message when a join is refused. - [ ] Tests, and an `integration_test` against the local backend with challenges created through the admin API | 7, 8 |
| 10 | `chore: demo challenges with covers and medals, created through the API` | backend | - [ ] A script generates the original cover and medal PNGs under `backend/demo/images/`. - [ ] `backend/hurl/demo_challenges.hurl` (or a script) creates the demo challenges of the Demo data section through `POST /images` and `POST /challenges` and publishes them. - [ ] Re-running it does not create duplicates; the README says how to run it. - [ ] Needs the Cloudinary credentials: `Not verified` against Cloudinary until the user has set them | 5 |

## Next plan

A later plan (002), to be written when this one is done, covers doing a challenge: how progress is counted (steps from health data for run; device workouts for swim and cycle), what a pause does to progress, finishing, awarding the three medals, the Active and Medals tabs, health permissions and anti-cheat rules. The web admin is another plan.
