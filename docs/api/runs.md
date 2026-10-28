# Runs API contract

The contract of the routes that count progress in the challenges a user is in. It grows with the plan in [`docs/plans/003-active-tab.md`](../plans/003-active-tab.md): this version holds step sync, the list of the caller's challenges with their progress, and the daily activity summary.

Every JSON example is also a file in `docs/api/examples/runs/`; the `<!-- example: ... -->` comment above each block names it.

Errors use the `ErrorResponse` of [`auth.md`](auth.md), and the codes of that file (`validation_error`, `not_authenticated`, ...) apply here too.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| `POST` | `/api/v1/runs/steps` | access token | Sync step samples and count them toward the challenges |
| `GET` | `/api/v1/runs` | access token | The challenges the caller is in, with progress |
| `PUT` | `/api/v1/runs/daily-activity` | access token | Sync the daily health figures (steps, calories, distance, sleep) |

A caller without a token gets `401 not_authenticated`. Both routes read and change only the caller's own enrollments; another user's are never visible.

## Sync step samples

`POST /api/v1/runs/steps` counts step samples read from Apple Health or Health Connect toward the caller's **active run challenges**. A sample is one health record.

| Field | Rule |
| --- | --- |
| `samples` | 1 to 500 samples. The app sends more in several requests. |
| `health_record_id` | 1 to 128 characters, no NUL: the id of the record on the device. |
| `start_time`, `end_time` | ISO 8601 with a timezone (a number is refused). `end_time` is not before `start_time`, and a sample covers at most 24 hours. |
| `steps` | A whole number from 1 to 100,000. |

A sample counts for an enrollment when **all** of these hold:

- the enrollment is `active` (a paused or left one counts nothing);
- the challenge is a run (steps); swim and cycle count distance, which is not synced yet, so they report `tracked: false`;
- `start_time` is not before the challenge's `starts_at`, nor before the enrollment's counting time (the moment of joining or of the last resume), so steps taken while paused never count;
- `end_time` is not after the challenge's `ends_at`, nor after the server's now plus 5 minutes, so a device with a wrong clock cannot count the future;
- the same `health_record_id` was not counted before for that enrollment. A sample sent twice counts once.

A sample that fails a rule is **ignored**, not an error: the request still answers `200`.

The answer lists `accepted` (samples counted) and `ignored`, and the progress of each of the caller's active enrollments, so the app can redraw without a second request.

<!-- example: runs/step_sync_request.json -->
```json
{
  "samples": [
    {
      "health_record_id": "HK-6F1C2A90-5B1E-4D0C-9E5B-0A1F2B3C4D5E",
      "start_time": "2026-11-02T06:30:00Z",
      "end_time": "2026-11-02T07:30:00Z",
      "steps": 4120
    },
    {
      "health_record_id": "HK-0B7A9C11-2D3E-4F50-8A61-7B8C9D0E1F23",
      "start_time": "2026-11-02T07:30:00Z",
      "end_time": "2026-11-02T08:30:00Z",
      "steps": 980
    }
  ]
}
```

<!-- example: runs/step_sync_result.json -->
```json
{
  "accepted": 2,
  "ignored": 0,
  "enrollments": [
    {
      "challenge_id": 7,
      "progress": {
        "current_value": 9000,
        "target_value": 50000,
        "percent": 18,
        "tracked": true,
        "started": true
      }
    },
    {
      "challenge_id": 9,
      "progress": {
        "current_value": 0,
        "target_value": 20000,
        "percent": 0,
        "tracked": false,
        "started": false
      }
    }
  ]
}
```

## The challenges I am in

`GET /api/v1/runs` answers `200` with the caller's **active and paused** enrollments, the soonest start first, as the cards of the My Challenges tab. A challenge the caller left is not listed. A challenge that has not started yet is listed with `progress.started: false`.

| Query | Rule |
| --- | --- |
| `limit` | 1 to 50, default 20. |
| `cursor` | The `next_cursor` of the previous page. Leave it out for the first page. A value that is not one answers `422 invalid_cursor`. |

Any other query parameter answers `422 validation_error`. `next_cursor` is `null` on the last page. The cursor is opaque.

