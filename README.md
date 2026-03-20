# 西电树洞（Flutter Web MVP）

这是一个基于 Flutter 的 Web 端前台 MVP，按 `sol.txt` 中的功能清单先实现了核心页面与交互骨架。

## 已实现页面

- 登录 / 注册（校内邮箱规则校验）
- 校园身份认证页
- 首页 / 信息流（频道筛选）
- 发帖页（表单校验、真实图片选择上传、发布后绑定 `imageUploadIds`）
- 帖子详情页（点赞/收藏/举报/评论占位）
- 搜索 / 筛选页（关键词、频道、状态、有图、可私信）
- 消息 / 私信页（申请列表、会话列表、真实消息收发）
- 会话详情页（真实消息同步，支持表情输入）
- 收藏页
- 个人中心页
- 我的帖子 / 我的评论 / 我的举报
- 管理员后台（概览、内容审核、图片审核、举报处理、用户管理、注销审核、分类标签、系统配置）
- 表情设置（开关、常用表情自定义）

## 技术说明

- 已接入 API 客户端、鉴权 token 持久化、仓库层（Repository）
- 前端核心页（首页/搜索/消息/发帖）已切换 Riverpod 状态管理，统一加载/错误态组件 `AsyncPageState`
- 已内置 Python 后端（`backend/server.py`），前后端可直接联调
- 后端已切换为 SQL 持久化（SQLite，Repository/DAO + 事务）
- 已接入图片上传链路（支持本地对象存储 / S3 兼容对象存储）与管理员图片审核流
- 私信链路已落库：支持发起私信申请、同意后建立双向会话、历史消息持久化
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

### 腾讯云试用机部署（CVM / Lighthouse）

仓库已补充腾讯云部署脚本和配置：

- `scripts/package_release.sh`：本地构建并打包发布包
- `scripts/deploy_tencent.sh`：从本机通过 SSH 上传并执行服务器安装
- `scripts/install_tencent_host.sh`：服务器侧安装 Nginx + systemd 并发布
- `deploy/tencent/backend.env.example`：后端环境变量模板
- `deploy/tencent/xdu-whisperbox.service`：systemd 服务
- `deploy/tencent/nginx-xdu-whisperbox.conf`：Nginx 反向代理配置

开始部署前，腾讯云实例需满足：

- Linux Ubuntu 22.04
- 已放通 `22`、`80`
- 你本机可以通过 SSH 登录该实例

本机执行：

```bash
DEPLOY_HOST=<你的腾讯云公网IP> \
DEPLOY_USER=root \
DEPLOY_SSH_KEY=~/.ssh/tencent-cloud.pem \
./scripts/deploy_tencent.sh
```

如果你的登录用户不是 `root`，把 `DEPLOY_USER` 改成实际用户名即可，例如 `ubuntu`。

部署完成后，服务器会生成环境变量文件：

```bash
/etc/xdu-whisperbox.env
```

至少应检查并修改：

- `BACKEND_ADMIN_PASSWORD`
- `BACKEND_SMTP_USERNAME`
- `BACKEND_SMTP_PASSWORD`
- `BACKEND_SMTP_FROM_EMAIL`

修改后重启服务：

```bash
sudo systemctl restart xdu-whisperbox
sudo systemctl status xdu-whisperbox
curl http://127.0.0.1:8080/api/channels
```

公网访问地址：

- `http://<你的腾讯云公网IP>/`
- `http://<你的腾讯云公网IP>/api/channels`

当前内测地址（2026-03-08）：

- 前台：`http://81.69.16.134/`
- API 健康检查：`http://81.69.16.134/api/channels`

说明：

- 该部署方式默认使用 SQLite + 本地对象存储，适合试用机和小规模内测
- 中国大陆以外访问限制，建议放在腾讯云边界产品上做；当前仓库内的 Nginx 模板只负责反向代理，不负责地理位置拦截

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
- 消息：发起私信申请、私信申请列表、同意/拒绝申请、会话列表、会话消息列表、发送私信
- 个人：我的资料、隐私设置、我的评论、删除评论、我的举报、注销账号申请
- 管理员认证：`/admin/auth/login`、`/admin/auth/logout`、`/admin/auth/me`、`/admin/auth/password`
- 管理员业务：统计概览、内容审核、图片审核、举报处理、用户状态管理、注销申请审核、匿名帖真实作者追溯、频道标签管理、敏感词/系统配置

