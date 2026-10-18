# The admin routes of docs/api/challenges.md, replayed against a running server.
#
#   backend/hurl/run.sh [base_url]
#
# run.sh signs up two accounts, makes one of them an admin with
# `python -m app.scripts.create_admin`, and passes their tokens in. It leaves
# a quest in the database; the challenges it makes are deleted at the end. A successful image upload is not
# replayed: it would store a file in Cloudinary. The integration tests cover it with a
# fake storage; here only the refusals run.
# Variables: base (the API base), admin_token, user_token, title (unique per run).

# Not signed in
POST {{base}}/challenges
{}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# A normal user is forbidden
POST {{base}}/challenges
Authorization: Bearer {{user_token}}
{}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "forbidden"

# A quest
POST {{base}}/quests
Authorization: Bearer {{admin_token}}
{
  "title": "{{title}}",
  "description": "Created by hurl."
}
HTTP 201
[Captures]
quest_id: jsonpath "$.id"
[Asserts]
jsonpath "$.title" == "{{title}}"

GET {{base}}/quests
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id == {{quest_id}})].title" == "{{title}}"

# Create a draft challenge
POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "quest_id": {{quest_id}},
  "title": "{{title}}",
  "type": "run",
  "target_value": 50000,
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2099-01-01T00:00:00Z",
  "description_md": "Walk or run 50,000 steps.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
  "medals": [
    {
      "tier": "gold",
      "name": "Gold",
      "threshold_value": 50000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg"
    }
  ]
}
HTTP 201
[Captures]
challenge_id: jsonpath "$.id"
[Asserts]
jsonpath "$.status" == "draft"
jsonpath "$.metric" == "steps"
jsonpath "$.mode" == "solo"
jsonpath "$.medals" count == 1

# validation_error names every broken rule
POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "title": " ",
  "type": "run",
  "target_value": 0,
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2026-10-01T00:00:00Z"
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields" count >= 3

# quest_not_found
POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "quest_id": 2147483000,
  "title": "No quest",
  "type": "run",
  "target_value": 100,
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2099-01-01T00:00:00Z"
}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "quest_not_found"

# The list and the detail: a draft is hidden from a user and open to an admin
GET {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{user_token}}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "challenge_not_found"

