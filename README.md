# See电 — 西电树洞

面向西安电子科技大学校内用户的匿名社区应用，支持 Web 端和移动端（Android / iOS）。

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Flutter Web + Dart SDK `>=3.3.0 <4.0.0` |
| 状态管理 | `flutter_riverpod: ^2.6.1` |
| HTTP 客户端 | `http: ^1.2.2` |
| 本地存储 | `shared_preferences: ^2.3.2` |
| 后端 | Python 3（标准库 HTTP 服务） |
| 数据库 | SQLite（WAL 模式） |
| 对象存储 | 本地文件系统 / 可选 S3 兼容存储 |
| 部署 | Docker / 腾讯云 Ubuntu + Nginx + systemd |

## 目录结构

```
xduWhisperBox/
├── backend/              # Python 后端（模块化架构）
│   ├── server.py         # 核心入口，路由分发 + 服务器启动
│   ├── _globals.py       # 全局状态单点
│   ├── sql_repository.py # SQLite schema、持久化逻辑
│   ├── object_storage.py  # 对象存储（本地 / S3）
│   ├── reset_db.py        # 数据库重置脚本
│   ├── migrate_json_to_sql.py  # JSON → SQL 迁移脚本
│   ├── helpers/          # 通用辅助函数（auth、datetime、http、mailer、rate_limit）
│   ├── handlers/         # HTTP 处理层（按功能域拆分）
│   ├── services/         # 业务逻辑层
│   └── tests/           # pytest 单元测试
├── lib/                  # Flutter Web 前端
│   ├── core/            # 核心基础设施（auth、config、network、theme...）
│   ├── features/        # 功能模块（admin、auth、feed、messages...）
│   ├── models/          # 数据模型
│   ├── repositories/    # Repository 层
│   └── widgets/         # 公共组件
├── lib/mobile/          # Flutter 移动端（Android / iOS）
├── scripts/             # 部署与构建脚本
├── deploy/              # Nginx / systemd / 环境变量模板
├── .github/workflows/   # GitHub Actions CI/CD
├── Dockerfile           # 后端 Docker 构建
├── docker-compose.yml   # 本地开发服务编排
└── docker-compose.prod.yml  # 生产环境覆盖
```

## 快速开始

### 前置依赖

- Flutter SDK `>=3.3.0 <4.0.0`
- Python 3.10+
- SQLite3
- （可选）Docker + Docker Compose

### 1. 克隆项目

```bash
git clone https://github.com/YOUR_USERNAME/xduWhisperBox.git
cd xduWhisperBox
```

### 2. 后端启动

```bash
cd backend

# 安装可选依赖（仅 S3 存储需要）
pip install boto3

# 配置环境变量（复制模板后修改）
cp deploy/tencent/backend.env.example .env

# 启动后端（默认端口 8080）
python3 server.py
```

后端启动后会：
- 自动创建 `backend/data/treehole.db`（SQLite WAL 模式）
- 初始化种子数据（默认管理员账号、示例帖子）
- 启动 HTTP 服务器

**默认管理员账号：** `admin` / `admin123456`（生产环境必须修改）

### 3. 前端启动

```bash
# 安装依赖
flutter pub get

# Web 开发服务器（默认连接 localhost:8080）
flutter run -d chrome

# Android APK（需要 Android SDK）
flutter build apk --release
```

### 4. Docker 方式启动后端

```bash
# 仅后端
docker compose up backend -d

# 后端 + Nginx 反向代理
docker compose up -d
```

## 环境变量

后端通过环境变量配置，参考 `deploy/tencent/backend.env.example`：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BACKEND_HOST` | `0.0.0.0` | 监听地址 |
| `BACKEND_PORT` | `8080` | 监听端口 |
| `BACKEND_DB_FILE` | `backend/data/treehole.db` | SQLite 数据库路径 |
| `BACKEND_STORAGE_DIR` | `backend/storage/objects` | 本地对象存储目录 |
| `BACKEND_WEB_ROOT` | `build/web` | Flutter Web 构建产物目录 |
| `BACKEND_OBJECT_STORAGE_BACKEND` | `local` | 存储后端（`local` 或 `s3`） |
| `BACKEND_ADMIN_USERNAME` | `admin` | 默认管理员用户名 |
| `BACKEND_ADMIN_PASSWORD` | `admin123456` | 默认管理员密码 |
| `BACKEND_SMTP_HOST` | — | SMTP 服务器地址 |
| `BACKEND_SMTP_PORT` | `465` | SMTP 端口 |
| `BACKEND_SMTP_USERNAME` | — | SMTP 用户名 |
| `BACKEND_SMTP_PASSWORD` | — | SMTP 密码/授权码 |
| `BACKEND_SMTP_FROM_EMAIL` | — | 发件人邮箱 |
| `BACKEND_ALLOW_DEBUG_VERIFY_CODE` | `false` | 允许调试验证码（生产必须 `false`） |
| `BACKEND_INCLUDE_DEBUG_CODE` | `false` | 响应包含调试信息（生产必须 `false`） |

**S3 存储配置**（当 `BACKEND_OBJECT_STORAGE_BACKEND=s3` 时）：

| 变量 | 说明 |
|------|------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_REGION` | S3 区域（如 `ap-northeast-1`） |
| `AWS_S3_BUCKET` | S3 Bucket 名称 |

