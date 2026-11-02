# Backend decisions and gotchas: auth

Loaded through `backend/CLAUDE.md`, with every `backend/decisions/<area>.md`, whenever Claude works on files under `backend/` ([plan 019](../../docs/plans/019-area-autopilot.md), [plan 037](../../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `backend/decisions/<area>.md`; another area could meet it: `backend/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `backend/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- A `/run-tasks` child session adds its own entries in its issue's last commit, lists them under `## Decisions added` in its PR, and keeps the entries of both branches when it merges `develop`. The parent never edits this file ([plan 037](../../docs/plans/037-decisions-per-area.md)).

## Entries

- **2026-11-02, #252.** Sign in revokes every refresh token of the user and moves `users.session_started_at` under the refresh-token lock, with the clock read after the lock (a token a waiting refresh issued is older). A test or hurl flow that signs in again must refresh with the latest sign-in's token.
- **2026-11-02, #271.** `refresh` reads the revoked token with `session_started_at` in a statement after `lock_refresh_token_owner`, never in the lock query: under READ COMMITTED that query's snapshot predates its lock wait, so it would miss the sign-in it waited for and answer `invalid_refresh_token` instead of `session_replaced`.
