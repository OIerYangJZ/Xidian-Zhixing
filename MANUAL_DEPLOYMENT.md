# 西电知行人工部署手册

适用版本：Flutter Web `0.1.0+22`

正式域名：`https://zhixing.xidian.edu.cn`

发布源 Git 提交：`00e6aa0`

## 1. 本地发布物

- 本地路径：`/Users/yangjinsey/Desktop/SeeRadio/dist/treehole-0.1.0+22+00e6aa0-20260723T061241Z.tar.gz`
- SHA-256：`3cbcce1414235b455e731afb00c8dfa296f9c115888749a330a122037db679a7`
- SHA-256 文件：`/Users/yangjinsey/Desktop/SeeRadio/dist/treehole-0.1.0+22+00e6aa0-20260723T061241Z.tar.gz.sha256`

发布包不包含 SQLite、上传文件、真实 `backend.env`、密钥、日志、证书或私钥。

## 2. 必须手动确认的变量

本手册不假设学校服务器的连接参数或目录。先在安全的终端会话中填写：

```bash
export BASTION_HOST='__FILL_BASTION_HOST__'
export BASTION_USER='__FILL_BASTION_USER__'
export BASTION_PORT='__FILL_BASTION_SSH_PORT__'
export TARGET_HOST='__FILL_TARGET_HOST__'
export TARGET_USER='__FILL_TARGET_USER__'
export TARGET_SSH_PORT='__FILL_TARGET_SSH_PORT__'

export DEPLOY_ROOT='__FILL_DEPLOY_ROOT__'
export SERVICE_NAME='__FILL_SYSTEMD_SERVICE_NAME__'
export NGINX_SERVICE_NAME='__FILL_NGINX_SERVICE_NAME__'
export NGINX_SITE_CONFIG='__FILL_NGINX_SITE_CONFIG_PATH__'
export APP_USER='__FILL_APPLICATION_USER__'
export APP_GROUP='__FILL_APPLICATION_GROUP__'

export RELEASE_ARCHIVE_LOCAL='/Users/yangjinsey/Desktop/SeeRadio/dist/treehole-0.1.0+22+00e6aa0-20260723T061241Z.tar.gz'
export RELEASE_ARCHIVE_REMOTE='__FILL_REMOTE_UPLOAD_PATH__'
export RELEASE_SHA256='3cbcce1414235b455e731afb00c8dfa296f9c115888749a330a122037db679a7'
```

这些变量必须由用户填写；不要把真实密码、Token、证书或私钥放进命令历史、Git 或本发布包。

可在服务器上用以下只读命令辅助查询：

```bash
systemctl list-units --type=service --all | grep -Ei 'treehole|zhixing|xidian'
systemctl cat "${SERVICE_NAME}"
readlink -f "${DEPLOY_ROOT}/current"
sudo nginx -T
ps -eo user,group,pid,cmd | grep -E 'backend/server.py|treehole|zhixing'
```

若变量仍不明确，先停止部署并让服务器管理员确认。

## 3. 通过堡垒机上传

在本地电脑执行：

```bash
scp -P "${BASTION_PORT}" \
  "${RELEASE_ARCHIVE_LOCAL}" \
  "${BASTION_USER}@${BASTION_HOST}:/tmp/"
```

登录堡垒机后，再上传到目标服务器：

```bash
scp -P "${TARGET_SSH_PORT}" \
  "/tmp/$(basename "${RELEASE_ARCHIVE_LOCAL}")" \
  "${TARGET_USER}@${TARGET_HOST}:${RELEASE_ARCHIVE_REMOTE}"
```

如果学校要求使用专用上传工具、审批工单、一次性凭据或不能经堡垒机落盘，应以学校运维制度为准。上述 SSH 主机、用户、端口和远端路径全部是待填变量。

## 4. 部署前检查

登录目标服务器后执行：

```bash
set -u
date -u
uname -a
df -h
df -i
readlink -f "${DEPLOY_ROOT}/current"
sudo systemctl status "${SERVICE_NAME}" --no-pager -l
sudo nginx -t
curl -fsS https://zhixing.xidian.edu.cn/api/health
```

