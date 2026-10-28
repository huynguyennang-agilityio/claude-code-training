# Plan 002: Challenge requests never refresh or end an expired session

Status: approved
Approved: 2026-10-18
Issues: #69

## Context

Bug found while running the app on the iOS simulator. When the stored session can no longer be used, a Challenges request neither refreshes the access token nor signs the user out. The user stays on the tab, sees "Your session has expired. Sign in again." with a Try again button, and has to sign out by hand from Profile.

This is not only about a deleted account. The same path runs when the 15-minute access token simply expires: the refresh token is still valid, but the challenge calls never use it, so every Challenges, detail, Join, Pause, Resume and Leave call fails 15 minutes after sign-in until the user signs out and in again.

### Root cause

`DioChallengeRemoteDataSource._request` sends every call with `validateStatus: (_) => true` (`mobile/lib/features/challenges/data/datasources/challenge_remote_data_source.dart:98`). Dio runs a response through the interceptors' `onError` only when `validateStatus` rejects it. With `(_) => true` a `401` arrives as a normal response, so `AuthInterceptor.onError` (refresh once and retry, or `expireSession` when the refresh token is rejected) never runs. The data source then turns the `401` body into `ChallengeFailureCode.invalidToken`, which is just a message.

`auth_interceptor_test.dart` passes because it uses a plain `dio.get`, whose default `validateStatus` does reach `onError`. Nothing tests the interceptor together with the data source that is wired to it.

The auth data source uses the same override but goes through the public client, which has no auth interceptor, so it is not affected.

### Reproduction (done on 2026-10-18)

Backend, local: sign up, delete the user, then call a protected route with the old tokens. The backend answers as `docs/api/auth.md` says:

```text
GET  /api/v1/challenges        401 {"error":{"code":"invalid_token","message":"The account no longer exists.","fields":[]}}
POST /api/v1/auth/refresh      401 {"error":{"code":"invalid_refresh_token","message":"The refresh token is unknown, expired or used.","fields":[]}}
```

App, iPhone 17 simulator, signed in and on the Challenges tab: delete the user from the database, then tap the Swim chip.

- Expected: the app refreshes, the refresh is rejected, the session ends and the router redirects to Sign in.
- Actual: the tab shows "Your session has expired. Sign in again." and Try again, and stays there.

## Open questions and assumptions

- Assumption: the backend and `docs/api/auth.md` are right and stay as they are; this is a mobile-only fix.
- Assumption: no other screen has this problem today, because the challenges data source is the only user of the authenticated client. A later data source on that client must not set `validateStatus: (_) => true`; the test below guards it for challenges only.

## Approach

Mobile only, `mobile/`:

- `challenge_remote_data_source.dart`: stop overriding `validateStatus`. A non-2xx answer then reaches the auth interceptor as a `DioException`. After the interceptor is done (refreshed and retried, or session ended) the data source reads the error body from `DioException.response` and maps it to a `ChallengeFailure` exactly as today. A `DioException` without a response, or a timeout, stays `ChallengeFailureCode.network`.
- Contract and error mapping do not change; no API, schema or dependency change.
- Touches authentication and session handling (the refresh and sign-out path), so the approval must cover that. The change makes the existing documented behaviour work; it adds no new rule.

## Risks

- A status the old code mapped now travels as a `DioException`: every failure code in `ChallengeFailure` must still come out the same. The existing data source tests cover them and are extended to run through the real interceptor.
- A refresh that fails for a reason other than a rejected token (network, rate limit) must keep the session, as `AuthInterceptor` already does; a test keeps that.

## Verification

- `flutter test test/features/challenges/data` and `test/core/network`: new tests put `DioChallengeRemoteDataSource` behind a real `AuthInterceptor` with a fake HTTP adapter:
  - an expired access token is refreshed and the request retried, and the list loads;
  - a rejected refresh token ends the session (`expireSession` is called) and the failure is returned;
  - a failed refresh that is not a rejection keeps the session;
  - every `ChallengeFailure` mapping still holds.
- `flutter analyze`, `flutter test` for the whole app.
- Bug: repeat the reproduction above on the simulator after the fix. Expected: the app lands on Sign in. Also let an access token expire (or send one signed with a wrong secret) and check the list loads after a silent refresh. If the simulator is not available, write `Not verified: <reason>`.

## Ticket evidence

`bug` ticket: steps to reproduce, expected and actual result, and the request and response log are in Context above. A screenshot of the stuck state is attached to the issue.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `fix: challenge requests do not refresh or end an expired session` | bug, frontend | - [ ] A `401` `token_expired` or `invalid_token` on any challenge call refreshes the tokens once and retries, and the user sees the result<br>- [ ] A rejected refresh token ends the session and the router redirects to Sign in<br>- [ ] A refresh that fails for another reason keeps the session and shows the original error<br>- [ ] All other `ChallengeFailure` mappings are unchanged<br>- [ ] A test runs the challenges data source behind the real `AuthInterceptor`<br>- [ ] `flutter analyze` and `flutter test` pass | none |
