# See电（西电树洞）项目进程文档

## 1. 项目概述

**See电**（西电树洞）是一个面向西安电子科技大学校内用户的匿名社区应用，采用 Flutter 跨端技术栈构建，同时支持 Web 端和移动端（Android / iOS）。

### 应用定位

- 为校内同学提供一个自由、平等、匿名的交流空间
- 支持多种话题频道，满足学习、生活、情感、吐槽等场景需求
- 强调社区治理能力，配备完善的内容审核、举报处理和用户管理体系

### 核心功能

**社区交流**

- 帖子发布与浏览（支持频道分类、多图上传）
- 评论与回复
- 点赞与收藏
- 搜索与筛选（关键词、频道、状态、有图、可私信等条件）

**用户体系**

- 校内邮箱注册与登录（学号 + 密码）
- 用户等级体系：一级用户（享有直接置顶帖子权限）、二级用户
- 匿名发帖：前台完全匿名，管理员后台可追溯真实账号
- 个人中心（资料查看、头像上传、我的帖子、我的评论、我的收藏、我的举报）
- 账号注销申请

**社交互动**

- 私信功能：私信申请 → 对方同意 → 双向会话建立
- 会话屏蔽（拉黑）：屏蔽后禁止继续发起私信和发送消息
- 消息未读数与已读状态

**通知中心**

- 评论通知、回复通知、点赞通知、收藏通知
- 举报处理结果通知
- 系统公告通知
- 未读数提示与一键已读

**管理员后台**

- 多管理员分级：一级管理员（完整权限）、二级管理员（受限权限）
- 内容审核与批量审核
- 图片审核
- 举报处理
- 用户管理（账号状态管理、注销/恢复）
- 申诉处理
- 数据导出
- 敏感词与系统配置管理
- 帖子置顶审批
- 一级用户升级申请审批

**合规与说明**

- 用户协议
- 隐私政策
- 社区规范
- 举报说明

---

## 2. 目录结构

