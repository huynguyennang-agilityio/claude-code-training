# Backend decisions and gotchas: runs

Loaded through `backend/CLAUDE.md`, with every `backend/decisions/<area>.md`, whenever Claude works on files under `backend/` ([plan 019](../../docs/plans/019-area-autopilot.md), [plan 037](../../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `backend/decisions/<area>.md`; another area could meet it: `backend/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `backend/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- A `/run-tasks` child session adds its own entries in its issue's last commit, lists them under `## Decisions added` in its PR, and keeps the entries of both branches when it merges `develop`. The parent never edits this file ([plan 037](../../docs/plans/037-decisions-per-area.md)).

## Entries

- **2026-11-02, #254.** An hour counts only from the join time, so a live replay never reaches an accepted hour. `hurl/run.sh` joins a fresh user and moves `runs.hours_from` and `users.session_started_at` back three days and `runs.counting_from` four (so a step sample before `hours_from` counts) before `step_hours.hurl`; integration tests do the same (`set_bounds` in `tests/integration/test_step_hours_api.py`).
- **2026-11-02, #255.** A join sets `hours_from` to the join time, so `POST /runs/steps` counts nothing for a fresh enrollment. A step-sync test must first move `runs.hours_from` past its samples (`count_from_long_ago` in `tests/integration/test_runs_progress_api.py`), or every sample comes back `ignored`.
