# 校园功能 API 与远程部署手册

面向新前后端重写的接口、协议和上线操作清单。保留社交平台、帖子、评论、关注、私信、通知、审核和校园服务能力；不引入旧产品语义。

## 1. 统一约定

### 1.1 API 地址与返回体

生产 API 根地址：

~~~text
https://zhixing.xidian.edu.cn
~~~

成功响应统一为：

~~~json
{"data": <payload>}
~~~

错误响应统一为：

~~~json
{"message": "错误说明", "data": {}}
~~~

普通用户请求使用：

~~~http
Authorization: Bearer <本站 token>
Content-Type: application/json
~~~

状态变更请求必须带允许的 Origin；OPTIONS 支持 CORS。后台管理使用独立管理员会话或 Bearer token，不得复用普通用户 token。

无需普通用户会话的路由：

~~~text
GET  /api/health
GET  /api/version
GET  /api/storage/{objectKey}
GET  /api/ai/models
GET  /api/admin/ai/knowledge-sources       # 仍需管理员校验
GET  /api/admin/ai/traces/{traceId}        # 仍需管理员校验
GET  /api/auth/xidian/start
GET  /api/auth/xidian/callback
POST /api/auth/xidian/session
GET  /api/auth/xidian/session/{attemptId}
POST /api/auth/logout
GET  /api/releases/android/latest
POST /api/appeals
GET  /api/appeals/mine
~~~

其余接口默认要求普通用户登录；管理员接口还要通过管理员校验。

### 1.2 分页与资源上传

列表分页响应：

~~~json
{"data":{"items":[],"page":1,"limit":20,"total":0,"hasMore":false}}
~~~

图片先调用 POST /api/uploads/images，再将返回的上传 id 放入帖子 imageUploadIds。支持 jpg、png、webp、gif；对象通过 GET /api/storage/{objectKey} 读取。

## 2. 本站业务 API

### 2.1 状态与统一登录

~~~text
GET  /api/health
GET  /api/version

POST /api/auth/xidian/session
GET  /api/auth/xidian/session/{attemptId}
GET  /api/auth/xidian/start?attempt={id}
GET  /api/auth/xidian/callback?ticket={ticket}
POST /api/auth/logout
~~~

登录流程：

1. 前端 POST 创建登录尝试，得到 attemptId 和 authorizeUrl。
2. 浏览器打开 authorizeUrl，跳转西电 IDS。
3. IDS 回调本站固定地址；后端服务端校验 ticket，创建或更新本站账号。
4. 前端轮询 GET session/{attemptId}，领取一次性本站 Bearer token。
5. 登录尝试约 10 分钟有效，认证结果只能消费一次。

### 2.2 用户、关系与账号

~~~text
GET    /api/users/me
PATCH  /api/users/me
GET    /api/users/{userId}
GET    /api/users/search?keyword=...
PATCH  /api/users/privacy
PATCH  /api/users/notification-preferences
PATCH  /api/users/me/notification-preferences
POST   /api/users/avatar

GET    /api/users/me/following
GET    /api/users/me/followers
GET    /api/users/me/friends
POST   /api/users/{userId}/follow
POST   /api/users/{userId}/unfollow

GET    /api/users/me/blocks
POST   /api/users/me/blocks
DELETE /api/users/me/blocks/{userId}
POST   /api/users/me/cancellation-request
POST   /api/users/me/level-upgrade-request
DELETE /api/users/me                  # 固定 405，注销必须提交申请
~~~

### 2.3 频道、分区与社团

~~~text
GET   /api/channels
GET   /api/colleges
GET   /api/sections
GET   /api/sections/tree
GET   /api/sections/{sectionId}/posts
POST  /api/sections                  # 管理员
PATCH /api/sections/{sectionId}       # 管理员

GET   /api/clubs
GET   /api/clubs/{clubId}
POST  /api/clubs/applications
GET   /api/clubs/applications/mine
GET   /api/admin/clubs/applications
POST  /api/admin/clubs/applications/{id}/handle
~~~

学院分区发帖前必须完成学号到学院分区的服务端映射；社团名义发帖必须是负责人或管理成员。

### 2.4 帖子、评论、互动与举报

~~~text
GET    /api/posts
GET    /api/posts/{postId}
POST   /api/posts
PATCH  /api/posts/{postId}
DELETE /api/posts/{postId}
GET    /api/posts/mine
GET    /api/posts/favorites
POST   /api/posts/{postId}/view
POST   /api/posts/{postId}/pin-request

