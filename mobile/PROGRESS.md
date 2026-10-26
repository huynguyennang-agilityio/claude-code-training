# Mobile progress

One line per finished task, appended at the end, in the task's last commit before its PR opens ([plan 019](../docs/plans/019-area-autopilot.md)). Use the issue number, not the PR number: the issue links to its PR through `Closes #N`, and adding a PR number later would re-run CI.

```text
- YYYY-MM-DD [area] #<issue> <issue title without the [area] prefix>. <one sentence on what changed>
```

A task that touches `backend/` too also writes a line in `backend/PROGRESS.md`. Read the end of this file with `tail -n 30`. Past 200 lines, move the older lines to `PROGRESS-archive.md`.

## Done
- 2026-10-26 [profile] #125 feat: Profile tab and settings form layout (mobile). Rebuilds the Profile tab (initials avatar, account list, Sign out), adds the three account routes and `SettingsFormLayout` with keyboard handling.
