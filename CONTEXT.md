# Project Context (XDUWhisperBox)

This file is the main handoff context for AI coding assistants working in this repository. Read it before making changes.

## Project Mission

西电树洞是一个面向西电校内用户的匿名社区 Web 应用，当前形态是 `Flutter Web + Python 后端` 的可内测版本，仓库也包含正在对齐主 App 的微信小程序端。

### Current state

- 前台主流程已具备登录/注册、发帖、评论、搜索、收藏、举报、私信、个人中心、头像上传、管理员后台等能力
- 后端已完成 JSON 到 SQLite Repository/DAO + 事务的迁移
- 图片上传、图片审核、账号注销审核、真实邮箱验证码、私信持久化都已完成
- 通知中心的评论/回复/点赞/收藏/举报结果/系统公告通知、未读数、已读逻辑已进入代码库
- AI 助手后端 RAG 接口已完成，并与小程序端联调
- 管理员后台已强化，包含审核/举报关键字搜索、批量审核、数据导出等能力
- **[最新进展]** 全局黑名单（屏蔽用户）功能已完成前后端联调与存储迁移，微信小程序端已上线“黑名单管理”页面并支持乐观更新，后端附带单元测试验证
- **[最新进展]** 微信小程序端 Markdown 渲染器大幅升级，支持代码块、表格、超链接、粗斜体、列表等多元素解析渲染，并修正了 DevTools 运行时判定与 loading/toast 冲突等 Bug
- **[最新进展]** 微信小程序端个人中心、公开主页、编辑资料、账号安全、隐私、通知、会话等页面已继续向移动端主 App 对齐
- **[最新进展]** 微信小程序端私信申请流程已移除，改为与主 App 一致的直接会话逻辑：隐私设置允许私信且帖子非匿名时可直接发起私信
- **[最新进展]** 微信小程序端头像展示已去除默认头像图兜底，统一使用昵称首字/“匿”文字头像；匿名帖在卡片与详情页展示“匿名”标签

## Recent Pushes

最近几次推送主要覆盖这些内容：

1. 小程序首页顶部图标与布局收紧，贴近主 App
2. 小程序帖子卡片样式对齐主 App
3. 小程序顶部栏布局修正
4. 小程序发帖页重做为主 App 同款结构，包含默认项、匿名、置顶、可见性、图片预览和底部工具栏
5. 小程序帖子详情页重做为主 App 同款结构，修正时间显示、关注按钮位置、评论排序入口、回复条和按钮逻辑
6. 小程序设置相关页面继续复用主 App 的卡片与列表样式
7. 新增小程序通知设置页
8. 新增全局黑名单（屏蔽用户）前后端功能，包含 SQLite 迁移、新 API 路由与小程序黑名单管理页面
9. 重构微信小程序端的 Markdown 解析与渲染逻辑，全面支持复杂的 Markdown 块（如表格、代码块）和行内样式
10. 修复小程序多端运行时对 `isDevtoolsRuntime` 的判定 Bug 并在 AI 模型切换页面修复 Loading/Toast 冲突问题
11. 小程序个人主页、公开主页、编辑资料、账号安全、隐私、通知、会话、搜索、关系列表等页面继续对齐移动端主 App
12. 删除小程序私信申请页与申请 API 封装，消息页只展示会话；公开主页和帖子详情通过直连会话发起私信
13. 小程序校园页帖子作者头像支持进入对应公开主页，匿名帖不跳转主页
14. 小程序帖子卡片、搜索结果、学院讨论、我的发布/收藏和帖子详情均增加“匿名”标签，匿名帖头像统一显示“匿”

## Repository Layout

```text
XDUWhisperBox/
├── backend/            # Python backend, SQLite repository, upload storage helpers
├── flutter_app/        # Flutter client for Web / mobile targets
├── miniprogram/        # Native WeChat Mini Program client
├── docs/               # Project docs and specifications
├── scripts/            # Local build/deploy/ops scripts
├── deploy/             # Deployment configs, including Tencent Cloud assets
├── CONTEXT.md          # Global AI assistant handoff context
└── AGENTS.md           # Codex-specific project instructions
```

Do not place Flutter-specific files such as `pubspec.yaml` at the repository root. Flutter commands should run from `flutter_app/`.

## Tech Stack

### Frontend

- Flutter Web
- Dart SDK: `>=3.3.0 <4.0.0`
- `flutter_riverpod: ^2.6.1`
- `http: ^1.2.2`
- `shared_preferences: ^2.3.2`
- `cupertino_icons: ^1.0.8`
- `flutter_lints: ^4.0.0`

### Backend

- Python 3
- Standard-library HTTP service: `http.server + ThreadingHTTPServer`
- SQLite persistence through `backend/sql_repository.py`
- Local object storage defaults to `backend/storage/objects`
- Optional S3-compatible object storage: `boto3 >=1.34,<2.0`

### Deployment

- Local development: Flutter Web + `python3 backend/server.py`
- Current internal-test server: Tencent Cloud Ubuntu 22.04
- Nginx + systemd deployment scripts live under `scripts/` and `deploy/tencent/`
- Production Web builds should use same-origin API by default: `--dart-define=API_BASE_URL=/api`

## Context Anchors

1. `backend/server.py`
   - Core backend entry point
   - HTTP APIs, authentication, business logic, and static Web hosting live here

2. `backend/sql_repository.py`
   - SQLite schema, initialization, JSON import, transactions, and persistence logic
   - Check this first for schema or data-persistence changes