确认上传文件存在且仅由授权用户可读：

```bash
ls -lh "${RELEASE_ARCHIVE_REMOTE}"
stat "${RELEASE_ARCHIVE_REMOTE}"
```

任一检查失败都应先查明原因，不要带病切换版本。

## 5. 记录当前版本

```bash
export PREVIOUS_RELEASE="$(readlink -f "${DEPLOY_ROOT}/current")"
printf 'previous release: %s\n' "${PREVIOUS_RELEASE}"

if [ -f "${DEPLOY_ROOT}/current/release-meta/version.json" ]; then
  cat "${DEPLOY_ROOT}/current/release-meta/version.json"
fi
```

把当前软链接目标、版本 JSON、部署时间和操作人记录到学校允许保存的变更单中。

## 6. 备份数据库和上传目录

先确认真实环境文件中 `BACKEND_DB_FILE` 和 `BACKEND_STORAGE_DIR` 的值。以下命令假设数据位于 `${DEPLOY_ROOT}/shared/data` 和 `${DEPLOY_ROOT}/shared/storage`；如实际路径不同，必须调整。

```bash
export BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -m 0700 "${DEPLOY_ROOT}/backups"

sudo systemctl stop "${SERVICE_NAME}"
sudo tar -C "${DEPLOY_ROOT}" \
  -czf "${DEPLOY_ROOT}/backups/data-storage-${BACKUP_ID}.tar.gz" \
  shared/data shared/storage
sudo systemctl start "${SERVICE_NAME}"
sudo systemctl is-active "${SERVICE_NAME}"
sudo chmod 0600 "${DEPLOY_ROOT}/backups/data-storage-${BACKUP_ID}.tar.gz"
```

短暂停服是为了获得 SQLite 与上传目录的一致快照。不得删除、清空或用发布包覆盖 `shared/data`、`shared/storage`。

## 7. 备份 Nginx 配置

`NGINX_SITE_CONFIG` 必须从 `nginx -T` 或服务器运维记录中确认，不能猜测。

```bash
sudo cp -a \
  "${NGINX_SITE_CONFIG}" \
  "${NGINX_SITE_CONFIG}.before-${BACKUP_ID}"
sudo chmod --reference="${NGINX_SITE_CONFIG}" \
  "${NGINX_SITE_CONFIG}.before-${BACKUP_ID}"
```

证书和私钥路径沿用服务器现有配置，本轮不替换也不猜测。

## 8. 校验发布包

```bash
cd "$(dirname "${RELEASE_ARCHIVE_REMOTE}")"
printf '%s  %s\n' \
  "${RELEASE_SHA256}" \
  "$(basename "${RELEASE_ARCHIVE_REMOTE}")" \
  | sha256sum -c -
```

若服务器使用 macOS/BSD 工具，改用：

```bash
shasum -a 256 "${RELEASE_ARCHIVE_REMOTE}"
```

输出必须与本手册第 1 节完全一致。

## 9. 创建并解压新 release

```bash
export RELEASE_ID="$(basename "${RELEASE_ARCHIVE_REMOTE}" .tar.gz)"
export NEW_RELEASE_DIR="${DEPLOY_ROOT}/releases/${RELEASE_ID}"

sudo install -d -o "${APP_USER}" -g "${APP_GROUP}" -m 0755 \
  "${DEPLOY_ROOT}/releases" \
  "${NEW_RELEASE_DIR}"
sudo tar -xzf "${RELEASE_ARCHIVE_REMOTE}" -C "${NEW_RELEASE_DIR}"
sudo python3 \
  "${NEW_RELEASE_DIR}/scripts/verify_release_archive.py" \
  "${RELEASE_ARCHIVE_REMOTE}"
cat "${NEW_RELEASE_DIR}/release-meta/version.json"
```

如果 `${NEW_RELEASE_DIR}` 已存在，停止操作并选择新的 release 标识；不要覆盖一个来源不明的既有目录。

## 10. 文件权限

