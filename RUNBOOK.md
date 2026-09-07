# 西电知行小程序 — 运维 Runbook

> 环境搭通日期：2026-09-06
> 项目路径（服务器）：`/home/ubuntu/treehole`

---

## 一、链路拓扑

```
MacBook (Claude Code 在这里跑)
   │  ssh vmgw            公钥认证，免密
   ▼
Windows 虚拟机 172.16.188.134   ← aTrust 必须连着
   │  ProxyCommand -W       纯 TCP 转发
   ▼
堡垒机 10.255.53.2:50022      ← 密码认证（网页那个）
   │  堡垒机代理
   ▼
服务器 10.255.73.81 (ubuntu)   ← 无外网
```

关键事实：

- 堡垒机 SSH 网关在 **50022**（「字符文件运维端口」），不是 22
- 服务器 IP `10.255.73.81` **不在** aTrust 隧道内，只能经堡垒机转发
- **堡垒机禁用了 SSH exec 通道** —— `ssh xd "命令"` 会被拒（回 `You could use sftp instead.`）
- **堡垒机每个认证会话只给一条 SFTP 通道，用完即废** —— 第二条起回
  `Invalid packet back from SSH2_FXP_INIT (type 101)`。所以必须把那条通道挂成常驻会话
  复用（`xd-up` 已经这么做），不能每条命令开一个 `sftp`
- 虚拟机纯粹是网络中转节点，不需要在里面做任何操作

---

## 二、每次开工清单

### 1. 起环境

- [ ] 插上外置硬盘，启动 Windows 虚拟机（不用登进桌面做事，开着就行）
- [ ] 虚拟机里连上 **aTrust**
- [ ] 确认虚拟机 IP 还是 `172.16.188.134`（已做 DHCP 静态绑定，正常不会变）

### 2. 建立隧道 + 常驻会话（必做）

**必须在真终端里跑**（Terminal.app / iTerm），不能在 Claude Code 里跑 —— `!` 前缀执行的命令
没有控制 TTY，ssh 拿不到地方弹密码提示，keyboard-interactive 和 password 会当场失败，
连问都不问就 `Permission denied` 两次，然后堡垒机以 `Too many authentication failures` 掐断。

```bash
~/bin/xd-up          # ~/bin 不在 PATH 里，用全路径
```

输一次堡垒机密码，期望看到：

```
Master running (pid=XXXXX)
>>> 隧道 + 常驻 SFTP 会话已就绪（ControlPersist 8h）
```

脚本干两件事，缺一不可：

1. `ssh -MNf xd-sftp` 建后台 master。**不能**用 `echo pwd | sftp xd-sftp` 来建 ——
   那样 master 是 sftp 的子进程，sftp 退出会把它一起收掉，`ControlPersist` 根本不生效
   （现象：认证明明成功，但 `~/.ssh/cm-*` 立刻消失，`ssh -O check` 说 No such file）
2. 把堡垒机给的那**唯一一条** SFTP 通道挂成 FIFO 驱动的常驻 sftp 进程，供反复复用

之后 8 小时内免密（`ControlPersist 8h`）。

### 3. 验证

```bash
ssh -O check xd-sftp     # 期望：Master running
~/bin/xd-do 'pwd'        # 期望：Remote working directory: /home/ubuntu
```

### 4. 收工

虚拟机可以直接关机。下次开工重跑 `~/bin/xd-up` 即可（关机会留下僵尸 socket 和死掉的
常驻会话，`xd-up` 会一并清掉重建）。

---

## 三、我自己的操作

### 执行部署（这一步只能手动）

```bash
ssh xd
tmux new -s deploy        # 或 tmux attach -t deploy
sudo /usr/local/sbin/deploy-treehole                       # 默认取 incoming/ 里最新的包
sudo /usr/local/sbin/deploy-treehole /home/ubuntu/treehole/incoming/包名   # 或显式指定
```

**一定要用 tmux。** VPN 断了、Mac 合盖了，部署进程照样跑完。

成功输出 `Deployment successful.` + `Package:` / `Current:` / `Running:` 三行。
脚本自带原子切链、健康检查（`http://127.0.0.1:8080/api`，30 次 × 2s）、失败自动回滚、
保留最近 8 版。并发有 `flock` 保护。

