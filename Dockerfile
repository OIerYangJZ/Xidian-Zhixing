# syntax=docker/dockerfile:1
FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    BACKEND_HOST=0.0.0.0 \
    BACKEND_PORT=8080 \
    BACKEND_DB_FILE=/app/data/treehole.db \
    BACKEND_STORAGE_DIR=/app/storage/objects \
    BACKEND_WEB_ROOT=/app/web \
    BACKEND_OBJECT_STORAGE_BACKEND=local \
    BACKEND_ALLOW_DEBUG_VERIFY_CODE=false \
    BACKEND_INCLUDE_DEBUG_CODE=false

WORKDIR /app

COPY backend/requirements-storage.txt /tmp/requirements-storage.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements-storage.txt \
    && rm -f /tmp/requirements-storage.txt \
    && groupadd --system treehole \
    && useradd --system --gid treehole --home-dir /app --shell /usr/sbin/nologin treehole

COPY --chown=treehole:treehole backend/server.py backend/_globals.py backend/object_storage.py backend/sql_repository.py /app/backend/
COPY --chown=treehole:treehole backend/handlers/ /app/backend/handlers/
COPY --chown=treehole:treehole backend/helpers/ /app/backend/helpers/
COPY --chown=treehole:treehole backend/services/ /app/backend/services/

RUN install -d -o treehole -g treehole /app/data /app/storage/objects

USER treehole

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/api/channels', timeout=4).read()"]

EXPOSE 8080

CMD ["python3", "backend/server.py"]
