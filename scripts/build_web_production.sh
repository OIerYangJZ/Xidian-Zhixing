#!/usr/bin/env bash
# scripts/build_web_production.sh
# 生产构建脚本：生成版本标识并注入到 Flutter Web 构建产物中。
#
# 使用方式：
#   ./build_web_production.sh              # 默认构建
#   FLUTTER_BIN=/path/to/flutter ./build_web_production.sh  # 指定 Flutter 路径
#   BUILD_TYPE=beta ./build_web_production.sh              # beta 构建
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_TYPE="${BUILD_TYPE:-release}"
export BUILD_TYPE

# 加载版本信息
source "$SCRIPT_DIR/version.sh"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_PROJECT_DIR="$ROOT_DIR/flutter_app"
FLUTTER_OUTPUT_DIR="$FLUTTER_PROJECT_DIR/build/web"
WEB_DIST_DIR="$ROOT_DIR/build/web"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "[build] Flutter not found: $FLUTTER_BIN"
  echo "[build] Set FLUTTER_BIN to absolute path, e.g. FLUTTER_BIN=/Users/yangjinsey/flutter/bin/flutter"
  exit 1
fi

echo "[build] === 西电树洞生产构建 ==="
echo "[build] APP_VERSION : $APP_VERSION"
echo "[build] GIT_HASH    : $GIT_HASH"
echo "[build] GIT_BRANCH  : $GIT_BRANCH"
echo "[build] BUILD_DATE  : $BUILD_DATE"
echo "[build] BUILD_TYPE  : $BUILD_TYPE"
echo "[build] FULL_VERSION: $FULL_VERSION"
echo "[build] DIRTY       : $GIT_DIRTY"

# 执行 Flutter Web 构建，注入版本标识
echo "[build] Running flutter pub get..."
(cd "$FLUTTER_PROJECT_DIR" && "$FLUTTER_BIN" pub get --enforce-lockfile)

echo "[build] Running flutter build web..."
(cd "$FLUTTER_PROJECT_DIR" && "$FLUTTER_BIN" build web --release \
    --dart-define=API_BASE_URL=/api \
    --dart-define=APP_VERSION="$FULL_VERSION" \
    --dart-define=APP_BUILD_TYPE="$BUILD_TYPE")

if [ ! -f "$FLUTTER_OUTPUT_DIR/index.html" ]; then
  echo "[build] Flutter output is incomplete: $FLUTTER_OUTPUT_DIR/index.html" >&2
  exit 1
fi

rm -rf "$WEB_DIST_DIR"
mkdir -p "$(dirname "$WEB_DIST_DIR")"
cp -R "$FLUTTER_OUTPUT_DIR" "$WEB_DIST_DIR"

python3 - "$WEB_DIST_DIR/.version.json" \
  "$APP_VERSION" "$GIT_HASH" "$GIT_BRANCH" "$GIT_TAG" "$GIT_DIRTY" \
  "$BUILD_DATE" "$BUILD_TIME" "$BUILD_TIMESTAMP" "$BUILD_TYPE" "$FULL_VERSION" <<'PY'
import json
import sys

(
    output_path,
    app_version,
    git_hash,
    git_branch,
    git_tag,
    git_dirty,
    build_date,
    build_time,
    build_timestamp,
    build_type,
    full_version,
) = sys.argv[1:]
payload = {
    "appVersion": app_version,
    "gitHash": git_hash,
    "gitBranch": git_branch,
    "gitTag": git_tag,
    "gitDirty": git_dirty == "true",
    "buildDate": build_date,
    "buildTime": build_time,
    "buildTimestamp": build_timestamp,
    "buildType": build_type,
    "fullVersion": full_version,
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
echo "[build] Version info written to $WEB_DIST_DIR/.version.json"

# 向 index.html 注入版本号 meta tag（便于快速确认当前运行的版本）
python3 - "$WEB_DIST_DIR/index.html" "$FULL_VERSION" "$GIT_HASH" "$BUILD_DATE" <<'PY'
import html
import sys

index_path, full_version, git_hash, build_date = sys.argv[1:]
with open(index_path, "r", encoding="utf-8") as handle:
    content = handle.read()
if "app-version" in content:
    raise SystemExit("[build] index.html already contains app-version metadata")
tags = "\n".join(
    [
        f'  <meta name="app-version" content="{html.escape(full_version, quote=True)}">',
        f'  <meta name="app-git-hash" content="{html.escape(git_hash, quote=True)}">',
        f'  <meta name="app-build-date" content="{html.escape(build_date, quote=True)}">',
    ]
)
if "<head>" not in content:
    raise SystemExit("[build] index.html is missing <head>")
content = content.replace("<head>", f"<head>\n{tags}", 1)
with open(index_path, "w", encoding="utf-8") as handle:
    handle.write(content)
print("[build] Injected version meta tags into index.html")
PY

# 生成内容哈希用于长期缓存
echo "[build] Checking main.dart.js hash..."
if command -v sha256sum >/dev/null 2>&1; then
  JS_HASH=$(sha256sum "$WEB_DIST_DIR/main.dart.js" | awk '{print substr($1,1,16)}')
elif command -v shasum >/dev/null 2>&1; then
  JS_HASH=$(shasum -a 256 "$WEB_DIST_DIR/main.dart.js" | awk '{print substr($1,1,16)}')
else
  echo "[build] sha256sum or shasum is required" >&2
  exit 1
fi
printf '%s\n' "$JS_HASH" > "$WEB_DIST_DIR/.main_hash"
echo "[build] main.dart.js hash: $JS_HASH"

echo "[build] === 构建完成 ==="
echo "[build] 输出目录: $WEB_DIST_DIR"
echo "[build] 完整版本: $FULL_VERSION"
echo "[build] Git 哈希: $GIT_HASH"
if [ "$GIT_DIRTY" = "true" ]; then
  echo "[build] 警告: 构建包含未提交的更改"
fi