```
xduWhisperBox/
├── backend/                        # Python 后端（模块化架构）
│   ├── server.py                   # 核心入口 (~745行)，路由分发 + 服务器启动
│   ├── _globals.py                 # 全局状态单点：配置常量 + 运行时对象
│   ├── sql_repository.py           # SQLite schema、初始化、持久化逻辑 (~1712行)
│   ├── object_storage.py           # 对象存储（本地 / S3 兼容）(~258行)
│   ├── reset_db.py                 # 数据库重置脚本
│   ├── migrate_json_to_sql.py      # JSON → MySQL/PostgreSQL 迁移脚本
│   ├── helpers/                    # 通用辅助函数（跨 handler/service 复用）
│   │   ├── __init__.py             # barrel file，重新导出所有 helpers
│   │   ├── _auth_helpers.py        # 密码哈希、邮箱验证、ID 解析
│   │   ├── _datetime_helpers.py    # 时间/时区处理
│   │   ├── _http_helpers.py        # HTTP 响应（json_error、send_json 等）
│   │   ├── _mailer.py              # 邮件发送（验证邮件、密码重置邮件）
│   │   └── _rate_limit.py          # 限流、IP 检查、文本风险评估
│   ├── handlers/                   # HTTP 请求处理层（按功能域拆分）
│   │   ├── __init__.py             # barrel file，重新导出 ~60 个 handle_* 函数
│   │   ├── _auth_handler.py        # 认证：登录/注册/登出/验证码/密码重置
│   │   ├── _post_handler.py        # 帖子：CRUD/点赞/收藏/举报/申诉/置顶申请
│   │   ├── _comment_handler.py     # 评论：创建/删除；账号：注销申请/等级升级
│   │   ├── _message_handler.py     # 私信：申请/接受/拒绝/会话/消息/屏蔽
│   │   ├── _user_handler.py        # 用户：个人资料/关注/粉丝/好友
│   │   ├── _notification_handler.py # 通知：列表/标记已读/全部已读
│   │   ├── _admin_handler.py       # 管理后台：审核/举报/用户/配置/公告等
│   │   ├── _upload_handler.py       # 文件上传：头像上传/图片上传
│   │   └── _static_handler.py      # 静态文件：存储文件读取/Web 兜底
│   ├── services/                   # 业务逻辑层（数据操作 + 业务规则）
│   │   ├── __init__.py             # barrel file，重新导出所有 service 函数
│   │   ├── _db_service.py          # 数据库操作：查询/序列化/管理员构建函数
│   │   └── _user_service.py        # 用户业务：通知创建/会话同步/数据规范化
│   ├── sql/                        # SQL schema 文件
│   │   ├── schema_mysql.sql
│   │   └── schema_postgresql.sql
│   └── tests/                      # 后端单元测试（pytest）
├── lib/                            # Flutter Web 前端
│   ├── core/                       # 核心基础设施
│   │   ├── auth/                   # 鉴权相关（AuthStore、AdminAuthStore）
│   │   ├── config/                 # 配置（AppConfig、API_BASE_URL 解析）
│   │   ├── emoji/                  # 表情目录 + 用户偏好
│   │   ├── media/                  # 媒体处理（图片选择器 Web/Mobile 条件编译）
│   │   ├── navigation/             # 导航（URL 状态管理）
│   │   ├── network/                # 网络请求（ApiClient、ApiEndpoints、JsonUtils）
│   │   ├── state/                  # 状态管理（AppProviders）
│   │   ├── theme/                  # 主题（AppTheme + SharedColors 统一跨端颜色）
│   │   └── utils/                  # 工具函数（Web 文件下载）
│   ├── data/                       # Mock 数据
│   ├── features/                   # 功能模块
│   │   ├── admin/                  # 管理员后台
│   │   ├── auth/                   # 登录/注册/验证码/密码重置
│   │   ├── favorites/              # 收藏
│   │   ├── feed/                   # 信息流
│   │   ├── legal/                  # 合规说明页（用户协议/隐私政策等）
│   │   ├── me/                     # 个人中心
│   │   ├── messages/               # 私信（会话列表 + 聊天）
│   │   ├── notifications/          # 通知中心
│   │   ├── post/                   # 发帖/帖子详情
│   │   └── search/                # 搜索
│   ├── models/                     # 数据模型
│   │   ├── admin/                 # 管理员模型子目录（9 个独立文件）
│   │   │   ├── admin_shared_helpers.dart
│   │   │   ├── admin_overview_models.dart
│   │   │   ├── admin_review_models.dart
│   │   │   ├── admin_report_models.dart
│   │   │   ├── admin_user_models.dart
│   │   │   ├── admin_system_models.dart
│   │   │   ├── admin_account_models.dart
│   │   │   ├── admin_appeal_models.dart
│   │   │   └── admin_export_models.dart
│   │   ├── admin_models.dart       # admin barrel file（重新导出）
│   │   └── [其他模型]              # post_item、comment_item、user_profile 等
│   ├── repositories/               # Repository 层（7 个文件）
│   └── widgets/                    # 公共组件（4 个文件）
├── lib/mobile/                     # Flutter 移动端（Android / iOS）
│   ├── core/                       # 核心基础设施（config、navigation、state、theme）
│   ├── features/                   # 功能模块（与 lib/features/ 平行独立实现）
│   ├── main.dart                   # 移动端入口（由 lib/main.dart 通过 kIsWeb 分流调用）
│   └── lib_mobile.dart            # 移动端 barrel file
├── packages/                       # 可选本地依赖（gitignore，见 scripts/setup_xdyou.sh）
│   └── traintime_pda/              # XDYou子APP，只需兼容移动端APP
├── scripts/                        # 部署与构建脚本
│   ├── build_web_beta.sh           # 内测 Web 构建
│   ├── build_web_production.sh     # 生产 Web 构建
│   ├── deploy_tencent.sh           # 腾讯云部署
│   ├── health_check.sh             # 健康检查
│   ├── install_tencent_host.sh     # 服务器环境安装
│   ├── package_release.sh          # 发布包打包
│   ├── rollback.sh                 # 版本回滚
│   ├── run_backend_beta.sh         # 内测后端启动
│   ├── setup_xdyou.sh              # 拉取 traintime_pda 至 packages/（移动端嵌入 XDYou）
│   └── version.sh                  # 版本信息生成
├── .github/
│   └── workflows/
│       ├── dart.yml               # Flutter CI（flutter analyze + flutter test）
│       └── python.yml              # Python CI（pytest 后端测试）
├── Dockerfile                      # 后端多阶段 Docker 构建
├── docker-compose.yml              # 服务编排（backend + nginx）
├── docker-compose.prod.yml         # 生产环境覆盖（TLS 扩展点）
├── deploy/                         # 部署配置
│   ├── production/                 # 生产环境配置
│   └── tencent/                    # 腾讯云配置
├── docs/                           # 文档
├── test/                           # 前端测试
├── web/                            # Web 静态资源（index.html、manifest.json）
├── pubspec.yaml                    # Flutter 依赖配置
├── analysis_options.yaml           # Dart Lint 配置（自定义规则 + 排除废弃目录）
├── .gitignore                      # Git 忽略配置
└── README.md                       # 项目主说明
```

