# Next.js Web 首发：离线部署与回滚

## 首发范围

首发只包含 Web。未接通的校园服务显示官方入口或“待接入”；正式 IDS 和 HTTPS 由信息中心提供并联调。当前旧 SQLite 数据没有真实用户，归档备份后可以让 PostgreSQL 从空库开始，不做用户数据迁移。旧 `4f46dab` 保留为独立的应急发布版本，不能把它的 SQLite 直接当作 Next 的 PostgreSQL 使用。

## 构建包

在与生产服务器相同 CPU 架构和 Linux 发行版的联网构建机上运行 `bash scripts/package-next-offline.sh`。脚本执行 `npm ci`、`next build`，把 `.next`、`node_modules`、`public`、`prisma` 和启动配置打包到 `dist/zhixing-<commit>-<time>.tar.gz`。包不包含环境变量、数据库、媒体或 Node 运行时。服务器必须预先具备匹配版本的 Node.js、PostgreSQL、Nginx、systemd、curl 和可用的 IDS/HTTPS 网络出口。`dist/` 已加入 Git 忽略。

## 服务器准备

创建 `zhixing` 系统用户与 `/opt/zhixing/releases`、`/var/lib/zhixing/media`。把 `deploy/zhixing-next.service` 安装到 `/etc/systemd/system/zhixing-next.service` 并执行 `systemctl daemon-reload`。将 `deploy/zhixing-next.nginx.conf` 按信息中心给出的证书路径安装到 Nginx，并在实际切流前完成 `nginx -t`。证书路径只是模板，须按真实服务器调整。

创建仅管理员和 `zhixing` 可读的 `/etc/zhixing/zhixing.env`。至少设置：

```sh
AUTH_URL=https://zhixing.xidian.edu.cn
NEXTAUTH_URL=https://zhixing.xidian.edu.cn
AUTH_SECRET=<独立生成的随机密钥>
DATABASE_URL=postgresql://zhixing:<数据库密码>@127.0.0.1:5432/zhixing?schema=public
XIDIAN_PUBLIC_ORIGIN=https://zhixing.xidian.edu.cn
XIDIAN_CAS_ISSUER=https://ids.xidian.edu.cn/authserver
ADMIN_STUDENT_NUMBERS=<管理员学号，逗号分隔>
MEDIA_STORAGE_DIR=/var/lib/zhixing/media
LOCAL_TEST_AUTH=false
```

生产数据库用户需有执行 Prisma 迁移的权限。媒体目录必须保留在版本目录外，并随数据库备份；它与 PostgreSQL 数据对应。图像审核/OCR 与校园官方 API 要以真实接入状态配置，未接通的服务不能宣称已可用。

## 发布与回退

把离线包和 `scripts/deploy-next-offline.sh`、`scripts/rollback-next-offline.sh` 传到服务器。首次切流前在服务器上由有权限的人执行：

```sh
sudo bash scripts/deploy-next-offline.sh /path/to/zhixing-<id>.tar.gz
```

脚本解包、运行 `prisma migrate deploy`、原子切换 `/opt/zhixing/current`、重启服务并访问本机首页。首页未就绪时切回前一 Next 版本。手动回退执行 `sudo bash scripts/rollback-next-offline.sh`。本次新增的迁移只增加可空字段；回退代码时不回滚数据库结构。第一次部署无前一 Next 版本，因此应在对外切流前完成服务启动和 IDS 联调。

## 切流判定

由三人明确负责：信息中心确认 HTTPS 证书、IDS 回调与域名；开发者之一执行服务器上传、迁移和切流；另一位完成浏览器验收与一次回退演练。验收覆盖登录、退出、发帖/匿名、图片、评论、举报、管理员审核、申诉、私信和媒体持久化。发布包及旧线上 `4f46dab` 均保留。部署人员的分工与代码基座的技术可行性分别决策。

设置里的“人本·初创”使用旧版朱砂赤主题的主要色值、宋体标题和纸面卡片样式；旧 Flutter 页面布局尚未逐页移植。若要求两套界面像素级一致，应按页面单独验收和安排工作量。
