# syntax=docker/dockerfile:1

# The base image is pinned by digest, not just a tag, so every build starts from the same
# layers and Dependabot proposes digest updates as reviewable pull requests.

# ---- build stage: install hash-locked dependencies into a virtual environment ----------------
FROM python:3.12-slim-trixie@sha256:78387bc3881b8273120a12ebe6c1ab22b018ccc2c9adf565ae1ac9b536e184ea AS build

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --require-hashes --no-deps -r /tmp/requirements.txt

# ---- runtime stage: only the virtual environment and the application code ---------------------
FROM python:3.12-slim-trixie@sha256:78387bc3881b8273120a12ebe6c1ab22b018ccc2c9adf565ae1ac9b536e184ea AS runtime

# Stamped by CI. BUILD_DATE is the commit timestamp, so the same commit always carries the same
# metadata. The release version is not baked in: it is supplied as configuration when a tested
# image is promoted (APP_VERSION), so promotion never needs a rebuild.
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="rotawell-coverage-api" \
      org.opencontainers.image.source="https://github.com/minhazA0099/rotawell-coverage-api" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GIT_SHA="${GIT_SHA}" \
    BUILD_DATE="${BUILD_DATE}" \
    APP_VERSION="unreleased"

# The pinned base can lag behind Debian security fixes, so apply them here. The image CI scans
# is the one it publishes and later promotes by digest, so what ships is exactly what was scanned.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /srv
COPY --from=build /opt/venv /opt/venv
COPY app ./app

# Unprivileged user. Nothing in the image writes to its own filesystem, so it runs with a
# read-only root filesystem: worker heartbeat files go to /dev/shm and gunicorn's control
# socket (which would need a writable home directory) is disabled.
USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).status == 200 else 1)"]

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--worker-tmp-dir", "/dev/shm", \
     "--no-control-socket", "--access-logfile", "-", "app:create_app()"]
