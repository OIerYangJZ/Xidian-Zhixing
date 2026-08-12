#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "[install] run as root" >&2
  exit 1
fi

ARCHIVE_PATH="${1:-}"
NGINX_CONFIG_PATH="${2:-}"
if [ -z "$ARCHIVE_PATH" ] || [ ! -f "$ARCHIVE_PATH" ] \
  || [ -z "$NGINX_CONFIG_PATH" ] || [ ! -f "$NGINX_CONFIG_PATH" ]; then
  echo "[install] usage: install_ubuntu_offline.sh /path/to/treehole-release.tar.gz /path/to/rendered-tls-nginx.conf" >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*listen[[:space:]]+443[[:space:]]+ssl([[:space:]]|;)' "$NGINX_CONFIG_PATH"; then
  echo "[install] nginx config must contain an active 'listen 443 ssl' directive" >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*listen[[:space:]]+80([[:space:]]|;)' "$NGINX_CONFIG_PATH" \
  || ! grep -Eq 'return[[:space:]]+30[18][[:space:]]+https://' "$NGINX_CONFIG_PATH"; then
  echo "[install] nginx config must redirect HTTP port 80 to HTTPS" >&2
  exit 1
fi

APP_DIR="/home/ubuntu/treehole"
APP_USER="treehole"
RELEASES_DIR="$APP_DIR/releases"
SHARED_DIR="$APP_DIR/shared"
CURRENT_LINK="$APP_DIR/current"
ENV_FILE="$SHARED_DIR/config/backend.env"
VENV_DIR="$SHARED_DIR/venv"
WHEEL_DIR="$APP_DIR/offline/wheels-cp310-manylinux-x86_64"
RELEASE_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"

for command in python3 tar nginx runuser systemctl sha256sum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "[install] missing $command; install the verified offline deb bundle first" >&2
    exit 1
  }
done
python3 - <<'PY'
import sys
if sys.version_info[:2] != (3, 10):
    raise SystemExit("[install] Ubuntu target must provide CPython 3.10")
PY

if [ ! -f "$WHEEL_DIR/SHA256SUMS" ]; then
  echo "[install] wheel bundle missing: $WHEEL_DIR/SHA256SUMS" >&2
  exit 1
fi
(
  cd "$WHEEL_DIR"
  sha256sum --check SHA256SUMS
)

python3 - "$ARCHIVE_PATH" <<'PY'
import sys
import tarfile
from pathlib import PurePosixPath

with tarfile.open(sys.argv[1], "r:gz") as archive:
    for member in archive.getmembers():
        name = member.name
        while name.startswith("./"):
            name = name[2:]
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"[install] unsafe archive path: {member.name}")
        if member.issym() or member.islnk() or member.isdev():
            raise SystemExit(f"[install] unsupported archive member: {member.name}")
PY

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi
install -d -m 0755 "$APP_DIR" "$RELEASES_DIR"
install -d -m 0750 -o "$APP_USER" -g "$APP_USER" \
  "$SHARED_DIR/data" "$SHARED_DIR/storage/objects" "$SHARED_DIR/config"

if [ ! -f "$ENV_FILE" ]; then
  python3 - "$ARCHIVE_PATH" "$ENV_FILE" <<'PY'
import sys
import tarfile
from pathlib import Path

archive_path, output_path = sys.argv[1:]
with tarfile.open(archive_path, "r:gz") as archive:
    member = next(
        (item for item in archive.getmembers()
         if item.name.lstrip("./") == "deploy/tencent/backend.env.example"),
        None,
    )
    if member is None or not member.isfile():
        raise SystemExit("[install] backend environment template is missing from the archive")
    handle = archive.extractfile(member)
    if handle is None:
        raise SystemExit("[install] cannot read backend environment template")
    Path(output_path).write_bytes(handle.read())
PY
  chown root:"$APP_USER" "$ENV_FILE"
  chmod 0640 "$ENV_FILE"
  echo "[install] created protected environment template: $ENV_FILE" >&2
  echo "[install] fill all placeholders, then run this installer again" >&2
  exit 3
