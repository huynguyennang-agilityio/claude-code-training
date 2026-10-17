# The auth flow of docs/api/auth.md, replayed against a running server.
#
#   backend/hurl/run.sh [base_url]
#
# It needs `docker compose up -d --wait db` and the API running (uvicorn app.main:app).
# Each run signs up its own user, and leaves it and two failed sign-ins in the database
# (the per-IP limit is 20 failed sign-ins in 15 minutes, so run it fewer than ten times
# in that time, or use another IP).
# Variables: base (the API base), email (unique per run).

# Sign up
POST {{base}}/auth/signup
{
  "email": "{{email}}",
  "password": "run4medals",
  "display_name": "  Lan Runner  "
}
HTTP 201
[Captures]
access_token: jsonpath "$.tokens.access_token"
refresh_token: jsonpath "$.tokens.refresh_token"
[Asserts]
jsonpath "$.user.email" == "{{email}}"
jsonpath "$.user.display_name" == "Lan Runner"
jsonpath "$.user.id" isString
jsonpath "$.user.created_at" matches /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$/
jsonpath "$.tokens.token_type" == "bearer"
jsonpath "$.tokens.expires_in" == 900
jsonpath "$.user.password" not exists
jsonpath "$.user.password_hash" not exists

# email_taken (the email is case-insensitive)
POST {{base}}/auth/signup
{
  "email": "{{email}}",
  "password": "run4medals",
  "display_name": "Lan Runner"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "email_taken"
jsonpath "$.error.fields" count == 0

# validation_error names the field
POST {{base}}/auth/signup
{
  "email": "x-{{email}}",
  "password": "runnerrun",
  "display_name": "Lan Runner"
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[0].field" == "password"
jsonpath "$.error.fields[0].message" == "Password must contain at least one digit."

# Sign in
POST {{base}}/auth/signin
{
  "email": "{{email}}",
  "password": "run4medals"
}
HTTP 200
[Asserts]
jsonpath "$.user.email" == "{{email}}"
jsonpath "$.tokens.access_token" isString

# invalid_credentials: a wrong password and an unknown email look the same
POST {{base}}/auth/signin
{
  "email": "{{email}}",
  "password": "wrong-pass1"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"
jsonpath "$.error.message" == "Email or password is incorrect."

POST {{base}}/auth/signin
{
  "email": "nobody-{{email}}",
  "password": "run4medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"
jsonpath "$.error.message" == "Email or password is incorrect."

# Current user
GET {{base}}/users/me
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.email" == "{{email}}"
jsonpath "$.display_name" == "Lan Runner"

GET {{base}}/users/me
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.error.code" == "not_authenticated"

GET {{base}}/users/me
Authorization: Bearer not.a.jwt
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.error.code" == "invalid_token"

# Refresh rotates the token: the new one works, the old one doesn't
POST {{base}}/auth/refresh
{
  "refresh_token": "{{refresh_token}}"
}
HTTP 200
[Captures]
new_refresh_token: jsonpath "$.refresh_token"
new_access_token: jsonpath "$.access_token"
[Asserts]
jsonpath "$.token_type" == "bearer"
jsonpath "$.expires_in" == 900
jsonpath "$.refresh_token" != "{{refresh_token}}"

POST {{base}}/auth/refresh
{
  "refresh_token": "{{refresh_token}}"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_refresh_token"

GET {{base}}/users/me
Authorization: Bearer {{new_access_token}}
HTTP 200

# Sign out revokes it, and signing out again is still 204
POST {{base}}/auth/signout
{
  "refresh_token": "{{new_refresh_token}}"
}
HTTP 204

POST {{base}}/auth/signout
{
  "refresh_token": "{{new_refresh_token}}"
}
HTTP 204

POST {{base}}/auth/refresh
{
  "refresh_token": "{{new_refresh_token}}"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_refresh_token"

# Missing body fields are validation errors
POST {{base}}/auth/refresh
{}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[0].field" == "refresh_token"
