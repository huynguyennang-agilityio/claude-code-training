---
name: release-android
description: Release the StrideQuest Android app from main to Firebase App Distribution by pushing one tag android-vX.Y.Z after the user confirms it. Run by the user as /release-android [patch|minor|major].
disable-model-invocation: true
---

# Release Android

Follow [`../release/steps.md`](../release/steps.md) with:

- **Prefix:** `android-v` (tags `android-vX.Y.Z`).
- **Workflow:** `release-android.yml`.
- **Names** (rows of "Prerequisites" in [plan 025](../../../docs/plans/025-release-pipeline.md)):

| Name | Kind | Row |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | secret | 5 (Android keystore) |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | secret | 6 (Firebase) |
| `API_BASE_URL` | variable | 3 (Render) |

The app talks to the API at `API_BASE_URL`. When the release includes app changes that need a newer API, release the API first (`/release-api`), or use `/release` for both.