部署后检查（这些路径我读不了，只能你看）：

```bash
readlink -f /home/ubuntu/treehole/current
REPORT="$(find /home/ubuntu/treehole/backups -maxdepth 1 -type f -name 'deployment-check-*.txt' | sort | tail -n 1)"
cat "$REPORT"      # 期望 DEPLOYMENT_RESULT=SUCCESS
less "$(sed -n 's/^LOG_FILE=//p' "$REPORT")"
```

失败会写 `DEPLOYMENT_RESULT=FAILED_AND_ROLLED_BACK` 并带 `RESTORED_RELEASE=`。

改环境变量：`sudo nano /home/ubuntu/treehole/shared/config/backend.env`

### 更新部署脚本本身

`/usr/local/sbin/deploy-treehole` 现在由 `scripts/deploy-treehole.sh` 版本控制。
Claude Code 把新版推到 `incoming/` 之后，装上去：

```bash
sudo install -m 0755 -o root -g root \
  /home/ubuntu/treehole/incoming/deploy-treehole.sh \
  /usr/local/sbin/deploy-treehole
sudo bash -n /usr/local/sbin/deploy-treehole && echo "语法 OK"
```

**坑：`/home/ubuntu/deploy-treehole.sh` 是过时副本**（比实际执行的那份少了一段 Nginx
可读性处理）。要读或改部署逻辑，取 `/usr/local/sbin/deploy-treehole`，别取 home 里那个。

### 安全习惯

- 只读命令（`journalctl`、`docker ps`、`cat` 配置）随便让 Claude Code 生成，直接敲
- 写操作（`systemctl restart`、改配置、跑迁移）**先看一眼再敲**
- 堡垒机全程审计录屏，每条命令记在 `sys_guyu_01` 名下 —— 出事是我的责任

---

## 四、Claude Code 能做 / 不能做

### ✅ 能自动做（一律通过 `~/bin/xd-do` 发给常驻会话）

| 操作 | 命令 |
|---|---|
| 列目录 | `~/bin/xd-do 'ls -l /home/ubuntu/treehole'` |
| 下载文件查看 | `~/bin/xd-do 'get 远端路径 /tmp/'` |
| 拉日志诊断 | 同上，`get` 下来本地分析 |
| 上传 | `put` / `put -r` |
| 目录与权限 | `mkdir` / `rm` / `rename` / `chmod` / `ln -s` |

多条命令走 stdin：

```bash
~/bin/xd-do <<'EOF'
cd /home/ubuntu/treehole
put -r ./dist/* incoming/
ls -l incoming
EOF
```

`xd-do` 在每批命令后追加一条 `!echo <标记>` 作为完成信号，读到标记就把这批输出返回；
输出里出现 `permission denied` / `no such file` 之类会返回退出码 2。sftp 交互模式遇错
不会自己退出，所以这个判断得由 `xd-do` 代劳。

### ❌ 不能做

- 任何进程执行：`systemctl` / `docker` / 跑脚本 / `apt install` / 数据库迁移 / `git pull`
- `ssh xd`（交互式 shell，agent 进去会挂住）
- **直接跑 `sftp xd-sftp`，任何形式** —— 包括 `-b` 和管道。会去开新通道，堡垒机拒绝，
  而且白白废掉这个会话的通道额度。只能用 `xd-do`
- `xd-up`（要交互输密码，见第二节）

### ⚠️ 权限盲区

`shared/`（含 `config/backend.env`）和 `backups/`（含部署报告和日志）是
`root:treehole drwxr-x---`，**ubuntu 读不了**，SFTP 会回 `Permission denied`。

所以「拉日志回来诊断」这条只在这些范围内成立：`releases/` 下的代码、
`current/release-meta/version.json`、`incoming/`。真要看 env 和部署日志，得你在运维
会话里 `sudo` 看完贴过来。

### 自动化程度