GET {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
HTTP 200
[Asserts]
jsonpath "$.status" == "draft"
jsonpath "$.participant_count" == 0
jsonpath "$.enrollment" == null
jsonpath "$.blocked_by" == null
jsonpath "$.medals" count == 1

GET {{base}}/challenges
Authorization: Bearer {{user_token}}
[QueryStringParams]
status: draft
q: {{title}}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "forbidden"

GET {{base}}/challenges
Authorization: Bearer {{admin_token}}
[QueryStringParams]
status: draft
q: {{title}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 1
jsonpath "$.items[0].id" == {{challenge_id}}

GET {{base}}/challenges?cursor=not-a-cursor
Authorization: Bearer {{user_token}}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "invalid_cursor"

GET {{base}}/challenges?colour=red
Authorization: Bearer {{user_token}}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"

# Edit: only what is sent changes, and null clears
PATCH {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
{
  "city": "Hanoi",
  "landmark": null
}
HTTP 200
[Asserts]
jsonpath "$.city" == "Hanoi"
jsonpath "$.landmark" == null
jsonpath "$.title" == "{{title}}"

# An edit that breaks a rule once merged
PATCH {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
{
  "target_value": 60000
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"

PATCH {{base}}/challenges/2147483000
Authorization: Bearer {{admin_token}}
{
  "title": "Nope"
}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "challenge_not_found"

# An id outside the integer range is a validation error, not a server error
POST {{base}}/challenges/2147483648/publish
Authorization: Bearer {{admin_token}}
HTTP 422

# Publish, then a published challenge cannot be deleted
POST {{base}}/challenges/{{challenge_id}}/publish
Authorization: Bearer {{admin_token}}
HTTP 200
[Asserts]
jsonpath "$.status" == "published"

DELETE {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "challenge_not_draft"

# A published challenge is in the list, with its participant count and no enrollment yet
GET {{base}}/challenges
Authorization: Bearer {{user_token}}
[QueryStringParams]
q: {{title}}
type: run
limit: 5
HTTP 200
[Asserts]
jsonpath "$.items" count == 1
jsonpath "$.items[0].id" == {{challenge_id}}
jsonpath "$.items[0].participant_count" == 0
jsonpath "$.items[0].enrollment" == null
jsonpath "$.next_cursor" == null

GET {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.status" == "published"

POST {{base}}/challenges/{{challenge_id}}/unpublish
Authorization: Bearer {{admin_token}}
HTTP 200
[Asserts]
jsonpath "$.status" == "draft"

DELETE {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
HTTP 204

# An incomplete draft cannot be published
POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "title": "{{title}} bare",
  "type": "swim",
  "target_value": 1000,
  "starts_at": "2026-11-01T00:00:00Z",
  "ends_at": "2099-01-01T00:00:00Z"
}
HTTP 201
[Captures]
bare_id: jsonpath "$.id"

POST {{base}}/challenges/{{bare_id}}/publish
Authorization: Bearer {{admin_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "challenge_not_publishable"
jsonpath "$.error.message" contains "a cover image"

DELETE {{base}}/challenges/{{bare_id}}
Authorization: Bearer {{admin_token}}
HTTP 204

# The method list of a path with several routes
POST {{base}}/challenges/{{bare_id}}
Authorization: Bearer {{admin_token}}
HTTP 405
[Asserts]
header "Allow" == "DELETE, GET, HEAD, PATCH"

# Images: the refusals
POST {{base}}/images
Authorization: Bearer {{admin_token}}
[MultipartFormData]
kind: covers
file: file,not_an_image.txt; text/plain
HTTP 415
[Asserts]
jsonpath "$.error.code" == "unsupported_image_type"

POST {{base}}/images
Authorization: Bearer {{user_token}}
[MultipartFormData]
kind: covers
file: file,not_an_image.txt; text/plain
HTTP 403

# Join, pause, resume and leave (as the normal user), then the overlap rule
POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "title": "{{title}} first",
  "type": "run",
  "target_value": 1000,
  "starts_at": "2098-01-01T00:00:00Z",
  "ends_at": "2098-02-01T00:00:00Z",
  "description_md": "First.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
  "medals": [
    {
      "tier": "gold",
      "name": "Gold",
      "threshold_value": 1000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg"
    }
  ]
}
HTTP 201
[Captures]
first_id: jsonpath "$.id"

POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "title": "{{title}} second",
  "type": "run",
  "target_value": 1000,
  "starts_at": "2098-01-15T00:00:00Z",
  "ends_at": "2098-03-01T00:00:00Z",
  "description_md": "Overlaps the first.",
  "cover_image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
  "medals": [
    {
      "tier": "gold",
      "name": "Gold",
      "threshold_value": 1000,
      "image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg"
    }
  ]
}
HTTP 201
[Captures]
second_id: jsonpath "$.id"

POST {{base}}/challenges/{{first_id}}/publish
Authorization: Bearer {{admin_token}}
HTTP 200

POST {{base}}/challenges/{{second_id}}/publish
Authorization: Bearer {{admin_token}}
HTTP 200

# Not in the challenge yet
POST {{base}}/challenges/{{first_id}}/pause
Authorization: Bearer {{user_token}}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "enrollment_not_found"

POST {{base}}/challenges/{{first_id}}/join
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.enrollment.status" == "active"
jsonpath "$.participant_count" == 1
jsonpath "$.blocked_by" == null

POST {{base}}/challenges/{{first_id}}/join
Authorization: Bearer {{user_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "already_joined"

# The overlapping challenge is blocked, and the detail says by which
GET {{base}}/challenges/{{second_id}}
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.blocked_by.id" == {{first_id}}
jsonpath "$.blocked_by.title" == "{{title}} first"

POST {{base}}/challenges/{{second_id}}/join
Authorization: Bearer {{user_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "overlapping_challenge"
jsonpath "$.error.message" contains "{{title}} first"

POST {{base}}/challenges/{{first_id}}/resume
Authorization: Bearer {{user_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "not_paused"

# Pausing frees the slot
POST {{base}}/challenges/{{first_id}}/pause
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.enrollment.status" == "paused"

POST {{base}}/challenges/{{first_id}}/pause
Authorization: Bearer {{user_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "not_active"

POST {{base}}/challenges/{{second_id}}/join
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.enrollment.status" == "active"

# Resuming is refused while the second is active
POST {{base}}/challenges/{{first_id}}/resume
Authorization: Bearer {{user_token}}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "overlapping_challenge"

GET {{base}}/challenges
Authorization: Bearer {{user_token}}
[QueryStringParams]
q: {{title}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 2
jsonpath "$.items[?(@.id == {{first_id}})].enrollment.status" == "paused"
jsonpath "$.items[?(@.id == {{second_id}})].enrollment.status" == "active"

# Leaving frees it again; the admin's own enrollment is separate
POST {{base}}/challenges/{{second_id}}/leave
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.enrollment" == null
jsonpath "$.participant_count" == 0

POST {{base}}/challenges/{{first_id}}/resume
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.enrollment.status" == "active"

# Someone else cannot touch it
POST {{base}}/challenges/{{first_id}}/leave
Authorization: Bearer {{admin_token}}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "enrollment_not_found"

# A challenge with participants is frozen
PATCH {{base}}/challenges/{{first_id}}
Authorization: Bearer {{admin_token}}
{
  "ends_at": "2098-04-01T00:00:00Z"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "challenge_in_use"

# Clean up, so a replay leaves no published challenge in the list of a dev database
POST {{base}}/challenges/{{first_id}}/leave
Authorization: Bearer {{user_token}}
HTTP 200

POST {{base}}/challenges/{{first_id}}/unpublish
Authorization: Bearer {{admin_token}}
HTTP 200

DELETE {{base}}/challenges/{{first_id}}
Authorization: Bearer {{admin_token}}
HTTP 204

POST {{base}}/challenges/{{second_id}}/unpublish
Authorization: Bearer {{admin_token}}
HTTP 200

DELETE {{base}}/challenges/{{second_id}}
Authorization: Bearer {{admin_token}}
HTTP 204
