# Plan 025: Release the API (Render + Neon), iOS (TestFlight) and Android (Firebase App Distribution) with GitHub Actions

Status: approved
Approved: 2026-10-27, by the user in chat: "/approve-plan 025"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/Pe9GigfEfKHnNV7dVkR7of, version 1793087250-9d1c

Related: [ADR 0001](../adr/0001-architecture.md), [plan 014](014-claude-github-actions.md), [plan 021](021-gh-forbidden-commands.md).

| Lane | Flow |
| --- | --- |
| API | Tag `api-vX.Y.Z` → checks → `alembic upgrade head` on Neon → Render API deploys the tag's exact commit → wait for the deploy to be live and `/api/v1/health` to return 200. |
| iOS | Tag `ios-vX.Y.Z` → `flutter build ipa` on a macOS runner → upload to TestFlight. |
| Android | Tag `android-vX.Y.Z` → `flutter build apk` signed with the release keystore → Firebase App Distribution. |

Tag `vX.Y.Z` runs all three: the API first, then iOS and Android in parallel once the API is live.

## Context

StrideQuest only runs locally so far: the backend in `docker compose`, the app pointing at `http://localhost:8000/api/v1/` (`mobile/lib/core/config/app_config.dart`). The user wants a real API and iOS and Android builds to install on real devices, at a cost as close to $0 as possible. Every build and release step runs on GitHub Actions, with no local machine needed. Claude has skills to trigger a release of everything or of each part.

Current state of the repo: there is no `backend/Dockerfile` yet. The Android release is still signed with the debug key (`signingConfigs.getByName("debug")` in `mobile/android/app/build.gradle.kts`). iOS already has team `KHAR8S7L52`, bundle id `huynang.stridequest`, the HealthKit entitlement and `NSHealthShareUsageDescription`. The backend already has `GET /api/v1/health`. The repo is public, so GitHub Actions (macOS runners included) is free.

### Decided by the user

- The API deploys to **Render** (Free Web Service), and the database is **Neon** (Free).
- Android goes to testers through **Firebase App Distribution**, not Google Play yet.
- iOS goes out through **TestFlight** (the Apple Developer account already exists).
- Releases run from **`main`**: the tag must point at a commit on `main`.
- There is only one **production** environment, no staging.
- Triggered by **tag and `workflow_dispatch`**: the skill creates the version tag, and it can still be run by hand on GitHub.
- There is a skill that releases everything (`/release`) and skills that release each part (`/release-api`, `/release-ios`, `/release-android`).
- What the user must do by hand is listed first, in the plan itself, so the tasks run end to end without stopping to ask.

### Prerequisites

Claude creates no accounts and never sees secret values. You enter secrets on GitHub yourself (Settings → Environments → `production`), or run `gh secret set <NAME> --env production` in your own terminal. Only secret names are listed below.

#### A. Before running `/run-tasks` for this plan's issues

- **No account or secret is needed.** All 5 tasks are verified only with `dry_run` (build, no deploy or upload), so they can run right after `/approve-plan`.
- **An Android emulator API 34+** (with Health Connect installed and sample step data), or an Android phone plugged into the machine. Task 4 needs it to check the release build.

#### B. Before the first release (after the 5 tasks have merged into `develop`)

| # | Task | Result to enter | When |
| --- | --- | --- | --- |
| 0 | **Release PR `develop` → `main`:** ask Claude to open the PR (say so explicitly in chat); you review and merge it yourself. `main` has never been released: it only has code up to 13/10 (106 files), no `.github/workflows`, `.claude/` or `docs/`, and is about 460 commits behind `develop`. A tag push runs the workflows in the tagged commit, so nothing can be released until this PR merges | No secret. Result: `main` has `render.yaml` and the `release*.yml` workflows | After task 5 merges into `develop`, before row 3 |
| 1 | **GitHub:** create the `production` environment; under Deployment branches and tags, choose the tags `v*`, `api-v*`, `ios-v*`, `android-v*` | Holds all the secrets below | First |
| 2 | **Neon:** create a project in region `aws-ap-southeast-1`, take the **direct** connection string (not the pooler), and rewrite it as `postgresql+asyncpg://…?ssl=require` | secret `NEON_DATABASE_URL` | Any time |
| 3 | **Render:** New → Blueprint from the repo (reads `render.yaml` on `main`). Enter `DATABASE_URL` (the same Neon string), `JWT_SECRET` (a random string, for example `openssl rand -hex 32`) and `CLOUDINARY_*` on the dashboard. Create an API key under Account Settings. | secret `RENDER_API_KEY`, `RENDER_SERVICE_ID` (`srv-…`); repository variable `API_BASE_URL` = `https://<service>.onrender.com/api/v1/` | After the release PR in row 0 merges into `main` |
| 4 | **Apple:** on App Store Connect, create the app with bundle `huynang.stridequest`; create an API key (Users and Access → Integrations, role App Manager); create an Apple Distribution certificate and export it as `.p12`; create an App Store provisioning profile with HealthKit | secret `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8` (base64), `IOS_DIST_CERT_P12` (base64), `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE` (base64) | Any time |
| 5 | **Android keystore:** run `keytool -genkeypair -v -keystore stridequest-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stridequest`, then **keep the file and the passwords somewhere safe outside GitHub** | secret `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Any time |
| 6 | **Firebase:** create a project, add the Android app `huynang.stridequest`, create the `testers` group in App Distribution and add tester emails; create a service account with the Firebase App Distribution Admin role and download its JSON key | secret `FIREBASE_ANDROID_APP_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | Any time |

