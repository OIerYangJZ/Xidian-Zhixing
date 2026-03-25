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
| — | — | — |

---

## 4. 未跨端兼容的功能

> 以下记录尚未同时在 Web 端和移动端适配的功能，跨端适配完成后请删除对应条目。

| 功能名称 | 描述 | 状态 |
|----------|------|------|
| — | — | — |

---

*最后更新：2026-03-25*
