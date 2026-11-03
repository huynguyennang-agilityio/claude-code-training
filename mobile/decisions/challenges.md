# Mobile decisions and gotchas: challenges

Loaded through `mobile/CLAUDE.md`, with every `mobile/decisions/<area>.md`, whenever Claude works on files under `mobile/` ([plan 019](../../docs/plans/019-area-autopilot.md), [plan 037](../../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `mobile/decisions/<area>.md`; another area could meet it: `mobile/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `mobile/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- A `/run-tasks` child session adds its own entries in its issue's last commit, lists them under `## Decisions added` in its PR, and keeps the entries of both branches when it merges `develop`. The parent never edits this file ([plan 037](../../docs/plans/037-decisions-per-area.md)).

## Entries

- **2026-11-02, #270.** Fixtures have fixed dates, so a test that opens `ChallengeDetailPage` through the router must pass a fixed `clock`: rebuild only the detail route in `createAppRouter(routes: ...)` (see `challenges_flow_test.dart`), never rely on `DateTime.now`.
- **2026-11-03, #264.** Challenge routes provide a `HealthNoticeBloc` (the join prompt and #265's banner read it); a test that builds them passes `notice`/`health`/`sync` to `registerChallengeBlocs`, which answers a `none` notice by default.
- **2026-11-03, #264.** To walk out through nested navigators (the list sits in a tab's navigator), use `navigator.context.findAncestorStateOfType<NavigatorState>()`: `Navigator.maybeOf(navigator.context)` returns that same navigator, so a loop on it froze the app on a join.
