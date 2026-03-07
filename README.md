# 西电树洞（Flutter Web MVP）

这是一个基于 Flutter 的 Web 端前台 MVP，按 `sol.txt` 中的功能清单先实现了核心页面与交互骨架。

## 已实现页面

- 登录 / 注册（校内邮箱规则校验）
- 校园身份认证页
- 首页 / 信息流（频道筛选）
- 发帖页（表单校验、真实图片选择上传、发布后绑定 `imageUploadIds`）
- 帖子详情页（点赞/收藏/举报/评论占位）
- 搜索 / 筛选页（关键词、频道、状态、有图、可私信）
- 消息 / 私信页（申请列表 + 会话列表）
- 会话详情页（本地演示发送，支持表情输入）
- 收藏页
- 个人中心页
- 我的帖子 / 我的评论 / 我的举报
- 管理员后台（概览、内容审核、举报处理、用户管理、分类标签、系统配置）
- 表情设置（开关、常用表情自定义）

## 技术说明

- 已接入 API 客户端、鉴权 token 持久化、仓库层（Repository）
- 前端核心页（首页/搜索/消息/发帖）已切换 Riverpod 状态管理，统一加载/错误态组件 `AsyncPageState`
- 已内置 Python 后端（`backend/server.py`），前后端可直接联调
- 后端已切换为 SQL 持久化（SQLite，Repository/DAO + 事务）
- 已接入图片上传链路（支持本地对象存储 / S3 兼容对象存储）与管理员图片审核流
- 前台页面优先走后端接口；接口不可用时，列表型页面会回退到本地 Mock（便于演示）

## 启动方式

### 推荐启动命令（2026-03-06）

先开一个终端启动后端，再开一个终端启动前端。

终端 A（后端）：

```bash
BACKEND_HOST=0.0.0.0 \
BACKEND_PORT=8080 \
BACKEND_ADMIN_USERNAME=admin \
BACKEND_ADMIN_PASSWORD=admin123456 \
BACKEND_SMTP_HOST=smtp.qq.com \
BACKEND_SMTP_PORT=465 \
BACKEND_SMTP_USERNAME=your@qq.com \
BACKEND_SMTP_PASSWORD='替换为你的 QQ 邮箱 SMTP 授权码（不是QQ登录密码）' \
BACKEND_SMTP_FROM_EMAIL=your@qq.com \
BACKEND_SMTP_FROM_NAME='西电树洞' \
BACKEND_SMTP_USE_SSL=true \
BACKEND_SMTP_USE_STARTTLS=false \
python3 backend/server.py
```

终端 B（前端）：

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

如果 `flutter` 不在 PATH，可改为：

```bash
/Users/yangjinsey/flutter/bin/flutter pub get
/Users/yangjinsey/flutter/bin/flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

### 公网内测上线（单端口）

后端现已支持同时托管 Flutter Web 静态文件（默认目录 `build/web`），可直接一个端口上线前后端。

1. 在服务器构建前端（API 走同源 `/api`）：

```bash
FLUTTER_BIN=/path/to/flutter ./scripts/build_web_beta.sh
```

2. 启动后端（会同时提供 Web 页面 + API）：

```bash
BACKEND_HOST=0.0.0.0 \
BACKEND_PORT=8080 \
BACKEND_ADMIN_USERNAME=admin \
BACKEND_ADMIN_PASSWORD='请改成强密码' \
BACKEND_SMTP_HOST=smtp.qq.com \
BACKEND_SMTP_PORT=465 \
BACKEND_SMTP_USERNAME=your@qq.com \
BACKEND_SMTP_PASSWORD='QQ SMTP 授权码' \
BACKEND_SMTP_FROM_EMAIL=your@qq.com \
BACKEND_SMTP_FROM_NAME='西电树洞' \
BACKEND_SMTP_USE_SSL=true \
BACKEND_SMTP_USE_STARTTLS=false \
./scripts/run_backend_beta.sh
```

3. 放行服务器防火墙端口（示例：`8080`），然后用同学浏览器访问：

- `http://<你的公网IP>:8080/`（前端）
- `http://<你的公网IP>:8080/api/channels`（接口健康检查）

4. 可选：若你有域名，可用 Nginx/Caddy 反向代理到 `127.0.0.1:8080`，再启用 HTTPS。

### 固定公网地址（GitHub + Render 免费版）

如果你不希望再使用自己电脑作为服务器，可以用 Render 免费 Web Service 部署，拿到固定地址：

- `https://<你的服务名>.onrender.com`

项目已提供 Render 配置文件：`render.yaml`（仓库根目录）。

1. 推送代码到 GitHub（`main` 分支）：

