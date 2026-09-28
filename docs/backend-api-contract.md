# 西电知行 (SeeRadio / treehole) backend: HTTP API contract

Source: `backend/server.py` dispatch + `backend/handlers/*.py` + `backend/services/*.py`, as of 2026-09-27.
The Flutter client (`flutter_app/lib/repositories`, `core/network/api_endpoints.dart`) cross-checks this.
All field names below are copied from the serializers. Anything not verified in code is marked **UNVERIFIED**.

---

## 0. Conventions

### Transport
- **Base path**: `/api` on the same origin (prod `https://zhixing.xidian.edu.cn/api`). Flutter uses `API_BASE_URL=/api`, and every endpoint path is relative to that.
- Plain `http.server`, JSON only (the one exception is the multipart admin APK upload). Request bodies must be JSON **objects**. A non-object or invalid body gets `400 {"message":"请求体不是有效的 JSON" | "JSON 请求体必须是对象"}`. The default body limit is 20 MB (`BACKEND_MAX_REQUEST_BODY_MB`), and going over it gets 413.
- **Origin check**: any POST/PATCH/DELETE under `/api` that carries an `Origin` header not listed in `CORS_ALLOWED_ORIGINS` gets `403 {"message":"Origin not allowed"}`. Same-origin requests and requests with no Origin pass. A Next dev server on another port must be added to the allow-list, or you must proxy.
- CORS allows headers `Content-Type, Authorization, X-Client-Type, X-Request-ID` and exposes `X-Request-ID`. The server echoes `X-Request-ID`, or generates one.
- When `ENABLE_XIDIAN_AUTH` is off, every `/api/auth/xidian/*` path returns `503 {"message":"学校统一身份认证尚未启用"}`.

### Auth
- Send `Authorization: Bearer <token>` on every call. The token is opaque (`secrets.token_urlsafe(24)`, about 32 chars) and is looked up in the `sessions` table. It **expires after 30 days** server-side (`SESSION_MAX_AGE_DAYS`). The server **never reads cookies for API auth**.
- **Session floor** (`_require_api_session`): every `/api/*` path needs a live session and returns `401 {"message":"请先登录"}` otherwise. These paths are exempt:
  - `/api/health`, `/api/version`
  - `/api/auth/xidian/session`, `/api/auth/xidian/session/<id>`, `/api/auth/xidian/start`, `/api/auth/xidian/callback`
  - `/api/auth/logout`, `/api/auth/check`, `DELETE /api/auth/web-session`
  - `/api/releases/android/latest`
  - `/api/storage/*` (capability URLs)
  - `/api/admin/*` (these use a separate admin session)
  - `/api/appeals` (this one verifies credentials itself)
  - `/api/ai/chat`, `/api/ai/chat/cancel`, `/api/ai/post-selection`, `/api/ai/models`: these run outside the floor, but each handler checks auth itself.
- Individual handlers still return `401 {"message":"Unauthorized"}` when the user is missing. Treat **any 401** as "session dead": clear the token and go to login.
- **Banned accounts** (`user.banned`) still hold a valid session. Almost every endpoint returns
  `403 {"message":"账号已被封禁，仅可提交解封申诉","data":{"accountState":"banned"}}`.
  A banned session may reach only: `POST /api/auth/logout`, `POST|DELETE /api/auth/web-session`, `GET /api/users/me` (read-only; PATCH is refused), `POST /api/appeals`, `GET /api/appeals/mine`.
  Flutter routes to the ban/appeal screen when it sees `status==403 && data.accountState=="banned"`.
- **Muted** (`user.muted`) is not a session state. Only create-post, create-comment, direct-conversation and send-message return a 403 carrying a plain message.
- A deleted/cancelled user gets 401 from the floor.

### Envelopes
- **Success**: `{"data": <payload>}`. Some endpoints also include a top-level `"message"` string alongside `data`: pin-request, send-message, level-upgrade-request, logout. Read `data`; `message` is display text only.
- **Error**: `{"message": "<Chinese text>", "data"?: {...}}`. `data` appears only in these cases:
  - banned: `{"accountState":"banned"}`
  - 429 rate limit: `{"retryAfterSeconds": int}`, with message `"<动作>过于频繁，请在 N 秒后重试"`
  - post sensitive-word block (400): `{"code":"POST_CONTENT_REJECTED","categories":[str]}`
  - DM first-message lock (403): `{"awaitingReply": true}`
  - AI cancelled (409): `{"cancelled": true}`
- There are no machine error codes apart from the ones above. Branch on HTTP status and show `message` to the user.
- Status codes seen: 200 for most success responses. **201** from these: new direct conversation, pending pin-request, level-upgrade-request, club application, section create. **204** with an empty body from these: web-session create/delete, `/api/auth/check`. Error codes seen: 400, 401, 403, 404, 405, 409, 413, 429, 502, 503.

### Pagination
- **Only `GET /api/posts` paginates**, and only when `page` or `limit` is present in the query. It then returns `data = {items:[Post], page:int, limit:int, total:int, hasMore:bool}`. `page` is 1-based. `limit` defaults to 20 and is clamped to 100.
- Without `page`/`limit` it returns a **bare array** `data = [Post]`. So does every other list endpoint, which all return the full list unpaginated.
- `build_pagination_meta` (`total/page/perPage/totalPages`) exists, but only admin code uses it.

### IDs
All IDs are strings of the form `prefix + sequential integer`. Never parse them as numbers.

| entity | format | entity | format |
|---|---|---|---|
| user | `u12` (seed users: `seed-user-1`) | post | `p123` |
| comment | `cm45` | upload/image | `up9` |
| conversation (per-viewer row) | `c7` | direct message | `m88` |
| notification | `n301` | report | `r4` |
| appeal | `ap2` | feedback | `fb3` |
| pin request | `pin1` | cancellation request | `cr1` |
| level request | `lr1` | section | none exposed: a section is named by its `sectionId`, a slug such as `general`, `cs`, or a club app id |
| club | `club1` | club application | `ca1` |
| moderation task | `mt1` | hot topic | `hot-YYYY-MM-DD-p123` |
| IDS attempt | url-safe random (about 32 chars) | | |