### 后端模块架构图

```
server.py (~745行)
  │
  ├── _globals.py                  # 全局状态单点（运行时对象 + 配置常量）
  │
  ├── helpers/                     # 通用工具层
  │     ├── _auth_helpers.py      # 密码哈希、邮箱验证、ID 解析
  │     ├── _datetime_helpers.py   # 时间/时区处理
  │     ├── _http_helpers.py       # HTTP 响应（json_error、send_json 等）
  │     ├── _mailer.py             # 邮件发送
  │     └── _rate_limit.py         # 限流、IP 检查、文本风险评估
  │
  ├── services/                    # 业务逻辑层
  │     ├── _db_service.py         # 数据库查询、序列化、管理员构建函数
  │     └── _user_service.py       # 用户业务规则、通知创建、会话同步
  │
  └── handlers/                    # HTTP 处理层（60+ handle_* 函数）
        ├── _auth_handler.py       # 认证：登录/注册/登出/验证码/密码重置
        ├── _post_handler.py       # 帖子：CRUD/点赞/收藏/举报/申诉/置顶申请
        ├── _comment_handler.py    # 评论创建/删除；账号注销申请/等级升级
        ├── _message_handler.py     # 私信：申请/接受/拒绝/会话/消息/屏蔽
        ├── _user_handler.py        # 用户：个人资料/关注/粉丝/好友
        ├── _notification_handler.py # 通知：列表/标记已读/全部已读
        ├── _admin_handler.py      # 管理后台：审核/举报/用户/配置/公告等
        ├── _upload_handler.py      # 文件上传：头像上传/图片上传
        └── _static_handler.py     # 静态文件：存储文件读取/Web 兜底
```

---

## 3. 版本历史

