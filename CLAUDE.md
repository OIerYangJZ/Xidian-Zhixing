# 部署环境约束

服务器：`/home/ubuntu/treehole`（西电知行小程序）

- 无外网访问
- 只能通过 SFTP 操作，**SSH exec 通道被堡垒机禁用**
- 部署脚本已就位：`/usr/local/sbin/deploy-treehole`，版本控制在 `scripts/deploy-treehole.sh`
  - **`/home/ubuntu/deploy-treehole.sh` 是过时副本，不是真相** —— 比实际执行的那份少了
    Nginx 可读性处理。要读或改部署逻辑，用仓库里那份，或从 `/usr/local/sbin/` 取
- 服务是 systemd `treehole`，跑在 `127.0.0.1:8080`，站点 `zhixing.xidian.edu.cn`

链路：Mac → `vmgw`(Windows VM 172.16.188.134，需 aTrust 连着) → 堡垒机 10.255.53.2:50022 → 服务器 10.255.73.81。
当前部署约束和操作边界以本文件及 `scripts/package_release.sh`、`scripts/deploy-treehole.sh` 为准；仓库不保存真实服务器连接参数。

## 服务器目录布局

```
/home/ubuntu/treehole/
├── backups/    root:treehole  drwxr-x---   ← 我读不了（部署报告和日志在这里）
├── current ->  软链，指向 releases/ 下某一版
├── incoming/   ubuntu:ubuntu  drwxr-x---   ← 唯一 ubuntu 可写，部署包上传到这里
├── releases/   root:root      drwxr-xr-x   （可读不可写，保留最近 8 版）
└── shared/     root:treehole  drwxr-x---   ← 我读不了（`config/backend.env` 在这里）
```

release 内部：`backend/` `web/` `deploy/` `scripts/` `release-meta/version.json`
`RELEASE-MANIFEST.sha256`。

**注意 `shared/` 和 `backups/` 对 ubuntu 是 Permission denied** —— 意味着我读不到
`backend.env`、也读不到 `deployment-check-*.txt` 报告和部署日志。要看这些只能你在
运维会话里 `sudo` 看，或者贴给我。别在这上面反复试，试了也是 denied。

## 前提：常驻会话要先建好

**堡垒机每个认证会话只给一条 SFTP 通道，用完即废。** 所以不能每条命令开一个 `sftp`，
必须复用一个常驻会话 —— 由**人**在真终端里跑 `~/bin/xd-up` 建立（输一次堡垒机密码，
ControlPersist 8h）。它做两件事：`ssh -MNf xd-sftp` 建 master，再把唯一那条 SFTP 通道
挂成一个 FIFO 驱动的常驻 sftp 进程。

判断状态：

    ssh -O check xd-sftp        # 期望 Master running
    ls -l /tmp/xd-sftp/         # 期望有 in(FIFO) / out / sftp.pid

## 可用命令

一律通过 `~/bin/xd-do` 发给常驻会话（`~/bin` 不在 PATH 里，用全路径）：

    ~/bin/xd-do 'ls -l /home/ubuntu/treehole'
    ~/bin/xd-do 'get /home/ubuntu/treehole/xxx /tmp/'

多条：

    ~/bin/xd-do <<'EOF'
    cd /home/ubuntu/treehole
    put -r ./dist/* incoming/
    ls -l incoming
    EOF

支持的子命令：`ls` / `get` / `put` / `put -r` / `mkdir` / `rm` / `rename` / `chmod` / `ln -s`。
`xd-do` 遇到 `permission denied` / `no such file` 之类会返回退出码 2。

## 禁止事项

- **不要直接跑 `sftp xd-sftp`（任何形式，包括 `-b` 和管道）** —— 会去开新通道，
  堡垒机拒绝，回 `Invalid packet back from SSH2_FXP_INIT (type 101)`，
  而且会白白废掉当前会话的额度。只用 `xd-do`
- 不要运行 `ssh xd` —— 交互式 shell，会话会挂住
- 不要自己跑 `xd-up` —— 要交互输密码，Claude Code 里没有 TTY，只会撞出认证失败
- 不要试图远程执行命令（`systemctl` / `docker` / 跑脚本 / `apt install` / 数据库迁移 / `git pull`）—— exec 通道被禁用，会被拒绝（回 `You could use sftp instead.`）
- 不要试图自动化部署执行环节，那一步由人手动完成
- 不要想办法绕过 exec 通道限制（私开隧道、cron 轮询自动执行落盘脚本之类）—— 那是堡垒机的设计意图，绕过是严重事件

## 无外网的处理

Python 依赖：

    pip download -r requirements.txt -d ./wheels    # 本地打包
    # 服务器上：pip install --no-index --find-links=./wheels -r requirements.txt

Docker 镜像：

    docker save -o app.tar image:tag               # 本地
    # 服务器上：docker load -i app.tar

## 部署流程

1. Claude Code：写代码、打离线依赖包
2. Claude Code：`xd-do` 把 `treehole-<版本>.tar.gz` 和同名 `.sha256` 推到 `incoming/`
3. **人工**：`ssh xd` → `tmux new -s deploy` → `sudo /usr/local/sbin/deploy-treehole`
   （不带参数＝取 `incoming/` 里 mtime 最新的包；也可以显式给包路径）
   成功的标志是输出 `Deployment successful.`
4. Claude Code：`get` 回 `current/release-meta/version.json` 确认切版；详细报告在
   `backups/` 里我读不了，要你 `sudo cat` 后贴过来

`deploy-treehole` 自己带包校验 + 原子切链 + 健康检查 + 失败自动回滚，我不需要另写这套逻辑。
包名里的 `+` 会被换成 `_` 作为 release 目录名。

`.sha256` 旁文件由 `package_release.sh` 生成，**不要手工敲** —— 部署脚本会拿它比对，
不一致直接拒绝部署。

写操作（改配置、跑迁移、重启服务）生成后由人先看一眼再执行 —— 生产机，堡垒机全程审计录屏，命令记在 `sys_guyu_01` 名下。
