#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/offline/wheels-cp310-manylinux-x86_64}"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
  echo "[offline] run this script on a connected Linux x86-64 build host" >&2
  exit 1
fi
python3 - <<'PY'
import sys
if sys.version_info[:2] != (3, 10):
    raise SystemExit("[offline] CPython 3.10 is required")
PY

if [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -print -quit | grep -q .; then
  echo "[offline] output directory must be empty: $OUTPUT_DIR" >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
python3 -m pip download \
  --only-binary=:all: \
  --dest "$OUTPUT_DIR" \
  -r "$ROOT_DIR/backend/requirements-storage.txt" \
  -r "$ROOT_DIR/backend/requirements-auth.txt"

python3 - "$OUTPUT_DIR" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
rows = []
for path in sorted(root.glob("*.whl")):
    rows.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
if not rows:
    raise SystemExit("[offline] no wheels were downloaded")
(root / "SHA256SUMS").write_text("\n".join(rows) + "\n", encoding="utf-8")
PY
echo "[offline] wheel bundle ready: $OUTPUT_DIR"