- A conversation id is **per viewer**: each side of a DM has its own `c…` row. Messages are keyed internally by the pair (`conversationKey`), which is never exposed.

### Timestamps
- `createdAt`/`updatedAt`/`readAt`/… are ISO-8601 in UTC **with microseconds and offset**, e.g. `2026-09-27T08:15:30.123456+00:00` (`datetime.now(timezone.utc).isoformat()`). An empty string `""` means unset; the value is never null.
- `timeText` is **pre-formatted China time** `"YYYY-MM-DD HH:MM"` (UTC+8), or `"-"` when empty. Conversation lists and `/comments/mine` give **only** `timeText`, with no ISO field.

### Images and uploads
1. `POST /api/uploads/images` with body `{dataBase64|imageDataBase64: string, fileName?: string, contentType?: string, postId?: string}`.
   - base64 may be raw, or a `data:image/png;base64,...` URI (the prefix is stripped).
   - Allowed formats are jpg/png/webp/gif, detected by magic bytes. If you declare `contentType`, it must match the real format or you get 400.
   - The size limit is `imageMaxMB` (default 5 MB).
   - Rate-limited (`upload`).
   - Response: `data = {id:"up9", url:"/api/storage/ab12/<32hex>.png", status:"approved"|"risk"|"rejected", moderationReason:string}`.
2. Attach images to a post by sending `imageUploadIds: ["up9", …]` (alias `imageIds`, max 9) in `POST /api/posts`. Each upload must belong to the caller and must not already be bound to another post. Uploads can also be bound to an existing own post by passing `postId` during upload.
3. For a profile background, upload through the same endpoint, then `PATCH /api/users/me {backgroundImageUrl: url}`. The upload must be yours, not bound to a post, and have `status=="approved"`.
4. For an avatar, use the dedicated `POST /api/users/avatar` (see Users). You cannot set `avatarUrl` via PATCH.
- **URLs are relative** (`/api/storage/<4hex>/<32hex>.<ext>`). `GET /api/storage/<key>` needs no auth; the key is a capability URL. It returns 404 if the object is unapproved, deleted, or belongs to a pending/private post that is not yours.
- Add `?w=<px>` to get a resized WebP, snapped to one of `320, 640, 960, 1280, 1920`.
- A post's `imageUrls` only includes uploads whose status is `approved` (or empty). The exception is the author's own view in `/posts/mine` and in the create response.

---

## 1. Auth

### IDS (西电统一身份认证 CAS) flow for web
1. `POST /api/auth/xidian/session` with body `{platform:"web"|"mobile", nextPath?: "/local/path"}`. No auth needed; it is rate-limited per IP.
   - Response: `data = {attemptId, status:"pending", platform, authorizeUrl}`, where `authorizeUrl` is `<BACKEND_XIDIAN_PUBLIC_ORIGIN>/api/auth/xidian/start?attempt=<attemptId>`.
   - `nextPath` is sanitized: it must start with a single `/`, otherwise it becomes `/`.
2. Navigate the browser top-level (Flutter uses `_self`) to `authorizeUrl`.
   - `GET /api/auth/xidian/start?attempt=<id>` returns 302 to `https://ids.xidian.edu.cn/authserver/login?service=<origin>/api/auth/xidian/callback` (`IDS_LOGIN_URL` in `helpers/_xidian_auth.py`).
   - It also sets the cookie `xdu_whisper_xidian_attempt=<id>` (HttpOnly, SameSite=Lax, Path=/, Secure on https, Max-Age 600).
   - Returns 404 JSON if the attempt is unknown or expired.
3. The user logs in at IDS. IDS redirects to `GET /api/auth/xidian/callback?ticket=…`. The server reads the attempt from the cookie, validates the ticket, upserts the user (new users get nickname `西电同学<last4 of studentId>`), and creates a session token.
   - **web**: 302 to `<nextPath>?xidianAuthAttempt=<attemptId>` (a relative Location that keeps the other query params) and clears the cookie. This happens on success **and** on failure.
   - **mobile**: returns an HTML page saying "登录成功", and the app polls instead.
   - Error pages are HTML (409/410) when the cookie or attempt is missing.
   - The student-id allow-list (private beta) marks the attempt failed with "当前仅向项目组测试账号开放".
4. The SPA reads `xidianAuthAttempt` from the URL, then calls `GET /api/auth/xidian/session/<attemptId>` (no auth, `Cache-Control: no-store`).
   - Response: `data = {attemptId, status:"pending"|"authenticated"|"failed", platform, message?, token?, verified?:true, email?, studentId?, banned?:bool}`.
   - **The token is delivered exactly once.** A second poll after `authenticated` returns `status:"authenticated"` with no token and `message:"登录结果已使用，请重新发起登录"`. Flutter treats that as an error.
   - The internal state `validating` is reported as `pending`.
   - After delivery the attempt is kept for 30 seconds, then returns 404 "登录请求不存在或已过期".
   - Mobile polls this every 2 seconds.
5. Store `token`. If `banned:true`, route straight to the appeal page.
6. (Static web only) `POST /api/auth/web-session` with the Bearer header returns 204 and sets `zx_session=<token>` (HttpOnly, Lax, 30 days). Nginx `auth_request` calls `GET /api/auth/check`, which reads that cookie and returns 204 or 401 with no body. Banned users pass this check. The cookie grants no API access.

There is no email/password login route. `handle_register`, `handle_verify`, `handle_send_code` and `handle_password_*` exist in `_auth_handler.py` but are **not dispatched**.

### Logout
- `POST /api/auth/logout` (session-exempt, works with a dead token) deletes the session. Response: `{"message":"已退出登录","data":{"ok":true}}`.
- Also call `DELETE /api/auth/web-session` (204) to clear the page-gate cookie.