## API 文档

后端启动后访问 `http://localhost:8080/api/` 根路径可查看可用端点。

### 主要端点

**认证**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/auth/send-code` | 发送邮箱验证码 |
| `POST` | `/api/auth/register` | 注册账号 |
| `POST` | `/api/auth/login` | 登录 |
| `POST` | `/api/auth/verify` | 验证邮箱 |
| `POST` | `/api/auth/logout` | 登出 |
| `POST` | `/api/auth/password/send-code` | 发送密码重置验证码 |
| `POST` | `/api/auth/password/reset` | 重置密码 |

**帖子**

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/posts` | 获取帖子列表（支持 channel、keyword、authorId 等过滤） |
| `POST` | `/api/posts` | 发布帖子 |
| `GET` | `/api/posts/{id}` | 获取帖子详情 |
| `POST` | `/api/posts/{id}/like` | 点赞 |
| `POST` | `/api/posts/{id}/favorite` | 收藏 |
| `DELETE` | `/api/posts/{id}/favorite` | 取消收藏 |
| `POST` | `/api/posts/{id}/comments` | 添加评论 |
| `POST` | `/api/reports` | 举报内容 |

**用户**

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/users/me` | 获取当前用户资料 |
| `PATCH` | `/api/users/me` | 更新个人资料 |
| `POST` | `/api/users/avatar` | 上传头像 |
| `POST` | `/api/users/{id}/follow` | 关注用户 |
| `POST` | `/api/users/{id}/unfollow` | 取消关注 |

**私信**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/messages/conversations/direct` | 直接创建/进入会话（微信模式） |
| `GET` | `/api/messages/conversations` | 会话列表 |
| `POST` | `/api/messages/conversations/{id}/messages` | 发送消息 |

**管理员**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/admin/auth/login` | 管理员登录 |
| `GET` | `/api/admin/overview` | 仪表盘统计 |
| `GET` | `/api/admin/reviews` | 内容审核列表 |
| `POST` | `/api/admin/reviews/batch` | 批量审核 |
| `GET` | `/api/admin/reports` | 举报处理列表 |
| `POST` | `/api/admin/reports/{id}/handle` | 处理举报 |
| `GET` | `/api/admin/users` | 用户管理 |
| `GET` | `/api/admin/export` | 数据导出 |

## 测试

### 前端测试

```bash
flutter test
```

### 后端测试

```bash
cd backend
pip install pytest requests

# 运行所有测试
python -m pytest tests/ -v

# 运行指定测试
python -m pytest tests/test_auth.py -v
```

## 部署

### 腾讯云部署

参考 `scripts/deploy_tencent.sh` 和 `deploy/tencent/` 目录：

```bash
# 1. 在服务器安装环境
bash scripts/install_tencent_host.sh

# 2. 部署后端
bash scripts/deploy_tencent.sh
```

### Docker 生产部署

```bash
# 1. 构建 Flutter Web
flutter build web

# 2. 启动生产服务
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 开发规范

### 后端

- API 路由通过 `server.py` 分发到 `handlers/` 中的独立模块
- 业务逻辑下沉到 `services/` 层
- 通用工具函数放在 `helpers/` 层
- 全局状态（线程锁、数据库连接池等）通过 `_globals.py` 统一管理
- 所有配置通过环境变量注入，不硬编码
- 生产环境必须设置 `BACKEND_ALLOW_DEBUG_VERIFY_CODE=false`

### 前端

- 页面使用 `Riverpod StateNotifier` 管理状态
- Repository 模式封装所有 HTTP 请求
- 公共接口路径统一放在 `lib/core/network/api_endpoints.dart`
- 页面初始化的异步加载放在 `initState + Future.microtask()`
- 发帖后立即展示，不等待审核

## 相关文档

- [项目进程文档](PROJECT.md) — 版本历史、构建记录、未跨端适配功能
- [开发规范](CLAUDE.md) — 架构约定、命名规范、状态管理规范
- [代理说明](AGENTS.md) — 项目使命、技术栈、上下文锚点、未完成任务

## 许可证

本项目仅供西安电子科技大学校内使用。
