# Production image for the StrideQuest API (Render). Plan: docs/plans/025-release-pipeline.md
# Build from backend/: `docker build -t stridequest-api backend`. See docs/deploy.md.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

# alembic/ and alembic.ini ship with the image, so migrations can run from it when needed.
COPY alembic.ini .
COPY alembic ./alembic
COPY app ./app

RUN useradd --create-home --uid 10001 app
USER app

EXPOSE 8000

# Render sets $PORT; locally it defaults to 8000. The shell form expands it.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers
