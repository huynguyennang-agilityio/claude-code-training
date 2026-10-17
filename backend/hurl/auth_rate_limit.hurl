# rate_limited, replayed against a running server (see auth.hurl for the setup).
#
# Five failed sign-ins for one email block that email for 15 minutes, even with the
# right password. This uses 5 of the 20 failed sign-ins the per-IP limit allows in 15
# minutes, so run it rarely. Variables: base, email.

POST {{base}}/auth/signup
{
  "email": "{{email}}",
  "password": "run4medals",
  "display_name": "Lan Runner"
}
HTTP 201

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "wrong-pass1" }
HTTP 401

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "wrong-pass1" }
HTTP 401

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "wrong-pass1" }
HTTP 401

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "wrong-pass1" }
HTTP 401

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "wrong-pass1" }
HTTP 401

POST {{base}}/auth/signin
{ "email": "{{email}}", "password": "run4medals" }
HTTP 429
[Asserts]
header "Retry-After" matches /^[1-9]\d*$/
jsonpath "$.error.code" == "rate_limited"
