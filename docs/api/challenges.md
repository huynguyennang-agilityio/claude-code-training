# Challenges API contract

The contract of the challenge routes. It grows with the plan in [`docs/plans/001-challenges.md`](../plans/001-challenges.md): this version holds the rules the data and the services already enforce and the error codes they raise; the routes, their request and response bodies and examples are added with the issues that build them (create, edit and publish; list and detail; join, pause, resume and leave).

Errors use the `ErrorResponse` of [`auth.md`](auth.md), and the codes of that file (`validation_error`, `not_authenticated`, `forbidden`, ...) apply here too.

## Field rules

| Field | Rule |
| --- | --- |
| `title` | 1 to 120 characters after trimming. |
| `type` | `run`, `swim` or `cycle`. |
| `metric` | Not sent: it follows the type. `steps` for a run, `distance_m` (metres) for a swim or a ride. |
| `target_value` | A whole number from 1 to 10,000,000: steps for a run, metres for a swim or a ride. |
| `starts_at`, `ends_at` | ISO 8601 with a timezone. `ends_at` is after `starts_at`. |
| `description_md`, `terms_md` | Markdown, at most 20,000 characters each. Shown without HTML. |
| `cover_image_url` | A `http(s)` URL (a Cloudinary delivery URL), or none. |
| `city`, `landmark` | 1 to 120 characters after trimming, or none. |
| `quest_id` | An existing quest. Without it the challenge goes to the default quest. |
| `medals` | At most three, one per tier (`bronze`, `silver`, `gold`). Each has a `name` (1 to 120 characters), an `image_url` and a `threshold_value` (1 to 10,000,000, the steps or metres at which it is earned). A higher tier asks for more than the tier below, no medal asks for more than `target_value`, and the gold medal, when there is one, is earned at `target_value`. |

A new challenge is a **draft**. Only a **published** challenge is shown to users; a draft answers `challenge_not_found` to anyone but an admin. To publish, a draft needs a cover image, a description, at least one medal and an `ends_at` in the future. Only a draft can be deleted.

## Error codes

| HTTP | `code` | When |
| --- | --- | --- |
| 404 | `challenge_not_found` | No challenge has that id, or it is a draft and the caller is not an admin. |
| 404 | `quest_not_found` | The `quest_id` of a new challenge matches no quest. |
| 409 | `challenge_not_publishable` | A draft is missing something it needs to be published. The message lists what. |
| 409 | `challenge_not_draft` | Only a draft can be deleted; a published challenge must be unpublished first. |