Convert a file to base64 with `base64 -i <file> | pbcopy`. Before creating a tag, each `/release*` skill checks that the secret and variable names it needs exist (names only, never values). If one is missing, the skill names the missing row of this table and stops.

## Open questions and assumptions

1. **Cold start and timeout:** Render free sleeps after about 15 minutes, and the first request takes about 30–60 seconds, while the Dio timeout is 15 seconds (`mobile/lib/core/network/dio_client.dart`). Assumption: this plan does **not** change the app, so the first request after the server sleeps may show a network error and the user has to retry. Handling it (a retry, or a "waking the server" screen) is a separate plan.
2. **Version:** one shared semver `X.Y.Z` from the tag. The app uses `--build-name=X.Y.Z`, and the build number is **Unix minutes**: `BUILD_NUMBER=$(( $(date +%s) / 60 ))` (about 29.9 million). It always increases, whether it runs from a single workflow, the full workflow or a re-run, so App Store Connect never rejects a duplicate or lower build number. It is also below Android's `versionCode` limit of 2,100,000,000. Not `github.run_number`, because each workflow has its own counter and a re-run keeps the same number. Not `date +%Y%m%d%H%M`, because a 12-digit number overflows `versionCode`. Two builds of the same platform in the same minute would share a number; assumed acceptable. `version:` in `mobile/pubspec.yaml` is not bumped, so a release creates no commit.
3. **One-time accounts and infrastructure:** the user does these, following "Prerequisites". Claude creates no accounts and enters no credentials. `docs/deploy.md` records those steps and the name of each secret (no values).
4. **Neon connection:** use the **direct** endpoint (not the pooler), written as `postgresql+asyncpg://…?ssl=require`. Neon's pooler (PgBouncer, transaction mode) breaks asyncpg's prepared statements. No backend code change is needed.
5. **Region:** Render Singapore and Neon `aws-ap-southeast-1`, close to the user in Vietnam and close to each other.
6. **GitHub environment `production`** holds every release secret, limited to the tags `v*`, `api-v*`, `ios-v*`, `android-v*`. Assumption: no required reviewer yet, because the skill already asks for confirmation before creating the tag. The user can turn it on later.
7. **Migrations:** they run on GitHub Actions before the new code deploys, so from now on every migration must be backward compatible with the running code (expand first, contract in a later release). This rule is written into `docs/deploy.md`.
8. **TestFlight:** internal testers (App Store Connect members) can install right away. External testers need Beta App Review, which the user does on App Store Connect.

## Approach

### Backend image

- `backend/Dockerfile`: `python:3.12-slim`, installs `requirements.txt`, runs as a non-root user, command `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers`. The image includes `alembic/` and `alembic.ini`, so migrations can run from the image when needed.
- `backend/.dockerignore` excludes `.env`, `tests/`, `demo/`, `hurl/`, caches and venvs.
- `.github/workflows/backend-ci.yml` adds a `docker build` step, so a PR that breaks the image fails.

### Render and Neon

- `render.yaml` (Blueprint): one web service `stridequest-api`, `runtime: docker`, `rootDir: backend`, `plan: free`, `region: singapore`, `autoDeploy: false`, `healthCheckPath: /api/v1/health`. The variables `DATABASE_URL`, `JWT_SECRET`, `CLOUDINARY_*` are `sync: false`; the user enters them on the Render dashboard.
- `autoDeploy: false`, because only the release workflow deploys, after the migrations have finished.

### Workflows (`.github/workflows/`)