### `GET /api/users/me` → `data: Me`
| field | type | notes |
|---|---|---|
| id | str | `u12` |
| alias, nickname | str | same value |
| studentId, email | str | email is campus mail |
| avatarUrl, backgroundImageUrl | str | relative `/api/storage/...` or `""` |
| bio, gender (`""`/`男`/`女`), major | str | |
| college | str | read-only: the name of the college section the identity mapping (`BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS`) assigns this student, `""` if none |
| verified | bool | |
| verifiedAt | str | |
| banned, muted, deleted | bool | |
| allowStrangerDm, showContactable | bool | privacy |
| notifyComment, notifyReply, notifyLike, notifyFavorite, notifyRepost, notifyMention, notifyReportResult, notifySystem | bool | default true |
| favoriteCount, postCount, followingCount, followerCount | int | postCount includes pending/rejected own posts |
| userLevel | int | 1 or 2 (2 = normal) |
| userLevelLabel | str | `一级用户`/`二级用户` |
| isLevelOneUser | bool | |
| levelUpgradeRequest | obj\|null | LevelRequest (§2) |
| accountCancellationRequest | obj\|null | CancellationRequest (§2) |
| createdAt | str | |

### `PATCH /api/users/me`
- Body: any of `nickname`, `bio` (≤100), `gender` (`""|男|女`), `major` (whitespace stripped, ≤80), `backgroundImageUrl`, `avatarUrl`.
  - `college` cannot be set: sending anything but the current verified value is 400 "学院由学校统一身份认证确定，不能自行修改" (echoing it back is ignored).
  - `avatarUrl` must equal the current value, otherwise you get 400 "请通过头像上传接口更换头像".
  - At least one key is required, otherwise 400.
- Response: `data = {ok:true, nickname, bio, gender, college, major, backgroundImageUrl}`.
- `DELETE /api/users/me` returns 405 "请改用注销申请接口".

---

## 2. Users and social

| method, path | body/query | `data` |
|---|---|---|
| GET `/api/users/<id>` | – | PublicProfile. 404 if missing or deleted |
| GET `/api/users/search?keyword=` | nickname substring, case-insensitive | `[PublicProfile]`, max 50, ranked exact > prefix > contains, then by follower count. Empty keyword gives `[]` |
| POST `/api/users/<id>/follow` | – | `{userId, following:true}`. If already following: `{followed:true, already:true}` (different shape) |
| POST `/api/users/<id>/unfollow` | – | `{userId, following:false}` (idempotent) |
| GET `/api/users/me/following` | – | `[FollowUser]`, newest first |
| GET `/api/users/me/followers` | – | `[FollowUser]`, newest first |
| GET `/api/users/me/friends` | – | `[FollowUser]` (mutual follows), sorted by nickname |
| GET `/api/users/me/blocks` | – | `[BlockedUser]`, newest first |
| POST `/api/users/me/blocks` | `{targetUserId}` (alias `userId`) | `{blocked:true}` (idempotent) |
| DELETE `/api/users/me/blocks/<userId>` | – | `{blocked:false}` |
| PATCH `/api/users/privacy` | `{allowStrangerDm?:bool, showContactable?:bool}` | `{ok:true}` |
| PATCH or POST `/api/users/notification-preferences` (alias `/api/users/me/notification-preferences`) | any of `notifyComment, notifyReply, notifyLike, notifyFavorite, notifyRepost, notifyMention, notifyReportResult, notifySystem` (bool) | `{ok:true}` |
| POST `/api/users/avatar` | `{avatarDataBase64\|dataBase64, fileName?, avatarContentType\|contentType?}` | `{avatarUrl}` (auto-approved; the old avatar is deleted) |
| POST `/api/users/me/cancellation-request` | `{reason?}` (default "用户主动申请注销") | CancellationRequest. 409 if one is already pending |
| POST `/api/users/me/level-upgrade-request` | `{reason?}` | **201** `{message, data: LevelRequest}`. 409 if already level 1 or a request is pending |

Object shapes:
- **PublicProfile**: `id, alias, nickname, avatarUrl, verified:bool, verifiedAt, userLevel:int, userLevelLabel, isLevelOneUser:bool, favoriteCount:0 (always 0), postCount:int (public, approved, non-anonymous only), followingCount, followerCount, isFollowing, isFollower, isOwnProfile, canFollow, isBlockedByMe:bool, bio, gender, college, major, backgroundImageUrl, canDirectMessage:bool`. `studentId` and `email` are never exposed.
- **FollowUser**: `userId, nickname, avatarUrl, isFollowing:bool, isFollower:bool`. The key is `userId`, not `id`.
- **BlockedUser**: `id (the blocked user's id), nickname ("已注销用户" if gone), avatarUrl, bio, blockedAt, timeText`.
- **CancellationRequest**: `id, userId, userEmail, userNickname, studentId, avatarUrl, reason, status (pending|approved|rejected), statusLabel, reviewNote, createdAt, handledAt, handledBy`.
- **LevelRequest**: `id, currentLevel:int, currentLevelLabel, targetLevel:int, targetLevelLabel, reason, status, statusLabel, adminNote, createdAt, handledAt, handledBy`.

Blocking semantics (屏蔽):
- Blocked users' posts (including anonymous ones), comments and notifications disappear for the blocker, and their past notifications are hidden too.
- Blocking in either direction prevents DMs.
- `/users/me/blocks` and the conversation `/block` endpoint write the same table.

There are no user-specific post-list endpoints. Use `GET /api/posts?authorId=<id>`.

---

## 3. Posts

