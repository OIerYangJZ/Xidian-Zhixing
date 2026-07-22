#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/offline/ubuntu2204-amd64-debs}"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
  echo "[offline] run this script on a connected Ubuntu 22.04 x86-64 build host" >&2
  exit 1
fi
if ! grep -q '^VERSION_ID="22.04"' /etc/os-release; then
  echo "[offline] Ubuntu 22.04 is required" >&2
  exit 1
fi
if [ "${EUID}" -ne 0 ]; then
  echo "[offline] run as root so apt metadata and apt-rdepends can be installed" >&2
  exit 1
fi

if [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "[offline] output directory must be empty: $OUTPUT_DIR" >&2
  exit 1
fi
apt-get update
apt-get install -y apt-rdepends
mkdir -p "$OUTPUT_DIR"

mapfile -t packages < <(
  apt-rdepends nginx python3 python3-venv python3-pip curl openssl sqlite3 \
    | awk '/^[A-Za-z0-9][A-Za-z0-9+.-]*$/ {print}' \
    | sort -u
)
(
  cd "$OUTPUT_DIR"
  apt-get download "${packages[@]}"
)

python3 - "$OUTPUT_DIR" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
rows = []
for path in sorted(root.glob("*.deb")):
    rows.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
if not rows:
    raise SystemExit("[offline] no deb files were downloaded")
(root / "SHA256SUMS").write_text("\n".join(rows) + "\n", encoding="utf-8")
PY
echo "[offline] deb bundle ready: $OUTPUT_DIR"
