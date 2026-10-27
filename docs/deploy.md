# Deploy

How StrideQuest is built and released. The plan is [plan 025](plans/025-release-pipeline.md): the API on Render with a Neon database, iOS on TestFlight and Android on Firebase App Distribution, all released from GitHub Actions. Later tasks of that plan add the sections for each of them.

## Backend image

`backend/Dockerfile` builds the production image of the API: `python:3.12-slim`, the packages in `backend/requirements.txt`, a non-root user (`app`, uid 10001), and `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers`. The image also holds `alembic/` and `alembic.ini`, so migrations can run from it. `backend/.dockerignore` keeps `.env`, `tests/`, `demo/`, `hurl/`, caches and the venv out of it.

The `backend` CI job (`.github/workflows/backend-ci.yml`) builds the image whenever `backend/` changes, so a PR that breaks it fails.

### Build

```bash
docker build -t stridequest-api backend
```

### Run locally with the compose database

Start the database with `docker compose up -d db`. The container cannot reach `localhost` of the host, so point `DATABASE_URL` at `host.docker.internal`. Docker Desktop resolves that name; on Docker Engine for Linux, add `--add-host=host.docker.internal:host-gateway` to each `docker run` below:

```bash
docker run --rm -p 8000:8000 \
  -e DATABASE_URL='postgresql+asyncpg://<user>:<password>@host.docker.internal:5432/<db>' \
  -e JWT_SECRET='<any local secret>' \
  stridequest-api
curl -i http://localhost:8000/api/v1/health
```

Run the migrations from the same image with the same `DATABASE_URL`:

```bash
docker run --rm -e DATABASE_URL='…' stridequest-api alembic upgrade head
```

### Environment variables

