#!/usr/bin/env bash
set -euo pipefail

archive="${1:?Usage: deploy-next-offline.sh /path/to/zhixing-release.tar.gz}"
base_dir="/opt/zhixing"
env_file="/etc/zhixing/zhixing.env"
release_name="$(tar -tzf "$archive" | sed -n '1s@/.*@@p')"
[[ "$release_name" == zhixing-* ]] || { echo 'Invalid release package.' >&2; exit 1; }
[[ -f "$env_file" ]] || { echo "Missing $env_file" >&2; exit 1; }
mkdir -p "$base_dir/releases" /var/lib/zhixing/media
tar -C "$base_dir/releases" -xzf "$archive"
chown -R zhixing:zhixing "$base_dir/releases/$release_name" /var/lib/zhixing/media

previous="$(readlink -f "$base_dir/current" || true)"
set -a
# The environment file contains shell-compatible KEY=VALUE assignments.
source "$env_file"
set +a
cd "$base_dir/releases/$release_name"
./node_modules/.bin/prisma migrate deploy
ln -sfn "$base_dir/releases/$release_name" "$base_dir/current.new"
mv -Tf "$base_dir/current.new" "$base_dir/current"
if [[ -n "$previous" ]]; then printf '%s\n' "$previous" > "$base_dir/previous-release"; fi
if ! systemctl restart zhixing-next; then
  if [[ -n "$previous" ]]; then
    ln -sfn "$previous" "$base_dir/current.new"
    mv -Tf "$base_dir/current.new" "$base_dir/current"
    systemctl restart zhixing-next
  fi
  exit 1
fi
ready=0
for attempt in $(seq 1 15); do
  if curl -fsS http://127.0.0.1:3002/ >/dev/null; then ready=1; break; fi
  sleep 2
done
if [[ "$ready" != 1 ]]; then
  if [[ -n "$previous" ]]; then
    ln -sfn "$previous" "$base_dir/current.new"
    mv -Tf "$base_dir/current.new" "$base_dir/current"
    systemctl restart zhixing-next
  fi
  echo 'New release did not become healthy.' >&2
  exit 1
fi
printf 'Deployed %s\n' "$release_name"