| 版本号 | 更新日期 | 更新内容 |
|--------|----------|----------|
| 0.1.0+22 | 2026-03-29 | **移动端优化与修复**：① 修复点赞 toggle 逻辑（`likePost`/`unlikePost` 应由前端判断后调用对应 API）；修复主页卡片（PostCard）点赞后再次点击不取消的问题；② 修复楼中楼回复：后端 `handle_create_comment` 创建评论时添加 `parentId` 字段，`_serialize_comment` 已包含此字段，评论树正确渲染；③ 修复帖子详情页底部评论 icon 无响应的问题，改为滚动到评论区；④ 修复私信页自己消息气泡显示对方头像的问题，改为显示当前用户头像；⑤ 修复私信页消息气泡旁头像点击无导航的问题，添加 `GestureDetector` + `context.push('/user/...')`；⑥ 修复私信页长按消息气泡无响应的问题，改用 `onLongPressStart` + `HapticFeedback` + 正确的全局坐标传递；⑦ 新增一级账号发帖置顶功能（`pinDurationMinutes` 选择器，1/3/7/30天选项）；⑧ 统一移动端和 Web 图片浏览器样式（均使用 `barrierColor: Colors.black` + 顶部浮动关闭按钮和页码指示器）；⑨ 修复匿名帖仍可点击头像进入主页的问题，改为匿名帖一律不响应头像点击；⑩ 修复发帖页匿名按钮每次点击随机生成新昵称（而非仅首次开启时生成）；⑪ `PostRepository` 新增 `unlikePost` 方法；⑫ 私信页 ChatPage 新增 `AuthStore.instance.currentUser` 头像获取 |
| 0.1.0+21 | 2026-03-29 | **修复 traintime_pda 子 App 中文字体不显示**：`packages/traintime_pda/lib/main.dart` 移除不可靠的 `chinese_font_library` 的 `useSystemChineseFont()` 调用（在嵌套 MaterialApp 场景下 platform channel 返回空字体名导致所有文字无字体渲染）；改为在 `DefaultTextStyle.merge` 中显式指定 `fontFamily: 'Noto Sans SC'`（Android 系统内置思源黑体）；`flutter analyze` 零 error |
| 0.1.0+20 | 2026-03-29 | `android/gradle.properties` 移除 `TLSv1.1` 和 `TLSv1` 不安全协议，保留 `TLSv1.2`/`TLSv1.3`；`flutter pub get` 确认 `device_calendar` 和 `sprintf` 共 2 个依赖移除生效；**修复 device_calendar 残留源码未清理**：此前 v0.1.0+20 仅删除了 `pubspec.yaml` 中的 `device_calendar` 声明，但 `classtable_state.dart` 的 import 和依赖代码未同步删除，导致 `flutter run` 报 `device_calendar` 包找不到的错误；现已彻底删除 `classtable_state.dart` 中的 `import 'package:device_calendar/device_calendar.dart'`、`import 'package:timezone/data/latest.dart' as tz` 及 `events`/`iCalenderStr`/`outputToCalendar` 三个成员（约 267 行）；`flutter analyze` 零 error；`flutter pub get` 正常 |
| 0.1.0+19 | 2026-03-29 | **精简 traintime_pda 包（方案 A）**：用户手动删除 `packages/traintime_pda/` 下非源码目录（`android/`、`ios/`、`linux/`、`windows/`、`pigeon_bridge/`、`test/`、`docs/`、`fastlane/`、`tool/`、`.github/`、`.vscode/`、`.flutter/`、`blobs/`、`XDYou-Poster.jpg`）；精简 `assets/` 目录（从 102 文件裁剪至 4 文件：`icon.png` + 3 个 i18n yaml）；`pubspec.yaml` 删除 `flutter_launcher_icons`、`flutter_native_splash` 配置段及对应依赖；`flutter pub get` 确认 `flutter_native_splash` 移除生效；`flutter analyze` 无 error；由于子 App 仅运行于移动端，无需添加 Web 兼容 stub |
| 0.1.0+18 | 2026-03-29 | **校园 Tab 仅登录可见**：`AuthStore` 继承 `ChangeNotifier` 并在 `init`/`saveToken`/`clear` 时 `notifyListeners()`；`GoRouter` 增加 `refreshListenable: AuthStore.instance`；`MobileShell` 用 `ListenableBuilder` 监听登录态，仅 `isAuthenticated` 时展示「校园」Tab，未登录时底部为 3 Tab（首页/消息/我的）并映射 branch 0、1、3；若未登录仍停留在校园 branch 则下一帧切回首页 |
| 0.1.0+17 | 2026-03-29 | **移动端嵌入 XDYou**：通过 path 依赖引入 `watermeter`（[Traintime PDA](https://github.com/BenderBlog/traintime_pda)，MPL-2.0）；`scripts/setup_xdyou.sh` 拉取源码至 `packages/traintime_pda`（目录已 gitignore）；`lib/mobile/integrations/xdyou_bootstrap.dart` 复现独立应用启动时的本地存储与通知初始化；底部 Tab 增加「校园」路由 `/xdyou` 全屏嵌入 `MyApp`；Dart SDK 提升至 `>=3.8.0`；`analysis_options` 排除 `packages/traintime_pda`；CI 在 `flutter pub get` 前执行 `setup_xdyou.sh` |
| 0.1.0+12 | 2026-03-27 | **后端模块化拆分**：将 `backend/server.py`（原 3620 行）拆分为职责清晰的模块结构，最终行数 745 行（-79%）；`backend/_globals.py` 作为全局状态单点，配置常量和运行时对象统一管理；`backend/helpers/` 子模块化（`auth_helpers`、`datetime_helpers`、`http_helpers`、`mailer`、`rate_limit`），消除 server.py 中 ~140 行 helpers 函数副本；`backend/services/` 子模块化（`_db_service`、`_user_service`），消除 server.py 中 ~870 行 services 函数副本；`backend/handlers/` 解耦为 8 个独立模块（`_auth_handler`、`_post_handler`、`_comment_handler`、`_message_handler`、`_user_handler`、`_notification_handler`、`_admin_handler`、`_static_handler`、`_upload_handler`），server.py 仅保留路由分发；补充 `services/_db_service.py` 中 handlers 依赖的缺失函数（`list_posts`、`build_admin_*_rows`、`serialize_*`、`build_export_payload`、`public_system_settings`、`build_pagination_meta`）；修复 handlers 与 services 间的循环导入；修复 `_globals.py` 中 `_lazy_proxy` 函数代理 handler 需要的 helpers/services 子模块函数；API `/api/version`、`/api/health`、`/api/channels`、`/api/posts` 测试通过 |
| 0.1.0+13 | 2026-03-28 | **移动端登录修复**：修复移动端（Android/iOS）无法登录的问题。根本原因是移动端默认 API 地址为 `localhost:8080`，但移动设备上 `localhost` 指向设备自身而非后端服务器；`AppConfig.apiBaseUrl` 移动端默认值从 `http://localhost:8080/api` 改为 `http://81.69.16.134/api`（腾讯云公网 IP，现网生产地址）；`MobileConfig.apiBaseUrl` 同步更新；仍支持通过 `--dart-define=MOBILE_API_BASE_URL=...` 注入真实服务器地址 |
| 0.1.0+14 | 2026-03-28 | **移动端消息页优化**：① 删除消息页 Tab 栏（「会话」「私信申请」切换），改为直接显示会话列表；② 修复会话界面 AppBar 标题和消息气泡中对方头像显示，改用 `CachedNetworkImage` + `AppConfig.resolveUrl()` 处理相对路径 URL；③ 消息气泡框内显示发送时间（对方消息显示 `HH:mm`，自己消息以半透明文字显示）；④ 删除聊天页的表情发送功能（表情按钮、`_buildEmojiBar`、`_toggleEmoji`、`_onTapEmoji` 等全部移除） |
| 0.1.0+15 | 2026-03-28 | **移动端帖子卡片样式重构**：参考 Instagram 风格重设计。标题统一改为 18sp Bold 突出显示；图文帖（hasImage）改为 PageView 全屏图片展示（固定 280dp 高），支持左右滑动切换 + 底部圆点指示器 + 点击进入全屏查看（InteractiveViewer 缩放），正文不再在卡片内显示；纯文帖保留 Big Text Poster（短内容<50字无标题）和正文截断（最多4行）；新建 `full_screen_image_page.dart` 全屏图片查看页；删除旧 `_ImageGrid` 小图网格。纯移动端 UI 调整，无跨端兼容条目新增。 |
| 0.1.0+16 | 2026-03-28 | **热度排序优化**：① 消除双重排序：后端 `list_posts()` 在 `sort_by="hot"` 时跳过预排序，由 `sort_posts_for_view` 全权负责；② 引入阅读量指标：新增 `POST /api/posts/<id>/view` 端点（防刷：每用户每帖每天计1次），`posts` 表增加 `viewCount` 字段，`serialize_post` 返回 `viewCount`；③ 调整热度算法：`likes * 2 + comments - ts/1e9` → `likes * 2 + comments * 3 + viewCount - ts/1e9`（评论权重从×1提升到×3，阅读量纳入计算）；④ 前端：Web 端 `PostCard` 和移动端 `PostCard` 均显示阅读量（眼睛图标+数字），`PostItem` 模型新增 `viewCount` 字段，帖子详情页打开时触发阅读计数 |
| 0.1.0+11 | 2026-03-26 | **工程审计整改（P2）**：后端 `backend/server.py` 添加 Python `logging` 结构化日志系统（`logging` 标准库，`_configure_logging()` 配置，`%(asctime)s | %(levelname)-8s | %(message)s` 格式）；所有 8 处 `print()` 调用全部替换为 `_logger.info()` / `_logger.warning()` / `_logger.debug()`；调试验证码开关激活时自动切换为 DEBUG 级别；`_handle_web_delete` 异常处理器由 `f"Internal server error: {error}"` 改为 `logger.exception()` + 固定文本 `"Internal server error"`，消除内部信息泄漏；`deploy/tencent/backend.env.example` 新增 `BACKEND_ALLOW_DEBUG_VERIFY_CODE` 和 `BACKEND_INCLUDE_DEBUG_CODE` 的 WARNING 注释，说明生产环境必须为 false |
| 0.1.0+10 | 2026-03-26 | **工程审计整改（P0+P1）**：删除废弃 `lib_mobile/` 目录（40 文件）和 `backup_lib/` 目录（80 文件）并从 git 移除；`backup_lib/` 加入 `.gitignore`；从 `pubspec.yaml` 移除未使用的 `date_format` 依赖；`admin_models.dart`（732 行）拆分为 `lib/models/admin/` 子目录（9 个独立文件，每文件 < 200 行）；确认 `lib/main.dart` 为唯一入口后删除 `lib/mobile/main.dart`（冗余入口）；新建 `lib/core/theme/shared_colors.dart` 统一跨端品牌色，`app_theme.dart` 和 `mobile_theme.dart` 均引用 `SharedColors` |
| 0.1.0+9 | 2026-03-26 | **后端**：新增 `POST /api/messages/conversations/direct` 端点（微信模式，无需申请直接创建/进入会话）；**移动端**：私信按钮改为直接进入或创建会话（替代原申请制流程）；他人主页头像点击跳转其个人主页；消息页新增 TabBar（会话列表 + 私信申请管理）；会话列表左滑删除；聊天页 AppBar 头像+昵称可点击进入对方主页；聊天页菜单新增屏蔽/解除屏蔽入口；聊天页消息气泡长按弹出操作菜单（复制/删除）；消息未读红点 Badge 跟随 Tab 栏显示 |
| 0.1.0+8 | 2026-03-26 | **后端**：评论列表 API 新增 `authorAvatar` 和 `authorUserId` 字段；帖子列表 API 支持 `authorId` 查询参数；**数据模型**：`PostItem` 新增 `isAnonymous`、`authorAvatarUrl`、`authorUserId` 字段，`CommentItem` 新增 `authorUserId` 字段；**移动端**：发帖页/主页频道列表将"其他"改名为"综合"；`PostCard` 非匿名帖显示真实头像并支持点击跳转他人主页；帖子详情页作者头像同理；新建他人公开主页 `PublicUserProfilePage`（关注/私信按钮）；我的页面：统计行删除"收藏"数字、TabBar 保持3个Tab、帖子Tab和收藏Tab改为图文卡片 `PostCard` 视图 |
| 0.1.0+6 | 2026-03-25 | 清理重复移动端目录，删除旧 `lib_mobile/`，保留 `lib/mobile/` 作为唯一移动端源码目录；同步项目文档中的移动端路径说明 |
| 0.1.0+5 | 2026-03-25 | 修复消息页加载不出（`MessagesPage` 恢复 `ConsumerStatefulWidget`，`initState` 触发 `loadInitial()`）；修复头像点击逻辑（自己帖子跳转 `/profile`，其他帖子提示「暂不支持查看该用户主页」） |
| 0.1.0+4 | 2026-03-25 | 重构底部导航（3 Tab：首页/消息/我的）；搜索入口移至首页 AppBar；管理员后台修复（使用真实 Web 端 AdminConsolePage）；实现关注/粉丝系统（API 端点 + Repository + 个人主页底部弹窗列表 + 好友标记）；消息页移除私信申请 Tab，改为首条消息警告横幅；帮助与反馈入口加入登录/注册页；头像点击逻辑（自己帖子跳我的主页，其他提示暂不支持）；管理员控制台恢复完整功能 |
| 0.1.0+2 | 2026-03-25 | 修复移动端 6 个问题：① 首页点赞/收藏改为乐观更新不再全量刷新 ② 下拉刷新添加 AlwaysScrollableScrollPhysics ③ 消息页移除 mock 数据回退 ④ 发帖页匿名模式添加昵称输入框 ⑤ 我的页登录后自动 fetchProfile、收藏 Tab 真实数据 ⑥ 设置页修改密码路由修复、关于区各页正确跳转 |
| 0.1.0+1 | 2026-03-25 | 优化 Android 构建方式：创建 `lib/mobile/` Junction 指向 `lib_mobile/`，在 `lib/main.dart` 用 `kIsWeb` 平台分流，无需 `--target` 参数，`flutter build apk` 直接可用 |
| 0.1.0+1 | 2026-03-25 | 首个 Android ARM64 Release APK；修复 `lib_mobile/` 未被纳入编译的问题（改用 `--target lib_mobile/main.dart` 构建）；修复 `PostCard` 引用不存在字段 `avatarUrl` / `nickname` 的编译错误 |

## 4. 未跨端兼容的功能

> 以下记录尚未同时在 Web 端和移动端适配的功能，跨端适配完成后请删除对应条目。

| 功能名称 | 描述 | 当前实现平台 |
|----------|------|-------------|
| 移动端整体 UI 风格 | Twitter/Instagram 风格重构：纯白背景、无卡片/无圆角/无阴影、紧凑布局、频道彩色圆点、FAB 发帖按钮 | 仅移动端（`lib/mobile/`） |
| 个人主页（ProfilePage） | 背景色条 + 重叠头像 + 统计行 + Tab（帖子/收藏/动态）+ 右上角设置入口 | 仅移动端 |
| 设置主页（SettingsMainPage） | 独立设置页：账号安全 / 隐私开关 / 通知 / 关于 / 退出登录；注销账号双重确认流程 | 仅移动端 |
| 发帖页（CreatePostPage） | 极简发帖：内联频道选择器、底部工具栏、匿名昵称输入、PopupMenu 可见性选择 | 仅移动端 |
| 帖子详情页（PostDetailPage） | 紧凑布局、底部操作栏压缩、AvatarWidget 头像 | 仅移动端 |
| 消息页（MessagesPage） | 会话列表直接展示，无 Tab 切换；头像使用 `CachedNetworkImage` + `AppConfig.resolveUrl()` 正确加载；会话列表点击跳转聊天 | 仅移动端（`lib/mobile/features/messages/`） |
| AvatarWidget | 使用 `AppConfig.resolveUrl()` + `CachedNetworkImage` 正确加载头像 | 仅移动端（`lib/mobile/features/widgets/`） |
| 学号登录（自动拼接邮箱后缀） | 登录/注册只需填学号，系统自动拼接 `@stu.xidian.edu.cn` | 仅移动端 |
| 关注/粉丝系统（FollowSystem） | 粉丝/关注数实时显示，点击弹出列表，互相关注标记为好友；API 端点 + `FollowUserItem` 模型 + Repository 方法 | 仅移动端 |
| 首条消息警告横幅 | 对话无历史消息时显示横幅提示"只能发1条消息"，对方回复或关注后解锁 | 仅移动端 |
| 私信直接进入（微信模式） | 私信按钮直接进入或创建会话，无需申请流程；长按气泡 WeChat 风格浮层（复制/转发/详情/回复/撤回）；消息详情显示秒级时间；屏蔽/解除屏蔽入口；批量选中删除；转发到联系人会话 | 仅移动端 |
| 匿名头像点击 | 匿名帖不能点击头像进入主页；非匿名帖点击头像进入公开主页（支持关注和私信） | 仅移动端（`lib/mobile/features/`）|
| 帮助与反馈入口（登录/注册页） | 登录页底部行增加「帮助与反馈」按钮；注册页底部同样添加入口 | 仅移动端 |
| 校园 Tab（XDYou 嵌入） | 底部导航「校园」嵌入完整 XDYou（课表/成绩/教务等）；**仅已登录树洞账号时显示该 Tab**；依赖 `packages/traintime_pda`，需运行 `scripts/setup_xdyou.sh` | 仅移动端（`lib/mobile/features/xdyou/`） |

---

*最后更新：2026-03-29（v0.1.0+22，移动端优化与修复：点赞toggle、楼中楼、评论icon、头像显示、长按菜单、置顶功能、图片浏览器样式统一、匿名帖子头像、匿名昵称随机化）*
