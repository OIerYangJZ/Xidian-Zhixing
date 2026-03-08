#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
VERSION="${VERSION:-$(date +%Y%m%d%H%M%S)}"
ARCHIVE_PATH="$DIST_DIR/xdu-whisperbox-release-$VERSION.tar.gz"

if [[ ! -f "$ROOT_DIR/build/web/index.html" || "${FORCE_BUILD:-0}" == "1" ]]; then
  FLUTTER_BIN="$FLUTTER_BIN" "$ROOT_DIR/scripts/build_web_beta.sh" >&2
fi

mkdir -p "$DIST_DIR"

export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

tar \
  --exclude='backend/__pycache__' \
  --exclude='backend/data' \
  --exclude='backend/storage' \
  -czf "$ARCHIVE_PATH" \
  backend \
  build/web \
  deploy \
  scripts \
  README.md

echo "$ARCHIVE_PATH"
