#!/usr/bin/env bash
# scripts/build_web_admin.sh
# 管理后台专用 Web 构建。
#
# 公开的 build_web_production.sh 不带 ENABLE_ADMIN_CONSOLE，因此那份产物里
# 完全没有后台代码（dart2js 会把整棵管理台子树剪掉）。这份产物是唯一带
# 后台的，务必与公开站点分开发布，不要覆盖 build/web。
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
FLUTTER_OUTPUT_DIR="$FLUTTER_PROJECT_DIR/build/web"
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
    --dart-define=ENABLE_ADMIN_CONSOLE=true \
    --dart-define=API_BASE_URL="$ADMIN_API_BASE_URL" \
    --dart-define=APP_VERSION="$FULL_VERSION" \
    --dart-define=APP_BUILD_TYPE="$BUILD_TYPE")

if [ ! -f "$FLUTTER_OUTPUT_DIR/index.html" ]; then
  echo "[admin-build] Flutter output is incomplete" >&2
  exit 1
fi

rm -rf "$ADMIN_DIST_DIR"
mkdir -p "$(dirname "$ADMIN_DIST_DIR")"
cp -R "$FLUTTER_OUTPUT_DIR" "$ADMIN_DIST_DIR"

echo "[admin-build] 产物: $ADMIN_DIST_DIR"
echo "[admin-build] 提醒: 请部署到与公开站点不同的域名或受限路径，"
echo "[admin-build]       并且不要放进 BACKEND_WEB_ROOT 指向的目录。"