GET    /api/posts/{postId}/comments
POST   /api/posts/{postId}/comments
GET    /api/comments/mine
DELETE /api/comments/{commentId}

POST   /api/posts/{postId}/like
POST   /api/comments/{commentId}/like
DELETE /api/comments/{commentId}/like
POST   /api/posts/{postId}/favorite
DELETE /api/posts/{postId}/favorite

POST   /api/reports
GET    /api/reports/mine
GET    /api/reports/{reportId}
POST   /api/appeals
GET    /api/appeals/mine
~~~

GET /api/posts 支持参数：

~~~text
keyword, hasImage, allowDm, status, sort, authorId,
sectionId, sectionType, channel, page, limit
~~~

创建帖子核心字段：

~~~json
{
  "title": "",
  "content": "",
  "contentFormat": "plain",
  "markdownSource": "",
  "tags": [],
  "imageUploadIds": [],
  "sectionType": "general",
  "sectionId": "",
  "sectionName": "",
  "publisherType": "user",
  "publisherClubId": "",
  "useAnonymousAlias": false,
  "anonymousAlias": "",
  "visibility": "public",
  "allowComment": true,
  "allowDm": true,
  "status": "ongoing",
  "pinDurationMinutes": null
}
~~~

匿名只改变展示身份，不改变帖子、评论、审核和举报的数据模型。评论字段为 content，可选 parentId 或 replyToId。举报字段：

~~~json
{
  "targetType": "post",
  "targetId": "p1",
  "reason": "违规内容",
  "description": ""
}
~~~

reason 可用：广告引流、人身攻击、违规内容、垃圾信息、其他。

### 2.5 图片与对象

~~~text
POST /api/uploads/images
GET  /api/uploads/mine
POST /api/users/avatar
GET  /api/storage/{objectKey}
~~~

图片上传字段：

~~~text
imageDataBase64 或 dataBase64
fileName
contentType
postId（可选）
~~~

### 2.6 私信、通知、反馈

~~~text
GET    /api/messages/requests
POST   /api/messages/requests
POST   /api/messages/requests/{id}/accept
POST   /api/messages/requests/{id}/reject

GET    /api/messages/conversations
POST   /api/messages/conversations/direct
GET    /api/messages/conversations/{conversationId}/messages
POST   /api/messages/conversations/{conversationId}/messages
POST   /api/messages/conversations/{conversationId}/block
POST   /api/messages/conversations/{conversationId}/unblock
DELETE /api/messages/conversations/{conversationId}
DELETE /api/messages/messages/{messageId}/recall?conversationId=...

GET    /api/notifications
GET    /api/notifications/{notificationId}/read
POST   /api/notifications/{notificationId}/read
POST   /api/notifications/read-all

POST   /api/feedback
GET    /api/feedback/mine
~~~

私信消息字段为 content，可选 replyToId；撤回仅允许发送后 120 秒内。

### 2.7 公告、热榜与 AI

~~~text
GET  /api/announcements
GET  /api/announcements/{id}
GET  /api/announcements/filters
GET  /api/announcements/daily-summary
GET  /api/hot-topics
GET  /api/ai/hot-topics/summary
POST /api/hot-topics/rebuild

GET  /api/ai/models
POST /api/ai/chat
POST /api/ai/search
POST /api/ai/post-selection

GET    /api/admin/ai/knowledge-sources
POST   /api/admin/ai/knowledge-sources
PATCH  /api/admin/ai/knowledge-sources/{id}
DELETE /api/admin/ai/knowledge-sources/{id}
POST   /api/admin/ai/reindex
GET    /api/admin/ai/traces/{traceId}
~~~

模型供应商密钥只存在服务端，前端不上传。AI 检索可引用校园知识和公开帖子，但个人数据仍须按权限过滤。

### 2.8 Android 发布

~~~text
GET  /api/releases/android/latest
GET  /api/admin/releases/android
POST /api/admin/releases/android
~~~

### 2.9 管理后台

查询：

~~~text
GET /api/admin/auth/me
GET /api/admin/overview
GET /api/admin/reviews
GET /api/admin/reports
GET /api/admin/images/reviews
GET /api/admin/users
GET /api/admin/post-pin-requests
GET /api/admin/user-level-requests
GET /api/admin/admin-accounts
GET /api/admin/account-cancellation-requests
GET /api/admin/appeals
GET /api/admin/export
GET /api/admin/channels-tags
GET /api/admin/config
GET /api/admin/clubs/applications
GET /api/admin/announcements
~~~