### Post object (`serialize_post`)
| field | type | notes |
|---|---|---|
| id | str | `p123` |
| title | str | ≤200 |
| content | str | plain text. For markdown posts this is the plain-text rendering |
| contentFormat | `"plain"\|"markdown"` | |
| markdownSource | str | raw markdown or `""` |
| tags | str[] | also parsed from `#tag` in title/content |
| authorAlias | str | nickname, or anonymous alias |
| isAnonymous | bool | |
| authorAvatarUrl | str | `""` if anonymous |
| authorUserId | str | **`""` unless the viewer may see the profile** (not anonymous, not private) |
| createdAt, updatedAt | str | ISO |
| hasImage | bool | |
| imageUrls | str[] | relative storage URLs |
| uploadedImageIds | str[] | |
| commentCount, likeCount, favoriteCount, viewCount, shareCount | int | |
| sectionType | `"general"\|"college"\|"club"` | |
| sectionId, sectionName | str | |
| publisherType | `"user"\|"club"` | |
| publisherClubId | str | |
| **liked, favorited** | bool | viewer flags. **Not** `isLiked`/`isFavorited` |
| status | `"none"\|"ongoing"\|"resolved"\|"closed"` | author-set 状态; `none` = no badge. Only the author changes it, in any direction; nothing changes it automatically and it does not lock comments |
| reviewStatus | `"approved"\|"pending"\|"rejected"\|"resolved"` | non-approved values are only visible to the author |
| allowComment | bool | |
| allowDm | bool | effective value: false if anonymous, private, the author disabled it, or the author set `allowStrangerDm=false` |
| visibility | `"public"\|"private"` | |
| isPrivate | bool | |
| isPinned | bool | pin currently active |
| pinStartedAt, pinExpiresAt | str | |
| pinDurationMinutes | int | |
| pinDurationLabel | str | |
| canViewAuthorProfile, canFollowAuthor, isFollowingAuthor, canMessageAuthor, isOwnPost | bool | viewer capabilities |

### Endpoints
**GET `/api/posts`** (feed and search)
- Query params:
  - `sort`: `latest` (default), `hot`, `likes`, or `oldest`. Active pinned posts always come first, ordered by pinStartedAt.
  - `page`, `limit`: optional; turn on pagination (§0).
  - `keyword`: lowercased substring match on title, content and tags.
  - `sectionType`: `general|college|club`.
  - `sectionId`: e.g. `general` or a college/club sectionId. Legacy posts count as `general`.
  - `tag`: posts carrying this tag.
  - `authorId`: anonymous posts are excluded unless it is your own id.
  - `hasImage`, `allowDm`: `true|false`.
  - `status`: `none|ongoing|resolved|closed`.
- There is **no following-only feed**. The old `channel` param is gone (it is ignored).
- Excludes deleted posts, non-approved posts (even your own), other people's private posts, and posts by users you block.
- Response `data`: `[Post]`, or `{items,page,limit,total,hasMore}` when paginated.

**Other GET endpoints**
- `GET /api/posts/<id>` returns `Post`. It returns 404 "帖子不存在或已被删除" if the post is deleted, pending/rejected and not yours, or private and not yours.
- `GET /api/posts/mine` returns `[Post]`: all your own posts including pending/rejected and private, with unapproved images included. Newest first, no pagination.
- `GET /api/posts/favorites` returns `[Post]` (your favorites that are still visible).
- `GET /api/posts/anonymous-alias` returns `{alias:str}`, a random alias such as "<形容词><名词>". Use it to pre-fill the anonymous name.

**POST `/api/posts`** (create) returns `Post` (including unapproved images). Body:
| field | type | notes |
|---|---|---|
| content | str | **required** (raw). Plain ≤10,000 |
| title | str | ≤200. The Flutter client makes it optional |
| contentFormat | `"plain"\|"markdown"` | |
| markdownSource | str | ≤20,000. Markdown images must point to `/api/storage/...` |
| tags | str[] | ≤10 tags, each ≤40 chars |
| sectionType | `general\|college\|club` | |
| sectionId, sectionName | str | `college` needs your IDS-verified college (403 otherwise). `club` needs publisherType=club and owner/manager membership of that club |
| publisherType | `"user"\|"club"` | |
| publisherClubId | str | alias `clubId` |
| imageUploadIds | str[] | alias `imageIds`, max 9 |
| useAnonymousAlias | bool | |
| anonymousAlias | str | used when anonymous. Default "匿名同学" |
| allowComment | bool | default true |
| allowDm | bool | default `!useAnonymousAlias` |
| visibility | `"public"\|"private"` | |
| status | `none\|ongoing\|resolved\|closed` | optional, default `none`; `open` = `ongoing`; anything else is 400 |
| pinDurationMinutes | int | one of 30, 60, 120, 180, 1440, 4320. **Level-1 users only** (403 otherwise) |
| hasImage | bool | sent by Flutter, **ignored** by the server |

- Sensitive text returns 400 with `data.code=POST_CONTENT_REJECTED`.
- Soft-risk text is stored with `reviewStatus:"pending"`: only the author sees it, and it shows as 待审核.
- Rate-limited (`post`).

**Mutations**
- `PATCH /api/posts/<id>` (author only) accepts `{status: "none"|"ongoing"|"open"|"resolved"|"closed"}` (`open` is stored as `ongoing`, `""` as `none`) and returns `Post`; text and image edits: see §14.
- `DELETE /api/posts/<id>` (author only) returns `{ok:true}`. Its images are deleted as well.
- `POST /api/posts/<id>/like` with `{liked: bool}` returns `{liked, likeCount}`.
  - **There is no DELETE for post likes.** Unlike with `{liked:false}`.
  - Omitting the body toggles (legacy behaviour).
- `POST /api/posts/<id>/favorite` with `{favorited: bool}` (omit to toggle) returns `{favorited, likeCount, favoriteCount}`.
- `DELETE /api/posts/<id>/favorite` returns `{ok:true, favorited:false, likeCount, favoriteCount}`.
- `POST /api/posts/<id>/view` (no body) returns `{ok:true, viewCount}`.
  - Rate-limited on both a burst limit and an hourly limit.
  - **Repeatedly exceeding the hourly limit force-logs-out ALL of the user's sessions** (401 "浏览行为异常…"). Call it once per detail open, not per render.
  - It does not count views on your own pending post.
