#!/usr/bin/env bash
set -euo pipefail

base_dir="/opt/zhixing"
previous="$(cat "$base_dir/previous-release")"
[[ -d "$previous" && "$previous" == "$base_dir/releases/"* ]] || { echo 'No previous release.' >&2; exit 1; }
current="$(readlink -f "$base_dir/current")"
ln -sfn "$previous" "$base_dir/current.new"
mv -Tf "$base_dir/current.new" "$base_dir/current"
printf '%s\n' "$current" > "$base_dir/previous-release"
systemctl restart zhixing-next
printf 'Rolled back to %s\n' "$previous"
