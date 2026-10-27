---
name: release
description: Release all of StrideQuest at once from main - the API to Render first, then iOS to TestFlight and Android to Firebase App Distribution - by pushing one tag vX.Y.Z after the user confirms it. Run by the user as /release [patch|minor|major].
disable-model-invocation: true
---

# Release everything

Follow [`steps.md`](steps.md) with:

- **Prefix:** `v` (tags `vX.Y.Z`).
- **Workflow:** `release.yml`. It calls `release-api.yml`, then `release-ios.yml` and `release-android.yml` in parallel once the API is live.
- **Names** (rows of "Prerequisites" in [plan 025](../../../docs/plans/025-release-pipeline.md)):

| Name | Kind | Row |
| --- | --- | --- |
| `NEON_DATABASE_URL` | secret | 2 (Neon) |
| `RENDER_API_KEY`, `RENDER_SERVICE_ID` | secret | 3 (Render) |
| `API_BASE_URL` | variable | 3 (Render) |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8`, `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE` | secret | 4 (Apple) |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | secret | 5 (Android keystore) |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | secret | 6 (Firebase) |

In step 4 the last release is the newest tag of any prefix, since `/release` releases every part. The version in step 5 is the next one after the highest of all release tags, as for the other skills.
