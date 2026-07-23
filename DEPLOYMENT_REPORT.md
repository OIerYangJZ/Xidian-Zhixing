# 西电知行网页端内测部署报告

报告日期：2026-07-23
正式地址：`https://zhixing.xidian.edu.cn`

## 0. 结论

代码、生产配置、正式 Web 构建和本机端到端验收已经完成；正式域名当前也能返回网页和健康检查。

但本轮**没有完成服务器上的新版本替换**。当前会话没有生产服务器 SSH 主机、用户、密钥或已配置的部署环境变量，也没有服务器证书文件的真实路径和项目组生产测试账号。不能安全上传发布包、修改 Nginx 或写入生产数据库，因此不得宣称新版本已经上线。

现网检查证明服务器仍在运行旧版本：

- `GET https://zhixing.xidian.edu.cn/` 返回 200；
- `GET https://zhixing.xidian.edu.cn/api/health` 返回 200，数据库、SMTP、对象存储均报告正常；
- `/auth/login` 刷新返回 200，SPA 回退正常；
- 现网静态文件 `Last-Modified` 为 2026-07-22；
- 现网 API 对任意 Origin 仍返回 `Access-Control-Allow-Origin: *`；
- 现网 HTTPS 响应未看到 HSTS；
- 本轮新代码已改为精确 CORS 白名单，但尚未部署到服务器。

因此当前状态是：**现网站点可访问，但本轮加固版本尚未正式发布，完整生产内测验收仍被服务器权限和测试账号阻塞。**

## 1. 项目架构

| 部分 | 技术栈 | 说明 |
|---|---|---|
| 网页端 | Flutter Web / Dart | `flutter_app/`；正式构建输出到 `build/web/` |
| Android/iOS | Flutter | 与网页端共享模型、Repository 和网络层 |
| 微信小程序 | 原生微信小程序 | `miniprogram/` |
| 后端 | Python 3 `ThreadingHTTPServer` | `backend/server.py`，无 Node 服务 |
| 数据库 | SQLite | 在线 Repository 为 SQLite；MySQL/PostgreSQL schema 仅供迁移评估 |
| 上传存储 | 本地对象目录或 S3 兼容存储 | 当前生产模板默认本地目录 |
| 反向代理 | Nginx | 静态文件、HTTPS、SPA 回退、`/api/` 代理 |
| 进程管理 | systemd | `treehole.service`；未引入 PM2 |
| 日志 | Python JSON 日志 + journald；Nginx 文件日志 | journald 负责后端日志轮转 |

生产请求链路：

`浏览器 -> HTTPS Nginx -> /api/ 代理到 127.0.0.1:8080 -> Python -> SQLite/对象存储`

网页端生产 API 地址统一为同源 `/api`，没有在业务页面中散落正式域名。App 与小程序保留显式构建/本地配置入口。

### 地址、端口和密钥审计

- 生产端口只使用 Nginx 80/443 和回环后端 8080。
- `127.0.0.1:8080` 出现在 Nginx upstream、systemd、健康检查、Docker 健康检查和本地测试中，均属于服务器内部或开发用途。
- `0.0.0.0:8080` 只用于容器或本地开发监听；systemd 生产配置强制覆盖为 `127.0.0.1`。
- Flutter 的 `127.0.0.1:8080`、Android 模拟器的 `10.0.2.2:8080`，以及小程序的 `localhost:8080`/示例 LAN 地址只用于开发模式；Flutter Web release 固定注入 `/api`。
- `example.com`、`smtp.example.com`、`s3.example.com` 和 `192.0.2.10` 只存在于测试、注释或示例模板中；未发现实际测试域名或临时生产域名。
- 正式域名只写在部署环境模板的来源白名单和文档中，没有散落到业务请求代码。
- Git 跟踪文件中未发现私钥头、OpenAI/GitHub/AWS 常见真实 Token 前缀或 JWT 字符串；发现的密码、SMTP、AI 和 S3 字段均为空值或明确占位符。
- 本地 SQLite、WAL/SHM、上传目录、`.env`、证书、私钥、日志、`build/` 和 `dist/` 均被 Git 忽略。

## 2. 启动、构建和配置

### 当前命令

- 后端开发启动：`bash scripts/start_backend.sh`
- 后端直接启动：`python3 backend/server.py`
- Flutter Web 正式构建：`FLUTTER_BIN=/path/to/flutter bash scripts/build_web_production.sh`
- 发布包：`FLUTTER_BIN=/path/to/flutter bash scripts/package_release.sh`
- systemd 启动：`sudo systemctl enable --now treehole`
- 健康检查：`bash scripts/health_check.sh`

### 生产环境文件

- 根模板：`.env.production.example`
- 部署模板：`deploy/tencent/backend.env.example`
- 服务器真实文件：`/home/ubuntu/treehole/shared/config/backend.env`

关键生产变量：

