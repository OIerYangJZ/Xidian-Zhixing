#!/usr/bin/env bash
# 将 XDYou（Traintime PDA / watermeter）源码放到 packages/traintime_pda，供 Flutter path 依赖使用。
# 任选其一：
# 1) 从 GitHub 浅克隆（CI 默认）
# 2) 本地复制：cp -R /path/to/traintime_pda "$(dirname "$0")/../packages/traintime_pda"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/packages/traintime_pda"
if [[ -f "$DEST/pubspec.yaml" ]]; then
  echo "XDYou already present: $DEST"
  exit 0
fi
mkdir -p "$ROOT/packages"
git clone --depth 1 https://github.com/BenderBlog/traintime_pda.git "$DEST"
echo "Cloned traintime_pda -> $DEST"
