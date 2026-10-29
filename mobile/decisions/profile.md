# Mobile decisions and gotchas: profile

Loaded through `mobile/CLAUDE.md`, with every `mobile/decisions/<area>.md`, whenever Claude works on files under `mobile/` ([plan 019](../../docs/plans/019-area-autopilot.md), [plan 037](../../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `mobile/decisions/<area>.md`; another area could meet it: `mobile/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `mobile/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- Claude never edits this file while `/run-tasks` issues are in progress. Child sessions propose entries as `DECISION:` lines in their `/run-tasks` result files (and list them in the PR for reviewers), and Claude picks from the merged issues' result files after the run, in one "decisions from run" PR merged only when `claude-review` approves it.

## Entries