以下为建议权限，必须与服务器现有 systemd/Nginx 用户模型核对：

```bash
sudo chown -R "${APP_USER}:${APP_GROUP}" "${NEW_RELEASE_DIR}"
sudo find "${NEW_RELEASE_DIR}" -type d -exec chmod 0755 {} +
sudo find "${NEW_RELEASE_DIR}" -type f -exec chmod 0644 {} +
sudo find "${NEW_RELEASE_DIR}/scripts" -type f -name '*.sh' -exec chmod 0755 {} +

sudo chown -R "${APP_USER}:${APP_GROUP}" \
  "${DEPLOY_ROOT}/shared/data" \
  "${DEPLOY_ROOT}/shared/storage"
sudo chown root:"${APP_GROUP}" \
  "${DEPLOY_ROOT}/shared/config/backend.env"
sudo chmod 0640 "${DEPLOY_ROOT}/shared/config/backend.env"
```

若 Nginx 不能读取 Web 静态文件，应修正目录遍历权限或服务器用户组，不要把私密配置改为全局可读。

## 11. shared/config、shared/data、shared/storage

- `shared/config/backend.env`：继续使用服务器已有真实配置；只依据模板逐项补齐新变量，不从发布包复制真实值。
- `shared/data`：保留 SQLite、WAL/SHM 所在数据边界；发布包不包含数据库。
- `shared/storage`：保留上传对象；发布包不包含上传文件。
- 新 release 目录只包含代码、Web 静态文件、模板和脚本。

检查真实配置中的路径：

```bash
sudo grep -E \
  '^(BACKEND_DB_FILE|BACKEND_STORAGE_DIR|BACKEND_WEB_ROOT|BACKEND_CORS_ALLOWED_ORIGINS|BACKEND_AUTH_ALLOWED_STUDENT_IDS|BACKEND_ENABLE_XIDIAN_AUTH)=' \
  "${DEPLOY_ROOT}/shared/config/backend.env"
```

确认：

```text
BACKEND_ENABLE_XIDIAN_AUTH=true
BACKEND_CORS_ALLOWED_ORIGINS=https://zhixing.xidian.edu.cn
BACKEND_WEB_ROOT=${DEPLOY_ROOT}/current/web
```

上面的 `${DEPLOY_ROOT}` 表示服务器实际绝对路径，不应把花括号字面量写进生产环境文件。

校验配置：

```bash
sudo -u "${APP_USER}" python3 \
  "${NEW_RELEASE_DIR}/scripts/validate_production_env.py" \
  "${DEPLOY_ROOT}/shared/config/backend.env"
```

## 12. 切换 current 软链接

```bash
test -d "${NEW_RELEASE_DIR}/web"
test -f "${NEW_RELEASE_DIR}/web/index.html"
test -f "${NEW_RELEASE_DIR}/backend/server.py"

sudo ln -sfn "${NEW_RELEASE_DIR}" "${DEPLOY_ROOT}/current.next"
sudo mv -Tf "${DEPLOY_ROOT}/current.next" "${DEPLOY_ROOT}/current"
readlink -f "${DEPLOY_ROOT}/current"
```

`mv -T` 是 GNU coreutils 语法；若服务器不支持，必须由管理员采用该系统可用的原子软链接替换方式。

