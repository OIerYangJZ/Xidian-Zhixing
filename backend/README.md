# XDU Treehole Backend (Python)

一个本地后端，核心 API 使用 Python 标准库实现；启用 S3/OSS 对象存储时需额外安装 `boto3`。
后端也可直接托管 Flutter Web 构建产物（默认 `build/web`），用于单端口内测发布。

## 启动

```bash
python3 backend/server.py
```

推荐（显式环境变量）：

```bash
BACKEND_HOST=0.0.0.0 \
BACKEND_PORT=8080 \
BACKEND_ADMIN_USERNAME=admin \
BACKEND_ADMIN_PASSWORD=admin123456 \
python3 backend/server.py
```

默认监听：`http://0.0.0.0:8080/api`

可选环境变量：

- `BACKEND_HOST`（默认 `0.0.0.0`）
- `BACKEND_PORT`（默认 `8080`）
- `BACKEND_DB_FILE`（默认 `backend/data/treehole.db`）
- `BACKEND_STORAGE_DIR`（默认 `backend/storage/objects`）
- `BACKEND_WEB_ROOT`（默认 `<项目根目录>/build/web`，用于托管前端静态文件）
- `BACKEND_OBJECT_STORAGE_BACKEND`（默认 `local`，可选 `s3` / `oss` / `s3_compat`）
- `BACKEND_ADMIN_USERNAME`（默认 `admin`）
- `BACKEND_ADMIN_PASSWORD`（默认 `admin123456`）
- `BACKEND_SMTP_HOST`（SMTP 主机，启用真实邮箱验证码必填，QQ 可用 `smtp.qq.com`）
- `BACKEND_SMTP_PORT`（默认 `465`，QQ 常用 `465`）
- `BACKEND_SMTP_USERNAME`（SMTP 登录账号）
- `BACKEND_SMTP_PASSWORD`（SMTP 登录密码/授权码）
- `BACKEND_SMTP_FROM_EMAIL`（发件邮箱，默认同 `BACKEND_SMTP_USERNAME`）
- `BACKEND_SMTP_FROM_NAME`（默认 `西电树洞`）
- `BACKEND_SMTP_USE_SSL`（默认 `true`，QQ 推荐 `true`）
- `BACKEND_SMTP_USE_STARTTLS`（默认 `false`，QQ 推荐 `false`）
- `BACKEND_ALLOW_DEBUG_VERIFY_CODE`（默认 `false`，设置为 `true` 后允许 `123456` 调试码）
- `BACKEND_INCLUDE_DEBUG_CODE`（默认 `false`，设置为 `true` 后接口响应会返回 `debugCode`）

当 `BACKEND_OBJECT_STORAGE_BACKEND=s3`（或 `oss` / `s3_compat`）时，额外支持：

- `BACKEND_S3_BUCKET`（必填）
- `BACKEND_S3_PREFIX`（可选，对象 key 前缀）
- `BACKEND_S3_REGION`（可选）
- `BACKEND_S3_ENDPOINT`（可选，S3 兼容网关/OSS Endpoint）
- `BACKEND_S3_ACCESS_KEY_ID`（可选，若实例角色可省略）
- `BACKEND_S3_SECRET_ACCESS_KEY`（可选）
- `BACKEND_S3_SESSION_TOKEN`（可选）
- `BACKEND_S3_PUBLIC_BASE_URL`（可选，前端访问图片 URL 前缀）
- `BACKEND_S3_ADDRESSING_STYLE`（可选，默认 `auto`）

## 一体化内测发布（Web + API）

在项目根目录执行：

```bash
FLUTTER_BIN=/path/to/flutter ./scripts/build_web_beta.sh
BACKEND_HOST=0.0.0.0 BACKEND_PORT=8080 ./scripts/run_backend_beta.sh
```

成功后可访问：

- `http://<server-ip>:8080/`（前端页面）
- `http://<server-ip>:8080/api/channels`（接口检查）