3. `flutter_app/lib/widgets/home_shell.dart`
   - Main shell after user login
   - Bottom navigation, message badges, notification entry, and page switching start here

4. `flutter_app/lib/features/admin/admin_console_page.dart`
   - Main admin console
   - Content review, report handling, image review, account-deletion review, system config, and announcements live here

5. `flutter_app/lib/repositories/app_repositories.dart`
   - Frontend repository assembly point
   - API client, user-facing repositories, and admin repositories are wired here

6. `flutter_app/lib/mobile/features/post/create_post_page.dart`
   - Flutter mobile reference for the create-post flow

7. `flutter_app/lib/mobile/features/post/post_detail_page.dart`
   - Flutter mobile reference for post detail layout and interactions

8. `miniprogram/app.wxss`
   - Shared mini program visual tokens and reusable card/list styles

9. `miniprogram/pages/campus/create-post/index.*`
   - Mini program create-post page aligned to the mobile App

10. `miniprogram/pages/campus/post-detail/index.*`
    - Mini program post detail page aligned to the mobile App

11. `miniprogram/pages/profile/notification-settings/index.*`
    - Mini program notification settings page

12. `miniprogram/pages/profile/privacy/blocklist/index.*`
    - Mini program blocklist page (user blacklist)

13. `miniprogram/utils/markdown.js`
    - Mini program markdown parsing and rendering node generation logic

14. `miniprogram/utils/format.js`
    - Mini program post/comment normalization, including anonymous-post display name, avatar initials, and URL resolution

15. `miniprogram/api/messages.js`
    - Mini program direct-message API wrapper; request/approval flow has been removed from the mini program

## Architecture Conventions

- Frontend code should go through the `Repository` layer; do not build ad hoc HTTP calls directly in pages
- Core page state should prefer Riverpod `StateNotifier`
- Shared API paths belong in `flutter_app/lib/core/network/api_endpoints.dart`
- Shared loading/error UI should reuse existing `AsyncPageState` patterns where available
- Backend should continue the single-file `server.py` style for HTTP handlers and helpers; do not introduce a new web framework without explicit direction
- Add backend serialization helpers using the existing `serialize_*` naming style
- Add backend creation/publishing helpers using the existing `create_*` / `publish_*` naming style

## Async and State Rules

- Page initialization async loading should use `initState + Future.microtask(...)` or a controller `loadInitial()` pattern
- User-triggered async operations need explicit busy state to prevent duplicate clicks
- Prefer optimistic frontend state updates for interactive changes, then refresh or roll back on failure

## Product and Logic Rules

- Posts should appear immediately after publishing; do not add a frontend flow where posts wait for review before becoming visible
- Anonymous posting is allowed, but the admin console must still expose the real account to admins
- Anonymous posts in the mini program should be immediately recognizable: avatar shows “匿”, author name is paired with a small “匿名” badge, and avatar taps must not open a user profile
- Mini program direct messages should follow the mobile App rule: no request/approval flow; users can directly create/open a conversation only when privacy settings permit and the source post is not anonymous
- Normal user login and admin login are separate entry points with separate tokens
- Do not edit generated `build/web/*` output by hand
- Do not treat runtime data as source code:
  - `backend/data/treehole.db`
  - `backend/storage/objects`

## UI and Copy Rules

- Keep the current light theme and visual direction unless the task explicitly calls for redesign
- UI copy should stay Chinese, concise, and direct
- This project does not use a Flutter routing framework; continue using `Navigator` / `MaterialPageRoute`
- Mini program pages should keep visual parity with the mobile App where the task requires it

## Current Unfinished Tasks

1. Deploy the current notification-center changes to the Tencent Cloud environment if that deployment is still pending
2. Keep closing the remaining mobile-admin placeholders and parity gaps
3. Continue the mini program vs mobile App parity work for any remaining mismatches in layout, default values, and interaction logic
4. Medium-term production work still needed:
   - Domain + HTTPS
   - ICP filing
   - Backup / rollback
   - Logging and alerting
5. **「电台产品需求梳理」中未实现的功能对接**：
   - **教师端与教师角色**：支持工号登录分流、教授/副教授身份认证、教师发布学院公告与招募信息、教师私信及邮箱联系等（目前数据库与前后端均无工号与教师角色设计）。
   - **学院分区发帖限制**：后端及前端在发布到学院分区时应增加权限校验（只有本学院学生可在本学院发帖，非本学院学生只能浏览不能发帖）。
   - **社团管理与以社团名义发帖**：小程序与 App 端需实现社团负责人以社团名义发布招募、活动和日常信息的界面，以及社团分区的管理（如成员管理）。
   - **真实 RAG AI 问答与大模型对接**：目前 AI 检索和提问仅为字面匹配及模拟回复，需对接真实大模型（如通过 API）并动态生成包含原帖/公告标题、链接及跳转入口的精准引用。
   - **校园服务一站式真实对接**：课表、成绩、考试安排、水电费等服务目前仅为“待接入”静态页面，需对接教务、校园系统真实数据接口。
   - **校园地图与楼宇结构图**：目前地图、B楼等结构图、教室/办公室定位页均为静态占位，需导入地图坐标和定位数据。
   - **论坛热榜 AI 总结与审核流**：小程序端增加热榜 AI 总结的展示区，并在审核后台完善对 AI 热点总结的审核确认发布流程。
   - **个性化公告推荐**：数据库支持保存用户的专业/学院关联推荐，小程序端在请求时自动获取并呈送，以优先推荐本专业/本学院公告。

## Workspace Note

- The workspace may still contain unrelated local edits. Preserve them unless the task explicitly asks to change them.
