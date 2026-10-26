# The profile routes of docs/api/profile.md, replayed against a running server.
#
#   backend/hurl/run.sh [base_url]
#
# run.sh passes: base, user_token and other_token (two normal users).

# Not signed in
GET {{base}}/users/me/profile
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

GET {{base}}/users/me/profile
Authorization: Bearer not-a-token
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_token"

# A user who never saved a profile gets the empty one, not a 404
GET {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.*" count == 9
jsonpath "$.first_name" == null
jsonpath "$.last_name" == null
jsonpath "$.birthday" == null
jsonpath "$.country" == null
jsonpath "$.state" == null
jsonpath "$.gender" == null
jsonpath "$.unit_system" == "metric"
jsonpath "$.height_cm" == null
jsonpath "$.weight_kg" == null

# Another user gets their own empty profile too
GET {{base}}/users/me/profile
Authorization: Bearer {{other_token}}
HTTP 200
[Asserts]
jsonpath "$.unit_system" == "metric"
jsonpath "$.first_name" == null
