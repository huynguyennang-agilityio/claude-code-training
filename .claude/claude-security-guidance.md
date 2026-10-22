# StrideQuest security rules

Project rules for the `security-guidance` plugin's diff review (plan 017). Keep this file under 8 KB: the plugin truncates the combined rule files past that. Never put secrets here; it is sent with every review.

The app: a Flutter mobile app and a FastAPI backend (modules `auth`, `challenges`, `runs`, `medals`) on PostgreSQL. The repo is public on GitHub.

## Backend (`backend/`)

- Every route declares who may call it in `ROUTE_ACCESS` (`backend/tests/unit/test_auth_sweep.py`): `public`, `user` or `admin`. A new or changed route missing from it, or declared looser than its contract's `Auth` column in `docs/api/`, is an auth bypass.
- An `admin` route answers a signed-in non-admin with `403 forbidden`.
- A user-owned resource (a run, a joined challenge, a medal) is always queried together with the current user's id. Another user's resource answers `404 not_found`, never `403` and never the data: a lookup by id alone is an IDOR.
- Errors are typed domain exceptions mapped to `ErrorResponse` by the global handler. A response never contains exception text, SQL, stack traces, file paths or another user's data.
- SQL goes through SQLAlchemy with bound parameters. `text()`, f-strings or `%` formatting built from request data are SQL injection.
- Request bodies and query parameters are Pydantic schemas with bounds (lengths, ranges, enums). Pagination has a maximum page size.
- Outbound HTTP uses `httpx.AsyncClient` with a timeout, to fixed hosts only. Fetching a URL that came from a request is SSRF.
- Only the backend uploads images to Cloudinary (`app/core/storage.py`), with server-side upload parameters. The database stores only the delivery URL. A client never gets Cloudinary credentials or a signed upload it can reuse for other paths.
- Secrets (`JWT_SECRET`, database URLs, Cloudinary credentials) come from `Settings` in `app/core/config.py`, never from code, logs, `docs/api/examples/`, test fixtures or `.hurl` files.
- Access tokens are JWTs verified only with HS256 (`decode_access_token` in `app/core/security.py`), with `exp` and `sub` required. Accepting another algorithm, `none` or a missing expiry is an auth bypass.
- Refresh tokens are random, stored only as a hash, and single-use: `consume_refresh_token` marks one used, and a used, expired or revoked one fails with `invalid_refresh_token`.
- Passwords are only stored hashed, and never logged or returned.
- Logs never contain tokens, passwords, `Authorization` headers, cookies or health data.
- Nothing blocking runs in the event loop (`requests`, `time.sleep`, sync file or database I/O in async code): it is a denial of service for every user.

## Mobile (`mobile/`)

- Tokens live only in `flutter_secure_storage` (`SecureAuthLocalDataSource`). Never `SharedPreferences`, plain files, logs, analytics or `GoRouter` `state.extra`.
- Dio interceptors never print `Authorization` headers or the bodies of auth calls. `AuthInterceptor` refreshes once and signs out on failure; it must not retry forever or send the refresh token to any host other than `AppConfig.apiBaseUrl`.
- `API_BASE_URL` is `https` outside local development.
- Health data (steps from Apple Health or Health Connect) is read only through `HealthRepository`, sent only to our backend, and never logged.
- Routes pass ids only. A deep link must not open another user's resource without the backend's ownership check.

## GitHub workflows (`.github/workflows/`)

- Untrusted event text (`github.event.*.title`, `.body`, `.head_ref`, comment bodies, branch names) is never written inside `run:` with `${{ }}`. It is passed through `env:` and quoted. Anything else is script injection.
- No `pull_request_target`, and no `workflow_run` that checks out PR code next to a secret. Fork code must never run in a job that holds a secret.
- `permissions: {}` at the top; each job asks only for what it needs. A review or scan job that runs Claude has no write permission; a separate job without AI posts its output. The one exception is `claude.yml`: by design (plan 014) it runs Claude with the Claude GitHub App token, which may comment, push `claude/...` or PR branches and open PRs, while the `develop`/`main` ruleset refuses pushes to those branches.
- Third-party actions are pinned to a full commit SHA, with the tag in a comment.
- Claude workflows run only for `OWNER`, `MEMBER` or `COLLABORATOR`, after the fail-closed `gate` job.
- No secrets in job outputs, artifacts or logs. The Claude transcript is not uploaded (the repo is public).

## Claude hooks and scripts (`.claude/hooks/`, `backend/hurl/run.sh`)

- Shell variables are always quoted, and input from a hook's JSON is parsed with `jq`, never with `eval`.
- A hook never sends repo content or environment variables anywhere except the tools it documents.
