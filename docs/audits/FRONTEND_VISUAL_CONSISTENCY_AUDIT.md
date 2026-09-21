# 前端跨端视觉与交互审计

审计范围：Flutter Web（桌面与窄屏浏览器）、Flutter 移动端代码、微信小程序全部注册页面。审计基线采用 X/Twitter 的信息流原则：内容列优先、时间线连续、操作区稳定、页面层级少、媒体尺寸可预测；桌面与移动只改变导航和容器宽度，不改变内容结构和操作语义。

参考行为：X 的 Home timeline 是连续帖子流，点击帖子内容进入详情；收藏、通知、个人资料和发帖属于稳定入口。[X timeline behavior](https://help.x.com/en/using-x/x-timeline) [X mobile navigation](https://help.x.com/en/using-x/x-ios-app)

## 历史冲突与当前状态

### 已关闭：树洞的双布局

当前树洞只保留 `threads` 结构和 `post-row` 组件。旧的 `card` 布局、对应设置项、模板和样式已删除；显示设置页中的深浅模式与配色是主题设置，不再切换帖子结构。

验收状态：已统一数据行、媒体区、操作区；旧值不会再被读取为帖子布局。

### 已关闭：Web 旧 Feed 分支与重复帖子卡片

`flutter_app/lib/features/feed/feed_page.dart` 现在只渲染 `DiscussionFeedView`，`flutter_app/lib/widgets/post_card.dart` 只保留讨论流实现；永久为真的旧布局开关、旧辅助组件和旧分支已删除。移动端帖子卡片也已改为由列表数据单一维护点赞状态。

### 待决策：Web 公开包是否携带管理台

当前脚本已经把公开包携带管理台写成明确契约，并允许显式传入 `ENABLE_ADMIN_CONSOLE=false` 生成不含管理台的公开包；`build_web_admin.sh` 仍负责独立管理包。这里剩下的是发布策略确认，不是运行时逻辑冲突。

### P1：小程序仍使用硬编码的伪安全区和固定层

以下页面均出现 `padding-right: 260rpx`：树洞、校园、AI、帖子详情、发帖页。该值与真实设备宽度无关，会制造空白和标题/操作按钮碰撞。树洞、校园、AI、详情、发帖页还组合了 `position: fixed`、`height: 100vh`、嵌套 `scroll-view` 和多个 z-index，容易出现内容被顶栏/底栏遮挡、输入栏覆盖最后一条内容、不同机型高度异常。

### P1：小程序字体与形状偏离时间线产品

全局仍使用宋体/楷体/Times New Roman 作为正文与界面主字体；树洞保留大标题 editorial panel、多个 20–48rpx 圆角、卡片阴影和浮动按钮。它与 Web 当前连续讨论流、X 的轻量信息流层级不一致。应统一为系统无衬线正文、稳定的 40–48rpx 头像、8–16rpx 媒体圆角、1px 分割线，减少装饰性面板。

### P1：页面列表没有统一的跨端导航模型

- Web：树洞、校园、校园 AI 三个主 tab，桌面侧栏；窄屏仍有底部三 tab，同时顶部还有搜索、通知、私信、设置。
- 小程序：同样三个 tab，但另外通过 `radio-drawer` 承载个人、私信、社团、管理员、设置等入口。
- Flutter 移动端：Home、Messages、Profile 三个主 tab，校园和 AI 不在移动主导航中。

同名入口在不同端位置、层级和返回行为不同；这会造成跨端学习成本和深链路不一致。应先确定统一信息架构，再分别映射为桌面侧栏、移动底部导航和小程序 tab/drawer。

## 页面全量清单与审计结论

### Flutter Web 页面

| 页面/组件 | 当前结论 |
| --- | --- |
| `admin/admin_console_page.dart`、`admin/admin_portal_page.dart`、`admin/admin_login_page.dart` | 管理台视觉独立；需与公开 Web 构建契约、权限和发布入口拆清 |
| `auth/login_page.dart`、`auth/banned_account_page.dart` | 独立登录/申诉流；需与主壳的返回和窄屏宽度统一 |
| `feed/feed_page.dart`、`feed/discussion_feed_view.dart`、`widgets/post_card.dart` | 核心时间线；已收敛为单一讨论流结构，桌面与窄屏只改变容器和导航 |
| `post/create_post_page.dart`、`post/post_detail_page.dart` | 核心发帖/详情；应与小程序的媒体比例、评论操作、固定输入栏统一 |
| `campus/campus_page.dart`、`campus_auth_center_page.dart`、`campus_service_detail_page.dart` | 校园服务链；与树洞时间线使用不同页面密度，需统一顶栏、卡片和返回层级 |
| `ai/ai_page.dart` | 主 tab 页面；需与小程序 AI 首页和聊天页统一入口及空状态 |
| `messages/messages_page.dart`、`messages/chat_page.dart` | 列表/聊天；需与小程序 conversations/chat 的头像、输入栏和未读状态统一 |
| `notifications/notification_center_page.dart` | 通知流；需沿用统一列表行和时间线操作区 |
| `profile/profile_page.dart`、`public_user_profile_page.dart` | 个人/他人资料；需统一帖子列表、关注、私信入口 |
| `me/my_posts_page.dart`、`my_comments_page.dart`、`my_favorites_page.dart`、`my_reports_page.dart`、`report_detail_page.dart` | 个人内容管理；入口与小程序 profile 子页面需一一对应 |
| `favorites/favorites_page.dart`、`search/search_page.dart` | 跨页列表；仍是 Flutter Web 与 Flutter 移动端两套页面层，属于待继续收敛的架构重复 |
| `profile/settings_page.dart`、`emoji_settings_page.dart` | 设置入口；不能再暴露与小程序冲突的旧主题/布局开关 |
| `legal/terms_of_service_page.dart`、`privacy_policy_page.dart`、`community_guidelines_page.dart`、`report_guidelines_page.dart` | 法务静态页；只需统一顶栏、正文宽度和返回行为 |
| `download/android_release_page.dart`、`common/access_state_page.dart` | 辅助页面；需统一空、错、下载状态组件 |

### 微信小程序页面（全部 `app.json` 注册页面）

| 页面组 | 全部页面 | 重点问题 |
| --- | --- | --- |
| 树洞 | `treehole/index`、`treehole/hot` | 主时间线已统一到 `post-row`；热榜仍是独立信息密度，需要继续对齐连续流的间距和媒体基线 |
| 校园主链 | `campus/index`、`campus/auth-center/index`、`campus/college/index`、`campus/map/index`、`campus/search/index`、`campus/service-detail/index`、`campus/tag-posts/index`、`campus/webview/index` | 顶栏、搜索、服务卡片、列表密度各自实现；多处固定层和 `100vh` |
| 校园内容 | `campus/post-detail/index`、`campus/create-post/index` | 与树洞帖子详情/发帖的组件逻辑重复，且详情页同时有固定顶栏、底部评论栏、表情层 |
| AI | `ai/index`、`ai/chat/index`、`ai/history/index` | 首页、聊天、历史三套布局；聊天输入栏固定，需统一键盘/安全区和消息气泡宽度 |
| 社团 | `clubs/index`、`clubs/detail/index`、`clubs/apply/index` | 圆角卡片和表单独立实现，需对齐统一列表、按钮、表单 token |
| 管理 | `admin/index` | 与 Flutter 管理台并行实现；权限、审核卡片、指标卡需明确唯一管理入口 |
| 个人中心 | `profile/index`、`profile/public-user/index`、`profile/social-list/index`、`profile/conversations/index`、`profile/chat/index`、`profile/notifications/index` | 个人、他人、社交、私信、通知分散多页；头像、列表行、返回和未读逻辑需合并规范 |
| 个人内容 | `profile/favorites/index`、`profile/my-posts/index`、`profile/my-comments/index`、`profile/my-reports/index`、`profile/report-detail/index` | 帖子列表已统一到 `post-row`；评论、举报和详情仍需继续统一空/错状态与工具栏 |
| 设置 | `profile/settings/index`、`profile/display-settings/index`、`profile/ai-settings/index`、`profile/edit-profile/index`、`profile/account-security/index`、`profile/notification-settings/index`、`profile/privacy/index`、`profile/privacy/blocklist/index` | 主题、语言、隐私、安全、通知分散；帖子布局开关已删除 |
| 认证与说明 | `profile/auth/index`、`profile/about/index`、`profile/feedback/index`、`profile/legal/index` | 顶栏、表单、正文和状态组件没有完全共享小程序 token |

## 本轮冲突、冗余与性能回填（2026-09-20）

### 已完成的合并与删除

- 小程序帖子行已统一为 `miniprogram/components/post-row/`，当前覆盖树洞、标签、学院、搜索、个人页、收藏、我的帖子、他人主页、社团详情 9 个页面组；这些页面不再维护各自的头像、标题、摘要、媒体和操作区模板。
- 点赞/收藏列表更新已抽取到 `miniprogram/utils/post_actions.js`，树洞、标签、学院、搜索、个人页、收藏、我的帖子、他人主页和社团详情共用同一套状态更新逻辑。
- 删除了只被树洞旧入口使用的 `miniprogram/api/post.js`，所有帖子请求统一走 `miniprogram/api/posts.js`。
- 删除 `post-row` 中没有实际行为的“更多”空入口；图片点击预览、作者跳转、标签跳转、点赞和收藏均改由组件事件向页面统一分发。
- 删除小程序全局已无引用的 `feed-card` 及其配套布局样式，保留图标 mask 和真正仍在使用的通用 token，避免旧卡片样式再次覆盖时间线。
- 移除了 Web Feed 的永久死分支、重复 PostCard 辅助层和 Flutter 移动端无效明暗模式存储；移动端管理员页删除“即将上线/逻辑正在迁移/请暂使用 Web 端”的不可用入口。
- 将“正在寻找声音”“服务器 AI”等实现导向的文案收敛为“加载中”“AI 状态”“AI 尚未启用”等面向用户的状态文案；设置页删除只解释实现方式的长说明。
- 小程序同一帖子的多张图片改为并行预处理；HTTPS 和相对路径图片不再被错误当作临时 HTTP 图片清空。

### P1 处理结果与保留边界

1. **已解决 Flutter 的逻辑重复。** Web 与移动端继续保留平台适配后的页面壳，但帖子模型、仓库、消息控制器、通知控制器和搜索控制器统一；移动端搜索页已删除本地请求/加载/错误状态，改用共享 `SearchController`。剩余差异是桌面/移动布局差异，不再复制同一套数据逻辑。
2. **已解决移动端首页点赞双重状态。** `PostCard` 只负责交互忙状态，点赞结果、计数和失败回滚全部由首页 Feed 控制器维护。
3. **已解决小程序滚动容器冲突。** 校园首页、帖子详情、AI 聊天、标签、个人聊天均保留一个主纵向滚动容器；固定层仅保留必须覆盖内容的顶栏、输入栏、表情面板和选择器，并统一使用真实安全区变量。帖子详情右侧更多按钮已移除旧的 `260rpx` 路径偏移。
4. **已解决重复状态视图。** 新增 `miniprogram/components/status-view/`，学院、收藏、我的帖子、他人主页、社团详情统一加载、错误、空状态和重试命中区。帖子行之外的页面可以保留业务专属内容，但不再重复实现状态模板。
5. **管理入口已收敛。** Flutter 移动端只保留已实现的审核、图片审核和举报入口；用户管理、公告、系统配置、导出等占位入口已删除，Web 管理台作为唯一完整管理入口。

### 全量检查与验证边界

- `miniprogram/app.json` 注册页面与页面目录已做静态一一对应检查：42 个注册页面均有对应入口文件，没有发现孤立注册路径或缺失页面目录。
- 本轮修改后的 Mini Program JavaScript 全部通过 `node --check`；Flutter `analyze` 通过；`test/ui_responsive_test.dart` 18 项全部通过。
- 小程序尚未在微信开发者工具中逐页启动运行；因此本报告把“代码层 P1 已收敛”和“运行时逐页通过”分开记录，真机验收仍需在微信开发者工具中完成。

## 尺寸与适配基线

## 本轮已完成

- Web `HomeShell` 已删除旧 AppBar/NavigationBar 分支，只保留 `DiscussionHomeScaffold`。
- 小程序树洞已删除 `card` 布局、布局设置项和 editorial hero，统一使用 `post-row` 组件承载时间线帖子。
- 小程序顶部栏不再使用 `260rpx` 伪预留空间；树洞、校园、AI、发帖、详情、标签、个人页改用页面实际内边距。
- Flutter 校园页保留离线 Dino 小游戏，但整合到校园服务/日程信息层级中，改用当前主题 token，不再作为孤立装饰块。
- Flutter 移动端账号安全页删除无入口的退出逻辑；静态分析已无问题。

后续整改以以下基线验收，具体数值集中进 token，不再页面内散写：

- 桌面 Web：主内容列目标宽度 600–680 CSS px；左导航固定窄/宽两档；右侧辅助内容不得挤压主时间线。
- Web 窄屏：内容满宽，左右内边距 16px；底部导航与浮动发帖按钮避开安全区；不出现横向滚动。
- 小程序：使用真实导航/安全区变量，不再用 `260rpx` 预留空间；正文左右 24–32rpx；头像统一 80rpx 左右；操作按钮命中区至少 88rpx；媒体容器统一比例和圆角。
- 所有端：列表项只允许一个主点击区域；点赞、收藏、评论、更多操作必须阻止误触发详情；加载、空、错误、无更多四种状态共用同一层级。
- 所有端：列表图片给出稳定尺寸；大列表分页/增量加载，避免页面一次性渲染全部帖子、评论和历史消息。

## 整改顺序

1. 抽取并复用跨端产品 token：内容列、头像、间距、圆角、分割线、按钮命中区、媒体比例、状态页。
2. 按页面组逐页替换重复的帖子、用户、列表、聊天、表单、弹层组件，并建立 Web Desktop / Web 窄屏 / 小程序验收矩阵。
3. 清理小程序剩余固定层、`100vh` 嵌套滚动和重复顶栏，改为真实安全区与单一滚动容器。
4. 处理 Flutter 移动端与小程序的主导航差异，以及管理台公开包构建契约。

本文件是本轮静态审计基线；整改完成后应逐项回填“已统一、保留平台差异、已删除入口”和实际截图/运行结果。
