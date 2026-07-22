#!/usr/bin/env bash
set -euo pipefail

DEB_DIR="${1:-/home/ubuntu/treehole/offline/ubuntu2204-amd64-debs}"
if [ "${EUID}" -ne 0 ]; then
  echo "[offline] run as root" >&2
  exit 1
fi
if [ ! -f "$DEB_DIR/SHA256SUMS" ]; then
  echo "[offline] checksum manifest missing: $DEB_DIR/SHA256SUMS" >&2
  exit 1
fi
if [ "$(uname -m)" != "x86_64" ] || ! grep -q '^VERSION_ID="22.04"' /etc/os-release; then
  echo "[offline] target must be Ubuntu 22.04 x86-64" >&2
  exit 1
fi
(
  cd "$DEB_DIR"
  sha256sum --check SHA256SUMS
)

set +e
dpkg -i "$DEB_DIR"/*.deb
dpkg_status=$?
set -e
if [ "$dpkg_status" -ne 0 ]; then
  echo "[offline] dpkg reported unconfigured dependencies; resolving only from uploaded packages"
fi
apt-get --no-download --fix-broken install -y
dpkg --configure -a
if dpkg --audit | grep -q .; then
  echo "[offline] dpkg audit still reports incomplete packages" >&2
  dpkg --audit >&2
  exit 1
fi

for command in python3 nginx sqlite3; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "[offline] required command is still missing: $command" >&2
    exit 1
  }
done
echo "[offline] system dependencies installed"