## 13. systemd 重启和日志

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
sudo systemctl is-active "${SERVICE_NAME}"
sudo systemctl status "${SERVICE_NAME}" --no-pager -l
sudo journalctl -u "${SERVICE_NAME}" -n 200 --no-pager
```

如果服务未正常启动，不要继续 reload Nginx；先执行第 17 节回滚。

## 14. Nginx 校验和 reload

若本轮没有改动服务器 Nginx 文件，仍要验证并平滑加载：

```bash
sudo nginx -t
sudo systemctl reload "${NGINX_SERVICE_NAME}"
sudo systemctl is-active "${NGINX_SERVICE_NAME}"
```

若 `NGINX_SERVICE_NAME` 不是 `nginx`，以服务器实际服务名为准。

## 15. 正式域名验收

```bash
curl -fsSI http://zhixing.xidian.edu.cn/
curl -fsSI https://zhixing.xidian.edu.cn/
curl -fsS https://zhixing.xidian.edu.cn/api/health
curl -fsSI https://zhixing.xidian.edu.cn/auth/login
cat "${DEPLOY_ROOT}/current/release-meta/version.json"
```

随后使用符合当前白名单策略的普通账号人工验收登录、会话恢复、发帖、图片上传、评论、删除本人内容、举报和退出；使用管理员账号验收管理员登录与举报处理。白名单为空时应任选已通过学校统一认证的测试账号，非空时应使用其中的学号。不得把真实账号或密码写入本文档。

## 16. CORS 和 HSTS

正式 Origin 预检：

```bash
curl -isS -X OPTIONS \
  -H 'Origin: https://zhixing.xidian.edu.cn' \
  -H 'Access-Control-Request-Method: POST' \
  https://zhixing.xidian.edu.cn/api/auth/xidian/session
```

未列入白名单的 Origin 应被拒绝，且不得返回通配符：

```bash
curl -isS -X OPTIONS \
  -H 'Origin: https://not-allowed.invalid' \
  -H 'Access-Control-Request-Method: POST' \
  https://zhixing.xidian.edu.cn/api/auth/xidian/session
```

HSTS：

```bash
curl -sSI https://zhixing.xidian.edu.cn/ \
  | grep -i '^strict-transport-security:'
```

## 17. 回滚

如新版本失败，立即切回第 5 节记录的旧 release：

```bash
test -n "${PREVIOUS_RELEASE}"
test -d "${PREVIOUS_RELEASE}"
sudo ln -sfn "${PREVIOUS_RELEASE}" "${DEPLOY_ROOT}/current.rollback"
sudo mv -Tf "${DEPLOY_ROOT}/current.rollback" "${DEPLOY_ROOT}/current"
sudo systemctl restart "${SERVICE_NAME}"
sudo nginx -t
sudo systemctl reload "${NGINX_SERVICE_NAME}"
curl -fsS https://zhixing.xidian.edu.cn/api/health
```

如 Nginx 配置曾被更改，恢复备份：

```bash
sudo cp -a \
  "${NGINX_SITE_CONFIG}.before-${BACKUP_ID}" \
  "${NGINX_SITE_CONFIG}"
sudo nginx -t
sudo systemctl reload "${NGINX_SERVICE_NAME}"
```

应用回滚只切换代码 release，不回退或删除 `shared/config`、`shared/data`、`shared/storage`。数据库恢复属于独立高风险操作，只有确认 schema/data 不兼容且备份完整时才由服务器管理员执行。

## 18. 必须由用户填写的未知信息

- 堡垒机主机、用户名、SSH 端口和认证方式；
- 目标服务器主机、用户名、SSH 端口和认证方式；
- 上传暂存路径；
- 部署根目录；
- systemd 服务名；
- Nginx 服务名与站点配置路径；
- 应用运行用户和组；
- SQLite、上传目录、环境文件的真实绝对路径；
- 服务器现有 SSL 证书和私钥路径（仅核对，不写入本文档）；
- 可选学号白名单（留空允许所有统一认证用户，非空时只允许列出的学号）；
- 生产管理员凭据和测试账号（仅服务器私密配置）。

## 19. 必须按服务器实际情况调整的命令

以下命令不能机械复制，必须先核对：

- 两段 `scp` 的主机、用户、端口和路径；
- `${DEPLOY_ROOT}`、`${RELEASE_ARCHIVE_REMOTE}`；
- `${SERVICE_NAME}`、`${NGINX_SERVICE_NAME}`；
- `${NGINX_SITE_CONFIG}`；
- `${APP_USER}`、`${APP_GROUP}`；
- 数据备份中的 `shared/data`、`shared/storage`；
- 环境文件和 Python/venv 路径；
- `mv -Tf` 的平台兼容性；
- 证书、私钥和 Nginx include 路径。

部署完成前，项目状态仍为：**本地代码、测试和生产发布包已经完成，等待用户手动部署到学校服务器。**