- `BACKEND_CORS_ALLOWED_ORIGINS=https://zhixing.xidian.edu.cn`
- `BACKEND_AUTH_ALLOWED_EMAILS=<项目组学生邮箱列表>`
- `BACKEND_ENABLE_XIDIAN_AUTH=false`
- `BACKEND_MAX_REQUEST_BODY_MB=20`
- `BACKEND_DB_FILE=/home/ubuntu/treehole/shared/data/treehole.db`
- `BACKEND_STORAGE_DIR=/home/ubuntu/treehole/shared/storage/objects`
- `BACKEND_WEB_ROOT=/home/ubuntu/treehole/current/web`

真实管理员密码、SMTP 授权码、AI/S3 密钥和测试成员邮箱不得提交到 Git。项目不使用 JWT；登录态使用不可预测会话 Token，并持久化在 SQLite。

## 3. 修改过的文件

### 新增

- `.env.example`
- `.env.production.example`
- `PRODUCTION_DEPLOYMENT.md`
- `DEPLOYMENT_REPORT.md`

### 修改

- `.gitignore`
- `backend/_globals.py`
- `backend/helpers/_http_helpers.py`
- `backend/helpers/__init__.py`
- `backend/handlers/_auth_handler.py`
- `backend/handlers/_admin_handler.py`
- `backend/server.py`
- `backend/services/_db_service.py`
- `backend/services/_user_service.py`
- `backend/tests/test_admin.py`
- `backend/tests/test_auth.py`
- `backend/tests/test_database_initialization.py`
- `scripts/validate_production_env.py`
- `deploy/production/.env.example`
- `deploy/production/nginx-cache.conf`
- `deploy/tencent/backend.env.example`
- `deploy/tencent/xdu-whisperbox.env`
- `flutter_app/lib/features/auth/login_page.dart`
- `flutter_app/lib/mobile/features/auth/login_page.dart`
- `flutter_app/lib/mobile/features/auth/register_page.dart`

主要变化：

- API CORS 从无条件 `*` 改为精确来源白名单；
- 生产环境强制要求项目组测试邮箱白名单；
- 注册、验证码、登录和既有会话均受白名单限制；
- 学校统一身份认证接口层保留，但默认明确禁用；
- 请求体统一限制为 20 MB，图片业务限制仍为 5 MB；
- 后端日志改为 JSON，异常包含堆栈；
- 增加 SIGTERM/SIGINT 优雅关闭；
- 修正健康检查中对象存储永远报告成功的问题；
- 修复专用管理员处理举报时触发 SQLite 外键 500 的问题；
- 登录和注册页明确显示“项目组内测白名单”；
- 扩展生产环境校验和敏感环境文件忽略规则。

## 4. 生产启动、停止、重启和日志

```bash
sudo systemctl enable --now treehole
sudo systemctl status treehole --no-pager -l
sudo systemctl stop treehole
sudo systemctl restart treehole
sudo journalctl -u treehole -n 200 --no-pager
sudo journalctl -u treehole -f
sudo journalctl -u treehole --since today
```

Nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo tail -n 200 /var/log/nginx/treehole.error.log
sudo tail -n 200 /var/log/nginx/treehole.access.log
```

## 5. 数据库迁移、备份和恢复

SQLite 初始化已经验证为原子操作；已有数据库不会因为零用户或缺少新元数据标记而被当作全新数据库重置。`reset_db.py` 是破坏性工具，不属于生产启动流程。

生产数据：

- `/home/ubuntu/treehole/shared/data/treehole.db`
- `/home/ubuntu/treehole/shared/storage/objects/`

一致性备份：

```bash
sudo systemctl stop treehole
sudo tar -C /home/ubuntu/treehole \
  -czf /home/ubuntu/treehole/backups/treehole-$(date -u +%Y%m%dT%H%M%SZ).tar.gz \
  shared/data shared/storage