| 环节 | 谁做 |
|---|---|
| 写代码、`deploy.sh`、回滚逻辑 | Claude Code |
| 打离线依赖包 | Claude Code |
| 推送到服务器 | Claude Code |
| 读日志、诊断、生成修复 | Claude Code |
| **执行部署** | 我，一行命令 |
| 验证结果（拉日志回来看） | Claude Code |

约 90% 自动化。剩下 10% 的人工不该消除 —— 生产机，且审计记在我账号名下。

---

## 五、项目根目录的 CLAUDE.md

已就位：[CLAUDE.md](CLAUDE.md)。约束的权威版本在那个文件里，**改约束改那边，别在这里再抄一份**
（抄两份必然会漂移）。这份 Runbook 负责的是「怎么把环境搭起来、坏了怎么修」。

## 五之二、辅助脚本

`~/bin/` 下两个，不在 PATH 里，一律用全路径调用：

| 脚本 | 谁跑 | 干什么 |
|---|---|---|
| `xd-up` | **人，在真终端** | 建 master + 起常驻 SFTP 会话，要交互输密码 |
| `xd-do` | Claude Code | 往常驻会话发 sftp 命令并取回输出 |

`xd-do` 的实现要点（改的时候别踩）：

- 常驻会话在 `/tmp/xd-sftp/`：`in` 是 FIFO，`out` 是全量输出日志
- 一个 `sleep 2147483647 > in` 常驻进程占住写端，否则 sftp 读到 EOF 就退出
- 每批命令后追加 `!echo <随机标记>`（`!` 是 sftp 的本地 shell 逃逸），轮询 `out`
  等标记出现，再把这一段截出来返回；超时 120s
- 用 `wc -c` 记偏移量来切分本批输出，所以 `out` 只能追加、不能中途清空

---

## 六、SSH 配置备份

`~/.ssh/config`：

```
Host vmgw
    HostName 172.16.188.134
    User YangJinsey

Host xd
    HostName 10.255.53.2
    Port 50022
    User sys_guyu_01#UTF-8#2466#SSH#ubuntu
    ProxyCommand ssh vmgw -W %h:%p
    PubkeyAuthentication no
    PreferredAuthentications keyboard-interactive,password
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group14-sha1
    Ciphers +aes128-cbc
    MACs +hmac-sha1
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 8h

Host xd-sftp
    HostName 10.255.53.2
    Port 50022
    User sys_guyu_01#UTF-8#2466#SFTP#ubuntu
    ProxyCommand ssh vmgw -W %h:%p
    PubkeyAuthentication no
    PreferredAuthentications keyboard-interactive,password
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group14-sha1
    Ciphers +aes128-cbc
    MACs +hmac-sha1
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 8h
```

### 为什么每一行都不能少

- `PubkeyAuthentication no` —— 堡垒机握手时**谎称**支持公钥认证，Mac 上有 `id_rsa` 就会优先走这条路，然后被服务端直接挂断（`Broken pipe`）。必须禁掉，强制走密码
- `ProxyCommand ssh vmgw -W %h:%p` —— 不用 `ProxyJump`。`-W` 只做 TCP 转发，加解密在 Mac 侧完成，算法参数才生效；`ProxyJump` 会在虚拟机上执行 ssh，受那边配置影响
- 四行算法参数 —— 堡垒机固件老，只提供 `ssh-rsa`/`ssh-dss` + `hmac-sha1`，新版 OpenSSH 默认全禁了。**只写在这两个 Host 块里，绝不要放到 `Host *`**

### 快速登录字符串（堡垒机网页 → 设备访问 → 登录字符串）

```
sys_guyu_01#UTF-8#2466#SSH#ubuntu     字符运维
sys_guyu_01#UTF-8#2466#SFTP#ubuntu    文件传输
sys_guyu_01#UTF-8#2466##              不指定资产，登进去自选
```

`2466` 是这台服务器在堡垒机里的资产编号。

---

## 七、故障排查

### Claude Code 的远端命令卡住不动

虚拟机关机或 VPN 断过之后，ControlMaster 的 socket 变成僵尸状态，**不报错只挂住**。
真终端里：

```bash
~/bin/xd-up
```

### `Invalid packet back from SSH2_FXP_INIT (type 101)`

