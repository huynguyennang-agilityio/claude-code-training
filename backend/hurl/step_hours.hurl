# PUT /runs/step-hours of docs/api/runs.md: the hours that count, replayed against a running
# server.
#
#   backend/hurl/run.sh [base_url]
#
# run.sh makes the enrollment first: a fresh user joins a run challenge, and the enrollment's
# `hours_from` and `counting_from` and the user's `session_started_at` are moved three days back
# (an hour counts only from the join time, and no whole hour passes during a replay). It passes:
# base, admin_token (to delete the challenge at the end), hours_token (the user), challenge_id,
# hour_3, hour_2, hour_1 (the starts of the UTC hours 3, 2 and 1 hours ago) and hour_next (the
# start of the UTC hour after the next one, so a replay that crosses an hour boundary still sends
# a future hour).

# Two hours count; 18,250 steps in one hour is ignored, not an error
PUT {{base}}/runs/step-hours
Authorization: Bearer {{hours_token}}
{
  "hours": [
    { "hour_start": "{{hour_3}}", "steps": 4120 },
    { "hour_start": "{{hour_2}}", "steps": 980 },
    { "hour_start": "{{hour_1}}", "steps": 18250 }
  ]
}
HTTP 200
[Asserts]
jsonpath "$.accepted" == 2
jsonpath "$.ignored" == 1
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 5100
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.tracked" == true

# The same hour again counts once, and is accepted
PUT {{base}}/runs/step-hours
Authorization: Bearer {{hours_token}}
{ "hours": [{ "hour_start": "{{hour_3}}", "steps": 4120 }] }
HTTP 200
[Asserts]
jsonpath "$.accepted" == 1
jsonpath "$.ignored" == 0
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 5100

# A higher value replaces it: the total grows by the difference (5,000 - 4,120)
PUT {{base}}/runs/step-hours
Authorization: Bearer {{hours_token}}
{ "hours": [{ "hour_start": "{{hour_3}}", "steps": 5000 }] }
HTTP 200
[Asserts]
jsonpath "$.accepted" == 1
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 5980

# A lower value replaces it too (100 - 5,000)
PUT {{base}}/runs/step-hours
Authorization: Bearer {{hours_token}}
{ "hours": [{ "hour_start": "{{hour_3}}", "steps": 100 }] }
HTTP 200
[Asserts]
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 1080

# An hour that has not started, and one with too many steps, are ignored and change nothing
PUT {{base}}/runs/step-hours
Authorization: Bearer {{hours_token}}
{
  "hours": [
    { "hour_start": "{{hour_next}}", "steps": 50 },
    { "hour_start": "{{hour_2}}", "steps": 15001 }
  ]
}
HTTP 200
[Asserts]
jsonpath "$.accepted" == 0
jsonpath "$.ignored" == 2
jsonpath "$.enrollments[?(@.challenge_id == {{challenge_id}})].progress.current_value" == 1080

# The list shows the same progress
GET {{base}}/runs?limit=50
Authorization: Bearer {{hours_token}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.challenge.id == {{challenge_id}})].progress.current_value" == 1080

# Clean up, so a replay leaves no published challenge in the list of a dev database
POST {{base}}/challenges/{{challenge_id}}/leave
Authorization: Bearer {{hours_token}}
HTTP 200

POST {{base}}/challenges/{{challenge_id}}/unpublish
Authorization: Bearer {{admin_token}}
HTTP 200

DELETE {{base}}/challenges/{{challenge_id}}
Authorization: Bearer {{admin_token}}
HTTP 204