```bash
git remote add origin <你的GitHub仓库URL>
git push -u origin main
```

2. 打开 Render 控制台：
   - New -> Blueprint
   - 选择你的 GitHub 仓库
   - Render 会自动识别 `render.yaml`

3. 在 Render 环境变量里补齐敏感配置（`sync: false` 的项）：
   - `BACKEND_ADMIN_PASSWORD`
   - `BACKEND_SMTP_USERNAME`
   - `BACKEND_SMTP_PASSWORD`
   - `BACKEND_SMTP_FROM_EMAIL`

4. 等待部署完成后，直接访问：
   - `https://<你的服务名>.onrender.com`
   - `https://<你的服务名>.onrender.com/api/channels`

注意：
- Render 免费实例会休眠，首次访问会有冷启动延迟。
- 免费实例文件系统非持久化，SQLite/本地图片存储不适合生产长期保存。

### 1) 启动后端（基础方式）

在项目根目录执行：

```bash
python3 backend/server.py
```

默认地址：`http://127.0.0.1:8080/api`  
默认普通用户账号：`demo@stu.xidian.edu.cn / 123456`  
默认管理员账号：`admin / admin123456`（首次初始化，可用环境变量覆盖）  
更多后端说明见：`backend/README.md`
管理员入口：登录页点击「管理员后台登录」

可选管理员环境变量：

- `BACKEND_ADMIN_USERNAME`（默认 `admin`）
- `BACKEND_ADMIN_PASSWORD`（默认 `admin123456`）

真实邮箱验证码 SMTP 环境变量：

- `BACKEND_SMTP_HOST`（例如 QQ 邮箱用 `smtp.qq.com`）
- `BACKEND_SMTP_PORT`（QQ 常用 `465`）
- `BACKEND_SMTP_USERNAME`
- `BACKEND_SMTP_PASSWORD`
- `BACKEND_SMTP_FROM_EMAIL`（可选，默认同用户名）
- `BACKEND_SMTP_FROM_NAME`（可选，默认 `西电树洞`）
- `BACKEND_SMTP_USE_SSL`（QQ 推荐 `true`）
- `BACKEND_SMTP_USE_STARTTLS`（QQ 推荐 `false`）

调试开关（仅开发环境）：

- `BACKEND_ALLOW_DEBUG_VERIFY_CODE=true`：允许 `123456` 调试验证码
- `BACKEND_INCLUDE_DEBUG_CODE=true`：验证码接口响应返回 `debugCode`

### 2) 后端数据与图片存储说明

- 默认数据库文件：`backend/data/treehole.db`
- 默认对象存储目录：`backend/storage/objects`（`BACKEND_OBJECT_STORAGE_BACKEND=local`）
- 兼容老数据：首次启动时若存在 `backend/data/db.json`，会自动导入 SQL
- 一键重置（SQL + 对象存储）：

```bash
python3 backend/reset_db.py
```

如果要切换到 S3/OSS（S3 兼容接口）：

```bash
pip install -r backend/requirements-storage.txt
BACKEND_OBJECT_STORAGE_BACKEND=s3 \
BACKEND_S3_BUCKET=xdu-treehole \
BACKEND_S3_ENDPOINT=https://s3.example.com \
BACKEND_S3_ACCESS_KEY_ID=xxxx \
BACKEND_S3_SECRET_ACCESS_KEY=yyyy \
python3 backend/server.py
```

### 3) 将 `backend/data/db.json` 迁移到 MySQL / PostgreSQL（可选）

先安装迁移依赖：

```bash
pip install -r backend/requirements-db.txt
```

PostgreSQL 示例：

```bash
python3 backend/migrate_json_to_sql.py \
  --dialect postgres \
  --database-url postgresql+psycopg://user:password@127.0.0.1:5432/xdu_treehole \
  --truncate
```

MySQL 示例：

```bash
python3 backend/migrate_json_to_sql.py \
  --dialect mysql \
  --database-url "mysql+pymysql://user:password@127.0.0.1:3306/xdu_treehole?charset=utf8mb4" \
  --truncate
```

- 建表 SQL：`backend/sql/schema_postgresql.sql`、`backend/sql/schema_mysql.sql`
- 已补索引：帖子列表、评论列表、举报处理、私信申请、会话列表、审计日志等高频查询路径
- 当前后端运行时使用 `backend/data/treehole.db`；迁移脚本用于把历史 `db.json` 导入 MySQL/PostgreSQL

### 4) 启动前端（Flutter Web）

在项目根目录执行：

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

如果你暂时不传 `API_BASE_URL`，默认会请求：

```bash
http://localhost:8080/api
```

