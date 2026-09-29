# 西电知行 Web

西电知行校园社交产品的 Web 前端与服务端应用。当前项目基于 Munia 的既有社交业务代码继续开发，保留其 Prisma 数据模型、API、React Query hooks 和帖子、评论、关注、收藏、转发、通知、私信等业务逻辑。

## 技术栈

- Next.js 15 App Router、React 18、TypeScript、Tailwind CSS
- Auth.js、Prisma、PostgreSQL 兼容数据库
- React Query、React Aria
- Pydantic AI Agent Harness 通过只读文件工具按需查阅校园资料

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

## 本地校园 Agent

校园问答由独立的 Pydantic AI Harness 提供。Agent 一次批量并行检索本地已发布资料、学校官网/新闻网/校内单位配置的公开网页，以及 DuckDuckGo 搜索到的互联网网页；结果按 URL 规范化去重，并可批量读取公开网页原文。校园网页列表在 `agent_harness/campus_sources.json`，可通过 `AGENT_HARNESS_CAMPUS_SOURCES` 指向另一份 JSON。网页只做公开只读 GET，Agent 会给实际打开的页面生成引用。聊天使用 SSE 展示简短进度状态和真实工具调用参数/结果，不再生成事后拼接的长推理摘要。

未来接入个人课表等校园 API 时，Agent 通过 `agent_harness/campus_connectors.py` 注册操作；Next.js 后端为已登录用户签发短时 HMAC 身份声明，Harness 根据服务端授予的 scope 决定可用能力。当前没有注册个人数据 API 或用户授权范围，所以课表等能力会明确返回未接入。Next.js 与 Harness 共用 `.env.local` 中的 `AGENT_HARNESS_INTERNAL_SECRET` 后才启用身份声明。将 `AGENT_HARNESS_BASE_URL`、`AGENT_HARNESS_API_KEY`、`AGENT_HARNESS_MODEL` 和 `AGENT_HARNESS_DB` 写入本机 `.env.local`，再启动 Harness：

```powershell
python -m pip install -r agent_harness/requirements.txt
python -m uvicorn agent_harness.app:app --host 127.0.0.1 --port 8002
```

本机默认模型为 `deepseek-v4-flash`，密钥只放在本机环境文件中。聊天页面继续通过已登录的 Next.js API 调用本地 Harness。

`npm run prisma:seed` 会运行 `prisma migrate reset` 并重建演示数据，执行前会清空目标数据库；不要对含有需要保留数据的数据库运行。

## 主题与主要页面

设置页可切换知行首页默认视觉、暖色参考视觉、浅色/深色显示模式和中英文。暖色参考视觉只调整颜色与字体变量，页面布局和业务行为保持共用。

应用包含首页信息流、帖子详情、搜索、校园、通知、私信、AI、个人主页、收藏及设置。校园正式数据、生产 IDS 登录、对象存储和 DeepSeek Harness 部署仍需按交接文档完成配置与验收。

## 常用检查

```powershell
npx tsc --noEmit
npm run lint
npm run build
```

本地构建与健康检查不能替代生产数据库、IDS/CAS、校园接口和媒体存储的联调。生产部署步骤与待配置项见 [`docs/交接工作总结.md`](docs/交接工作总结.md) 和 [`docs/重建项目架构与部署缺口.md`](docs/重建项目架构与部署缺口.md)。
