# miniprogram2 与知行 Web API 对齐记录

小程序通过统一认证获取知行 Bearer token，后续请求复用现有 `/api` 路由。响应适配集中在 `utils/request.js`、`utils/format.js` 和 `api/`，页面不直接拼装后端业务。

## 已对齐

- 统一认证：`/api/auth/xidian/session`、session status/token、`/api/users/me`
- 本机开发可通过 `/api/auth/local-test` 直接登录本地测试账号；生产环境仍走西电统一认证
- Feed、热度流、帖子、标签、评论、点赞、收藏、举报、删帖：`/api/users/:id/feed`、`/api/posts/trending`、`/api/posts`、`/api/comments`、`/api/users/:id/{liked-posts,liked-comments,bookmarks}`、`/api/reports`
- 校园学院与分区目录：`/api/campus/spaces`；帖子流支持 `spaceId` 过滤
- 个人评论与举报记录：`/api/users/:id/comments`、`/api/users/:id/reports`
- 用户资料、关注、粉丝、屏蔽、通知偏好：`/api/users`、`/api/users/:id`、`/api/users/:id/{following,blocks}`、`/api/settings`
- 通知、私信：`/api/users/:id/notifications`、`/api/messages`
- AI 对话：`/api/ai/models`、`/api/ai/chat`；小程序本地会话保存 Web API 返回的 `conversationId` 并用于后续提问
- 头像和封面上传：`/api/users/:id/profile-photo`、`/api/users/:id/cover-photo`
- 帖子 JSON 文本发布已适配到现有发布校验和审核流程；Web 端 multipart 发布保持原样。

## 当前后端没有同等接口

- 社团目录/申请、热榜 AI 摘要
- 草稿图片预上传、反馈列表与提交、账号注销/等级申请、私信撤回
- 清除封面，以及性别/学院/专业资料字段（当前 Web User 模型没有这些字段）
- 小程序原管理后台的大部分面板（当前 Web 后端只提供审核案件和知识库管理路由）

以上能力没有替换成相似但语义不同的 API。对应页面仍需服务端接口支持后，才能与 Web 后端完整联调。

## 移动端视觉基准

- 颜色、字体、背景、分割线、控件色统一由 `styles/tokens.wxss` 管理，浅色默认白底、知行红强调色，深色使用纯黑底。
- 信息流帖子复用 `components/post-row`：头像 48px、内容左起点 60px、正文 14px/20px、无卡片间距并以 1px 分割线分隔，作者名、用户名、时间放在同一身份行。
- 移动底栏顺序与 Web 竖屏一致：首页、校园、知行 AI、消息、我的；帖子详情、资料页、通知和私信使用连续列表与轻分割线。
- 原生小程序没有 Web 的浏览器布局和组件环境，像系统导航栏、系统弹层与校园服务专属控件仍按原生交互呈现；布局基准对应 Web 约 390px 竖屏。
