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
├── backend/                        # Python 后端
│   ├── server.py                   # 核心入口，所有 HTTP API、鉴权、业务逻辑
│   ├── sql_repository.py           # SQLite schema、初始化、持久化逻辑
│   ├── object_storage.py           # 对象存储（本地 / S3 兼容）
│   ├── reset_db.py                 # 数据库重置脚本
│   ├── migrate_json_to_sql.py      # JSON → MySQL/PostgreSQL 迁移脚本
│   ├── sql/                        # SQL schema 文件
│   │   ├── schema_mysql.sql
│   │   └── schema_postgresql.sql
│   └── tests/                      # 后端单元测试
├── lib/                            # Flutter Web 前端
│   ├── core/                       # 核心基础设施
│   │   ├── auth/                   # 鉴权相关
│   │   ├── config/                 # 配置
│   │   ├── emoji/                  # 表情
│   │   ├── media/                  # 媒体处理
│   │   ├── navigation/             # 导航
│   │   ├── network/                # 网络请求
│   │   ├── state/                  # 状态管理
│   │   ├── theme/                  # 主题
│   │   └── utils/                  # 工具函数
│   ├── data/                       # 数据层
│   ├── features/                   # 功能模块
│   │   ├── admin/                  # 管理员后台
│   │   ├── auth/                   # 登录/注册
│   │   ├── favorites/              # 收藏
│   │   ├── feed/                    # 信息流
│   │   ├── legal/                   # 合规说明页
│   │   ├── me/                      # 个人中心
│   │   ├── messages/                # 私信
│   │   ├── notifications/           # 通知中心
│   │   ├── post/                    # 发帖
│   │   └── search/                  # 搜索
│   ├── models/                     # 数据模型
│   ├── repositories/               # Repository 层
│   └── widgets/                    # 公共组件
├── lib_mobile/                     # Flutter 移动端（Android / iOS）
│   ├── core/                       # 核心基础设施
│   ├── features/                   # 功能模块
│   └── main.dart                   # 移动端入口
├── scripts/                        # 部署与构建脚本
│   ├── build_web_beta.sh           # 内测 Web 构建
│   ├── build_web_production.sh     # 生产 Web 构建
│   ├── deploy_tencent.sh           # 腾讯云部署
│   ├── health_check.sh             # 健康检查
│   ├── install_tencent_host.sh     # 服务器环境安装
│   ├── package_release.sh          # 发布包打包
│   ├── rollback.sh                 # 版本回滚
│   ├── run_backend_beta.sh         # 内测后端启动
│   └── version.sh                  # 版本信息生成
├── deploy/                         # 部署配置
│   ├── production/                 # 生产环境配置
│   └── tencent/                    # 腾讯云配置
├── docs/                           # 文档
├── test/                           # 前端测试
├── web/                            # Web 静态资源
├── pubspec.yaml                    # Flutter 依赖配置
└── README.md                       # 项目主说明
```

---

## 3. 版本历史

| 版本号 | 更新日期 | 更新内容 |
|--------|----------|----------|
| 0.1.0+1 | 2026-03-25 | 首个 Android ARM64 Release APK；修复 `lib_mobile/` 未被纳入编译的问题（改用 `--target lib_mobile/main.dart` 构建）；修复 `PostCard` 引用不存在字段 `avatarUrl` / `nickname` 的编译错误 |
| 0.1.0+1 | 2026-03-25 | 优化 Android 构建方式：创建 `lib/mobile/` Junction 指向 `lib_mobile/`，在 `lib/main.dart` 用 `kIsWeb` 平台分流，无需 `--target` 参数，`flutter build apk` 直接可用 |
| 0.1.0+2 | 2026-03-25 | 修复移动端 6 个问题：① 首页点赞/收藏改为乐观更新不再全量刷新 ② 下拉刷新添加 AlwaysScrollableScrollPhysics ③ 消息页移除 mock 数据回退 ④ 发帖页匿名模式添加昵称输入框 ⑤ 我的页登录后自动 fetchProfile、收藏 Tab 真实数据 ⑥ 设置页修改密码路由修复、关于区各页正确跳转 |
| 0.1.0+4 | 2026-03-25 | 重构底部导航（3 Tab：首页/消息/我的）；搜索入口移至首页 AppBar；管理员后台修复（使用真实 Web 端 AdminConsolePage）；实现关注/粉丝系统（API 端点 + Repository + 个人主页底部弹窗列表 + 好友标记）；消息页移除私信申请 Tab，改为首条消息警告横幅；帮助与反馈入口加入登录/注册页；头像点击逻辑（自己帖子跳我的主页，其他提示暂不支持）；管理员控制台恢复完整功能 |
| 0.1.0+5 | 2026-03-25 | 修复消息页加载不出（`MessagesPage` 恢复 `ConsumerStatefulWidget`，`initState` 触发 `loadInitial()`）；修复头像点击逻辑（自己帖子跳转 `/profile`，其他帖子提示「暂不支持查看该用户主页」） |

## 4. 构建记录

| 日期 | 构建类型 | 平台 | 文件大小 | 路径 | 构建命令 |
|------|----------|------|----------|------|----------|
| 2026-03-25 | Release | Android ARM64 | 18.4 MB | `build/app/outputs/flutter-apk/app-release.apk` | `flutter build apk --target-platform android-arm64 --release` |
| 2026-03-25 | Release | Android ARM64 | 18.4 MB | `build/app/outputs/flutter-apk/app-release.apk` | 移动端 6 项 bug 修复后重新构建 |
| 2026-03-25 | Release | Android ARM64 | 18.8 MB | `build/app/outputs/flutter-apk/app-release.apk` | v0.1.0+4：关注系统 + 底部导航重构 + 消息页简化 + 管理员修复 |
| 2026-03-25 | Release | Android ARM64 | 18.8 MB | `build/app/outputs/flutter-apk/app-release.apk` | v0.1.0+5：消息页加载修复 + 头像点击逻辑修复 |

## 5. 未跨端兼容的功能

> 以下记录尚未同时在 Web 端和移动端适配的功能，跨端适配完成后请删除对应条目。

| 功能名称 | 描述 | 当前实现平台 |
|----------|------|-------------|
| 移动端整体 UI 风格 | Twitter/Instagram 风格重构：纯白背景、无卡片/无圆角/无阴影、紧凑布局、频道彩色圆点、FAB 发帖按钮 | 仅移动端（`lib_mobile/`） |
| 个人主页（ProfilePage） | 背景色条 + 重叠头像 + 统计行 + Tab（帖子/收藏/动态）+ 右上角设置入口 | 仅移动端 |
| 设置主页（SettingsMainPage） | 独立设置页：账号安全 / 隐私开关 / 通知 / 关于 / 退出登录；注销账号双重确认流程 | 仅移动端 |
| 发帖页（CreatePostPage） | 极简发帖：内联频道选择器、底部工具栏、匿名昵称输入、PopupMenu 可见性选择 | 仅移动端 |
| 帖子详情页（PostDetailPage） | 紧凑布局、底部操作栏压缩、AvatarWidget 头像 | 仅移动端 |
| 消息页（MessagesPage） | TabBar 无外层 padding、头像尺寸优化、无 mock 数据回退 | 仅移动端 |
| AvatarWidget | 使用 `AppConfig.resolveUrl()` + `CachedNetworkImage` 正确加载头像 | 仅移动端（`lib_mobile/features/widgets/`） |
| 学号登录（自动拼接邮箱后缀） | 登录/注册只需填学号，系统自动拼接 `@stu.xidian.edu.cn` | 仅移动端 |
| 关注/粉丝系统（FollowSystem） | 粉丝/关注数实时显示，点击弹出列表，互相关注标记为好友；API 端点 + `FollowUserItem` 模型 + Repository 方法 | 仅移动端 |
| 首条消息警告横幅 | 对话无历史消息时显示横幅提示"只能发1条消息"，对方回复或关注后解锁 | 仅移动端 |
| 匿名头像点击提示 | 非自己帖子头像点击弹出 SnackBar「暂不支持查看该用户主页」；自己帖子点击跳转 `/profile` | 仅移动端 |
| 帮助与反馈入口（登录/注册页） | 登录页底部行增加「帮助与反馈」按钮；注册页底部同样添加入口 | 仅移动端 |

---

*最后更新：2026-03-25（v0.1.0+5）*