## 更新日志

### 2026-03-20

- 私信功能增强：新增未读数与全局红点提醒，进入会话后自动已读
- 私信消息支持已读状态展示，发送方可看到“已读 / 未读”
- 新增会话级屏蔽功能：可屏蔽或解除屏蔽对方，屏蔽后禁止继续发起私信和发送消息
- 新增单侧删除会话功能：删除后仅从当前用户列表隐藏，不立即物理删除历史消息
- 私信发送失败时保留失败内容，并提供“重试发送”入口

### 2026-03-08

- 私信功能从演示版改为真实可用：支持帖子详情页发起私信申请、管理员同意后建立双向会话、消息持久化存储与历史消息拉取
- 管理员审核页支持查看匿名帖/匿名评论的真实账号信息（昵称、邮箱、学号、内部用户 ID）
- 输入区交互优化：表情入口改为紧凑按钮，不再挡住评论/私信输入框
- 发帖页标题输入框拦截 `Tab` 焦点跳转，不再自动跳到正文
- 腾讯云现网已更新到最新版：`http://81.69.16.134/`

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

## 上线前检查清单

### 当前判断

- 现阶段已具备小范围内测能力
- 若目标是正式公网长期运行，当前仍缺少一层生产化能力
- 主要差距不在页面数量，而在生产配置收口、运维可靠性、风控闭环、通知与私信的完整度

### P0：正式上线前必须完成

1. 收口内测/演示能力
   - 关闭前端接口失败时回退本地 Mock 的逻辑
   - 关闭调试验证码返回 `debugCode`
   - 移除或禁用 demo 账号、默认管理员密码、默认演示配置
   - 明确区分开发环境、测试环境、生产环境配置
2. 完成正式部署基础设施
   - 绑定正式域名
   - 启用 HTTPS
   - 配置健康检查、进程守护、日志轮转
   - 落实备份与恢复方案
   - 若仅面向中国大陆正式提供服务，按要求完成备案
3. 将默认运行存储切到正式方案
   - 数据库切换为 MySQL 或 PostgreSQL
   - 图片与头像切换到正式对象存储
   - 明确迁移、回滚、容灾方案
4. 补齐核心风控闭环
   - 强化发帖、评论、私信、上传的频率限制
   - 完善敏感内容识别与拦截策略
   - 建立违规内容复核与追溯机制
   - 保证管理员关键操作有完整审计记录

### P1：上线后高频会暴露的功能缺口

1. 完善私信能力
   - 未读数与红点提醒
   - 已读状态
   - 拉黑或屏蔽
   - 删除会话
   - 更明确的发送失败与重试提示
2. 补齐通知中心
   - 评论通知
   - 回复通知
   - 收藏或点赞通知
   - 举报处理结果通知
   - 系统公告通知
3. 继续增强管理员后台
   - 批量审核
   - 更强的筛选、排序与搜索
   - 数据导出
   - 申诉处理
   - 已注销账号恢复
   - 多管理员权限分级
4. 完善账号安全能力
   - 登录会话管理
   - 强制下线
   - 更完整的改密与找回密码异常处理
   - 更换绑定邮箱流程

### P2：可用性与长期维护能力

1. 建立自动化测试
   - 注册
   - 登录
   - 发帖
   - 图片上传
   - 私信
   - 举报
   - 管理员审核
   - 找回密码
2. 完善发布流程
   - 一键部署
   - 版本标识
   - 回滚方案
   - 前端静态资源缓存更新策略
3. 补充合规与说明页面
   - 用户协议
   - 隐私政策
   - 内容管理规则
   - 举报处理说明

### 结论

- 当前版本适合继续做校园内测
- 若要作为正式站点长期稳定运行，优先完成 P0，再按 P1 补齐用户日常高频能力
