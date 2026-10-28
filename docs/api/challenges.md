# Challenges API contract

The contract of the challenge routes. It grows with the plan in [`docs/plans/001-challenges.md`](../plans/001-challenges.md): this version holds the routes that read the catalog (list, detail) and the admin routes that write it (create, edit, publish, delete, quests, image upload), the rules they enforce and the error codes they raise. Join, pause, resume and leave (the caller's own enrollment) close the contract.

Every JSON example is also a file in `docs/api/examples/challenges/`; the `<!-- example: ... -->` comment above each block names it.

Errors use the `ErrorResponse` of [`auth.md`](auth.md), and the codes of that file (`validation_error`, `not_authenticated`, `forbidden`, ...) apply here too.

## Field rules

| Field | Rule |
| --- | --- |
| `title` | 1 to 120 characters after trimming, on one line (no control characters). |
| `type` | `run`, `swim` or `cycle`. |
| `metric` | Not sent: it follows the type. `steps` for a run, `distance_m` (metres) for a swim or a ride. |
| `target_value` | A whole number from 1 to 10,000,000: steps for a run, metres for a swim or a ride. |
| `starts_at`, `ends_at` | ISO 8601 text with a timezone (a number is refused). `ends_at` is after `starts_at`. |
| `description_md`, `terms_md` | Markdown, at most 20,000 characters each, line breaks allowed but no NUL character. Shown without HTML. |
| `cover_image_url` | A `http(s)` URL (a Cloudinary delivery URL), or none. |
| `city`, `landmark` | 1 to 120 characters after trimming, on one line, or none. |
| `quest_id` | An existing quest. Without it the challenge goes to the default quest. |
| `medals` | At most three, one per tier (`bronze`, `silver`, `gold`). Each has a `name` (1 to 120 characters, on one line), an `image_url` and a `threshold_value` (1 to 10,000,000, the steps or metres at which it is earned). A higher tier asks for more than the tier below, no medal asks for more than `target_value`, and the gold medal, when there is one, is earned at `target_value`. |

A new challenge is a **draft**. Only a **published** challenge is shown to users; a draft answers `challenge_not_found` to anyone but an admin. To publish, a draft needs a cover image, a description, at least one medal and an `ends_at` in the future. Only a draft can be deleted, and not one that people have joined.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| `GET` | `/api/v1/challenges` | access token | List the published challenges |
| `GET` | `/api/v1/challenges/{challenge_id}` | access token | Read one challenge |
| `POST` | `/api/v1/challenges/{challenge_id}/join` | access token | Join a challenge |
| `POST` | `/api/v1/challenges/{challenge_id}/pause` | access token | Pause the challenge you joined |
| `POST` | `/api/v1/challenges/{challenge_id}/resume` | access token | Resume a paused challenge |
| `POST` | `/api/v1/challenges/{challenge_id}/leave` | access token | Leave the challenge |
| `POST` | `/api/v1/challenges` | admin | Create a draft challenge |
| `PATCH` | `/api/v1/challenges/{challenge_id}` | admin | Edit a challenge |
| `DELETE` | `/api/v1/challenges/{challenge_id}` | admin | Delete a draft |
| `POST` | `/api/v1/challenges/{challenge_id}/publish` | admin | Publish a draft |
| `POST` | `/api/v1/challenges/{challenge_id}/unpublish` | admin | Take a challenge back to draft |
| `POST` | `/api/v1/quests` | admin | Create a quest |
| `GET` | `/api/v1/quests` | access token | List the quests |
| `POST` | `/api/v1/images` | admin | Upload a cover or a medal image |

`challenge_id` is a whole number from 1 to 2,147,483,647; any other value answers `422 validation_error`. A caller without a token gets `401 not_authenticated`; a signed-in caller who is not an admin gets `403 forbidden` on an admin route.

### List the challenges

`GET /api/v1/challenges` answers `200` with a `ChallengePage`: the published challenges, oldest first, as the cards of the Challenges tab.

| Query | Rule |
| --- | --- |
| `type` | `run`, `swim` or `cycle`: only that type. |
| `q` | At most 100 characters on one line. Matches the title, the city and the landmark, ignoring case (accents count as typed); `%` and `_` are plain text. |
| `status` | `published` (the default) or `draft`. Only an admin may ask for `draft`; anyone else gets `403 forbidden`. |
| `limit` | 1 to 50, default 20. |
| `cursor` | The `next_cursor` of the previous page. Leave it out for the first page. A value that is not one answers `422 invalid_cursor`. |

`next_cursor` is `null` on the last page, so the app stops without asking for an empty one. The cursor is opaque: the app must not read or build it.

Each card has `participant_count`, how many users are in it (active or paused; someone who left is not counted), and `enrollment`, the caller's own place in the challenge (`status` `active`, `paused` or `left`, and `joined_at`) or `null` when they have not joined.

<!-- example: challenges/challenge_page.json -->
```json
{
  "items": [
    {
      "id": 7,
      "title": "Hoan Kiem 50K Steps",
      "type": "run",
      "metric": "steps",
      "target_value": 50000,
      "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
      "city": "Hanoi",
      "landmark": "Hoan Kiem Lake",
      "status": "published",
      "starts_at": "2026-11-01T00:00:00Z",
      "ends_at": "2026-11-30T23:59:59Z",
      "participant_count": 813,
      "enrollment": null
    },
    {
      "id": 9,
      "title": "My Khe Bay 20 km",
      "type": "swim",
      "metric": "distance_m",
      "target_value": 20000,
      "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/my-khe.jpg",
      "city": "Da Nang",
      "landmark": "My Khe Beach",
      "status": "published",
      "starts_at": "2026-11-01T00:00:00Z",
      "ends_at": "2026-12-15T23:59:59Z",
      "participant_count": 0,
      "enrollment": null
    }
  ],
  "next_cursor": "OQ"
}
```

<!-- example: challenges/error_invalid_cursor.json -->
```json
{
  "error": {
    "code": "invalid_cursor",
    "message": "The cursor is not valid."
  }
}
```

### Read a challenge

`GET /api/v1/challenges/{challenge_id}` answers `200` with a `ChallengeDetail`: every field of a `Challenge`, with the medals as the checkpoints (bronze, silver, gold, up to three), plus `participant_count`, `enrollment` as above and `blocked_by`. `blocked_by` is the `{id, title}` of the challenge the caller is active in that overlaps this one in time and so stops them joining it (or resuming it, when it is paused), or `null`. It is `null` for a challenge the caller is active in.

A draft answers `404 challenge_not_found` to anyone but an admin, as if it did not exist.

<!-- example: challenges/challenge_detail.json -->
```json
{
  "id": 7,
  "quest_id": 1,
  "title": "Hoan Kiem 50K Steps",
  "type": "run",
  "metric": "steps",
  "target_value": 50000,
  "mode": "solo",
  "description_md": "Walk or run 50,000 steps around the lake.",
  "terms_md": "Steps are counted from Apple Health or Health Connect.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "city": "Hanoi",
  "landmark": "Hoan Kiem Lake",
  "status": "published",
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-11-30T23:59:59Z",
  "medals": [
    {
      "id": 12,
      "tier": "bronze",
      "name": "Lake Walker",
      "threshold_value": 20000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/bronze.png"
    },
    {
      "id": 13,
      "tier": "gold",
      "name": "Lake Master",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/gold.png"
    }
  ],
  "participant_count": 813,
  "enrollment": null,
  "blocked_by": null
}
```

### Join, pause, resume and leave

All four act on the **caller's own** enrollment and answer `200` with the `ChallengeDetail` as the caller now sees it, so the app redraws from the answer. Nobody can reach another user's enrollment: a caller who is not in the challenge gets `404 enrollment_not_found` from `pause`, `resume` and `leave`.

| Route | What it does | Errors |
| --- | --- | --- |
| `join` | Enroll in a published challenge, also before it starts, until it ends (`now < ends_at`). Someone who left joins again on the same enrollment. | `404 challenge_not_found` (unknown or a draft), `409 challenge_ended`, `409 already_joined` (active or paused), `409 overlapping_challenge` |
| `pause` | Active to paused. A paused challenge frees its slot for another challenge of the type. Only after the challenge has started: before `starts_at` there is nothing to pause (the user can leave instead). | `404 enrollment_not_found`, `409 not_active`, `409 challenge_not_started` |
| `resume` | Paused to active. | `404 enrollment_not_found`, `409 not_paused`, `409 challenge_ended`, `409 overlapping_challenge` |
| `leave` | Active or paused to left; the enrollment is no longer shown. | `404 enrollment_not_found` |

**The overlap rule.** A user can't be *active* in two challenges of the same `type` whose windows overlap. A window is `[starts_at, ends_at)`, so a challenge that starts at the instant another ends is fine, and a challenge of another type is never in the way. Only `active` enrollments count: a paused one does not block, but resuming it is refused (`overlapping_challenge`) while another active challenge overlaps it. The database enforces the rule, so two joins at once cannot both succeed: the loser gets `409 overlapping_challenge` too. The message names the other challenge; the same `{id, title}` is `blocked_by` in the detail, which the app uses to disable the Join button before the user taps it.

<!-- example: challenges/challenge_detail_joined.json -->
```json
{
  "id": 7,
  "quest_id": 1,
  "title": "Hoan Kiem 50K Steps",
  "type": "run",
  "metric": "steps",
  "target_value": 50000,
  "mode": "solo",
  "description_md": "Walk or run 50,000 steps around the lake.",
  "terms_md": "Steps are counted from Apple Health or Health Connect.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "city": "Hanoi",
  "landmark": "Hoan Kiem Lake",
  "status": "published",
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-11-30T23:59:59Z",
  "medals": [
    {
      "id": 12,
      "tier": "bronze",
      "name": "Lake Walker",
      "threshold_value": 20000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/bronze.png"
    },
    {
      "id": 13,
      "tier": "gold",
      "name": "Lake Master",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/gold.png"
    }
  ],
  "participant_count": 814,
  "enrollment": {
    "status": "active",
    "joined_at": "2026-10-20T08:30:00Z"
  },
  "blocked_by": null
}
```

<!-- example: challenges/challenge_detail_blocked.json -->
```json
{
  "id": 7,
  "quest_id": 1,
  "title": "Hoan Kiem 50K Steps",
  "type": "run",
  "metric": "steps",
  "target_value": 50000,
  "mode": "solo",
  "description_md": "Walk or run 50,000 steps around the lake.",
  "terms_md": "Steps are counted from Apple Health or Health Connect.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "city": "Hanoi",
  "landmark": "Hoan Kiem Lake",
  "status": "published",
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-11-30T23:59:59Z",
  "medals": [
    {
      "id": 12,
      "tier": "bronze",
      "name": "Lake Walker",
      "threshold_value": 20000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/bronze.png"
    },
    {
      "id": 13,
      "tier": "gold",
      "name": "Lake Master",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/gold.png"
    }
  ],
  "participant_count": 813,
  "enrollment": null,
  "blocked_by": {
    "id": 4,
    "title": "September 30K Steps"
  }
}
```

<!-- example: challenges/error_overlapping_challenge.json -->
```json
{
  "error": {
    "code": "overlapping_challenge",
    "message": "You are already in “September 30K Steps”, which runs at the same time as this challenge. Finish, pause or leave it to join this one."
  }
}
```

### Create a challenge

`POST /api/v1/challenges` answers `201` with the new challenge, a draft. `metric`, `mode` and `status` are never sent.

<!-- example: challenges/challenge_create_request.json -->
```json
{
  "title": "Hoan Kiem 50K Steps",
  "type": "run",
  "target_value": 50000,
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-11-30T23:59:59Z",
  "description_md": "Walk or run 50,000 steps around the lake.",
  "terms_md": "Steps are counted from Apple Health or Health Connect.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "city": "Hanoi",
  "landmark": "Hoan Kiem Lake",
  "medals": [
    {
      "tier": "bronze",
      "name": "Lake Walker",
      "threshold_value": 20000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/bronze.png"
    },
    {
      "tier": "gold",
      "name": "Lake Master",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/gold.png"
    }
  ]
}
```

The response is a `Challenge`:

<!-- example: challenges/challenge.json -->
```json
{
  "id": 7,
  "quest_id": 1,
  "title": "Hoan Kiem 50K Steps",
  "type": "run",
  "metric": "steps",
  "target_value": 50000,
  "mode": "solo",
  "description_md": "Walk or run 50,000 steps around the lake.",
  "terms_md": "Steps are counted from Apple Health or Health Connect.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "city": "Hanoi",
  "landmark": "Hoan Kiem Lake",
  "status": "draft",
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-11-30T23:59:59Z",
  "medals": [
    {
      "id": 12,
      "tier": "bronze",
      "name": "Lake Walker",
      "threshold_value": 20000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/bronze.png"
    },
    {
      "id": 13,
      "tier": "gold",
      "name": "Lake Master",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/medals/gold.png"
    }
  ]
}
```

A body that breaks a field rule answers `422 validation_error` with `fields`, as in `auth.md`.

### Edit a challenge

`PATCH /api/v1/challenges/{challenge_id}` takes any of the create fields; what is not sent stays. `cover_image_url`, `city` and `landmark` accept `null` to clear them; the other fields do not. When `medals` is sent it replaces all the medals. The result must still follow every field rule, so a `422 validation_error` can come from a field that was not sent (for example, changing `target_value` without moving the gold medal). A published challenge must stay publishable, so it cannot lose its cover, description or medals (`409 challenge_not_publishable`).

Once anyone has joined, `type`, `target_value`, `starts_at`, `ends_at` and `medals` are what the participants count toward, so changing them answers `409 challenge_in_use`. Sending the stored value again is not a change. Titles, texts, cover, place and quest stay editable.

<!-- example: challenges/challenge_update_request.json -->
```json
{
  "title": "Hoan Kiem Lake 50K Steps",
  "city": null
}
```

The response is the updated `Challenge`.

<!-- example: challenges/error_challenge_in_use.json -->
```json
{
  "error": {
    "code": "challenge_in_use",
    "message": "People have joined this challenge, so target_value cannot change."
  }
}
```

### Delete, publish and unpublish

- `DELETE /api/v1/challenges/{challenge_id}` answers `204` for a draft and `409 challenge_not_draft` for a published challenge.
- `POST .../publish` answers `200` with the `Challenge`, now `published`, or `409 challenge_not_publishable` when the draft lacks what publishing needs. Publishing a published challenge changes nothing.
- `POST .../unpublish` answers `200` with the `Challenge`, back to `draft`.

### Quests

`POST /api/v1/quests` takes a `title` (1 to 120 characters) and a `description` (at most 2,000, default empty) and answers `201` with a `Quest`. A quest `title` is on one line. `GET /api/v1/quests` answers `200` with a list of quests ordered by `id`.

<!-- example: challenges/quest_create_request.json -->
```json
{
  "title": "Hanoi Highlights",
  "description": "Challenges around the capital."
}
```

<!-- example: challenges/quest.json -->
```json
{
  "id": 2,
  "title": "Hanoi Highlights",
  "description": "Challenges around the capital."
}
```

### Upload an image

`POST /api/v1/images` is `multipart/form-data` with a `kind` (`covers` or `medals`) and a `file`. The file is a JPEG, PNG or WebP of at most 5 MB; the type is read from the file's first bytes, not from its name or `Content-Type`. The backend stores it in Cloudinary and answers `201` with the delivery URL to use as `cover_image_url` or a medal's `image_url`.

<!-- example: challenges/uploaded_image.json -->
```json
{
  "url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/hoan-kiem.jpg",
  "public_id": "stridequest/covers/hoan-kiem",
  "width": 1600,
  "height": 900,
  "size_bytes": 184320
}
```

### Not an admin

<!-- example: challenges/error_forbidden.json -->
```json
{
  "error": {
    "code": "forbidden",
    "message": "This action needs an admin account."
  }
}
```

## Error codes

| HTTP | `code` | When |
| --- | --- | --- |
| 404 | `challenge_not_found` | No challenge has that id, or it is a draft and the caller is not an admin. |
| 404 | `quest_not_found` | The `quest_id` of a new challenge matches no quest. |
| 409 | `challenge_not_publishable` | A draft is missing something it needs to be published. The message lists what. |
| 409 | `challenge_not_draft` | Only a draft can be deleted; a published challenge must be unpublished first. |
| 409 | `challenge_in_use` | People have joined, and the edit changes the type, the target, the window or the medals, or the delete would remove their enrollments. |
| 422 | `invalid_cursor` | The `cursor` of the list is not one the server gave. |
| 422 | `validation_error` | The body, or the challenge once the edit is applied, breaks a field rule. `fields` names each problem. |
| 413 | `image_too_large` | The image is over 5 MB. |
| 415 | `unsupported_image_type` | The file is not a JPEG, PNG or WebP. |
| 502 | `upload_failed` | Cloudinary refused or could not be reached. Try again. |
| 503 | `storage_not_configured` | The server has no Cloudinary settings. |
| 404 | `enrollment_not_found` | The caller is not in the challenge (never joined, or left). |
| 409 | `challenge_ended` | The challenge has ended (`now >= ends_at`): it can't be joined or resumed. |
| 409 | `already_joined` | The caller is already active or paused in the challenge. |
| 409 | `overlapping_challenge` | Another active challenge of the same type overlaps this one in time. The message names it. |
| 409 | `not_active` | Only an active enrollment can be paused. |
| 409 | `challenge_not_started` | The challenge has not started (`now < starts_at`), so it can't be paused. |
| 409 | `not_paused` | Only a paused enrollment can be resumed. |
