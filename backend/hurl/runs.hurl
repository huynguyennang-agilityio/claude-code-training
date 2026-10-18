# The step sync and the "my challenges" routes of docs/api/runs.md, replayed against a running
# server.
#
#   backend/hurl/run.sh [base_url]
#
# run.sh passes: base, admin_token, user_token, other_token (a second normal user), title
# (unique per run), and sample_start and sample_end, the window of one step sample. The sample
# starts shortly after now (the user joins first, and steps count only from joining) and ends
# less than 5 minutes ahead (a sample from further in the future is ignored).

# Not signed in
GET {{base}}/runs
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

POST {{base}}/runs/steps
{ "samples": [] }
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# A published run challenge that has already started, with a quest to hang it on
POST {{base}}/quests
Authorization: Bearer {{admin_token}}
{
  "title": "{{title}}",
  "description": "Created by hurl."
}
HTTP 201
[Captures]
quest_id: jsonpath "$.id"

POST {{base}}/challenges
Authorization: Bearer {{admin_token}}
{
  "quest_id": {{quest_id}},
  "title": "{{title}}",
  "type": "run",
  "target_value": 50000,
  "starts_at": "2026-10-01T00:00:00Z",
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

POST {{base}}/challenges/{{challenge_id}}/publish
Authorization: Bearer {{admin_token}}
HTTP 200

POST {{base}}/challenges/{{challenge_id}}/join
Authorization: Bearer {{user_token}}
HTTP 200

# Before any steps: the challenge is listed with 0 progress
GET {{base}}/runs
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].progress.current_value" == 0
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].progress.tracked" == true
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].challenge.enrollment.status" == "active"

# A sample is counted
POST {{base}}/runs/steps
Authorization: Bearer {{user_token}}
{
  "samples": [
    {
      "health_record_id": "hurl-{{title}}",
      "start_time": "{{sample_start}}",
      "end_time": "{{sample_end}}",
      "steps": 1200
    }
  ]
}
HTTP 200
[Asserts]
jsonpath "$.accepted" == 1
jsonpath "$.ignored" == 0
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 1200
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.percent" == 2

# The same record again counts once
POST {{base}}/runs/steps
Authorization: Bearer {{user_token}}
{
  "samples": [
    {
      "health_record_id": "hurl-{{title}}",
      "start_time": "{{sample_start}}",
      "end_time": "{{sample_end}}",
      "steps": 1200
    }
  ]
}
HTTP 200
[Asserts]
jsonpath "$.accepted" == 0
jsonpath "$.ignored" == 1
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 1200

# A sample from the future is ignored, not an error
POST {{base}}/runs/steps
Authorization: Bearer {{user_token}}
{
  "samples": [
    {
      "health_record_id": "hurl-future-{{title}}",
      "start_time": "2098-01-01T00:00:00Z",
      "end_time": "2098-01-01T01:00:00Z",
      "steps": 500
    }
  ]
}
HTTP 200
[Asserts]
jsonpath "$.accepted" == 0
jsonpath "$.ignored" == 1

# The list shows the progress
GET {{base}}/runs?limit=50
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].progress.current_value" == 1200
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].progress.started" == true

# Another user sees none of it
GET {{base}}/runs
Authorization: Bearer {{other_token}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0
jsonpath "$.next_cursor" == null

# validation_error
POST {{base}}/runs/steps
Authorization: Bearer {{user_token}}
{ "samples": [] }
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"

POST {{base}}/runs/steps
Authorization: Bearer {{user_token}}
{
  "samples": [
    {
      "health_record_id": "x",
      "start_time": "2026-11-02T06:30:00",
      "end_time": "2026-11-02T07:30:00",
      "steps": 0
    }
  ]
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields" count >= 2

GET {{base}}/runs?limit=0
Authorization: Bearer {{user_token}}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"

# invalid_cursor
GET {{base}}/runs?cursor=bm90LWEtY3Vyc29y
Authorization: Bearer {{user_token}}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "invalid_cursor"

# Clean up, so a replay leaves no published challenge in the list of a dev database
POST {{base}}/challenges/{{challenge_id}}/leave
Authorization: Bearer {{user_token}}
HTTP 200

POST {{base}}/challenges/{{challenge_id}}/unpublish
Authorization: Bearer {{admin_token}}
HTTP 200

DELETE {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
HTTP 204
