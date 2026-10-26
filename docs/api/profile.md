# Profile API contract

The contract of the profile routes: the optional personal details of the signed-in user. It follows plan [`024`](../plans/024-profile-settings.md). Changing the email and the password is in [`auth.md`](auth.md).

Every JSON example is also a file in `docs/api/examples/profile/`; the `<!-- example: ... -->` comment above each block names it. Backend and app tests compare their code with those files, so change the file and the block together.

Errors use the `ErrorResponse` of [`auth.md`](auth.md), and the codes of that file (`validation_error`, `not_authenticated`, `invalid_token`, `token_expired`, ...) apply here too. This file adds no error code.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| `GET` | `/api/v1/users/me/profile` | access token | Read the caller's profile |
| `PUT` | `/api/v1/users/me/profile` | access token | Replace the caller's profile |

Both routes are for any signed-in user (the `user` level). A user only reads and writes their own profile; there is no route for another user's.

## Field rules

Every field is optional and can be `null`. The app should check these on the form before calling the API. The backend checks them again.

| Field | Rule |
| --- | --- |
| `first_name`, `last_name` | 1 to 50 characters after trimming spaces, or `null`. |
| `birthday` | An ISO 8601 date (`YYYY-MM-DD`) after 1900-01-01 and not in the future, or `null`. No minimum age. |
| `country` | An ISO 3166-1 alpha-2 code matching `^[A-Z]{2}$`, or `null`. The backend checks only the format and keeps no country list; the app ships the list. |
| `state` | Free text of at most 100 characters after trimming, or `null`. |
| `gender` | `female`, `male`, `non_binary` or `prefer_not_to_say`, or `null`. |
| `unit_system` | `imperial` or `metric`. Default `metric`. A display preference only: `height_cm` and `weight_kg` are always metric. |
| `height_cm` | A number from 50.0 to 272.0 with at most one decimal, or `null`. |
| `weight_kg` | A number from 20.0 to 400.0 with at most one decimal, or `null`. |

`display_name` (see [`auth.md`](auth.md)) is not part of the profile and is not derived from the names.

## Shared shapes

### `Profile`

Returned by both routes and sent as the body of `PUT`. The body always has the nine fields.

<!-- example: profile/profile.json -->
```json
{
  "first_name": "Max",
  "last_name": "Darsonval",
  "birthday": "1991-06-24",
  "country": "US",
  "state": "California",
  "gender": "male",
  "unit_system": "imperial",
  "height_cm": 180.3,
  "weight_kg": 84.4
}
```

## `GET /api/v1/users/me/profile`

Header: `Authorization: Bearer <access_token>`.

Responses:

- `200 OK` with `Profile`. A user who never saved a profile gets every field `null` and `unit_system` `metric`, not a `404`:

<!-- example: profile/profile_empty.json -->
```json
{
  "first_name": null,
  "last_name": null,
  "birthday": null,
  "country": null,
  "state": null,
  "gender": null,
  "unit_system": "metric",
  "height_cm": null,
  "weight_kg": null
}
```

- `401 not_authenticated`, `401 invalid_token`, `401 token_expired`.

## `PUT /api/v1/users/me/profile`

Header: `Authorization: Bearer <access_token>`.

`PUT` replaces the whole profile: send every field, and a field sent as `null` clears its value. The first save creates the profile. A field left out of the body is treated as `null` (`metric` for `unit_system`), so the app always sends all nine.

Request (`Profile`):

<!-- example: profile/profile_put_request.json -->
```json
{
  "first_name": "Max",
  "last_name": "Darsonval",
  "birthday": "1991-06-24",
  "country": "US",
  "state": "California",
  "gender": "male",
  "unit_system": "imperial",
  "height_cm": 180.3,
  "weight_kg": 84.4
}
```

Responses:

- `200 OK` with the saved `Profile`.
- `422 validation_error` when a field breaks its rule. `fields` names each one:

<!-- example: profile/error_validation.json -->
```json
{
  "error": {
    "code": "validation_error",
    "message": "Request is invalid.",
    "fields": [
      { "field": "country", "message": "Country must be a two-letter code in capitals." },
      { "field": "height_cm", "message": "Height must be between 50.0 and 272.0 cm." }
    ]
  }
}
```

- `401 not_authenticated`, `401 invalid_token`, `401 token_expired`.

The profile holds personal data. It is only readable with the owner's access token, it is never logged, and it is deleted with the user.

## Out of scope for the MVP

- An avatar image.
- Exporting or deleting the profile apart from the account.
- A state list per country.
