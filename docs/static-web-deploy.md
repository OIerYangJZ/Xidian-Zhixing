# 静态前端首次上线：部署与回滚手册

适用于第一个"静态前端"发布包，也就是 `web/` 是 `web_next/out`、管理后台在 `web/admin/` 的那种包。它和之前的 Flutter Web 包有两个不同：

- **发布包和 Nginx 配置必须一起切换**。只切发布包（Nginx 还是旧的）时，旧配置会把所有路径回退到 `index.html`，结果 `/feed` 等页面全都显示成公开首页。只切 Nginx（发布包还是旧的）时，Flutter 单页应用失去回退，页面会直接 404。
- **回滚也必须两样一起回**。

以后再发静态前端的包，只需要走正常流程（`deploy-treehole`），不用再改 Nginx。

---

## 0. 上传前（本地）

```bash
bash scripts/package_release.sh          # 默认 WEB_FRONTEND=next
~/bin/xd-do <<'EOF'
cd /home/ubuntu/treehole
put dist/treehole-<版本>.tar.gz incoming/
put dist/treehole-<版本>.tar.gz.sha256 incoming/
put deploy/production/nginx-treehole-http.static-web.conf incoming/
ls -l incoming
EOF
```

发布包里本身就有 `deploy/production/nginx-treehole-http.static-web.conf`。另外单独上传一份到 `incoming/`，是为了切换前能先检查它。

## 1. 预检（审计会话里，只读）

```bash
nginx -V 2>&1 | grep -o http_auth_request_module     # 必须输出这一行
ls -l /etc/nginx/sites-enabled/treehole.conf
sudo nginx -T 2>/dev/null | grep -c auth_request     # 期望 0（还是旧配置）
```

`auth_request` 模块不在的话，**先停下来**，不要部署。

## 2. 切换（按顺序执行，中间不要停太久）

```bash
tmux new -s deploy

# 2.1 备份当前 Nginx 配置（回滚时要用）
sudo cp /etc/nginx/sites-enabled/treehole.conf /root/treehole.conf.bak-$(date +%Y%m%d%H%M%S)

# 2.2 部署发布包（后端和前端一起更新）
sudo /usr/local/sbin/deploy-treehole
#     看到 "Deployment successful." 再继续

# 2.3 换 Nginx 配置并检查
sudo install -m 0644 /home/ubuntu/treehole/incoming/nginx-treehole-http.static-web.conf \
     /etc/nginx/sites-enabled/treehole.conf
sudo nginx -t && sudo systemctl reload nginx
```

先部署发布包、再换 Nginx，是因为新配置的登录检查依赖新后端的 `/api/auth/check`。2.2 和 2.3 之间页面会有一两分钟显示异常，这是预期内的。

`nginx -t` 报错时，**不要 reload**，直接走第 4 步只恢复 Nginx 配置；这时后端是新的，但接口向下兼容。

## 3. 验证

```bash
curl -s  http://127.0.0.1/api/health
curl -sI http://127.0.0.1/                   | head -1   # 200 公开首页
curl -sI http://127.0.0.1/login              | head -1   # 200
curl -sI http://127.0.0.1/feed               | grep -iE '^HTTP|^location'   # 302 → /login?next=/feed&
curl -sI http://127.0.0.1/p/p1               | grep -iE '^HTTP|^location'   # 302 → /post?id=p1
curl -sI http://127.0.0.1/admin/             | head -1   # 200 管理后台
curl -sI http://127.0.0.1/_next/static/      | head -1   # 404 即正常（目录不列出）
curl -sI http://127.0.0.1/no-such-page       | head -1   # 404
```

然后用浏览器实测：

1. 统一身份认证登录，回来后进入首页
2. 发一条带图的帖子，评论，点赞
3. 打开 `/admin/`，用管理员账号登录

`current/release-meta/version.json` 用 `xd-do get` 取回来核对版本号。

## 4. 回滚（两样一起回）

```bash
# 4.1 前后端回到上一版
sudo AUTO_CONFIRM=1 DEPLOY_DIR=/home/ubuntu/treehole SERVICE_NAME=treehole \
     bash /home/ubuntu/treehole/current/scripts/rollback.sh

# 4.2 Nginx 回到 2.1 的备份
sudo cp /root/treehole.conf.bak-<时间戳> /etc/nginx/sites-enabled/treehole.conf
sudo nginx -t && sudo systemctl reload nginx
```

## 附：这一版里的临时措施

- `web/main.dart.js` 是一个空的占位文件。`deploy-treehole` 会优先使用**当前线上版本**自带的校验器，而 0.1.0+32 的校验器要求这个文件必须存在。这个包带上了新版校验器，所以等它上线以后，下一版就可以去掉这个占位文件（删掉 `package_release.sh` 里写占位文件的那几行）。
- 管理后台用的是 Flutter 构建（`ADMIN_ONLY=true`，`--base-href /admin/`），和以前是同一套后台，只是入口改成了 `/admin/`。
