# ADR 0003: Cloudinary for challenge and medal images

- **Status:** Accepted
- **Date:** 2026-10-18
- **Issue:** #60
- **Plan:** [Plan 001](../plans/001-challenges.md)

## Context

[ADR 0001](0001-architecture.md) put medal images in S3-compatible object storage (AWS S3 in production, SeaweedFS in `docker-compose.yml` locally). Nothing used it: the backend only had two unused settings (`S3_ENDPOINT_URL`, `S3_BUCKET`) and no upload code.

Plan 001 adds challenges with a cover image and three medals each, created through an API. The images are delivered to the mobile app on screens of many sizes, and nobody wants to run an image pipeline (resizing, formats, a CDN) by hand. The team already planned to use Cloudinary.

## Decision

Challenge covers and medal images are stored in **Cloudinary**, and S3 and SeaweedFS are removed.

- Only the backend uploads, with **signed** requests that use the API secret. The mobile app never uploads and never sees the secret. No unsigned upload preset exists.
- The database stores the delivery URL (`https://res.cloudinary.com/<cloud>/image/upload/...`), as it stored an object storage URL before.
- Screens ask for the size and format they need through the URL (`f_auto,q_auto,w_<width>`); `app.core.storage.resized_url` builds it.
- `app/core/storage.py` is a small client on `httpx` (async, no global state, no SDK dependency). It raises `StorageError`; the service that handles an upload turns it into a typed `DomainError`.
- The settings `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` and `CLOUDINARY_FOLDER` are optional: the app and its tests start without them, and an upload without them fails with `StorageNotConfiguredError`.

## Consequences

- No local object storage: `docker-compose.yml` has only PostgreSQL. A developer needs a Cloudinary account (the free plan is enough) to upload; everything else works without one.
- Images are served by a third party. Mitigation: the database holds only URLs, so a move to another store means rewriting URLs; originals are kept outside Cloudinary (the demo images live in the repository).
- A quota (storage and monthly credits) applies and can cost money past the free plan.
- Tests never call Cloudinary: they use `httpx.MockTransport`. A real upload is checked by hand once credentials are set.
- `docs/architecture.md`, the README, `CLAUDE.md` and the system-context diagram describe Cloudinary instead of S3.

## Alternatives considered

- **Keep S3 and add a CDN and image resizing:** more parts to run and pay for, for the same result.
- **The official `cloudinary` SDK:** it is blocking and keeps global configuration. A small signed `httpx` call is async and easier to test.
- **Unsigned uploads from the app:** simpler for the app, but anyone with the preset could fill the account.