- `POST /api/posts/<id>/pin-request` (author only) with `{durationMinutes: 30|60|120|180|1440|4320 (default 1440), reason?}`:
  - Level-1 user: 200 `{message:"帖子已置顶", data:{mode:"direct", post: Post}}`.
  - Otherwise: **201** `{message, data:{mode:"pending", request: PinRequest}}`, where PinRequest is `id, postId, postTitle, userId, userNickname, userLevel, userLevelLabel, durationMinutes, durationLabel, postDeleted, postPinned, reason, status, statusLabel, adminNote, createdAt, handledAt, handledBy`.
  - 400 if already pinned. 409 if a pending request exists.
- Like, favorite and comment-like count as `interaction` for rate limiting.

---

## 4. Comments

### Comment object (`_post_handler._serialize_comment`)
`id ("cm45"), postId, content, authorAlias, authorId, authorUserId (both "" if anonymous), authorAvatarUrl, authorAvatar (duplicate), isOwnComment:bool, isPostAuthor:bool (洞主 flag), likeCount:int, liked:bool, createdAt, isAnonymous:bool, reviewStatus:str, parentId:str ("" = top level)`.

- A comment is anonymous only when its author is the author of an anonymous post. That comment then takes the post's `authorAlias`. Ordinary commenters always appear under their nickname.
- **Nesting**: the list is **flat**. The client threads it using `parentId`, which points at the directly replied-to comment, at any depth. There is no `replyTo` user field; derive it from the parent comment's `authorAlias`.

### Endpoints
- `GET /api/posts/<postId>/comments?sort=latest|hot` returns `[Comment]`.
  - Not paginated.
  - `latest` is **newest first** (createdAt desc). `hot` sorts by likeCount desc, then createdAt desc (`top` also means hot).
  - Includes your own pending comments. Excludes deleted comments and those by users you block.
  - 404 if the post is not viewable.
- `POST /api/posts/<postId>/comments` with `{content: str (≤2000), parentId?: str}` (alias `replyToId`) returns `Comment`.
  - 400 if comments are closed (`allowComment=false`), or the parent is missing, on another post, or not yet approved.
  - Muted users get 403. Rate-limited (`comment`).
  - Sends a `reply` notification to the parent's author and a `comment` notification to the post author.
- `DELETE /api/comments/<id>` (own comment only) returns `{ok:true}`. This is a soft delete, and child replies are **not** removed.
- `POST /api/comments/<id>/like` with `{liked: bool}` (omit to toggle) returns `{liked}`. There is no count in the response; update it optimistically.
- `DELETE /api/comments/<id>/like` returns `{liked:false}` (always unlikes).
- `GET /api/comments/mine` returns `[{id, commentId (same), postId, postTitle ("原帖" if the post is gone), content, timeText}]`. There is no ISO timestamp, and the list is sorted by the timeText string.

---

## 5. Notifications

### Notification object
`id ("n301"), type, title, content, relatedType ("post"|"comment"|""), relatedId, postId, actorId ("" when anonymous or system), actorAlias, actorAvatarUrl, createdAt, readAt, isRead:bool`.

**Types**
| type | trigger | related |
|---|---|---|
| `comment` | new comment on your post | post |
| `reply` | reply to your comment | comment, with `postId` set |
| `like` | like on your post or comment | post or comment |
| `favorite` | favorite on your post | post |
| `report_result` | your report was handled | |
| `system` | admin actions and announcements | |

- Any unknown type is counted under `system` (e.g. `system_announcement`).
- Like and favorite from the same actor on the same target are **coalesced**: the existing row is updated, its createdAt is bumped, and it becomes unread again.
- Each user keeps at most 500 notifications.
- A notification preference `notifyX=false` suppresses creation.

### Endpoints
- `GET /api/notifications` (no filter params) returns `{items:[Notification], unreadCount:int, unreadByType:{comment,reply,like,favorite,report_result,system: int}}`.
  - `data` is an object, not an array. Newest first.
  - Filter by type on the client.
- `POST /api/notifications/<id>/read` returns `Notification`. `GET /api/notifications/<id>/read` also works.
- `POST /api/notifications/read-all` with `{type?: one of the 6 categories}` returns `{ok:true, marked:int}`. An unknown type gets 400. `GET /api/notifications/read-all` also works (marks all).
- There is no separate unread-count endpoint; use `unreadCount`/`unreadByType` from the list. Message unread counts come from conversations (`unreadCount`).
- UNVERIFIED edge case: read-all checks a stored `isRead` flag, while the serializer derives `isRead` from `readAt`. A coalesced like re-notification clears `readAt` but not the stored flag, so read-all may skip it; per-id read has the same issue. Refetch after read-all.

---

## 6. Direct messages

### Conversation object
`id ("c7", per viewer), peerUserId, name (peer nickname), avatarUrl, lastMessage ("开始聊天吧" if empty; "你撤回了一条消息"/"对方撤回了一条消息" after a recall), timeText (China "YYYY-MM-DD HH:MM", no ISO), unreadCount:int, hasUnread:bool, blockedByMe:bool, blockedByPeer:bool, awaitingReply:bool`.

### DirectMessage object
`id ("m88"), content, createdAt (ISO), timeText, fromMe:bool, senderUserId, senderAlias, readAt, isRead:bool, deliveryStatus ("sent"|"read"|"recalled"), canRecall:bool (own message and ≤120 s old), recalled:bool, replyToId|null, replyToSender|null, replyToContent|null ("该消息已撤回" if the quoted message was recalled)`.
- A recalled message stays in the list as a placeholder with `content:""`, `recalled:true`, and null reply fields.

### Endpoints
- `GET /api/messages/conversations` returns `[Conversation]`, sorted by updatedAt desc and excluding conversations you deleted.
- `POST /api/messages/conversations/direct` with `{targetUserId, postId?|fromPostId?}` returns a `Conversation`.
  - Returns 200 if the conversation exists (it is un-deleted). Returns **201** when a new one is created (for both sides).
  - Errors:
    - 403 if either side blocked the other.
    - 403 "对方未开放陌生人联系入口" if the target has `showContactable=false` or `allowStrangerDm=false`.
    - When started from a post: 403 "该帖子未开放私信" if the post does not allow DMs, and 400 if it is anonymous.
    - 400 if you target yourself. Muted users get 403.
  - **There is no message-request inbox.** The first message goes straight to the peer.