## 默认测试账号

- 普通用户：`demo@stu.xidian.edu.cn / 123456`
- 管理员：`admin / admin123456`（首次初始化；独立账号体系，不复用用户密码）
- 密码在数据库中以 PBKDF2-SHA256 哈希存储（兼容旧明文自动迁移）

## 真实邮箱验证码配置

后端现在默认按 SMTP 实际发送验证码邮件。未配置 SMTP 时，`/api/auth/send-code` 会返回错误。

QQ 邮箱示例：

```bash
BACKEND_SMTP_HOST=smtp.qq.com \
BACKEND_SMTP_PORT=465 \
BACKEND_SMTP_USERNAME=your@qq.com \
BACKEND_SMTP_PASSWORD='替换为你的 QQ 邮箱 SMTP 授权码（不是QQ登录密码）' \
BACKEND_SMTP_FROM_EMAIL=your@qq.com \
BACKEND_SMTP_FROM_NAME=西电树洞 \
BACKEND_SMTP_USE_SSL=true \
BACKEND_SMTP_USE_STARTTLS=false \
python3 backend/server.py
```

如果你需要开发调试模式（不建议生产启用）：

```bash
BACKEND_ALLOW_DEBUG_VERIFY_CODE=true
BACKEND_INCLUDE_DEBUG_CODE=true
```

## 已实现接口

- 认证：`/auth/send-code` `/auth/login`（支持学号或邮箱标识） `/auth/verify` `/auth/resend-code` `/auth/logout`
- 用户：`/users/me` `/users/privacy`
- 频道/帖子：`/channels` `/posts` `/posts/mine` `/posts/favorites` `/posts/{id}`
- 上传/图片：`/uploads/images` `/uploads/mine` `/storage/{key}`
- 评论：`/posts/{id}/comments` `/comments/mine` `/comments/{id}`
- 互动：`/posts/{id}/like` `/posts/{id}/favorite`（POST 收藏、DELETE 取消收藏）
- 举报：`/reports` `/reports/mine`
- 消息：`/messages/requests` `/messages/requests/{id}/accept|reject` `/messages/conversations`
- 管理员：
  - 认证：`/admin/auth/login` `/admin/auth/logout` `/admin/auth/me` `/admin/auth/password`
  - 概览：`/admin/overview`
  - 内容审核：`/admin/reviews` `/admin/reviews/{post|comment}/{id}/{approve|reject|delete|risk}`
  - 图片审核：`/admin/images/reviews` `/admin/images/{id}/review`
  - 举报处理：`/admin/reports` `/admin/reports/{id}/handle`
  - 用户管理：`/admin/users` `/admin/users/{id}/action`
  - 分类标签：`/admin/channels-tags` `/admin/channels` `/admin/channels/{name}` `/admin/tags` `/admin/tags/{name}`
  - 系统配置：`/admin/config`

## 数据存储

- 启动后会在 `backend/data/treehole.db` 使用 SQLite 持久化（Repository/DAO + 事务）。
- 图片对象默认写入 `backend/storage/objects`（本地对象存储）。
- 已支持切换到 S3 兼容对象存储（AWS S3 / Aliyun OSS S3 兼容接口）。
- 若首次启动检测到 `backend/data/db.json`，会自动导入到 SQL。
- 已提供 JSON -> MySQL/PostgreSQL 迁移脚本与建表 SQL（见下文）。

### S3 / OSS 启动示例

先安装存储依赖：

```bash
pip install -r backend/requirements-storage.txt
```

示例（S3 兼容接口）：

```bash
BACKEND_OBJECT_STORAGE_BACKEND=s3 \
BACKEND_S3_BUCKET=xdu-treehole \
BACKEND_S3_REGION=ap-east-1 \
BACKEND_S3_ENDPOINT=https://s3.example.com \
BACKEND_S3_ACCESS_KEY_ID=xxxx \
BACKEND_S3_SECRET_ACCESS_KEY=yyyy \
python3 backend/server.py
```