fi
chown root:"$APP_USER" "$ENV_FILE"
chmod 0640 "$ENV_FILE"
python3 "$(dirname "$0")/validate_production_env.py" "$ENV_FILE"

if [ -e "$RELEASE_DIR" ]; then
  echo "[install] release directory already exists: $RELEASE_DIR" >&2
  exit 1
fi
install -d -m 0755 "$RELEASE_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$RELEASE_DIR"
python3 "$RELEASE_DIR/scripts/verify_release_archive.py" "$ARCHIVE_PATH"
chmod -R a+rX "$RELEASE_DIR"
if ! id -u www-data >/dev/null 2>&1; then
  echo "[install] nginx runtime user www-data is missing" >&2
  exit 1
fi
runuser -u "$APP_USER" -- test -r "$RELEASE_DIR/backend/server.py"
if ! runuser -u www-data -- test -r "$RELEASE_DIR/web/index.html"; then
  echo "[install] www-data cannot traverse /home/ubuntu and read the Web release" >&2
  echo "[install] adjust directory execute permissions deliberately before retrying" >&2
  exit 1
fi

if [ ! -x "$VENV_DIR/bin/python" ]; then
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install \
  --no-index \
  --find-links "$WHEEL_DIR" \
  -r "$RELEASE_DIR/backend/requirements-storage.txt" \
  -r "$RELEASE_DIR/backend/requirements-auth.txt"
# cryptography is required by the campus-service login (RSA of the school login
# page); without it those endpoints fail at runtime, not at startup.
"$VENV_DIR/bin/python" -c 'import boto3, PIL, requests, cryptography'
chown -R root:"$APP_USER" "$VENV_DIR"
chmod -R g+rX,o-rwx "$VENV_DIR"

install -m 0644 "$RELEASE_DIR/deploy/tencent/xdu-whisperbox.service" \
  /etc/systemd/system/treehole.service
install -m 0644 "$NGINX_CONFIG_PATH" \
  /etc/nginx/sites-available/treehole.conf
ln -sfn /etc/nginx/sites-available/treehole.conf /etc/nginx/sites-enabled/treehole.conf
rm -f /etc/nginx/sites-enabled/default

PREVIOUS_RELEASE=""
if [ -L "$CURRENT_LINK" ]; then
  PREVIOUS_RELEASE="$(readlink -f "$CURRENT_LINK")"
fi

restore_previous_release() {
  if [ -n "$PREVIOUS_RELEASE" ]; then
    ln -sfn "$PREVIOUS_RELEASE" "$CURRENT_LINK"
  else
    rm -f "$CURRENT_LINK"
  fi
  set +e
  systemctl restart treehole
  treehole_status=$?
  systemctl restart nginx
  nginx_status=$?
  set -e
  if [ "$treehole_status" -ne 0 ] || [ "$nginx_status" -ne 0 ]; then
    echo "[install] rollback activation also failed; manual recovery is required" >&2
    return 1
  fi
  return 0
}

ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
nginx -t
systemctl daemon-reload
systemctl enable treehole
systemctl enable nginx
if ! systemctl restart treehole || ! systemctl restart nginx; then
  restore_previous_release
  echo "[install] service activation failed; previous release restored when available" >&2
  exit 1
fi

for _ in $(seq 1 15); do
  if "$VENV_DIR/bin/python" - <<'PY'
import urllib.request
urllib.request.urlopen("http://127.0.0.1:8080/api/channels", timeout=2).read()
PY
  then
    echo "[install] deployment activated: $RELEASE_DIR"
    exit 0
  fi
  sleep 1
done

echo "[install] backend health check failed; inspect journalctl -u treehole" >&2
if [ -n "$PREVIOUS_RELEASE" ]; then
  restore_previous_release
  echo "[install] previous release restored: $PREVIOUS_RELEASE" >&2
else
  restore_previous_release
fi
exit 1
