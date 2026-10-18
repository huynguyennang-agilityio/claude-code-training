# Challenges API contract

The contract of the challenge routes. It grows with the plan in [`docs/plans/001-challenges.md`](../plans/001-challenges.md): this version holds the admin routes that write the catalog (create, edit, publish, delete, quests, image upload), the rules they enforce and the error codes they raise. List, detail, join, pause, resume and leave are added with the issues that build them.

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

A new challenge is a **draft**. Only a **published** challenge is shown to users; a draft answers `challenge_not_found` to anyone but an admin. To publish, a draft needs a cover image, a description, at least one medal and an `ends_at` in the future. Only a draft can be deleted.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| `POST` | `/api/v1/challenges` | admin | Create a draft challenge |
| `PATCH` | `/api/v1/challenges/{challenge_id}` | admin | Edit a challenge |
| `DELETE` | `/api/v1/challenges/{challenge_id}` | admin | Delete a draft |
| `POST` | `/api/v1/challenges/{challenge_id}/publish` | admin | Publish a draft |
| `POST` | `/api/v1/challenges/{challenge_id}/unpublish` | admin | Take a challenge back to draft |
| `POST` | `/api/v1/quests` | admin | Create a quest |
| `GET` | `/api/v1/quests` | access token | List the quests |
| `POST` | `/api/v1/images` | admin | Upload a cover or a medal image |

`challenge_id` is a whole number from 1 to 2,147,483,647; any other value answers `422 validation_error`. A caller without a token gets `401 not_authenticated`; a signed-in caller who is not an admin gets `403 forbidden` on an admin route.

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
| 409 | `challenge_in_use` | People have joined, and the edit changes the type, the target, the window or the medals. |
| 422 | `validation_error` | The body, or the challenge once the edit is applied, breaks a field rule. `fields` names each problem. |
| 413 | `image_too_large` | The image is over 5 MB. |
| 415 | `unsupported_image_type` | The file is not a JPEG, PNG or WebP. |
| 502 | `upload_failed` | Cloudinary refused or could not be reached. Try again. |
| 503 | `storage_not_configured` | The server has no Cloudinary settings. |
