#!/usr/bin/env bash
# scripts/build_web_admin.sh
# 管理后台专用 Web 构建。
#
# build_web_production.sh 现在默认 ENABLE_ADMIN_CONSOLE=true，所以公开产物里
# 已经带后台，登录页底部的入口就是它。这份脚本用于另一种部署方式：公开产物用
# ENABLE_ADMIN_CONSOLE=false 构建（dart2js 会把整棵管理台子树剪掉），后台单独
# 出一份产物、发布到独立域名或受限路径。两种方式只能选一种，用哪种都不要把
# build/web-admin 覆盖到 build/web 或放进 BACKEND_WEB_ROOT。
#
# 使用方式：
#   ./build_web_admin.sh
#   ADMIN_API_BASE_URL=https://zhixing.xidian.edu.cn/api ./build_web_admin.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_TYPE="${BUILD_TYPE:-admin}"
export BUILD_TYPE

source "$SCRIPT_DIR/version.sh"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_PROJECT_DIR="$ROOT_DIR/flutter_app"
ADMIN_DIST_DIR="$ROOT_DIR/build/web-admin"
# 后台一般部署在独立域名/独立路径下，因此 API 地址需要显式指定绝对地址；
# 留空则沿用同源 /api。
ADMIN_API_BASE_URL="${ADMIN_API_BASE_URL:-/api}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "[admin-build] Flutter not found: $FLUTTER_BIN" >&2
  exit 1
fi

echo "[admin-build] === 管理后台构建 ==="
echo "[admin-build] FULL_VERSION : $FULL_VERSION"
echo "[admin-build] API_BASE_URL : $ADMIN_API_BASE_URL"

(cd "$FLUTTER_PROJECT_DIR" && "$FLUTTER_BIN" pub get --enforce-lockfile)
(cd "$FLUTTER_PROJECT_DIR" && "$FLUTTER_BIN" build web --release \
    --no-web-resources-cdn \
    --output="$ADMIN_DIST_DIR" \
    --dart-define=ENABLE_ADMIN_CONSOLE=true \
    --dart-define=API_BASE_URL="$ADMIN_API_BASE_URL" \
    --dart-define=APP_VERSION="$FULL_VERSION" \
    --dart-define=APP_BUILD_TYPE="$BUILD_TYPE")

if [ ! -f "$ADMIN_DIST_DIR/index.html" ]; then
  echo "[admin-build] Flutter output is incomplete" >&2
  exit 1
fi

echo "[admin-build] 产物: $ADMIN_DIST_DIR"
echo "[admin-build] 提醒: 请部署到与公开站点不同的域名或受限路径，"
echo "[admin-build]       并且不要放进 BACKEND_WEB_ROOT 指向的目录。"