认证与处理：

~~~text
POST   /api/admin/auth/login
POST   /api/admin/auth/logout
POST   /api/admin/auth/password
POST   /api/admin/reviews/batch
POST   /api/admin/reviews/{post|comment}/{id}/{approve|reject|delete|risk}
POST   /api/admin/reports/{id}/handle
POST   /api/admin/images/{id}/review
POST   /api/admin/users/{id}/action
POST   /api/admin/appeals/{id}/handle
POST   /api/admin/account-cancellation-requests/{id}/handle
POST   /api/admin/post-pin-requests/{id}/handle
POST   /api/admin/user-level-requests/{id}/handle
POST   /api/admin/admin-accounts
POST   /api/admin/admin-accounts/{id}/action
POST   /api/admin/channels
PATCH  /api/admin/channels/{oldName}
DELETE /api/admin/channels/{name}
POST   /api/admin/tags
PATCH  /api/admin/tags/{oldName}
DELETE /api/admin/tags/{name}
PATCH  /api/admin/config
POST   /api/admin/announcements
~~~

常见 body：

~~~text
reviews/batch: {"items":[{"type":"post|comment","id":"...","action":"..."}]}
reports handle: {"action":"resolve|delete|warn|ban|misreport","reviewNote":"..."}
images review: {"action":"approve|reject|delete|risk","reviewNote":"..."}
users action: {"action":"mute|unmute|ban|unban|cancel|restore|grant_admin|revoke_admin"}
appeals: {"action":"approve|approve_restore|reject|close"}
cancellation/pin/level: {"action":"approve|reject"}
admin account: {"action":"activate|deactivate"}
~~~

## 3. 校园功能 API 与上游协议

### 3.1 校园服务目录、地图与课表

这些接口是本站统一数据层，前端只依赖本站协议：

~~~text
GET /api/campus/services
GET /api/campus/services/{id-or-slug}
GET /api/campus/maps
GET /api/campus/quick-links
GET /api/campus/schedules/today
GET /api/campus/schedules/calendar?startDate=YYYY-MM-DD&days=7&source=all
~~~

服务目录字段：

~~~text
id, slug, name, groupId, groupName, kind, iconKey, authType,
authReady, status, description, requiredAccess, features, dataFields,
calendarSource, emptyText, mapIds, actions, path, enabled, sortOrder
~~~

课表聚合当前读取本站数据源：

~~~text
courseSchedules   -> 课表
examSchedules     -> 考试安排
experimentSchedules -> 实验安排
~~~

today 返回 date、items；每项含 title、date、startTime、endTime、location、teacher、section、kind、seatNo、examType、source、isActive、isEmphasized。calendar 返回 startDate、endDate、days[]，支持 1 至 31 天和 source 过滤。

当前仓库没有课表/成绩/考试上游同步协议。上述数据若要接入信息中心，必须新增正式适配器，不能从页面链接或本地字段猜测。

### 3.2 西电 IDS/CAS 一站式登录

上游：

~~~text
登录页：
https://ids.xidian.edu.cn/authserver/login

验票优先：
https://ids.xidian.edu.cn/authserver/p3/serviceValidate

兼容验票：
https://ids.xidian.edu.cn/authserver/serviceValidate

生产 service：
https://zhixing.xidian.edu.cn/api/auth/xidian/callback
~~~

协议：

1. 后端把 service 和随机 state/attempt 绑定，跳转 IDS login。
2. IDS 回调 ticket。
3. 仅后端向 serviceValidate 发送 service、ticket，解析 CAS XML 的 authenticationSuccess，读取学号/邮箱。
4. 服务端创建本站会话；前端永远只拿本站 token。
5. ticket、attempt 不能重复消费；回调必须校验固定 HTTPS origin。

禁止把 IDS 密码、ticket、本站 token 写日志或发给前端以外的系统。

### 3.3 一站式 eHall

当前只有入口：

~~~text
https://ehall.xidian.edu.cn/new/index.html
~~~

仓库没有 eHall 登录交换、OAuth/CAS 回调、免登 Cookie/Token、课表、成绩、考试、空闲教室等接口实现。authReady 只表示本站已有 IDS 学号，不表示已登录 eHall。