## 重置数据

```bash
python3 backend/reset_db.py
```

该命令会重置：
- `backend/data/treehole.db`
- `backend/storage/objects`

## 图片上传与审核链路（最小示例）

1) 用户上传图片（Base64）：

```http
POST /api/uploads/images
Authorization: Bearer <token>
Content-Type: application/json

{
  "fileName": "demo.png",
  "contentType": "image/png",
  "dataBase64": "<base64-data>"
}
```

2) 发帖时绑定上传 ID：

```json
{
  "title": "xxx",
  "content": "xxx",
  "channel": "学习交流",
  "tags": ["学习"],
  "imageUploadIds": ["img1"]
}
```

3) 管理员审核图片：

```http
POST /api/admin/images/{id}/review
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "action": "approve",
  "note": "通过"
}
```

## 风控与频率限制

- 频率限制按用户维度执行（默认 1 小时窗口）：
  - `postRateLimit`：发帖
  - `commentRateLimit`：评论
  - `messageRateLimit`：举报、私信申请处理、图片上传
- 以上阈值可在管理员配置接口中调整：`/api/admin/config`
- 文本风控（发帖/评论）：
  - 目前不再对联系方式关键词、手机号、外链做封控
  - 对敏感词命中、疑似刷屏、超长文本做风险标记 `riskMarked=true` 并写审计日志
- 图片风控：
  - 同一用户重复上传同哈希图片会被标记为风险（`status=risk`），进入审核流

## 迁移到 MySQL / PostgreSQL

### 1) 安装依赖

```bash
pip install -r backend/requirements-db.txt
```

### 2) 执行迁移

PostgreSQL:

```bash
python3 backend/migrate_json_to_sql.py \
  --dialect postgres \
  --database-url postgresql+psycopg://user:password@127.0.0.1:5432/xdu_treehole \
  --truncate
```

MySQL:

```bash
python3 backend/migrate_json_to_sql.py \
  --dialect mysql \
  --database-url "mysql+pymysql://user:password@127.0.0.1:3306/xdu_treehole?charset=utf8mb4" \
  --truncate
```

### 3) Schema 和索引

- PostgreSQL: `backend/sql/schema_postgresql.sql`
- MySQL: `backend/sql/schema_mysql.sql`
- 索引已覆盖：帖子流、评论、举报、私信申请、会话、审计日志等高频查询。

> 注意：当前 `backend/server.py` 运行时已使用 SQLite（`backend/data/treehole.db`）。
> 上述脚本用于把历史 `db.json` 数据迁移到 MySQL/PostgreSQL。

## 更新日志

### 2026-03-07

- 增加 `BACKEND_WEB_ROOT`，后端可直接托管 Flutter Web 静态文件
- 新增非 `/api` 请求的 SPA 回退逻辑（回退 `index.html`）
- 新增内测部署脚本：`scripts/build_web_beta.sh`、`scripts/run_backend_beta.sh`
- 认证体验优化：注册自动从邮箱前缀推导学号，登录支持学号标识
- 邮件服务未配置时启用内测验证码兜底（`123456`）
- 私信申请列表返回并展示申请状态（待处理/已同意/已拒绝）
- 用户资料收藏数改为按可见收藏帖子计算，和收藏列表一致
- 验证码发送失败时新增“邮箱不存在/不可达”识别提示

### 2026-03-06

- 增加管理员独立认证接口：`/admin/auth/login`、`/admin/auth/logout`、`/admin/auth/me`、`/admin/auth/password`
- 管理员账号密码从用户体系中解耦，改为 `settings` 独立维护哈希
- 管理员 token 会话与用户 token 会话分离，互不影响
- 对象存储新增 S3/OSS 兼容实现（可通过环境变量从 `local` 切换到 `s3`）
- 注册验证码改为 SMTP 真实发送（可通过环境变量启用调试码）
