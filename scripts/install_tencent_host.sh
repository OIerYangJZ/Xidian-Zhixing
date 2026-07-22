#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[install] install_tencent_host.sh is retained as a compatibility entrypoint"
exec bash "$SCRIPT_DIR/install_ubuntu_offline.sh" "$@"
