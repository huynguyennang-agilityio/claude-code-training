---
name: release-api
description: Release the StrideQuest API from main - migrate Neon, then deploy the same commit on Render - by pushing one tag api-vX.Y.Z after the user confirms it. Run by the user as /release-api [patch|minor|major].
disable-model-invocation: true
---

# Release the API

Follow [`../release/steps.md`](../release/steps.md) with:

- **Prefix:** `api-v` (tags `api-vX.Y.Z`).
- **Workflow:** `release-api.yml`.
- **Names** (rows of "Prerequisites" in [plan 025](../../../docs/plans/025-release-pipeline.md)):

| Name | Kind | Row |
| --- | --- | --- |
| `NEON_DATABASE_URL` | secret | 2 (Neon) |
| `RENDER_API_KEY`, `RENDER_SERVICE_ID` | secret | 3 (Render) |
| `API_BASE_URL` | variable | 3 (Render) |

Before step 6, show the migrations that will run: `git diff --name-only <last tag>..origin/main -- backend/alembic/versions/` (all of them when there is no tag yet). They must be backward compatible ("Migrations must be backward compatible" in `docs/deploy.md`); when one drops or renames a column, say so in the confirmation question.