sudo systemctl start treehole
sudo systemctl is-active treehole
```

恢复时先把当前目录移动到带时间戳的保留位置，再解压经过校验的备份，修正属主后启动。完整步骤见 `PRODUCTION_DEPLOYMENT.md`。本轮未删除、清空或覆盖任何现有数据库和上传文件。

## 6. Nginx

仓库模板：

`deploy/production/nginx-treehole-https.conf.template`

服务器目标：

`/etc/nginx/sites-available/treehole.conf`

静态根目录：

`/home/ubuntu/treehole/current/web`

模板已覆盖：

- HTTP 到 HTTPS；
- TLS 1.2/1.3；
- HSTS 和常用安全头；
- `/api/` 反向代理；
- `client_max_body_size 20m`；
- Flutter SPA 刷新回退；
- HTML、Service Worker 和入口清单不缓存；
- 其他静态资源缓存；
- Nginx 访问与错误日志。

服务器当前证书路径未知，本轮没有猜测或改写现有证书配置。

## 7. 构建和自动化测试结果

### 通过

- Python 语法编译检查通过；
- 后端 pytest：`115 passed`；
- Flutter analyze：`No issues found`；
- Flutter test：`87 tests passed`；
- Flutter Web release 构建通过；
- 构建输出：`build/web/`；
- 发布归档路径和 SHA-256 清单验证通过；
- 验证归档：`dist/treehole-0.1.0+21+fd5c01e.tar.gz`，约 11 MB；
- 生产环境校验器：填入测试值的临时配置通过，模板占位符被正确拒绝；
- `git diff --check` 通过。

归档是基于未提交工作区生成的本机验证包，只能用于验证，不应直接作为正式发布包。正式部署前应先审查并提交预期变更，再从干净工作区重新构建。

### 本机真实 HTTP 端到端验收

所有数据均写入系统临时目录中的独立 SQLite 和上传目录，没有触碰仓库现有数据库：

| 验收项 | 结果 |
|---|---|
| 首页 | 通过 |
| SPA 路由刷新 | 通过 |
| 创建白名单测试账号 | 通过 |
| 非白名单账号注册 | 403，通过 |
| 登录状态保持 | 通过 |
| 退出登录 | 通过 |
| 帖子列表 | 通过 |
| 发布帖子 | 通过 |
| 帖子详情 | 通过 |
| 评论 | 通过 |
| 删除本人评论和帖子 | 通过 |
| 上传 PNG 图片并绑定帖子 | 通过 |
| 错误请求提示 | 400，通过 |
| 未登录受限接口 | 401，通过 |
| 管理端登录 | 通过 |
| 举报列表和处理 | 通过 |
| 精确 CORS 来源 | 正式来源 200，未列入来源 403 |
| 统一认证关闭 | 503 且明确提示尚未启用 |
| SIGTERM 优雅关闭 | 通过，进程正常退出并输出 JSON 停止日志 |
| 服务重启后数据和会话仍存在 | 通过 |

## 8. 正式域名检查

2026-07-23 的无副作用现网检查：

| 项目 | 结果 |
|---|---|
| HTTP 跳 HTTPS | 302，通过 |
| HTTPS 首页 | 200，通过 |
| `/auth/login` 刷新 | 200，通过 |
| `/api/health` GET | 200；database/smtp/storage 均为 ok |
| 未登录发布 | 401，通过 |
| 桌面浏览器首屏 | 登录页可正常显示，无 Flutter Debug banner |
| 静态资源缓存 | HTML 不缓存；入口 JS 当前也不缓存 |
| CORS | 不通过；任意 Origin 都返回 `*` |
| HSTS | 当前响应未发现 |
| 新构建版本 | 未部署；现网静态文件时间仍为 2026-07-22 |

## 9. 尚未完成的问题和阻塞项

1. 未提供 SSH 主机、用户、密钥或 `DEPLOY_HOST/DEPLOY_USER`，无法上传新发布包和执行 systemd/Nginx 操作。
2. 未提供服务器现有 TLS 证书和私钥路径，无法安全渲染并替换 HTTPS Nginx 配置。
3. 未提供项目组生产测试邮箱白名单、生产管理员账号或可用测试账号，不能在正式数据库执行注册、发帖、评论、上传、举报和审核。
4. 手机尺寸浏览器自动化的视口覆盖没有生效，正式站点手机首屏未完成可靠截图验收；Flutter 代码和桌面浏览器已通过，仍需真机或可控移动视口复测。
5. “无网络/接口异常提示”已有 `ApiClient` 超时和网络错误转换，并被 Flutter 单元测试覆盖，但本轮没有在正式站点断网状态下完成可视化手工验收。
6. 现网仍有开放 CORS 和缺少 HSTS 的问题，必须部署本轮配置后再次核验。
7. systemd 自动启动、journald 轮转和 Nginx `nginx -t` 只能在目标 Ubuntu 服务器上最终确认；本机 macOS 无 systemd/Nginx。

## 10. 回滚方法

应用版本回滚：

```bash
sudo DEPLOY_DIR=/home/ubuntu/treehole SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh --list
sudo DEPLOY_DIR=/home/ubuntu/treehole SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh
```

该脚本切换 `current` 软链接并重启服务；启动失败时会尝试恢复原版本。`shared/data`、`shared/storage` 和真实环境文件不随应用版本回滚。

Nginx 回滚应在替换前保存旧配置：

```bash
sudo cp -a /etc/nginx/sites-available/treehole.conf \
  /etc/nginx/sites-available/treehole.conf.before-zhixing-release
```

若新配置验证失败，恢复备份后运行：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

数据库恢复必须使用第 5 节的已验证备份，并先保留当前数据副本；不要直接删除生产数据库。

## 11. 完成正式上线所需的下一步

提供以下信息后才能继续完成服务器发布和正式账号验收：

- 可用的 SSH 主机、用户、端口和密钥方式；
- 服务器现有证书与私钥的绝对路径；
- 项目组测试邮箱白名单；
- 一个普通测试账号和一个管理员测试账号，或允许在生产环境创建专用测试账号。

随后应从干净工作区重新构建，先备份 shared 数据和 Nginx 配置，再发布、执行完整生产验收，并复查 CORS、HSTS、缓存、日志、自动启动和重启持久化。