- `GET /api/messages/conversations/<cid>/messages` returns `[DirectMessage]`, oldest first, the whole history (no paging). It **marks the conversation read** as a side effect. Blocked users can still read the history.
- `POST /api/messages/conversations/<cid>/messages` with `{content: str (≤1000), replyToId?}` returns `{message:"发送成功", data: DirectMessage}`.
  - 403 if blocked either way.
  - 403 "对方已关闭私信，消息未发送" if the peer has `allowStrangerDm=false`, **even in an existing chat**.
  - Rate-limited (`message`). High-risk text gets 400.
- **First-message rule**: while you have a non-recalled message out and the peer has never written in this conversation, sending again returns `403 {"message":"对方回复前只能发送一条消息","data":{"awaitingReply":true}}`.
  - The same state shows up as `awaitingReply:true` on the Conversation object; use it to lock the composer.
  - Recalling your only message frees the slot.
  - Once the peer has written, the conversation stays open, even if the peer later recalls.
- `DELETE /api/messages/messages/<mid>/recall?conversationId=<cid>` returns `{ok:true}`.
  - **The query param is required** (400 otherwise). Only the sender can recall, within 120 s (400 after that).
  - The route is `/messages/messages/…`, not `/messages/conversations/…`.
- `DELETE /api/messages/conversations/<cid>` returns `{ok:true}`. It hides the conversation for you only, and it reappears on the next message.
- `POST /api/messages/conversations/<cid>/block` returns `{blocked:true}`, and `/unblock` returns `{blocked:false}`. These are the same as the global block.

---

## 7. Reports, appeals, feedback

- `POST /api/reports` with `{targetType: "post"|"comment"|"user", targetId, reason, description?}` returns `{ok:true, id:"r4"}`.
  - `reason` **must be one of**: `广告引流 人身攻击 违规内容 垃圾信息 其他 垃圾广告 违法违规 色情低俗 虚假信息 侵犯隐私` (400 otherwise).
  - You cannot report yourself. Rate-limited.
- `GET /api/reports/mine` returns `[{id, target ("post: p1"), targetType, targetId, targetTitle, reason, status (pending|…), description, result, createdAt, handledAt}]`.
- `GET /api/reports/<id>` (own only; 403 otherwise) returns `{id, targetType, targetId, targetTitle, reason, description, status, result, createdAt, handledAt}`.
- `GET /api/appeals/mine` (banned users allowed) returns `{appeal: null | {id, appealType, title, content, status, adminNote, createdAt, handledAt}, banned:bool, canSubmit:bool, supportEmail:str}`.
  - Show the form only when `canSubmit` is true. Each ban gets one in-app appeal; after it is rejected, direct the user to `supportEmail`.
- `POST /api/appeals` (session-exempt; banned users allowed) with `{email (must be @stu.xidian.edu.cn and match the account), appealType, content (≤4000), password?}` returns `{ok:true, id:"ap2"}`.
  - `appealType` is one of `account_restore`, `ban_revoke`, `wrong_punishment`, `account_cancel_reject`.
  - Authentication is either the Bearer session of that same account or a password. IDS accounts have no password, so they must send the Bearer token.
  - Errors: 403 if signed in as a different user; 401 if the credentials are invalid; 409 if an appeal is pending, the in-app ban appeal is used up, or `account_restore` is sent for a non-deleted account.
  - Flutter sends `{email: <me.email>, appealType:"ban_revoke", content}`.
- `POST /api/feedback` with `{content (required, ≤1000), contact?, category? (free text, default "其他反馈")}` returns `{ok:true, id:"fb3"}`. Rate-limited.
- `GET /api/feedback/mine` returns `[{id, category, content, contact, status ("pending"|…), schoolReply, createdAt, handledAt}]`.

---

## 8. Sections, colleges, tags, clubs, hot topics, announcements

- `GET /api/sections` returns `[Section]`: enabled sections, sorted by sortOrder then name.
  - **Section**: `sectionType (general|college|club), sectionId, sectionName, name, description, ruleText, enabled:bool, sortOrder:int, createdAt, updatedAt`.
  - `sectionId` is a section's only identifier (posts, filters, clubs, the identity mapping and the admin API). It matches `[0-9A-Za-z_-]{1,80}`, is unique and never changes.
- `GET /api/sections/tree` returns `{sections:[Section], general:[…], colleges:[…], clubs:[…]}`. This is what Flutter uses.
- `POST /api/sections` (requires a new valid `sectionId`, 409 if taken) and `PATCH /api/sections/<sectionId>` (400 if the body tries to change `sectionId`) are admin only (admin token).
- `GET /api/colleges` returns `[{sectionId, sectionName, icon}]`: the enabled college sections the identity mapping assigns anyone to, in section order. Nothing is hard-coded; an empty mapping gives `[]`.
- Channels are gone (no `/api/channels`, no `channel` field or param); their names were folded into tags.
- Public tag endpoint: none. Tags are free text on posts; the admin tag list is `GET /api/admin/tags`.
- `GET /api/clubs` returns `[Club + canPublishAs:bool]`. **Club** is `id, name, description, category, ownerUserId, ownerName, sectionId, status, createdAt`.
- `GET /api/clubs/<id>` returns `Club + {memberCount:int, posts:[Post]}`.
- `POST /api/clubs/applications` with `{name (required), description (required), category?, contact?}` returns **201** with the raw application `{id:"ca1", name, description, category, applicantUserId, applicantName, contact, status:"pending", reviewNote, createdAt, handledAt, handledBy, clubId}`. 409 on a duplicate pending application.
- `GET /api/clubs/applications/mine` returns `[application]`.
- `GET /api/hot-topics` returns up to 50 rows of `[{id, date:"YYYY-MM-DD", rank:int (1..n), postId, title, summary, hotScore:float, sectionName, reviewStatus, createdAt}]`.
- `GET /api/ai/hot-topics/summary` returns `{answer:str, citations:[HotTopic ≤8], reviewStatus}`. The answer is a string template, not an LLM call.
- `GET /api/announcements?type=` returns `[Announcement]`. **Announcement** is `id, title, content, summary, aiSummary, publishedAt, createdAt, publisher, sourceName, type, isImportant:bool, originalUrl, createdBy, timeText (= publishedAt ISO, not formatted)`.
- `GET /api/announcements/<id>` returns `Announcement`.
- `GET /api/announcements/filters` returns `{types:[str]}`.
- `GET /api/announcements/daily-summary` returns `{title, summary}`.
- `GET /api/releases/android/latest` (no auth) returns `{versionName, downloadUrl, …}` (full field list UNVERIFIED beyond `versionName, downloadUrl, objectKey, uploadedAt, uploadedBy, uploadedByUsername`). Returns 404 if there is no release.