| File | Trigger | What it does | Secrets (environment `production`) |
| --- | --- | --- | --- |
| `release-api.yml` | tag `api-v*`, `workflow_call`, `workflow_dispatch` (input `dry_run`), `pull_request` (always a dry run; paths `.github/workflows/release-api.yml`, `render.yaml`, `backend/Dockerfile`) | Checks the tag is on `origin/main`; runs `ruff`, `mypy` and the unit tests; `alembic upgrade head` on Neon; calls `POST /v1/services/{serviceId}/deploys` with `commitId` set to the tag's commit, takes `deploy.id` and polls until `live`; checks `/api/v1/health` returns 200 | `NEON_DATABASE_URL`, `RENDER_API_KEY`, `RENDER_SERVICE_ID` |
| `release-ios.yml` | tag `ios-v*`, `workflow_call`, `workflow_dispatch` (`dry_run`), `pull_request` (always a dry run; paths `.github/workflows/release-ios.yml`, `mobile/ios/**`) | Checks the tag is on `main`; pins the Xcode version; installs Flutter (the same version as `mobile-ci.yml`); imports the certificate and profile into a temporary keychain; `flutter build ipa --release` with `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}` to make `Runner.xcarchive`; `xcodebuild -exportArchive` with `ExportOptions.plist` (`destination: upload`) and `-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID` to upload to TestFlight; deletes the keychain | `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8`, `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE` |
| `release-android.yml` | tag `android-v*`, `workflow_call`, `workflow_dispatch` (`dry_run`), `pull_request` (always a dry run; paths `.github/workflows/release-android.yml`, `mobile/android/**`) | Checks the tag is on `main`; decodes the keystore; `flutter build apk --release` with the same `API_BASE_URL`; `firebase appdistribution:distribute` to the `testers` group, release notes from the tag | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_ANDROID_APP_ID` |
| `release.yml` | tag `v*`, `workflow_dispatch`, `pull_request` (always a dry run; path `.github/workflows/release.yml`) | Calls `release-api.yml`, then `release-ios.yml` and `release-android.yml` in parallel (`needs: api`) | inherited (`secrets: inherit`) |

**Common rules for the three child workflows:**

- Check out with `fetch-depth: 0`. The default shallow clone has no history and no `origin/main`, so `git merge-base --is-ancestor "$GITHUB_SHA" origin/main` would always fail.
- The job uses `environment: ${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`. On a tag push the event is `push` and `inputs.dry_run` is empty, so the job uses `production`. In a PR (event `pull_request`) or a `workflow_dispatch` with `dry_run`, no environment is attached, so the "tags only" rule of `production` does not block the job. Don't write `inputs.dry_run && '' || 'production'`: `''` is falsy, so that expression always returns `'production'`. If a trial run in the PR shows that `environment: ''` does not drop the environment, split it into a `dry-run` job and a `release` job, each with its own `if:` condition.
- **The dry run in a PR runs through the `pull_request` trigger, not `workflow_dispatch`.** GitHub only dispatches a workflow whose file is already on the default branch (`develop`), so a new `release*.yml` file cannot be dispatched from the PR's branch. Each workflow computes `DRY_RUN: ${{ github.event_name == 'pull_request' || inputs.dry_run == true }}`, and every migrate, deploy and upload step has `if: env.DRY_RUN != 'true'`. In a workflow called through `workflow_call`, `github.event_name` is the calling workflow's event, so a dry run of `release.yml` in a PR is a dry run in all three child workflows too. For `workflow_dispatch`, `release.yml` passes `dry_run` down. `workflow_dispatch` with `dry_run` stays, for manual runs after the merge.
- The `pull_request` trigger has a `paths` filter (table above), so the macOS runner only runs when a PR touches iOS or that workflow. PRs from forks get no secrets, and a dry run needs none. The dry run in a PR uses its own `concurrency` group keyed on `github.ref`, so it does not queue with a real release.
- The build number is Unix minutes (assumption 2), computed in the child workflow, so a single run or a run through `release.yml` both give an increasing number.

`vars.API_BASE_URL` is a repository variable, for example `https://stridequest-api.onrender.com/api/v1/`. It is not a secret. A release build always uses `ApiMode.real`, as the current code already does.

A dry run (event `pull_request`, or `dry_run: true`) only builds: no migration, no deploy, no upload. iOS uses `--no-codesign`, Android signs with the debug key. This mode tests the workflow without real secrets.

### Mobile

- `mobile/android/app/build.gradle.kts`: add `signingConfigs.release`, read from environment variables (`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Without the environment variables it falls back to the debug key, so local builds stay as they are.
- `mobile/ios/ExportOptions.plist`: `method: app-store-connect`, `destination: upload`, manual signing with the profile of `huynang.stridequest`. Upload with `xcodebuild -exportArchive` and the App Store Connect API key, Apple's own way, without `altool` and without third-party actions. The workflow overrides the Release configuration's signing in CI only (`CODE_SIGN_STYLE=Manual`, `PROVISIONING_PROFILE_SPECIFIER`). Local Debug signing does not change.

### Skills (`.claude/skills/`)

- `release-api/`, `release-ios/`, `release-android/`, `release/`: one `SKILL.md` each with `disable-model-invocation: true`, so only the user typing the command can run them. The shared steps are in `.claude/skills/release/steps.md`.
- The steps:
  1. Check that the secret and variable names it needs exist with `gh secret list --env production` and `gh variable list` (names only). If one is missing, name its row in "Prerequisites" and stop.
  2. `git fetch origin main --tags`.
  3. Check that CI of the latest commit on `main` is green (`gh run list --branch main`).
  4. Show the latest tag of that prefix and the commits since that tag.
  5. Propose the next version (patch, minor or major by argument; patch by default).
  6. Ask for confirmation of the tag and commit.
  7. `git tag -a <prefix>vX.Y.Z origin/main -m …`, then `git push origin refs/tags/<tag>`. Push only that tag.
  8. `gh run watch` the triggered run and report the result with its link.
- A skill never deletes, overwrites or force-pushes a tag, never pushes a branch, and does not run when `main` has no commit to release.
- `.claude/hooks/block-forbidden-command.sh`: add rules that refuse deleting a remote tag (`git push origin :refs/tags/…`, `git push --delete origin <tag>`) and force-pushing a tag. Pushing a new tag is still allowed. Tests in `.claude/hooks/test-block-forbidden-command.sh`.
- `CLAUDE.md`: add a "Push a release tag" row to the Git and GitHub permissions table: only through `/release`, `/release-api`, `/release-ios` or `/release-android`, typed by the user. Deleting or moving a tag is never allowed.

### Docs

- `docs/deploy.md`: the deploy architecture, the one-time setup steps for Neon, Render, Apple and Firebase, the list of secrets and variables (names only), the backward-compatible migration rule, how to roll back (redeploy an older commit on the Render dashboard; for the apps, ship the older build again), and the free-tier limits.
- `README.md`: add a "Release" section pointing to `docs/deploy.md` and the skills.

### Changes the approval must cover (Phase 2 risk categories)

- **Production and real data:** this is the first production environment. Migrations run on the real database.
- **Cost:** Render free, Neon free, Firebase App Distribution free, GitHub Actions free (public repo). The user already has Apple Developer. The plan adds no cost, but costs may come from going over a free tier or upgrading a plan later.
- **Security boundary:** the app signing secrets, the Apple, Firebase and Render API keys and the database connection string live in the GitHub environment `production`. Workflows may use them only when running from a tag.
- **New core technology:** Render, Neon, Firebase App Distribution.
- **Claude rules:** `CLAUDE.md` and the hook gain the permission to push a release tag through a skill.
- No public API change, no database schema change, no auth change.

## Risks

| Risk | How it is contained |
| --- | --- |
| Secrets leak in logs | No `echo` of a secret, `::add-mask::` for decoded values, temporary files in `$RUNNER_TEMP` deleted in an `always()` step. Workflows run from a (fork) PR have no access to the `production` environment. |
| A migration fails halfway | Each Alembic migration runs in a PostgreSQL transaction. If the migration fails, the deploy is not called, so the old code keeps running. |
| The new code fails after migrating | Migrations must be backward compatible (assumption 7), then roll back by redeploying the previous version on Render. The workflow fails if `/api/v1/health` does not return 200 within 10 minutes. |
| A tag points at a commit not on `main` | Each workflow runs `git merge-base --is-ancestor "$GITHUB_SHA" origin/main` and stops if it is not (checkout with `fetch-depth: 0`). The environment only accepts tags matching the patterns. |
| Deploying the wrong commit (a new commit reaches `main` during the release) | Call the Render API with `commitId` set to the tag's commit, not a deploy hook (a hook always builds the branch's latest commit). The deployed code is exactly the code that just ran the migrations. |
| The first release PR into `main` is very large (about 460 commits), and `main` has no `.claude/`, so Claude's review and security scan on GitHub may not run, since they read their rules from the base branch | The user reviews and merges this PR themself (row 0 of Prerequisites). The PR only holds code already reviewed and passed through CI on `develop`. Claude opens the PR only when the user asks in chat, and does not merge a PR into `main` unless the user authorizes that PR. |
| A duplicate or lower build number on App Store Connect | The build number is Unix minutes (assumption 2), not `run_number`. |
| A change of Xcode on the runner breaks the build or upload | Pin the Xcode version in the workflow, and upload with `xcodebuild -exportArchive`, not `altool`. |
| Losing the Android release keystore | `docs/deploy.md` tells the user to keep the keystore and passwords somewhere safe outside GitHub. Without the keystore the app cannot be updated on Google Play later. |
| The iOS certificate or profile expires (1 year) | The workflow fails with a clear error. `docs/deploy.md` has the renewal steps. |
| The Android release build fails because of R8 or proguard (`health`, `flutter_secure_storage`) | Task 4 installs the release build on a real device and checks reading steps and signing in. Add proguard rules if needed. |
| Going over the free tier (Neon 0.5 GB, Render 750 hours/month) | One service does not exceed 750 hours. `docs/deploy.md` says how to check storage on Neon. |
| A cold start makes the first request time out | Accepted in assumption 1. Written in `docs/deploy.md`. |

## Verification

- **In the PR:** `actionlint` for every new workflow; `docker build` and `docker run` of the image with the `docker compose` database, then `curl /api/v1/health`; each PR runs its own dry run through the `pull_request` trigger for the workflow it adds (green build, no deploy or upload; run link recorded in Evidence); `bash .claude/hooks/test-block-forbidden-command.sh`.
- **Order before the first release:** the 5 tasks merge into `develop`, then the release PR `develop` → `main` merges (Prerequisites row 0), then the user enters the secrets (rows 1–6), and only then `/release-api` runs. Check that `main` has the workflows: `git ls-tree --name-only origin/main .github/workflows/` lists `release-api.yml`, `release-ios.yml`, `release-android.yml` and `release.yml`.
- **After merging to `main` and the user has entered the secrets:** `/release-api` creates `api-v0.1.0`, then check Render is live, `curl https://…/api/v1/health` returns 200, and sign up/sign in through `hurl` against the production URL. `/release-ios`: the build appears on TestFlight, installs on an iPhone, signs in and reads steps from Apple Health. `/release-android`: the tester gets the Firebase email, installs the APK, signs in and reads Health Connect. `/release` with `v0.1.1`: all three jobs green, in the right order.
- **Not verifiable in the PR:** the real deploy, upload and signing, because they need the user's secrets and a tag on `main`. This is recorded as `Not verified: needs production secrets and a tag on main` in Evidence and is checked at the first release.

## Ticket evidence

Ticket type: chore/tooling. The evidence needed is the scope of the change and what must stay unchanged. Must stay unchanged: running locally (`docker compose`, `flutter run` pointing at localhost, debug signing), the existing CI checks (`backend-ci.yml`, `mobile-ci.yml`), and the behavior of the app and the API. No images needed.

## Task breakdown

One task is one issue. The plan has no new backend endpoint.

Order: 1, 3 and 4 start at once, in parallel. 1 → 2. Task 5 waits for 2, 3 and 4.

### Task 1: `[infra] chore: backend Docker image for production`

**Requirements**

- The image runs on Render: it listens on `$PORT`, runs as a non-root user, and contains no `.env` or tests.
- No change to the code in `backend/app/`.

**Steps**

1. Add `backend/Dockerfile` and `backend/.dockerignore` as in the Approach.
2. Add a `docker build backend` step to `.github/workflows/backend-ci.yml`, running only when `backend/` changes (by the existing filter).
3. Create `docs/deploy.md` with a "Backend image" section: how to build, how to run it locally with the compose database, and the environment variables it needs.
4. Try it: `docker build`, then `docker run` with `DATABASE_URL` pointing at the compose database, then `curl /api/v1/health`.

**Checklist**

- [ ] `backend/Dockerfile` (python:3.12-slim, non-root, `uvicorn … --port ${PORT:-8000} --proxy-headers`) and `backend/.dockerignore` (excludes `.env`, `tests/`, `demo/`, `hurl/`)
- [ ] `docker build` passes and the container answers `GET /api/v1/health` with 200 against the compose database (output in Evidence)
- [ ] `backend-ci.yml` builds the image when `backend/` changes
- [ ] `docs/deploy.md` created with the "Backend image" section
- [ ] `ruff check .`, `ruff format --check .`, `mypy` and the full `pytest` pass

### Task 2: `[infra] chore: API release workflow to Render with Neon migrations`

**Requirements**

- Order: the migration runs first, the deploy after. If the migration fails, there is no deploy.
- Runs only from a tag on `main`, or as a dry run (event `pull_request`, or `workflow_dispatch` with `dry_run`).
- Secrets live only in the `production` environment and never appear in logs.

**Steps**

1. Add `render.yaml` at the root (free, singapore, docker, `rootDir: backend`, `autoDeploy: false`, `healthCheckPath: /api/v1/health`, the variables `sync: false`).
2. Add `.github/workflows/release-api.yml` with the triggers `push.tags: ['api-v*']`, `workflow_call`, `workflow_dispatch` (input `dry_run`) and `pull_request` (paths `.github/workflows/release-api.yml`, `render.yaml`, `backend/Dockerfile`), checkout with `fetch-depth: 0`, `environment: ${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`, `concurrency: release-api` (the dry run in a PR uses its own group keyed on `github.ref`).
3. The steps: check the tag is on main; run ruff, mypy and the unit tests; `alembic upgrade head` with `DATABASE_URL=${{ secrets.NEON_DATABASE_URL }}`; `POST https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys` with body `{"commitId": "$GITHUB_SHA"}` to get `deploy.id`; poll `GET https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys/<id>` until `live` (fail on `build_failed`, `update_failed` or after 10 minutes); `curl` the health of `vars.API_BASE_URL`.
4. Add to `docs/deploy.md`: the Neon and Render setup steps, the secret names, the backward-compatible migration rule, how to roll back.
5. Run `actionlint`; push the branch and open the PR so the `pull_request` trigger runs the dry run.

**Checklist**

- [ ] `render.yaml` with a free Docker web service, `autoDeploy: false` and `healthCheckPath: /api/v1/health`; no secret values in the file
- [ ] `.github/workflows/release-api.yml`: tag `api-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`
- [ ] The workflow stops when the tag's commit is not on `origin/main` (checkout with `fetch-depth: 0`)
- [ ] `alembic upgrade head` runs before the Render deploy, and a failed migration skips the deploy
- [ ] The workflow starts the deploy with `POST /v1/services/{serviceId}/deploys` and `commitId` set to the tag's commit (no deploy hook), then waits for that deploy to be `live` and for `/api/v1/health` to return 200, and fails after 10 minutes
- [ ] `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)
- [ ] `docs/deploy.md`: Neon and Render setup, secret names, backward-compatible migration rule, rollback
- [ ] Evidence: real deploy `Not verified: needs production secrets and a tag on main`

### Task 3: `[infra] chore: iOS release workflow to TestFlight`

**Requirements**

- The build runs on a `macos` runner with a pinned Xcode version, using the same Flutter version as `mobile-ci.yml`.
- Upload with `xcodebuild -exportArchive` (`destination: upload`) and the App Store Connect API key. No `altool` (it may be removed in newer Xcode), no `notarytool` (it only notarizes macOS apps), no third-party action.
- Local Debug signing and `Runner.xcodeproj` do not change. Manual signing applies only in CI.
- The keychain and temporary files are deleted in an `always()` step.

**Steps**

1. Add `mobile/ios/ExportOptions.plist` (`app-store-connect`, `destination: upload`, team `KHAR8S7L52`, the profile of `huynang.stridequest`).
2. Add `.github/workflows/release-ios.yml` with the triggers `ios-v*`, `workflow_call`, `workflow_dispatch` (`dry_run`) and `pull_request` (paths `.github/workflows/release-ios.yml`, `mobile/ios/**`), checkout with `fetch-depth: 0`, `environment: ${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`.
3. The steps: check the tag is on main; pin the Xcode version (`sudo xcode-select -s /Applications/Xcode_<version>.app`); install Flutter; `flutter pub get` and `pod install`; create a temporary keychain, import the `.p12` and the profile; compute `BUILD_NUMBER=$(( $(date +%s) / 60 ))`; `flutter build ipa --release --build-name --build-number=$BUILD_NUMBER --dart-define=API_BASE_URL` with the manual signing override, making `build/ios/archive/Runner.xcarchive`; `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportOptionsPlist ios/ExportOptions.plist -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …` to upload to TestFlight; clean up the keychain and the `.p8` file.
4. On a dry run (event `pull_request` or `dry_run`): run `flutter build ios --release --no-codesign` and do not upload.
5. Add to `docs/deploy.md`: creating the app record, the API key, the distribution certificate and the profile; how to base64-encode them for the secrets; how to invite TestFlight testers; how to renew the certificate.

**Checklist**

- [ ] `mobile/ios/ExportOptions.plist` for `app-store-connect` with team `KHAR8S7L52` and `destination: upload`; the upload uses `xcodebuild -exportArchive` with the App Store Connect API key (no `altool`), on a pinned Xcode version
- [ ] `.github/workflows/release-ios.yml`: tag `ios-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`; stops when the tag is not on `origin/main` (checkout with `fetch-depth: 0`)
- [ ] Build uses `--build-name` from the tag, `--build-number=$(( $(date +%s) / 60 ))` (Unix minutes) and `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`
- [ ] The temporary keychain, certificate and key files are deleted in an `always()` step; no secret is echoed
- [ ] Local Debug signing and `Runner.xcodeproj` unchanged; `flutter analyze` and `flutter test` pass
- [ ] `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)
- [ ] `docs/deploy.md`: App Store Connect app, API key, certificate and profile setup, secret names, TestFlight testers, renewal
- [ ] Evidence: real TestFlight upload `Not verified: needs production secrets and a tag on main`

### Task 4: `[infra] chore: Android release workflow to Firebase App Distribution`

**Requirements**

- The release build is signed with the release keystore from environment variables. Without the variables it falls back to the debug key, as now.
- The keystore is never committed. `*.jks` and `*.keystore` are in `.gitignore`.

**Steps**

1. Change `mobile/android/app/build.gradle.kts`: add `signingConfigs.release` reading `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`; the `release` buildType uses this config when `ANDROID_KEYSTORE_PATH` is set, and `debug` otherwise.
2. Add `.github/workflows/release-android.yml` with the triggers `android-v*`, `workflow_call`, `workflow_dispatch` (`dry_run`) and `pull_request` (paths `.github/workflows/release-android.yml`, `mobile/android/**`), checkout with `fetch-depth: 0`, `environment: ${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`.
3. The steps: check the tag is on main; install Java and Flutter; decode the keystore into `$RUNNER_TEMP`; compute `BUILD_NUMBER=$(( $(date +%s) / 60 ))`; `flutter build apk --release --build-name --build-number=$BUILD_NUMBER --dart-define=API_BASE_URL`; `npx firebase-tools appdistribution:distribute` to the `testers` group; delete the keystore.
4. Install the release build on an Android emulator (API 34+, with Health Connect) or a real device (locally, debug-signed, pointing at the local backend), check signing in and reading Health Connect, and add proguard rules if needed.
5. Add to `docs/deploy.md`: creating the keystore and keeping it safe, creating the Firebase project, app and `testers` group, the service account, the secret names.

**Checklist**

- [ ] `build.gradle.kts` signs `release` with the keystore from `ANDROID_KEYSTORE_*` env vars and falls back to the debug key without them
- [ ] `*.jks` and `*.keystore` in `.gitignore`; no keystore in the diff
- [ ] `.github/workflows/release-android.yml`: tag `android-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' || '' }}`; stops when the tag is not on `origin/main` (checkout with `fetch-depth: 0`)
- [ ] Build uses `--build-name` from the tag, `--build-number=$(( $(date +%s) / 60 ))` (Unix minutes) and `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`; uploads to Firebase App Distribution group `testers`
- [ ] A release build installed on an Android emulator (API 34+, Health Connect) or a real device signs in and reads Health Connect steps (screenshot in Evidence)
- [ ] `flutter analyze` and `flutter test` pass; `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)
- [ ] `docs/deploy.md`: keystore creation and backup, Firebase project, app, `testers` group, service account, secret names
- [ ] Evidence: real Firebase upload `Not verified: needs production secrets and a tag on main`

### Task 5: `[infra] chore: full release workflow and release skills`

**Requirements**

- A skill runs only when the user types its command (`disable-model-invocation: true`), and asks for confirmation of the tag before pushing.
- A skill pushes exactly one new tag. It never pushes a branch, and never deletes, moves or forces a tag.
- Order in `/release`: the API is live first, then iOS and Android.

**Steps**

1. Add `.github/workflows/release.yml` with the triggers `v*`, `workflow_dispatch` and `pull_request` (path `.github/workflows/release.yml`, always a dry run): job `api` calls `release-api.yml`; jobs `ios` and `android` have `needs: api` and call their workflows; all use `secrets: inherit`.
2. Add `.claude/skills/release/SKILL.md` and `.claude/skills/release/steps.md` (the shared steps), and `release-api/SKILL.md`, `release-ios/SKILL.md` and `release-android/SKILL.md`, each with its own tag prefix and a `patch|minor|major` argument.
3. Change `.claude/hooks/block-forbidden-command.sh` to refuse deleting a remote tag and force-pushing a tag, and add tests to `.claude/hooks/test-block-forbidden-command.sh` (pushing a new tag is allowed; `:refs/tags/x`, `--delete` and `-f` with a tag are refused).
4. Change `CLAUDE.md`: add the "Push a release tag" row to the permissions table. Change `README.md`: add a "Release" section. Add a "Releasing" section to `docs/deploy.md`.
5. Run `actionlint`, the hook tests, and the dry run of `release.yml` through the PR's `pull_request` trigger.

**Checklist**

- [ ] `.github/workflows/release.yml`: tag `v*`, `workflow_dispatch`, and `pull_request` (always a dry run, passed to the called workflows); `ios` and `android` jobs `needs: api`; `secrets: inherit`
- [ ] Skills `release`, `release-api`, `release-ios`, `release-android` with `disable-model-invocation: true` and shared `.claude/skills/release/steps.md`
- [ ] Each skill checks that the secret and variable names it needs exist (`gh secret list --env production`, `gh variable list`, names only) and names the missing Prerequisites row, checks that `main` CI is green, shows the commits since the last tag, asks to confirm the tag, pushes only `refs/tags/<tag>`, and reports the run link
- [ ] `block-forbidden-command.sh` refuses deleting a remote tag and force-pushing a tag; tests added and `bash .claude/hooks/test-block-forbidden-command.sh` passes
- [ ] `CLAUDE.md` permission table has the "Push a release tag" row; `README.md` has a "Release" section; `docs/deploy.md` has "Releasing"
- [ ] `actionlint` passes; the `pull_request` dry run of `release.yml` on the PR is green with `api` before `ios` and `android` (link in Evidence)

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] chore: backend Docker image for production` | chore, area:infra | - [ ] `backend/Dockerfile` (python:3.12-slim, non-root, `uvicorn … --port ${PORT:-8000} --proxy-headers`) and `backend/.dockerignore` (excludes `.env`, `tests/`, `demo/`, `hurl/`)<br>- [ ] `docker build` passes and the container answers `GET /api/v1/health` with 200 against the compose database (output in Evidence)<br>- [ ] `backend-ci.yml` builds the image when `backend/` changes<br>- [ ] `docs/deploy.md` created with the "Backend image" section<br>- [ ] `ruff check .`, `ruff format --check .`, `mypy` and the full `pytest` pass | none |
| 2 | `[infra] chore: API release workflow to Render with Neon migrations` | chore, area:infra, human-merge | - [ ] `render.yaml` with a free Docker web service, `autoDeploy: false` and `healthCheckPath: /api/v1/health`; no secret values in the file<br>- [ ] `.github/workflows/release-api.yml`: tag `api-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' \|\| '' }}`<br>- [ ] The workflow stops when the tag's commit is not on `origin/main` (checkout with `fetch-depth: 0`)<br>- [ ] `alembic upgrade head` runs before the Render deploy, and a failed migration skips the deploy<br>- [ ] The workflow starts the deploy with `POST /v1/services/{serviceId}/deploys` and `commitId` set to the tag's commit (no deploy hook), then waits for that deploy to be `live` and for `/api/v1/health` to return 200, and fails after 10 minutes<br>- [ ] `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)<br>- [ ] `docs/deploy.md`: Neon and Render setup, secret names, backward-compatible migration rule, rollback<br>- [ ] Evidence: real deploy `Not verified: needs production secrets and a tag on main` | 1 |
| 3 | `[infra] chore: iOS release workflow to TestFlight` | chore, area:infra, human-merge | - [ ] `mobile/ios/ExportOptions.plist` for `app-store-connect` with team `KHAR8S7L52` and `destination: upload`; the upload uses `xcodebuild -exportArchive` with the App Store Connect API key (no `altool`), on a pinned Xcode version<br>- [ ] `.github/workflows/release-ios.yml`: tag `ios-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' \|\| '' }}`; stops when the tag is not on `origin/main` (checkout with `fetch-depth: 0`)<br>- [ ] Build uses `--build-name` from the tag, `--build-number=$(( $(date +%s) / 60 ))` (Unix minutes) and `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`<br>- [ ] The temporary keychain, certificate and key files are deleted in an `always()` step; no secret is echoed<br>- [ ] Local Debug signing and `Runner.xcodeproj` unchanged; `flutter analyze` and `flutter test` pass<br>- [ ] `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)<br>- [ ] `docs/deploy.md`: App Store Connect app, API key, certificate and profile setup, secret names, TestFlight testers, renewal<br>- [ ] Evidence: real TestFlight upload `Not verified: needs production secrets and a tag on main` | none |
| 4 | `[infra] chore: Android release workflow to Firebase App Distribution` | chore, area:infra, human-merge | - [ ] `build.gradle.kts` signs `release` with the keystore from `ANDROID_KEYSTORE_*` env vars and falls back to the debug key without them<br>- [ ] `*.jks` and `*.keystore` in `.gitignore`; no keystore in the diff<br>- [ ] `.github/workflows/release-android.yml`: tag `android-v*`, `workflow_call`, `workflow_dispatch` with `dry_run`, and `pull_request` with a `paths` filter that always runs as a dry run; environment `${{ github.event_name != 'pull_request' && !inputs.dry_run && 'production' \|\| '' }}`; stops when the tag is not on `origin/main` (checkout with `fetch-depth: 0`)<br>- [ ] Build uses `--build-name` from the tag, `--build-number=$(( $(date +%s) / 60 ))` (Unix minutes) and `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`; uploads to Firebase App Distribution group `testers`<br>- [ ] A release build installed on an Android emulator (API 34+, Health Connect) or a real device signs in and reads Health Connect steps (screenshot in Evidence)<br>- [ ] `flutter analyze` and `flutter test` pass; `actionlint` passes; the `pull_request` dry run on the PR is green (link in Evidence)<br>- [ ] `docs/deploy.md`: keystore creation and backup, Firebase project, app, `testers` group, service account, secret names<br>- [ ] Evidence: real Firebase upload `Not verified: needs production secrets and a tag on main` | none |
| 5 | `[infra] chore: full release workflow and release skills` | chore, area:infra, human-merge | - [ ] `.github/workflows/release.yml`: tag `v*`, `workflow_dispatch`, and `pull_request` (always a dry run, passed to the called workflows); `ios` and `android` jobs `needs: api`; `secrets: inherit`<br>- [ ] Skills `release`, `release-api`, `release-ios`, `release-android` with `disable-model-invocation: true` and shared `.claude/skills/release/steps.md`<br>- [ ] Each skill checks that the secret and variable names it needs exist (`gh secret list --env production`, `gh variable list`, names only) and names the missing Prerequisites row, checks that `main` CI is green, shows the commits since the last tag, asks to confirm the tag, pushes only `refs/tags/<tag>`, and reports the run link<br>- [ ] `block-forbidden-command.sh` refuses deleting a remote tag and force-pushing a tag; tests added and `bash .claude/hooks/test-block-forbidden-command.sh` passes<br>- [ ] `CLAUDE.md` permission table has the "Push a release tag" row; `README.md` has a "Release" section; `docs/deploy.md` has "Releasing"<br>- [ ] `actionlint` passes; the `pull_request` dry run of `release.yml` on the PR is green with `api` before `ios` and `android` (link in Evidence) | 2, 3, 4 |
