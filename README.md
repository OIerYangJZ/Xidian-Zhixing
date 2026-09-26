# 西电知行 Web

西电知行校园社交产品的 Web 前端与服务端应用。当前项目基于 Munia 的既有社交业务代码继续开发，保留其 Prisma 数据模型、API、React Query hooks 和帖子、评论、关注、收藏、转发、通知、私信等业务逻辑。

## 技术栈

- Next.js 15 App Router、React 18、TypeScript、Tailwind CSS
- Auth.js、Prisma、PostgreSQL 兼容数据库
- React Query、React Aria
- 独立 Python 知识服务提供 AI/RAG 接入

## 本地开发

1. 安装 Node.js 与 npm，复制 `.env.local.example` 为 `.env.local` 并填写本地配置。
2. 启动本地 PostgreSQL 兼容数据库，并将 `DATABASE_URL` 指向该实例。当前开发机使用持久化 PGlite 数据库；其数据目录位于 `%LOCALAPPDATA%\zhixing-dev-pglite`，仅供本地开发。
3. 安装依赖并应用 Prisma migrations：

   ```powershell
   npm install
   npm run prisma:deploy
   ```

4. 启动 Web：

   ```powershell
   npm run dev
   ```

   开发地址为 `http://127.0.0.1:3002`。只有非生产环境可启用本地测试登录；部署环境不得开放该登录方式。

`npm run prisma:seed` 会运行 `prisma migrate reset` 并重建演示数据，执行前会清空目标数据库；不要对含有需要保留数据的数据库运行。

## 主题与主要页面

设置页可切换知行首页默认视觉、暖色参考视觉、浅色/深色显示模式和中英文。暖色参考视觉只调整颜色与字体变量，页面布局和业务行为保持共用。

应用包含首页信息流、帖子详情、搜索、校园、通知、私信、AI、个人主页、收藏及设置。校园正式数据、生产 IDS 登录、对象存储和 AI/RAG 部署仍需按交接文档完成配置与验收。

## 常用检查

```powershell
npx tsc --noEmit
npm run lint
npm run build
```

本地构建与健康检查不能替代生产数据库、IDS/CAS、校园接口、媒体存储和 RAG 服务的联调。生产部署步骤与待配置项见 [`docs/交接工作总结.md`](docs/交接工作总结.md) 和 [`docs/重建项目架构与部署缺口.md`](docs/重建项目架构与部署缺口.md)。