接入前必须从信息中心取得：正式接口 URL、认证/签名方式、回调白名单、token 生命周期、字段和错误码、身份映射、缓存与限流规则、注销策略。

### 3.4 校园网自服务

上游：

~~~text
https://zfw.xidian.edu.cn
~~~

本站接口：

~~~text
POST /api/campus/auth/schoolnet/captcha
POST /api/campus/auth/schoolnet/login
~~~

流程：

1. 后端 GET /login，动态解析 CSRF 字段和值、RSA 公钥。
2. 后端 GET /site/captcha，返回 attemptId、图片 Base64、有效期约 8 分钟。
3. 前端提交 attemptId、password、captcha；服务端只允许当前登录用户自己的学号。
4. 密码用 RSA PKCS#1 v1.5 加密后 Base64 编码。
5. 先 POST /site/validate-user，再 POST /，最后 GET /home。
6. 仅返回流量摘要和在线设备，不保存密码或上游 Cookie。

预校验字段：

~~~text
LoginForm[username]
LoginForm[password]
LoginForm[verifyCode]
~~~

最终登录额外带：

~~~text
<csrf-name>=<csrf-value>
LoginForm[username]
LoginForm[password]
LoginForm[smsCode]=
LoginForm[verifyCode]
~~~

### 3.5 宿舍水机

上游：

~~~text
https://i.ilife798.com
~~~

本站接口：

~~~text
POST /api/campus/auth/dorm-water/captcha
POST /api/campus/auth/dorm-water/sms
POST /api/campus/auth/dorm-water/login
~~~

上游协议：

~~~text
GET  /api/v1/captcha/?s=<16位数字>&r=<时间戳>
POST /api/v1/acc/login/code
     {"s":"<sessionId>","authCode":"<imageCode>","un":"<phone>"}
POST /api/v1/acc/login
     {"cid":"","authCode":"<smsCode>","un":"<phone>"}
~~~

本站流程先获取图形验证码，再发送短信，最后用短信验证码登录。服务端只返回认证状态、uid/eid 和 hasToken，不向前端暴露上游 token；当前未实现设备控制、扫码绑定和订单接口。

### 3.6 已知未接入的学校系统

以下能力目前只有页面或本地数据模型，没有可复用的正式上游协议：

~~~text
课表、成绩、考试、空闲教室、考勤、实验、校园卡、住宿同步
图书馆、报修、请销假、空间预约、电费、订水、体育业务
GIS 室内楼层与真实 POI
水机设备控制、扫码绑定、订单
~~~

新增适配器时记录：上游 URL、认证方式、请求/响应字段、错误码、身份映射、缓存 TTL、限流、敏感数据保存期限、注销和故障降级策略。

## 4. 当前生产部署结构

当前服务器仍使用既有兼容命名；新技术栈迁移时只替换服务名、目录和构建命令，接口契约可保持不变。

~~~text
前端：Flutter Web，输出 build/web
后端：Python ThreadingHTTPServer，127.0.0.1:8080
入口：Nginx 反向代理
进程：systemd 服务 treehole
数据库：SQLite

/home/ubuntu/treehole/
├── current
├── releases/
├── incoming/
├── shared/
│   ├── config/backend.env
│   ├── data/treehole.db
│   ├── storage/objects/
│   └── venv/
└── backups/
~~~

核心脚本：

~~~text
scripts/package_release.sh
scripts/deploy-treehole.sh
scripts/rollback.sh
deploy/tencent/xdu-whisperbox.service
~~~

发布方式是“本地构建打包 → SFTP 上传 → 服务器原子切换 release → systemd 重启 → 健康检查”，不要在生产目录直接 git pull，也不要在服务器临时构建前端。

## 5. 远程更新完整流程

### 5.1 本地构建与打包

在 Git Bash 执行：

~~~bash
cd /c/Users/24045/Desktop/电台
FLUTTER_BIN=/c/src/flutter/bin/flutter.bat \
  bash scripts/package_release.sh
~~~

输出：

~~~text
dist/treehole-<VERSION>.tar.gz
dist/treehole-<VERSION>.tar.gz.sha256
~~~

脚本会构建 Flutter Web、复制后端与部署文件、生成 RELEASE-MANIFEST.sha256、检查敏感文件并生成 SHA-256 sidecar。默认要求工作区干净；紧急未提交改动才使用：

