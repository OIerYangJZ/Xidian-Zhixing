#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Build the offline package on Linux matching the production architecture." >&2
  exit 1
fi

release_id="$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M%S)"
release_dir="${PWD}/dist/zhixing-${release_id}"
mkdir -p "$release_dir"

npm ci
npm run build
cp -a .next node_modules public prisma package.json package-lock.json next.config.js "$release_dir/"
tar -C dist -czf "dist/zhixing-${release_id}.tar.gz" "zhixing-${release_id}"
printf 'Created %s\n' "dist/zhixing-${release_id}.tar.gz"