堡垒机拒绝开新的 SFTP 通道 —— 每个认证会话只给一条，已经用掉了。两种原因：

1. Claude Code 绕过 `xd-do` 直接跑了 `sftp xd-sftp`（额度被它废掉了）
2. 常驻会话进程死了

不管哪种，都只能真终端里重跑 `~/bin/xd-up` 换一条新通道（要重输密码）。

### 认证还没问密码就 `Permission denied` / `Too many authentication failures`

在没有 TTY 的地方跑了需要交互输密码的命令（典型：在 Claude Code 里跑 `xd-up`）。
ssh 没地方弹提示，两种认证方式直接失败，堡垒机掐断。

**注意别反复重试** —— 每次送两条认证失败，撞多了可能触发账号锁定。去真终端跑。

### 常驻 SFTP 会话状态怎么看

```bash
ssh -O check xd-sftp     # master 活着吗
ls -l /tmp/xd-sftp/      # in(FIFO) / out / sftp.pid / holder.pid
tail -30 /tmp/xd-sftp/out
```

`holder.pid` 是一个 `sleep 2147483647`，作用是占住 FIFO 写端 —— 没它的话每次写完
FIFO 关闭，sftp 读到 EOF 就退出了。

### `ssh vmgw` 连不上

按顺序查：

1. 虚拟机开着吗？
2. Windows 里 `Get-Service sshd` 是 Running 吗？
3. Mac 上 `nc -vz 172.16.188.134 22` 通吗？
4. Windows 网卡是不是又变回 `Public` 了？（管理员 PowerShell）
   ```powershell
   Get-NetConnectionProfile
   Set-NetConnectionProfile -InterfaceAlias "以太网" -NetworkCategory Private
   ```
5. mihomo 劫走了？配置里应有：
   ```yaml
   tun:
     route-exclude-address:
       - 172.16.0.0/12
   rules:
     - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
   ```

### `ssh xd` 报 `Broken pipe`

`PubkeyAuthentication no` 丢了。见上面「为什么每一行都不能少」。

### 报 `no matching host key type / MAC / cipher found`

算法参数没生效。检查是不是用了 `ProxyJump` 而不是 `ProxyCommand`。

### 虚拟机 IP 变了

已做 DHCP 静态绑定（Mac 上 `/Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf`，按 MAC `00:0c:29:ef:1f:c5` 固定到 `.134`）。**Fusion 升级后这个文件可能被重置**，需重新添加：

```
host winvm {
    hardware ethernet 00:0c:29:ef:1f:c5;
    fixed-address 172.16.188.134;
}
```

改完重启网络服务：

```bash
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --stop
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --start
```

### 不要在虚拟机里给以太网设静态 IP

试过，aTrust 会直接「网络不可用」。用上面的 DHCP 绑定方案。

---

## 八、备用通道

Mac 侧链路挂了但急着传文件时，虚拟机里还有 WinSCP：

- 站点 `xd-prod` 已保存（含密码），图形界面直接拖拽
- 命令行：`"C:\Program Files (x86)\WinSCP\winscp.com" /script="脚本路径" /log="日志路径"`
- 脚本文件格式：
  ```
  open xd-prod
  put -r C:\path\* /home/ubuntu/treehole/
  exit
  ```

注意 `/ini=nul` 和 `/session=` 不能一起用，会读不到保存的会话。

---

## 九、想进一步提升的话

当前限制的根源是堡垒机禁用 exec 通道 —— 这是它的设计意图，**不要想办法绕过**（私开隧道、cron 轮询自动执行落盘脚本之类，性质完全变了，被发现是很严重的事）。

正路有两条，都是走申请：

1. **内网测试机** —— 权限宽松，随便折腾，验证好了再往生产走。比申请生产机开放容易批得多
2. **CI runner** —— runner 在内网、有免密权限，部署动作由 pipeline 触发，连那一行都省了

补充：如果哪天想彻底摆脱 Windows 虚拟机，方向是在 macOS 上让 mihomo 和 aTrust 共存（`route-exclude-address` 放行 aTrust 下发的那十几条 `/32` 路由）。属于锦上添花。
