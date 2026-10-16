# Auth API contract

This is the source of truth for sign up and sign in between the Flutter app and the FastAPI backend. Change this file first, in its own merge request, before changing either side.

- Server: `http://localhost:8000` locally.
- API base: `http://localhost:8000/api/v1`. Every path below is written from the server root and already includes `/api/v1`, for example `http://localhost:8000/api/v1/auth/signin`.
- Clients that resolve relative paths, such as the app's Dio client (`createDio` in `mobile/lib/core/network/dio_client.dart`), must set their base URL to the API base, not the server.
- The `/api/v1` prefix was added in #26. Earlier versions of this contract listed the same routes without it.
- All bodies are JSON (`Content-Type: application/json`).
- Field names are `snake_case`. Timestamps are ISO 8601 in UTC, for example `2026-10-13T09:55:00Z`.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/signup` | none | Create an account and sign in |
| `POST` | `/api/v1/auth/signin` | none | Sign in with email and password |
| `POST` | `/api/v1/auth/refresh` | none (refresh token in body) | Swap a refresh token for a new token pair |
| `POST` | `/api/v1/auth/signout` | none (refresh token in body) | Revoke a refresh token |
| `GET` | `/api/v1/users/me` | access token | Read the signed-in user |

## Tokens

- **Access token:** a JWT, valid for 15 minutes. Send it on protected routes as `Authorization: Bearer <access_token>`. The app must treat it as opaque and must not read its claims.
- **Refresh token:** an opaque random string, valid for 30 days. Send it only to `/api/v1/auth/refresh` and `/api/v1/auth/signout`.
- **Rotation:** every successful refresh returns a new refresh token and revokes the old one. Store the new pair and discard the old one. Using a revoked refresh token returns `401 invalid_refresh_token`.
- Store both tokens in secure storage (Keychain or Keystore), never in plain preferences.
- When a protected route returns `401` with `token_expired` or `invalid_token`, call `/api/v1/auth/refresh` once and retry the request. If the refresh fails, clear the tokens and go to Sign in.

Lifetimes are configurable on the backend (`ACCESS_TOKEN_TTL_MINUTES`, `REFRESH_TOKEN_TTL_DAYS`). Use `expires_in` from the response instead of hard-coding 15 minutes.

## Field rules

The app should check these on the form before calling the API. The backend checks them again.

| Field | Rule |
| --- | --- |
| `email` | A valid email address, at most 254 characters. Case-insensitive: the backend stores it lowercase. |
| `password` | 8 to 128 characters, with at least one letter and one digit. |
| `display_name` | 1 to 50 characters after trimming spaces. |

## Shared shapes

### `TokenPair`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "kq3Vh0b0yQyF2m7...",
  "token_type": "bearer",
  "expires_in": 900
}
```

`expires_in` is the access token lifetime in seconds.

### `User`

```json
{
  "id": "6f1c2b3a-8d4e-4f5a-9b6c-7d8e9f0a1b2c",
  "email": "runner@example.com",
  "display_name": "Lan Runner",
  "created_at": "2026-10-13T09:55:00Z"
}
```

### `AuthResponse`

Returned by sign up and sign in.

```json
{
  "user": { "...": "User" },
  "tokens": { "...": "TokenPair" }
}
```

### `ErrorResponse`

Every error, including validation errors, has this shape. Branch on `error.code`, never on `message`: the message is for logs and may change.

```json
{
  "error": {
    "code": "invalid_credentials",
    "message": "Email or password is incorrect.",
    "fields": []
  }
}
```

`fields` is only filled for `validation_error`. Each item names the field and why it failed:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Request is invalid.",
    "fields": [
      { "field": "password", "message": "Password must contain at least one digit." }
    ]
  }
}
```

## Error codes

| HTTP | `code` | When |
| --- | --- | --- |
| 422 | `validation_error` | The body is missing a field or breaks a field rule. See `fields`. |
| 409 | `email_taken` | Sign up with an email that already has an account. |
| 401 | `invalid_credentials` | Sign in with a wrong email or a wrong password. Both cases return the same code on purpose. |
| 401 | `invalid_refresh_token` | Refresh with a token that is unknown, expired or already revoked. |
| 401 | `not_authenticated` | A protected route was called without an `Authorization` header. |
| 401 | `invalid_token` | The access token is malformed, has a bad signature, or its user no longer exists. |
| 401 | `token_expired` | The access token has expired. Refresh and retry. |
| 429 | `rate_limited` | Too many failed sign-ins for this email or device. Wait for the number of seconds in the `Retry-After` header. |

## `POST /api/v1/auth/signup`

Request:

```json
{
  "email": "runner@example.com",
  "password": "run4medals",
  "display_name": "Lan Runner"
}
```

Responses:

- `201 Created` with `AuthResponse`.
- `409 email_taken`, `422 validation_error`.

## `POST /api/v1/auth/signin`

Request:

```json
{
  "email": "runner@example.com",
  "password": "run4medals"
}
```

Responses:

- `200 OK` with `AuthResponse`.
- `401 invalid_credentials`, `422 validation_error`, `429 rate_limited`.

Sign in is rate limited: after 5 failed attempts for the same email within 15 minutes, or 20 failed attempts from the same IP within 15 minutes, it returns `429` until the window passes, even with the right password. A successful sign-in clears the count for that email.

## `POST /api/v1/auth/refresh`

Request:

```json
{
  "refresh_token": "kq3Vh0b0yQyF2m7..."
}
```

Responses:

- `200 OK` with `TokenPair` (a new access token and a new refresh token).
- `401 invalid_refresh_token`, `422 validation_error`.

## `POST /api/v1/auth/signout`

Request:

```json
{
  "refresh_token": "kq3Vh0b0yQyF2m7..."
}
```

Responses:

- `204 No Content`. Also returned when the token is unknown or already revoked, so signing out twice is safe.
- `422 validation_error`.

The access token stays valid until it expires (at most 15 minutes). The app should delete both tokens locally when signing out.

## `GET /api/v1/users/me`

Header: `Authorization: Bearer <access_token>`.

Responses:

- `200 OK` with `User`.
- `401 not_authenticated`, `401 invalid_token`, `401 token_expired`.

## Out of scope for the MVP

- Sign in with Apple or Google.
- Password reset by email.
- Email verification.
