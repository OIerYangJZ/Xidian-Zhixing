#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILD_TYPE=beta \
FLUTTER_BIN="${FLUTTER_BIN:-flutter}" \
bash "$ROOT_DIR/scripts/build_web_production.sh"
