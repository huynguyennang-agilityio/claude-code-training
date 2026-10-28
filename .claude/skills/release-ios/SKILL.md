---
name: release-ios
description: Release the StrideQuest iOS app from main to TestFlight by pushing one tag ios-vX.Y.Z after the user confirms it. Run by the user as /release-ios [patch|minor|major].
disable-model-invocation: true
---

# Release iOS

Follow [`../release/steps.md`](../release/steps.md) with:

- **Prefix:** `ios-v` (tags `ios-vX.Y.Z`).
- **Workflow:** `release-ios.yml`.
- **Names** (rows of "Prerequisites" in [plan 025](../../../docs/plans/025-release-pipeline.md)):

| Name | Kind | Row |
| --- | --- | --- |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8`, `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE` | secret | 4 (Apple) |
| `API_BASE_URL` | variable | 3 (Render) |

The app talks to the API at `API_BASE_URL`. When the release includes app changes that need a newer API, release the API first (`/release-api`), or use `/release` for both.
