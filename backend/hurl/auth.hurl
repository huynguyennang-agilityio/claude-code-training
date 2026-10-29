# The auth flow of docs/api/auth.md, replayed against a running server.
#
#   backend/hurl/run.sh [base_url]
#
# It needs `docker compose up -d --wait db` and the API running (uvicorn app.main:app).
# Each run signs up its own user, and leaves its users and a few failed sign-ins in the database
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

# Change the email (a second account, to own an email)
POST {{base}}/auth/signup
{
  "email": "other-{{email}}",
  "password": "run4medals",
  "display_name": "Other Runner"
}
HTTP 201

# 403 incorrect_password (and it never says whether the new email is registered)
PUT {{base}}/users/me/email
Authorization: Bearer {{access_token}}
{
  "new_email": "other-{{email}}",
  "current_password": "wrong-pass1"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "incorrect_password"
jsonpath "$.error.message" == "The current password is incorrect."
jsonpath "$.error.fields" count == 0

# 422: the same email after lowercasing, naming new_email
PUT {{base}}/users/me/email
Authorization: Bearer {{access_token}}
{
  "new_email": "{{email}}",
  "current_password": "run4medals"
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[0].field" == "new_email"

# 422: not an email
PUT {{base}}/users/me/email
Authorization: Bearer {{access_token}}
{
  "new_email": "not-an-email",
  "current_password": "run4medals"
}
HTTP 422
[Asserts]
jsonpath "$.error.fields[0].field" == "new_email"

# 409 email_taken
PUT {{base}}/users/me/email
Authorization: Bearer {{access_token}}
{
  "new_email": "other-{{email}}",
  "current_password": "run4medals"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "email_taken"

# 401 without a token
PUT {{base}}/users/me/email
{
  "new_email": "new-{{email}}",
  "current_password": "run4medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# 200: the new email works for sign in, the old one no longer does
PUT {{base}}/users/me/email
Authorization: Bearer {{access_token}}
{
  "new_email": "NEW-{{email}}",
  "current_password": "run4medals"
}
HTTP 200
[Asserts]
jsonpath "$.email" == "new-{{email}}"
jsonpath "$.display_name" == "Lan Runner"

POST {{base}}/auth/signin
{
  "email": "new-{{email}}",
  "password": "run4medals"
}
HTTP 200

POST {{base}}/auth/signin
{
  "email": "{{email}}",
  "password": "run4medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"

# Change the password: sign in again to hold a refresh token (the email is new-{{email}} now)
POST {{base}}/auth/signin
{
  "email": "new-{{email}}",
  "password": "run4medals"
}
HTTP 200
[Captures]
pw_access_token: jsonpath "$.tokens.access_token"
pw_refresh_token: jsonpath "$.tokens.refresh_token"

# 401 without a token
PUT {{base}}/users/me/password
{
  "current_password": "run4medals",
  "new_password": "newrun5medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# 403 incorrect_password
PUT {{base}}/users/me/password
Authorization: Bearer {{pw_access_token}}
{
  "current_password": "wrong-pass1",
  "new_password": "newrun5medals"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "incorrect_password"
jsonpath "$.error.fields" count == 0

# 422: the same password, naming new_password
PUT {{base}}/users/me/password
Authorization: Bearer {{pw_access_token}}
{
  "current_password": "run4medals",
  "new_password": "run4medals"
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[0].field" == "new_password"

# 422: a new password without a digit
PUT {{base}}/users/me/password
Authorization: Bearer {{pw_access_token}}
{
  "current_password": "run4medals",
  "new_password": "newrunmedals"
}
HTTP 422
[Asserts]
jsonpath "$.error.fields[0].field" == "new_password"

# 200: a new token pair; the old refresh token is revoked and the new one works
PUT {{base}}/users/me/password
Authorization: Bearer {{pw_access_token}}
{
  "current_password": "run4medals",
  "new_password": "newrun5medals"
}
HTTP 200
[Captures]
changed_access_token: jsonpath "$.access_token"
changed_refresh_token: jsonpath "$.refresh_token"
[Asserts]
jsonpath "$.token_type" == "bearer"
jsonpath "$.expires_in" == 900
jsonpath "$.refresh_token" != "{{pw_refresh_token}}"

POST {{base}}/auth/refresh
{
  "refresh_token": "{{pw_refresh_token}}"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_refresh_token"

GET {{base}}/users/me
Authorization: Bearer {{changed_access_token}}
HTTP 200

POST {{base}}/auth/refresh
{
  "refresh_token": "{{changed_refresh_token}}"
}
HTTP 200

# Sign in works with the new password only
POST {{base}}/auth/signin
{
  "email": "new-{{email}}",
  "password": "newrun5medals"
}
HTTP 200
[Captures]
del_access_token: jsonpath "$.tokens.access_token"
del_refresh_token: jsonpath "$.tokens.refresh_token"

POST {{base}}/auth/signin
{
  "email": "new-{{email}}",
  "password": "run4medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"

# Delete the account (the password is newrun5medals now)

# 401 without a token
POST {{base}}/users/me/delete
{
  "current_password": "newrun5medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "not_authenticated"

# 422: an empty password, naming current_password
POST {{base}}/users/me/delete
Authorization: Bearer {{del_access_token}}
{
  "current_password": ""
}
HTTP 422
[Asserts]
jsonpath "$.error.code" == "validation_error"
jsonpath "$.error.fields[0].field" == "current_password"

# 403 incorrect_password: nothing is deleted
POST {{base}}/users/me/delete
Authorization: Bearer {{del_access_token}}
{
  "current_password": "wrong-pass1"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "incorrect_password"
jsonpath "$.error.fields" count == 0

GET {{base}}/users/me
Authorization: Bearer {{del_access_token}}
HTTP 200

# 204 with no body
POST {{base}}/users/me/delete
Authorization: Bearer {{del_access_token}}
{
  "current_password": "newrun5medals"
}
HTTP 204
[Asserts]
body == ""

# The account is gone: the old access token, the refresh token and the password all fail
GET {{base}}/users/me
Authorization: Bearer {{del_access_token}}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_token"

POST {{base}}/auth/refresh
{
  "refresh_token": "{{del_refresh_token}}"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_refresh_token"

POST {{base}}/auth/signin
{
  "email": "new-{{email}}",
  "password": "newrun5medals"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"
