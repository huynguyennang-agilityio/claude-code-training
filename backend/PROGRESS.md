# Backend progress

One line per finished task, appended at the end, in the task's last commit before its PR opens ([plan 019](../docs/plans/019-area-autopilot.md)). Use the issue number, not the PR number: the issue links to its PR through `Closes #N`, and adding a PR number later would re-run CI.

```text
- YYYY-MM-DD [area] #<issue> <issue title without the [area] prefix>. <one sentence on what changed>
```

A task that touches `mobile/` too also writes a line in `mobile/PROGRESS.md`. Read the end of this file with `tail -n 30`. Past 200 lines, move the older lines to `PROGRESS-archive.md`.

## Done
- 2026-10-26 [profile] #120 docs: profile, email and password contract. Adds `docs/api/profile.md`, the email and password routes and `incorrect_password` in `docs/api/auth.md`, and their examples.
- 2026-10-26 [profile] #121 feat: GET /users/me/profile (backend). Adds the `profile` module, the `user_profiles` table and `GET /api/v1/users/me/profile`, which returns an empty profile when the user never saved one.