如果你遇到旧数据导致账号状态异常（例如 demo 账号被注销），可以先重置：

```bash
python3 backend/reset_db.py
```

## 已接入接口分组

- 认证：发送验证码、登录、验证码认证、重发验证码、退出登录
- 帖子：频道、帖子列表、帖子详情、发帖（支持 `imageUploadIds`）、评论、点赞、收藏/取消收藏、举报、我的帖子、收藏帖子
- 上传：图片上传（`/uploads/images`）、我的上传记录（`/uploads/mine`）、对象存储访问（`/storage/{key}`）
- 消息：私信申请列表、同意/拒绝申请、会话列表
- 个人：我的资料、隐私设置、我的评论、删除评论、我的举报、删除账号
- 管理员认证：`/admin/auth/login`、`/admin/auth/logout`、`/admin/auth/me`、`/admin/auth/password`
- 管理员业务：统计概览、内容审核、图片审核、举报处理、用户状态管理、频道标签管理、敏感词/系统配置

## 更新日志

### 2026-03-07

- 后端新增静态资源托管：非 `/api` 路径可直接返回 `build/web` 内容，支持 SPA 路由回退
- 新增内测部署脚本：`scripts/build_web_beta.sh`、`scripts/run_backend_beta.sh`
- 新增 README 公网内测上线步骤（单端口发布 Web + API）
- 落实内测意见：注册头像本地上传、注册自动推导学号、登录改学号、无 SMTP 时启用验证码兜底

### 2026-03-06

- 管理员后台入口独立：从用户“个人中心”移除管理员入口，改为登录页独立入口
- 管理员认证独立：新增 `/api/admin/auth/*`，管理员 token 与用户 token 分离
- 管理员账号密码独立：默认 `admin / admin123456`（首次初始化），不复用用户密码
- 首页视觉升级：登录后首页新增顶部欢迎区、快捷操作、增强搜索与筛选样式、导航图标样式优化
- 帖子卡片视觉升级：频道/状态胶囊、指标徽标、标签样式和信息层次优化
- 表情功能上线：发帖正文、评论/回复、私聊会话输入均可选择表情
- 新增表情设置：支持启用/关闭表情、常用表情自定义
- 发帖发布后立即展示，不再提示“等待审核后展示”
- 对象存储支持 S3/OSS：后端可通过环境变量从本地存储切换到 S3 兼容存储
- 注册验证码改为 SMTP 真实邮箱发送（支持配置调试码开关）

## 建议下一步（路线图）

### 已完成

1. 后端读写从 JSON 切换为 SQL（SQLite，Repository/DAO + 事务）
2. 增加图片审核与对象存储上传链路（本地对象存储 + 管理员审核）
3. 提供 `db.json` 到 MySQL/PostgreSQL 的迁移脚本与索引 schema
4. 密码存储升级为 PBKDF2-SHA256 哈希（兼容旧明文自动迁移）
5. 增加全局频率限制策略（发帖/评论/举报/私信处理/图片上传）
6. 增加更细粒度风控（敏感词/重复文本/重复图片哈希）
7. 前端抽离状态管理（Riverpod）并统一加载/错误态组件（`AsyncPageState`）
8. 前端接入真实图片选择与上传组件（Web 端图片选择 -> `/uploads/images` -> 发帖绑定 `imageUploadIds`）
9. 给帖子分类频道增加“其他”，并支持排序（按发布时间 / 按点赞量）
10. 发帖改为直接发布（默认不走审核）
11. 去掉联系方式关键词、手机号、外链的封控
12. 页面视觉升级（主题色、导航样式、背景层次与卡片观感优化）
13. 对象存储从本地扩展到 S3/OSS（S3 兼容）

### 待完成

- 暂无（README 中原有待完成项已完成）


### 内测意见一（已落实 2026-03-07）
1. 注册头像改为本地图片上传（不再要求手填 URL）
2. 注册页移除手填学号，学号自动取注册邮箱前缀
3. 登录改为“学号 + 密码”，后端兼容邮箱/学号两种标识
4. 未配置 SMTP 时启用内测验证码兜底（默认 `123456`），避免注册流程中断
### 内测意见二（已落实 2026-03-07）
1. 帖子详情页支持 URL 状态同步，刷新后可自动恢复到同一帖子
2. 启用 SMTP 真实邮箱验证码链路（内测部署已按环境变量开启）
3. 发送验证码失败时对“邮箱不存在/不可达”场景给出明确提示
4. 私信申请同意/拒绝后保留状态并展示“已同意/已拒绝”
5. 个人中心收藏数量改为按真实可见收藏帖计算，与收藏列表对齐
