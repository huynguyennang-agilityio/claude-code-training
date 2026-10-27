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

Start the database with `docker compose up -d db`. The container cannot reach `localhost` of the host, so point `DATABASE_URL` at `host.docker.internal` (Docker Desktop):

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
| `ACCESS_TOKEN_TTL_MINUTES` | no | `15` by default |
| `REFRESH_TOKEN_TTL_DAYS` | no | `30` by default |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | no | needed only for image uploads ([ADR 0003](adr/0003-cloudinary-for-images.md)) |
| `CLOUDINARY_FOLDER` | no | `stridequest` by default |

Never bake a value into the image or commit it: set them on the host (Render's dashboard in production).
