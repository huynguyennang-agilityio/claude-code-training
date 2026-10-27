# Backend progress

One line per finished task, appended at the end, in the task's last commit before its PR opens ([plan 019](../docs/plans/019-area-autopilot.md)). Use the issue number, not the PR number: the issue links to its PR through `Closes #N`, and adding a PR number later would re-run CI.

```text
- YYYY-MM-DD [area] #<issue> <issue title without the [area] prefix>. <one sentence on what changed>
```

A task that touches `mobile/` too also writes a line in `mobile/PROGRESS.md`. Read the end of this file with `tail -n 30`. Past 200 lines, move the older lines to `PROGRESS-archive.md`.

## Done
- 2026-10-26 [profile] #120 docs: profile, email and password contract. Adds `docs/api/profile.md`, the email and password routes and `incorrect_password` in `docs/api/auth.md`, and their examples.
- 2026-10-26 [profile] #121 feat: GET /users/me/profile (backend). Adds the `profile` module, the `user_profiles` table and `GET /api/v1/users/me/profile`, which returns an empty profile when the user never saved one.
- 2026-10-26 [profile] #122 feat: PUT /users/me/profile (backend). Adds `PUT /api/v1/users/me/profile`, an upsert that replaces the whole profile, with every contract field rule checked as `422 validation_error`.
- 2026-10-27 [auth] #123 feat: PUT /users/me/email (backend). Adds `PUT /api/v1/users/me/email` with the current-password check, the shared sign-in rate limit, `403 incorrect_password` and `409 email_taken`.
- 2026-10-27 [auth] #124 feat: PUT /users/me/password (backend). Adds `PUT /api/v1/users/me/password`, which checks the current password like the email change, revokes every refresh token of the user and returns a new token pair.
