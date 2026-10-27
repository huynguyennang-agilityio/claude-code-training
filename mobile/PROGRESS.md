# Mobile progress

One line per finished task, appended at the end, in the task's last commit before its PR opens ([plan 019](../docs/plans/019-area-autopilot.md)). Use the issue number, not the PR number: the issue links to its PR through `Closes #N`, and adding a PR number later would re-run CI.

```text
- YYYY-MM-DD [area] #<issue> <issue title without the [area] prefix>. <one sentence on what changed>
```

A task that touches `backend/` too also writes a line in `backend/PROGRESS.md`. Read the end of this file with `tail -n 30`. Past 200 lines, move the older lines to `PROGRESS-archive.md`.

## Done
- 2026-10-26 [profile] #125 feat: Profile tab and settings form layout (mobile). Rebuilds the Profile tab (initials avatar, account list, Sign out), adds the three account routes and `SettingsFormLayout` with keyboard handling.
- 2026-10-26 [profile] #126 feat: profile info (mobile, mock). Adds the Profile info form (pickers, Units switch, metric storage) with its domain, data layer and `FakeProfileRemoteDataSource`, and closes the keyboard on a downward drag at the top of `SettingsFormLayout`.
- 2026-10-27 [profile] #129 feat: profile info (mobile, integration). Runs the Profile info flow against the local backend on a simulator (empty profile, every field, both unit systems, a backend 422) and adds remote data source tests; no contract drift.
- 2026-10-27 [auth] #127 feat: change email (mobile, mock). Adds the Email screen with the current password, `ChangeEmailBloc`, `AuthRepository.changeEmail` and the `userUpdated` stream that `AuthBloc` listens to.
- 2026-10-27 [auth] #128 feat: change password (mobile, mock). Adds the Password screen with `ChangePasswordBloc` and `AuthRepository.changePassword`, which stores the new token pair before reporting success, against the fake data source.
- 2026-10-27 [auth] #130 feat: change email (mobile, integration). Runs the change-email flow against the local backend on a simulator (change, sign in with the new email, 403, 409, 422, 429) and makes the page pop through GoRouter, which the AuthBloc refresh otherwise rebuilt.
