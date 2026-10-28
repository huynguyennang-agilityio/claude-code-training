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

# PUT: not signed in
PUT {{base}}/users/me/profile
{
  "first_name": "Max", "last_name": "Darsonval", "birthday": "1991-06-24", "country": "US",
  "state": "California", "gender": "male", "unit_system": "imperial",
  "height_cm": 180.3, "weight_kg": 84.4
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# The first save creates the profile; text is trimmed
PUT {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
{
  "first_name": "  Max ", "last_name": "Darsonval", "birthday": "1991-06-24", "country": "US",
  "state": "California", "gender": "male", "unit_system": "imperial",
  "height_cm": 180.3, "weight_kg": 84.4
}
HTTP 200
[Asserts]
jsonpath "$.first_name" == "Max"
jsonpath "$.birthday" == "1991-06-24"
jsonpath "$.unit_system" == "imperial"
jsonpath "$.height_cm" == 180.3
jsonpath "$.weight_kg" == 84.4

# GET returns what was saved
GET {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.first_name" == "Max"
jsonpath "$.country" == "US"
jsonpath "$.gender" == "male"
jsonpath "$.height_cm" == 180.3

# Another user's profile is untouched
GET {{base}}/users/me/profile
Authorization: Bearer {{other_token}}
HTTP 200
[Asserts]
jsonpath "$.first_name" == null
jsonpath "$.unit_system" == "metric"

# A second save replaces everything; null clears a value
PUT {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
{
  "first_name": "Lan", "last_name": null, "birthday": null, "country": null,
  "state": null, "gender": null, "unit_system": "metric",
  "height_cm": null, "weight_kg": 70
}
HTTP 200
[Asserts]
jsonpath "$.first_name" == "Lan"
jsonpath "$.last_name" == null
jsonpath "$.country" == null
jsonpath "$.unit_system" == "metric"
jsonpath "$.height_cm" == null
jsonpath "$.weight_kg" == 70

# 422 validation_error names each broken field and stores nothing
PUT {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
{
  "first_name": "Lan", "last_name": null, "birthday": null, "country": "us",
  "state": null, "gender": null, "unit_system": "metric",
  "height_cm": 300, "weight_kg": 70
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields" count == 2
jsonpath "$.error.fields[0].field" == "country"
jsonpath "$.error.fields[0].message" == "Country must be a two-letter code in capitals."
jsonpath "$.error.fields[1].field" == "height_cm"

# A missing key is a 422 naming it
PUT {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
{ "first_name": "Lan" }
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[*].field" contains "state"

GET {{base}}/users/me/profile
Authorization: Bearer {{user_token}}
HTTP 200
[Asserts]
jsonpath "$.first_name" == "Lan"