| Variable | Required | Notes |
| --- | --- | --- |
| `DATABASE_URL` | yes | `postgresql+asyncpg://…`; the only one Alembic needs |
| `JWT_SECRET` | yes | a long random string, for example `openssl rand -hex 32` |
| `PORT` | no | the port uvicorn listens on, `8000` by default; Render sets it |
| `FORWARDED_ALLOW_IPS` | behind a proxy | the proxy addresses uvicorn trusts for `X-Forwarded-For` (`127.0.0.1` by default). The sign-in rate limit counts failed attempts per client IP, so behind Render's proxy this must name the proxy, or every client shares the proxy's IP and 20 failed sign-ins lock out everyone. Never `*`: then uvicorn takes the leftmost `X-Forwarded-For` entry, which the client controls. The value for Render is set in `render.yaml` with the API release task (#151) |
| `ACCESS_TOKEN_TTL_MINUTES` | no | `15` by default |
| `REFRESH_TOKEN_TTL_DAYS` | no | `30` by default |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | no | needed only for image uploads ([ADR 0003](adr/0003-cloudinary-for-images.md)) |
| `CLOUDINARY_FOLDER` | no | `stridequest` by default |

Never bake a value into the image or commit it: set them on the host (Render's dashboard in production).

## iOS release (TestFlight)

`.github/workflows/release-ios.yml` builds the app on a `macos-15` runner with a pinned Xcode (`XCODE_APP` in the workflow) and the same Flutter version as `mobile-ci.yml`, then uploads it to TestFlight. It runs on a tag `ios-vX.Y.Z` on `main`, from `release.yml` for a tag `vX.Y.Z`, by hand (`workflow_dispatch`, a dry run by default), and on every PR into `develop` that changes the workflow or `mobile/ios/` (always a dry run). A dry run runs `flutter build ios --release --no-codesign` and uploads nothing, so it needs no secret.

- **Version:** `--build-name` is `X.Y.Z` from the tag; `--build-number` is Unix minutes, `$(( $(date +%s) / 60 ))`, so App Store Connect never sees a duplicate or lower build number.
- **API:** the build passes `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`. A real release fails when the variable is missing.
- **Signing:** the committed project keeps automatic signing for local Debug builds. In CI only, the workflow switches the `Runner` target's Release configuration to manual signing with the distribution certificate and the App Store profile (through the `xcodeproj` gem, so the Pods targets are untouched), imports both into a temporary keychain, and deletes the keychain, the profile and the API key file in an `always()` step.
- **Upload:** Flutter writes the build settings (`flutter build ios --config-only`), `xcodebuild archive` makes `build/ios/archive/Runner.xcarchive`, and `xcodebuild -exportArchive` with `mobile/ios/ExportOptions.plist` (`app-store-connect`, `destination: upload`) and the App Store Connect API key (`-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`) uploads it. No `altool`, no third-party action.

### One-time setup

1. **App record.** In App Store Connect → Apps, create the app with bundle ID `huynang.stridequest` (register the ID first under Certificates, Identifiers & Profiles with the HealthKit capability if it is not there).
2. **API key.** Users and Access → Integrations → App Store Connect API: create a team key with the App Manager role. Note its Key ID and the Issuer ID, and download the `.p8` (it can be downloaded only once).
3. **Distribution certificate.** In Certificates, create an Apple Distribution certificate from a CSR made in Keychain Access, install it, and export it with its private key as a `.p12` with a password.
4. **Provisioning profile.** In Profiles, create an App Store Connect profile for `huynang.stridequest` with that certificate, and download the `.mobileprovision`. The workflow reads the profile's UUID, so its name is free.
5. **Secrets** in the GitHub environment `production` (names only; enter the values yourself on GitHub or with `gh secret set <NAME> --env production`). Encode a file with `base64 -i <file> | pbcopy`:

   | Secret | Value |
   | --- | --- |
   | `APP_STORE_CONNECT_KEY_ID` | the Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID |
   | `APP_STORE_CONNECT_KEY_P8` | the `.p8`, base64 |
   | `IOS_DIST_CERT_P12` | the `.p12`, base64 |
   | `IOS_DIST_CERT_PASSWORD` | the `.p12` password |
   | `IOS_PROVISIONING_PROFILE` | the `.mobileprovision`, base64 |

   Keep the `.p8`, `.p12` and `.mobileprovision` outside the repo.

### TestFlight testers

Internal testers (members of the App Store Connect team) can install a build as soon as it finishes processing: add them in TestFlight → Internal Testing. External testers need Beta App Review first; submit the build for review in TestFlight → External Testing.

### Renewal

The distribution certificate and the profile expire after a year, and the workflow then fails at signing. Create a new certificate, export a new `.p12`, regenerate the profile with it, and update `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD` and `IOS_PROVISIONING_PROFILE`. When the runner image drops the pinned Xcode, the "Select Xcode" step fails and lists the Xcode versions it has; update `XCODE_APP`.

## Android release (Firebase App Distribution)

`.github/workflows/release-android.yml` builds a release APK and sends it to the `testers` group in Firebase App Distribution. It runs on a tag `android-vX.Y.Z` on `main`, from `release.yml` for a tag `vX.Y.Z`, by hand (`workflow_dispatch`, a dry run by default), and on every PR into `develop` that changes the workflow or `mobile/android/` (always a dry run). A dry run builds the APK signed with the debug key and uploads nothing, so it needs no secret.

- **Version:** `--build-name` is `X.Y.Z` from the tag; `--build-number` is Unix minutes, `$(( $(date +%s) / 60 ))`, so it always increases and stays below Android's `versionCode` limit of 2,100,000,000.
- **API:** the build passes `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`. A real release fails when the variable is missing.
- **Signing:** `mobile/android/app/build.gradle.kts` signs `release` with the keystore at `ANDROID_KEYSTORE_PATH` (with `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Without `ANDROID_KEYSTORE_PATH` it keeps the debug key, so `flutter run --release` works locally. The workflow decodes the keystore into `$RUNNER_TEMP`, checks with `apksigner` that a real release is not debug-signed, and deletes the keystore in an `always()` step.

### One-time setup

1. **Keystore.** Outside the repo, run:

   ```bash
   keytool -genkeypair -v -keystore stridequest-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stridequest
   ```

   Keep the file and both passwords somewhere safe outside GitHub, such as a password manager. Without this keystore the app can never be updated on Google Play later. `*.jks`, `*.keystore`, `*.p12`, `*.p8` and `*.mobileprovision` are git-ignored repo-wide, but don't create them inside the repo.
2. **Firebase.** Create a Firebase project and add an Android app with package `huynang.stridequest`. In App Distribution, create the group `testers` (that exact alias) and add the testers' emails. In Google Cloud IAM, create a service account with the Firebase App Distribution Admin role and download its JSON key.
3. **Secrets** in the GitHub environment `production` (names only; enter the values yourself on GitHub or with `gh secret set <NAME> --env production`):

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | `base64 -i stridequest-release.jks` |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_ALIAS` | `stridequest` |
   | `ANDROID_KEY_PASSWORD` | the key password |
   | `FIREBASE_SERVICE_ACCOUNT_JSON` | the service account's JSON key, as is |
   | `FIREBASE_ANDROID_APP_ID` | the app ID from Firebase project settings (`1:…:android:…`) |

   The repository variable `API_BASE_URL` is set with the API release (plan 025, Prerequisites row 3).

Testers get an email from Firebase and install the APK from the App Distribution page; they need to allow installs from unknown sources.