---

## 9. Campus

- `GET /api/campus/services` returns `[CampusService]` (enabled, sorted by sortOrder). **CampusService** fields:
  `id, slug, name, groupId, groupName, kind ("integration"…), iconKey, authType, authReady:bool (true only when authType=="ids" and the user has a studentId), status (display text e.g. "待接入"), description, requiredAccess, features:[str], dataFields:[str], calendarSource, emptyText, mapIds:[str], actions:[{label, type, url, path, payload}], path (mini-program path), enabled, sortOrder, createdAt, updatedAt`.
- `GET /api/campus/services/<id-or-slug>` returns `CampusService + maps:[CampusMap]`.
- `GET /api/campus/maps` returns `[CampusMap]`, the raw stored rows: `{id, name, type, status, description, officialUrl, items:[{name, category, campus, location, x, y}]}`. Seed shape only; UNVERIFIED for admin-edited rows.
- `GET /api/campus/quick-links` returns `[CampusService]` where groupId is `quick` or `tools`.
- `GET /api/campus/schedules/today` returns `{date:"YYYY-MM-DD" (UTC+8), items:[Schedule + isActive:bool, isEmphasized:bool]}`.
- `GET /api/campus/schedules/calendar?startDate=YYYY-MM-DD&days=7(1..31)&source=all|academic|courseSchedules|examSchedules|experimentSchedules` returns `{startDate, endDate, days:[{date, weekday:"一".."日", isToday:bool, items:[Schedule]}]}`. `startDate` defaults to this Monday.
  - **Schedule** fields: `id, ownerUserId, source (courseSchedules|examSchedules|experimentSchedules), sourceLabel (课表|考试安排|实验安排), title, startTime "HH:MM", endTime, location, date, teacher, section, kind, seatNo, examType, timeRange "HH:MM-HH:MM"`.
- Campus system logins. These are POST, not banned, require a studentId, and are rate-limited (`campus_auth`). They return `{data}` with no-store.
  - `/api/campus/auth/schoolnet/captcha` with `{}` returns `{attemptId, imageBase64, imageContentType, expiresInSeconds}`.
  - `/api/campus/auth/schoolnet/login` with `{attemptId, password, captcha, identifier? (must equal your own studentId)}` returns `{system:"schoolnet", status:"authenticated", studentId, usage:{summary:{used,rest,charged}, onlineDevices:[{ip,location,used}]}, message}`.
  - `/api/campus/auth/dorm-water/captcha` returns `{sessionId, imageBase64, imageContentType}`.
  - `/api/campus/auth/dorm-water/sms` with `{sessionId, phone, imageCode}` returns `{system:"dormWater", status:"smsSent", phone, message}`.
  - `/api/campus/auth/dorm-water/login` with `{sessionId, phone, smsCode}` returns `{system:"dormWater", status:"authenticated", phone, uid, eid, hasToken:bool, message}`.

---

## 10. AI

- `POST /api/ai/chat` with `{content: str (≤12000; alias question), messages?: [{role:"user"|"assistant", content}], requestId?: /[A-Za-z0-9_-]{8,64}/, includePosts?: bool (default true)}` returns `{answer, reply (same), role:"assistant", traceId, citations:[Citation], references (same), relatedActions:[], usage:{sourceCount, knowledgeCount, postCount}, reviewStatus:"approved"}`.
  - **Not streamed to the client.** The response is a single JSON body. The server streams from the provider internally and can take a long time; Flutter uses a 165 s timeout.
  - The server keeps only the last 8 history turns. If the history ends with the current question, that entry is de-duplicated.
  - **Citation**: `{sourceType ("帖子"|"校园知识"), targetType ("post"|"knowledge"), targetId (post id for posts), title, summary, publishedAt, updatedAt, publisher, sourceUrl, jumpUrl, authority, score}`.
  - Errors: 503 if no provider is configured; 502 on upstream failure; 429 when rate-limited (`ai_chat`); banned users get 403 with accountState.
- `POST /api/ai/chat/cancel` with `{requestId}` returns `{cancelled: bool}`. It is idempotent. The pending chat request then fails with `409 {"message":"已停止生成","data":{"cancelled":true}}`, which the client should ignore.
  - Generate `requestId` client-side (Flutter uses 32 hex chars).
- `POST /api/ai/post-selection` with `{selectedText|content (≤11000), question?}` returns the same shape as chat, as a text task with no retrieval. Rate-limited (`ai_search`).
- `GET /api/ai/models` returns `{models:[str], currentModel:str}`. It is a status probe only.
- **No server-side AI conversation history.** There are no list, get or delete conversation endpoints; the client keeps the history locally and sends it in `messages`.

---

## 11. Misc / infra

- `GET /api/health` returns a **bare object with no `data` wrapper**: `{status:"healthy"|"degraded", version, database, smtp, storage, timestamp}`. Returns 503 if the DB is down.
- `GET /api/version` returns `{version, backendVersion, gitHash, buildDate, timestamp}`, also **without a `data` wrapper**.
- `GET /api/uploads/mine` returns `[{id, url, fileName, contentType, sizeBytes, status, createdAt, postId, uploaderId, uploaderAlias}]`. `url` here is not normalized; it is usually `/api/storage/...`.
- Non-`/api` GET paths serve the static web bundle, with SPA fallback to `index.html`.

