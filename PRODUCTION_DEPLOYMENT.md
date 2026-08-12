# 西电知行网页端生产配置说明

正式地址：`https://zhixing.xidian.edu.cn`

本项目沿用现有 `Nginx + systemd + Python 3.10 + SQLite + Flutter Web` 架构。生产服务器只运行 Nginx 和 Python 后端；Flutter Web 作为静态文件发布。不要同时启用 Docker Compose、PM2 或另一套进程管理。

## 1. 生产环境文件

1. 以根目录 `.env.production.example` 或 `deploy/tencent/backend.env.example` 为模板。
2. 真实环境文件固定放在：

   `/home/ubuntu/treehole/shared/config/backend.env`

3. 文件权限：

   ```bash
   sudo chown root:treehole /home/ubuntu/treehole/shared/config/backend.env
   sudo chmod 0640 /home/ubuntu/treehole/shared/config/backend.env
   ```

4. 启动前校验：

   ```bash
   /home/ubuntu/treehole/shared/venv/bin/python \
     /home/ubuntu/treehole/current/scripts/validate_production_env.py \
     /home/ubuntu/treehole/shared/config/backend.env
   ```

生产必填项包括管理员凭据、SQLite 和对象目录、Web 根目录以及正式 CORS 来源。可选学号白名单、学院授权映射及真实学号、管理员密码和 AI/S3 密钥只能写入服务器环境文件。

网页端生产 API 使用同源 `/api`，由 Nginx 反向代理到 `127.0.0.1:8080`。移动 App 和小程序需要在各自构建配置中显式注入正式 HTTPS 地址。

当前内测约束：

- `BACKEND_CORS_ALLOWED_ORIGINS=https://zhixing.xidian.edu.cn`
- `BACKEND_AUTH_ALLOWED_STUDENT_IDS=` 留空允许所有通过学校统一认证的用户；非空时只允许英文逗号分隔的学号
- `BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS=` 使用 `学号=分区ID` 的英文逗号分隔映射；未映射用户不能在学院分区发帖，个人资料中的学院字段不授予权限
- `BACKEND_ENABLE_XIDIAN_AUTH=true`
- `BACKEND_XIDIAN_PUBLIC_ORIGIN=https://zhixing.xidian.edu.cn`
- `BACKEND_ALLOW_DEBUG_VERIFY_CODE=false`
- `BACKEND_INCLUDE_DEBUG_CODE=false`
- `BACKEND_SEED_DEMO_DATA=false`

普通用户只通过西电官方统一身份认证页面登录，固定登记的 CAS `service`/回调地址为 `https://zhixing.xidian.edu.cn/api/auth/xidian/callback`。本站不展示学号密码输入框、不接收统一认证密码，只校验 IDS 发给该回调地址的票据。首次认证成功后自动创建本站账号。校园邮箱注册、邮箱验证码和邮箱找回密码接口不再对外开放。

## 2. 正式构建与发布包

构建：

```bash
FLUTTER_BIN=/path/to/flutter bash scripts/build_web_production.sh
```

输出：

`build/web/`

正式发布前工作区必须干净，随后生成发布包：

```bash
FLUTTER_BIN=/path/to/flutter bash scripts/package_release.sh
```

发布包不包含数据库、上传目录、真实 `.env`、证书私钥、日志或缓存。

## 3. Nginx

HTTPS 模板：

`deploy/production/nginx-treehole-https.conf.template`

根据服务器上的真实证书路径渲染：

```bash
python3 scripts/render_nginx_https.py \
  deploy/production/nginx-treehole-https.conf.template \
  zhixing.xidian.edu.cn \
  /absolute/path/to/fullchain.pem \
  /absolute/path/to/private.key \
  /tmp/treehole.conf
sudo install -m 0644 /tmp/treehole.conf /etc/nginx/sites-available/treehole.conf
sudo ln -sfn /etc/nginx/sites-available/treehole.conf /etc/nginx/sites-enabled/treehole.conf
sudo nginx -t
sudo systemctl reload nginx
```

离线安装和 `scripts/deploy_tencent.sh` 不再安装归档内的 HTTP 示例配置。必须把上述已渲染、已核对证书绝对路径的 `/tmp/treehole.conf` 作为安装脚本第二个参数，或通过 `DEPLOY_NGINX_CONFIG=/tmp/treehole.conf` 传给部署脚本。

配置包含：

- HTTP 跳转 HTTPS；
- `/api/` 反向代理；
- `try_files ... /index.html`，支持 Flutter Web 路由刷新；
- `client_max_body_size 20m`；
- HTML、Service Worker 和入口清单不缓存；
- 其他静态资源缓存 7 天；
- TLS 1.2/1.3、HSTS、`nosniff`、`SAMEORIGIN` 和 Referrer Policy；
- Nginx 访问与错误日志。

证书路径必须以服务器现有配置为准，不要猜测。

## 4. systemd 生命周期与日志

服务文件：

`deploy/tencent/xdu-whisperbox.service`

安装位置：

`/etc/systemd/system/treehole.service`

常用命令：

```bash
sudo systemctl enable --now treehole
sudo systemctl status treehole --no-pager -l
sudo systemctl stop treehole
sudo systemctl restart treehole
sudo journalctl -u treehole -n 200 --no-pager
sudo journalctl -u treehole -f
sudo journalctl -u treehole --since today
```

后端输出 JSON 日志到 journald；错误堆栈写入同一日志流。日志轮转和容量控制沿用服务器 journald 策略，不额外引入第二套日志守护进程。

## 5. 数据备份与恢复

生产数据位置：

- SQLite：`/home/ubuntu/treehole/shared/data/treehole.db`
- 上传对象：`/home/ubuntu/treehole/shared/storage/objects/`
- 私密配置：`/home/ubuntu/treehole/shared/config/backend.env`

一致性备份应先短暂停服，再复制整个 shared 数据边界：

```bash
sudo systemctl stop treehole
sudo tar -C /home/ubuntu/treehole \
  -czf /home/ubuntu/treehole/backups/treehole-$(date -u +%Y%m%dT%H%M%SZ).tar.gz \
  shared/data shared/storage
sudo systemctl start treehole
sudo systemctl is-active treehole
```

备份文件应限制为仅管理员可读，并保存到独立介质。环境文件和证书应使用加密的秘密备份，不与普通数据包混放。

恢复前先保留当前数据副本，禁止直接清空：

```bash
sudo systemctl stop treehole
sudo mv /home/ubuntu/treehole/shared/data \
  /home/ubuntu/treehole/shared/data.before-restore
sudo mv /home/ubuntu/treehole/shared/storage \
  /home/ubuntu/treehole/shared/storage.before-restore
sudo tar -xzf /path/to/verified-backup.tar.gz -C /home/ubuntu/treehole
sudo chown -R treehole:treehole \
  /home/ubuntu/treehole/shared/data \
  /home/ubuntu/treehole/shared/storage
sudo systemctl start treehole
curl -fsS https://zhixing.xidian.edu.cn/api/health
```

## 6. 健康检查与回滚

健康检查：

```bash
API_BASE_URL=https://zhixing.xidian.edu.cn/api \
WEB_BASE_URL=https://zhixing.xidian.edu.cn \
bash /home/ubuntu/treehole/current/scripts/health_check.sh
```

版本回滚：

```bash
sudo DEPLOY_DIR=/home/ubuntu/treehole SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh --list
sudo DEPLOY_DIR=/home/ubuntu/treehole SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh
```

回滚只切换 `current` 版本软链接，不替换 `shared/data`、`shared/storage` 或生产环境文件。