Each item has `challenge`, the same card as in [`challenges.md`](challenges.md) (including the caller's `enrollment`, `active` or `paused`), and `progress`:

| Field | Meaning |
| --- | --- |
| `current_value` | Steps counted so far; 0 when `tracked` is false. |
| `target_value` | The challenge's target. |
| `percent` | `current_value` as a whole percent of the target, at most 100. |
| `tracked` | `false` for a swim or cycle challenge: its progress is not counted yet. |
| `started` | `true` once the challenge's `starts_at` has passed. |

<!-- example: runs/my_challenge_page.json -->
```json
{
  "items": [
    {
      "challenge": {
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
        "enrollment": {
          "status": "active",
          "joined_at": "2026-10-28T09:15:00Z"
        }
      },
      "progress": {
        "current_value": 9000,
        "target_value": 50000,
        "percent": 18,
        "tracked": true,
        "started": true
      }
    },
    {
      "challenge": {
        "id": 9,
        "title": "My Khe Bay 20 km",
        "type": "swim",
        "metric": "distance_m",
        "target_value": 20000,
        "cover_image_url": "https://res.cloudinary.com/demo/image/upload/stridequest/covers/my-khe.jpg",
        "city": "Da Nang",
        "landmark": "My Khe Beach",
        "status": "published",
        "starts_at": "2026-12-01T00:00:00Z",
        "ends_at": "2026-12-15T23:59:59Z",
        "participant_count": 4,
        "enrollment": {
          "status": "paused",
          "joined_at": "2026-10-30T18:00:00Z"
        }
      },
      "progress": {
        "current_value": 0,
        "target_value": 20000,
        "percent": 0,
        "tracked": false,
        "started": false
      }
    }
  ],
  "next_cursor": null
}
```

## Sync the daily activity

`PUT /api/v1/runs/daily-activity` stores what the health data said for each calendar day, so StrideQuest has the figures the Active tab shows. It is separate from step sync: the figures do not count toward challenges.

A request has 1 to 7 days. For each day the server **replaces** the caller's row, so the call can be repeated and a figure that is left out goes back to empty. The app sends only the metrics the user allowed.

| Field | Rule |
| --- | --- |
| `date` | The calendar day on the device, as `YYYY-MM-DD` text, from 2020-01-01. The server accepts up to its own today plus one day (time zones); a later day answers `422 validation_error`. Each day appears once in a request. |
| `steps` | Optional, a whole number from 0 to 200,000. |
| `calories_kcal` | Optional, a whole number from 0 to 50,000. |
| `distance_m` | Optional, a whole number of metres from 0 to 500,000. |
| `sleep_minutes` | Optional, minutes asleep in the night that ends on this day, from 0 to 1,440. |

The answer is `200` with the stored days, oldest first, each with `updated_at`. The figures belong to the caller alone: the route reads and writes only their rows, and there is no route to read another user's. They are deleted with the account, and the server never logs them.

<!-- example: runs/daily_activity_request.json -->
```json
{
  "days": [
    {
      "date": "2026-11-02",
      "steps": 8412,
      "calories_kcal": 312,
      "distance_m": 6120,
      "sleep_minutes": 410
    },
    {
      "date": "2026-11-03",
      "steps": 5490
    }
  ]
}
```

<!-- example: runs/daily_activity_result.json -->
```json
{
  "days": [
    {
      "date": "2026-11-02",
      "steps": 8412,
      "calories_kcal": 312,
      "distance_m": 6120,
      "sleep_minutes": 410,
      "updated_at": "2026-11-03T21:55:04Z"
    },
    {
      "date": "2026-11-03",
      "steps": 5490,
      "calories_kcal": null,
      "distance_m": null,
      "sleep_minutes": null,
      "updated_at": "2026-11-03T21:55:04Z"
    }
  ]
}
```

## Error codes

| HTTP | `code` | When |
| --- | --- | --- |
| 422 | `invalid_cursor` | The `cursor` of the list is not one the server gave. |
| 422 | `validation_error` | The body or the query breaks a field rule, or a day is in the future. `fields` names each problem. |