~~~bash
ALLOW_DIRTY_RELEASE=1 \
FLUTTER_BIN=/c/src/flutter/bin/flutter.bat \
  bash scripts/package_release.sh
~~~

### 5.2 上传到服务器

使用学校批准的 SFTP、堡垒机或服务器控制台入口。校内可尝试直连内网地址；若 SSH 端口探测被拒绝，改用信息中心指定入口。

~~~bash
sftp -P <SSH_PORT> <SSH_USER>@10.255.73.81
put dist/treehole-<VERSION>.tar.gz /home/ubuntu/treehole/incoming/
put dist/treehole-<VERSION>.tar.gz.sha256 /home/ubuntu/treehole/incoming/
bye
~~~

### 5.3 服务器发布

~~~bash
sudo /usr/local/sbin/deploy-treehole \
  /home/ubuntu/treehole/incoming/treehole-<VERSION>.tar.gz
~~~

脚本会检查压缩包路径安全性、sidecar 校验和、发布 manifest、web/index.html、Nginx 可读性，然后：

1. 解压到 releases 临时目录；
2. 原子切换 current 软链接；
3. 重启 systemd 服务；
4. 检查进程工作目录和 /api 健康响应；
5. 失败时自动切回旧 release。

### 5.4 发布后检查

~~~bash
sudo systemctl status treehole --no-pager -l
sudo systemctl is-active treehole
curl -fsS http://127.0.0.1:8080/api/health
curl -fsS http://127.0.0.1:8080/api/version
curl -fsS https://zhixing.xidian.edu.cn/api/health
curl -fsS https://zhixing.xidian.edu.cn/api/version
curl -I https://zhixing.xidian.edu.cn/
~~~

重点确认：服务 active、版本号为本次版本、健康状态 healthy、前端首页 200、IDS 回调地址仍为固定生产域名。

### 5.5 手动回滚

~~~bash
sudo DEPLOY_DIR=/home/ubuntu/treehole \
  SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh --list

sudo AUTO_CONFIRM=1 \
  DEPLOY_DIR=/home/ubuntu/treehole \
  SERVICE_NAME=treehole \
  bash /home/ubuntu/treehole/current/scripts/rollback.sh
~~~

回滚只切换代码 release，不替换 shared/data、shared/storage、shared/config。数据库 schema 变化必须先备份 SQLite 和对象存储，再执行迁移；当前发布脚本不使用 Prisma。

## 6. 生产配置

真实配置文件：

~~~text
/home/ubuntu/treehole/shared/config/backend.env
~~~

关键项：

~~~text
BACKEND_ENV=production
BACKEND_HOST=127.0.0.1
BACKEND_PORT=8080
BACKEND_CORS_ALLOWED_ORIGINS=https://zhixing.xidian.edu.cn
BACKEND_ENABLE_XIDIAN_AUTH=true
BACKEND_XIDIAN_PUBLIC_ORIGIN=https://zhixing.xidian.edu.cn
BACKEND_DB_FILE=/home/ubuntu/treehole/shared/data/treehole.db
BACKEND_STORAGE_DIR=/home/ubuntu/treehole/shared/storage/objects
BACKEND_WEB_ROOT=/home/ubuntu/treehole/current/web
BACKEND_SEED_DEMO_DATA=false
BACKEND_ALLOW_DEBUG_VERIFY_CODE=false
BACKEND_INCLUDE_DEBUG_CODE=false
~~~

权限：

~~~bash
sudo chown root:treehole /home/ubuntu/treehole/shared/config/backend.env
sudo chmod 0640 /home/ubuntu/treehole/shared/config/backend.env
~~~

不要把 backend.env、数据库、上游密码、IDS ticket、校园网密码、短信验证码、服务器密码提交到 Git 或发布包。此前在聊天中暴露过的服务器密码应立即轮换。

## 7. 新技术栈迁移时的最小保留项

1. 保持上述本站 API 路径、鉴权语义、成功/错误包络和关键字段。
2. 把 IDS、校园网、水机封装成独立 server-side adapter；前端只调用本站 API。
3. 课表等信息中心业务取得正式授权和协议后再接入，未取得协议的服务显示“待接入”，不伪造数据。
4. 将 SQLite 数据迁移到新数据库时先定义用户、帖子、评论、互动、消息、通知、审核、校园服务和校园数据源的表结构，再做一次性迁移与回滚备份。
5. 新部署系统继续采用可校验的 release 包、原子切换、健康检查和可回滚目录结构。
