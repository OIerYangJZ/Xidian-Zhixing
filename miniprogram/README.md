# 西电知行微信小程序

小程序通过单个 `web-view` 页面加载现有 Next.js 网站，页面、样式和交互继续由 Web 源码提供，不维护第二份前端实现。

## 配置

1. 在 `config/site.js` 中，将 `siteUrl` 设为当前 Next.js 网站的 HTTPS 地址。
2. 在 `project.config.json` 中，将开发用 `touristappid` 替换为小程序 AppID。
3. 在微信公众平台配置该 HTTPS 主机为小程序业务域名。
4. 在微信开发者工具中直接打开 `miniprogram` 目录预览。

当前开发环境的 Web 地址为 `http://127.0.0.1:3002`，只能由开发机访问，不能作为手机 WebView 地址。仓库文档规划的 `https://zhixing.xidian.edu.cn` 在本次检查中未能通过 HTTPS 连接验证；部署并验证当前 Next.js 网站后，再把实际地址写入 `config/site.js`。本地开发者工具可在“详情 → 本地设置”临时关闭合法域名校验；真机体验和正式发布仍须使用已配置的 HTTPS 业务域名。