---

## 12. Admin (paths only)

Admin auth uses `POST /api/admin/auth/login`, which returns an admin token (a separate in-memory session store) used as the Bearer token. Administrator accounts are separate from student accounts: a student token is never accepted on admin endpoints (401), `isAdmin` is no longer sent anywhere, and the `grant_admin` / `revoke_admin` user actions are gone. Clients keep the admin token apart from the student one, so either can be signed in without the other. The session floor does not apply.

- POST `/api/admin/auth/login` · POST `/api/admin/auth/logout` · GET `/api/admin/auth/me` · PATCH `/api/admin/auth/password`
- GET `/api/admin/overview`
- GET `/api/admin/reviews` · POST `/api/admin/reviews/batch` · POST `/api/admin/reviews/(post|comment)/<id>/(approve|reject|delete|risk)`
- GET `/api/admin/reports` · POST `/api/admin/reports/<id>/handle`
- GET `/api/admin/images/reviews` · POST `/api/admin/images/<uploadId>/review`
- GET `/api/admin/users` · POST `/api/admin/users/<id>/action`
- GET `/api/admin/post-pin-requests` · POST `/api/admin/post-pin-requests/<id>/handle`
- GET `/api/admin/user-level-requests` · POST `/api/admin/user-level-requests/<id>/handle`
- GET `/api/admin/admin-accounts` · POST `/api/admin/admin-accounts` · POST `/api/admin/admin-accounts/<id>/action`
- GET `/api/admin/account-cancellation-requests` · POST `/api/admin/account-cancellation-requests/<id>/handle`
- GET `/api/admin/appeals` · POST `/api/admin/appeals/<id>/handle`
- GET `/api/admin/feedbacks` · POST `/api/admin/feedbacks/<id>/handle`
- GET `/api/admin/export`
- GET `/api/admin/tags` · POST `/api/admin/tags` · PATCH `/api/admin/tags/<name>` · DELETE `/api/admin/tags/<name>`
- GET `/api/admin/config` · PATCH `/api/admin/config`
- GET `/api/admin/announcements` · POST `/api/admin/announcements`
- GET `/api/admin/releases/android` · POST `/api/admin/releases/android` (multipart APK, ≤300 MB)
- GET `/api/admin/clubs/applications?status=` · POST `/api/admin/clubs/applications/<id>/handle`
- POST `/api/sections` · PATCH `/api/sections/<sectionId>` · POST `/api/hot-topics/rebuild`
- GET/POST `/api/admin/ai/knowledge-sources` · PATCH/DELETE `/api/admin/ai/knowledge-sources/<id>` · POST `/api/admin/ai/reindex` · GET `/api/admin/ai/traces/<traceId>`

---

## 13. Rate-limit buckets (all 429 + `data.retryAfterSeconds`)

`post, comment, message, report, upload, interaction (like/favorite/comment-like), view + view_hourly (with force-logout escalation), pin_request, feedback, appeal (per email), club_application, auth_login (IDS session create, per IP), campus_auth, dorm_water_sms (per phone, 3), ai_chat, ai_search`. The limits are admin-configurable (`/api/admin/config`), with defaults in `_globals.DEFAULT_SETTINGS`.

---

## 14. Reposts, edits, mentions, activity (added 2026-09-27)

- `POST /api/posts/<id>/repost` `{reposted?: bool}` (omit to toggle) → `{reposted, repostCount}`. 400 for one's own anonymous post (the repost would name the author) and for private posts; 404 if the viewer cannot see the post. Undoing an existing repost always works, even after the post went private or back to review. Notifies the author (`type:"repost"`) once per reposter, rate-limited as `interaction`.
- Post objects gain `repostCount:int`, `reposted:bool`, `mentions:[{userId, nickname}]`, `editedAt:str` (`""` = never edited). Comments gain `mentions` and `editedAt`.
- `GET /api/users/<id>/timeline?page&limit` → `{items, page, limit, total, hasMore}`; each item is a Post plus `repostedBy: {userId, nickname}|null`, `eventKey` (unique per item: one post can appear as written and as reposted) and `eventAt`. Anonymous posts never appear under their author except to the author.
- `PATCH /api/posts/<id>` now also takes `title`, `content`, `markdownSource`, `imageUploadIds` (the full new list; dropped uploads are deleted) and `mentionUserIds`, alone or with `status`. Author only; 403 while muted; rate-limited as `interaction`. Text is moderated again; a risky edit returns the post to `reviewStatus:"pending"`, and a rejected edit changes nothing (not even `status`). A markdown post stays markdown unless `content` replaces its text (it then becomes plain); `markdownSource` edits are checked like on create.
- `PATCH /api/comments/<id>` `{content, mentionUserIds?}` → Comment. Author only, 403 while muted, rate-limited as `interaction`, moderated again.
- Mentions: `POST /api/posts` and `POST /api/posts/<id>/comments` accept `mentionUserIds:[str]` (max 10). A mention counts only if `@<nickname>` is in the text and not followed by another letter or character, the account exists, is not the author, and neither side blocks the other. Each gets one `type:"mention"` notification once others can open the content: the post (and comment) approved and the post not private, so content held for review notifies on approval. Nobody is notified twice for the same post or comment, whatever the edits; anonymous writing (including the post author commenting on their anonymous post) sends no `actorId`.
- `GET /api/users/me/activity?page&limit` → paged `{items}` of the signed-in user's own actions, newest first: `type` ∈ `post | comment | like_post | like_comment | favorite | repost | follow`; post-related items carry `post:{id, title}` (plus `commentId`, `content` for comment ones; other people's comments only while approved and not from a blocked user), `follow` carries `user:{userId, nickname}`.
- Notification categories are now `comment, reply, like, favorite, repost, mention, report_result, system`. `repost` and `mention` have their own switches, `notifyRepost` and `notifyMention` (default true; also accepted by the notification-preferences endpoint).
- Likes and favorites now keep their real `created_at` across saves (they used to be restamped on every rewrite).
