# Mobile decisions and gotchas: runs

Loaded through `mobile/CLAUDE.md`, with every `mobile/decisions/<area>.md`, whenever Claude works on files under `mobile/` ([plan 019](../../docs/plans/019-area-autopilot.md), [plan 037](../../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `mobile/decisions/<area>.md`; another area could meet it: `mobile/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `mobile/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- A `/run-tasks` child session adds its own entries in its issue's last commit, lists them under `## Decisions added` in its PR, and keeps the entries of both branches when it merges `develop`. The parent never edits this file ([plan 037](../../docs/plans/037-decisions-per-area.md)).

## Entries

- **2026-11-02, #262.** `RunsRepository.earliestRunJoin` is the join time; a run challenge counts steps only from `startsAt`. For "how long steps have counted", use `earliestRunCounting` (the later of the two).
- **2026-11-02, #256.** On iOS, read step hours with one `getHealthIntervalDataFromTypes(interval: 3600)` anchored at a UTC hour, not one `getTotalStepsInInterval` per hour: 30 days read in about 60 ms on an iPhone 13.
- **2026-11-02, #257.** In `SyncActivity`, only step hours start at the earliest run join; daily figures ignore the join and start at the later of the window start and `firstSyncAt`, so they are sent with no active run.
- **2026-11-02, #258.** Only `HealthSyncService` runs `SyncActivity`; screens and `ActivityBloc` use the domain `HealthSync` (`state`/`stream`/`sync(force: true)`). A session change bumps a generation so an in-flight run's result is dropped.
  Tests use `HealthSyncService.withClock`; `AppLifecycleListener` resume can't be driven from a unit test.
