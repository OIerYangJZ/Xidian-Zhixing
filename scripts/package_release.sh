#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

source "$SCRIPT_DIR/version.sh" >/dev/null

if [ "$GIT_DIRTY" = "true" ] && [ "${ALLOW_DIRTY_RELEASE:-0}" != "1" ]; then
  echo "[package] refusing to create a production release from a dirty worktree" >&2
  echo "[package] commit/stage the intended release, or set ALLOW_DIRTY_RELEASE=1 for a local verification archive" >&2
  exit 1
fi

ARCHIVE_VERSION="${FULL_VERSION}"
SAFE_ARCHIVE_VERSION="$(printf '%s' "$ARCHIVE_VERSION" | tr -c 'A-Za-z0-9._+-' '_')"
ARCHIVE_PATH="$DIST_DIR/treehole-${SAFE_ARCHIVE_VERSION}.tar.gz"
WEB_DIR="$ROOT_DIR/build/web"

if [ "${SKIP_WEB_BUILD:-0}" != "1" ]; then
  echo "[package] rebuilding Flutter Web for this release"
  FLUTTER_BIN="$FLUTTER_BIN" bash "$SCRIPT_DIR/build_web_production.sh"
else
  echo "[package] SKIP_WEB_BUILD=1: using the existing explicitly prebuilt Web directory"
fi

if [ ! -f "$WEB_DIR/index.html" ] || [ ! -f "$WEB_DIR/main.dart.js" ]; then
  echo "[package] incomplete Web release in $WEB_DIR" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/treehole-release.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

install -d \
  "$STAGING_DIR/backend" \
  "$STAGING_DIR/web" \
  "$STAGING_DIR/deploy/tencent" \
  "$STAGING_DIR/deploy/production" \
  "$STAGING_DIR/scripts" \
  "$STAGING_DIR/release-meta"

for file in server.py _globals.py object_storage.py rag_service.py sql_repository.py \
  requirements-storage.txt requirements-auth.txt; do
  install -m 0644 "$ROOT_DIR/backend/$file" "$STAGING_DIR/backend/$file"
done

tar -C "$ROOT_DIR/backend" \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  -cf - handlers helpers services \
  | tar -C "$STAGING_DIR/backend" -xf -

cp -R "$WEB_DIR"/. "$STAGING_DIR/web/"

for file in backend.env.example nginx-xdu-whisperbox.conf xdu-whisperbox.service; do
  install -m 0644 "$ROOT_DIR/deploy/tencent/$file" "$STAGING_DIR/deploy/tencent/$file"
done
for file in .env.example nginx-cache.conf nginx-container.conf nginx-treehole-https.conf.template; do
  install -m 0644 "$ROOT_DIR/deploy/production/$file" "$STAGING_DIR/deploy/production/$file"
done
for file in \
  health_check.sh \
  install_offline_debs.sh \
  install_ubuntu_offline.sh \
  render_nginx_https.py \
  rollback.sh \
  validate_production_env.py \
  verify_release_archive.py; do
  install -m 0755 "$ROOT_DIR/scripts/$file" "$STAGING_DIR/scripts/$file"
done

python3 - "$STAGING_DIR/release-meta/version.json" \
  "$ARCHIVE_VERSION" "$GIT_HASH" "$GIT_BRANCH" "$GIT_DIRTY" \
  "$BUILD_DATE" "$BUILD_TIME" <<'PY'
import json
import sys

path, version, git_hash, git_branch, dirty, build_date, build_time = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "version": version,
            "gitHash": git_hash,
            "gitBranch": git_branch,
            "gitDirty": dirty == "true",
            "buildDate": build_date,
            "buildTime": build_time,
        },
        handle,
        ensure_ascii=False,
        indent=2,
    )
    handle.write("\n")
PY

python3 - "$STAGING_DIR" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
forbidden_suffixes = {
    ".db", ".sqlite", ".sqlite3", ".pem", ".key", ".p12", ".pfx",
    ".jks", ".keystore", ".log", ".pyc",
}
private_key = re.compile(br"BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY")
known_token = re.compile(
    br"(?:AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,})"
)
rows: list[str] = []
for path in sorted(item for item in root.rglob("*") if item.is_file()):
    relative = path.relative_to(root).as_posix()
    if path.suffix.lower() in forbidden_suffixes:
        raise SystemExit(f"[package] forbidden file type: {relative}")
    if path.name in {".env", ".env.local", "key.properties"}:
        raise SystemExit(f"[package] forbidden secret file: {relative}")
    data = path.read_bytes()
    if private_key.search(data) or known_token.search(data):
        raise SystemExit(f"[package] secret-like content detected: {relative}")
    rows.append(f"{hashlib.sha256(data).hexdigest()}  {relative}")
(root / "RELEASE-MANIFEST.sha256").write_text("\n".join(rows) + "\n", encoding="utf-8")
PY

mkdir -p "$DIST_DIR"
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1
tar -C "$STAGING_DIR" -czf "$ARCHIVE_PATH" .

python3 "$SCRIPT_DIR/verify_release_archive.py" "$ARCHIVE_PATH"

echo "[package] archive: $ARCHIVE_PATH"
echo "[package] size: $(du -h "$ARCHIVE_PATH" | awk '{print $1}')"
printf '%s\n' "$ARCHIVE_PATH"
