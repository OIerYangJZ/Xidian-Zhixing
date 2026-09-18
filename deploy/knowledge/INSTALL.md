# 小电知识服务：首次安装

目标主机 `ubuntu-KVM`（`zhixing.xidian.edu.cn`）。这台机器**没有外网**，堡垒机也**禁用了
SSH exec 通道**，所以不要在服务器上执行 `git pull` —— `/home/ubuntu/treehole` 不是 Git
工作区，取不到代码。本包已经把代码和数据都带齐。

模型**不在本包内**，因为主机上已经有了，不需要再传 3.4 GB。

## 本包内容

```text
zhixing-knowledge/
  current/knowledge_service/   服务代码（已含原文回读路径修复）
  data/knowledge.db            规范知识库，567 篇已发布 + 64 篇已禁用
  data/raw/                    631 份官方原始资料快照
  knowledge.env.example        配置模板
  qdrant.yaml                  Qdrant 配置
  systemd/                     service 与 timer 单元
  HANDOFF.json                 交接校验信息
  DATA_README.md               数据说明
```

## 0. 一键安装（推荐）

`install-knowledge.sh` 把下面第 1–6 步做完，并在失败时打印 systemd 日志。它不建索引、
不改后端配置、不启用 refresh/community timer，这三件仍由人决定：

```bash
sudo bash /home/ubuntu/treehole/incoming/install-knowledge.sh
```

先读一遍再跑。想手动逐步来就跳过本节，按第 1 步往下。

## 1. 服务用户与解包

systemd 单元里写的是 `User=zhixing`，**这台机器上原本没有这个用户**，要先建：

```bash
sudo useradd --system --home-dir /opt/zhixing-knowledge --no-create-home \
             --shell /usr/sbin/nologin zhixing

sudo tar -C /opt -xzf /home/ubuntu/treehole/incoming/zhixing-knowledge-<版本>.tar.gz
```

## 2. 放置模型（用主机上已有的那份）

模型已在 `/home/ubuntu/treehole/incoming/ks-offline/models/`，9 月 10 日就位，固定修订与
`knowledge.env.example` 一致（`bge-m3` 为 `5617a9f6…`，`bge-reranker-base` 为
`2cfc18c9…`），且已按运行所需裁剪。

```bash
sudo cp -a /home/ubuntu/treehole/incoming/ks-offline/models /opt/zhixing-knowledge/models
sudo chown -R zhixing:zhixing /opt/zhixing-knowledge/models
```

## 3. Python 环境

用离线包直接建到目标路径。venv 内部记录绝对路径，从 `~/ks-env` 复制过去会留下指向旧位置的
console script，所以重建而不是拷贝：

```bash
sudo bash /home/ubuntu/treehole/incoming/ks-offline/install.sh /opt/zhixing-knowledge/venv
```

它全程离线（`--no-index`，wheel 取自 `ks-offline/wheels/`），开头会校验整个离线包（含 3.2 GB
模型，要几分钟），结尾实测 import 并打印 `ALL_IMPORTS_OK`。

已核对 `~/ks-env` 里的依赖与 `knowledge_service/requirements.txt` 逐项一致
（torch 2.6.0+cpu、sentence-transformers 4.1.0、transformers 4.51.3、qdrant-client 1.15.1、
jieba 0.42.1、lxml 6.1.3、numpy 1.26.4 等），所以离线包是完整的。

注意部署文档写的是 Python 3.11，本机只有 3.10，全部依赖在 3.10 可得，离线包也是按 3.10
准备的。

## 4. Qdrant

主机上的 Qdrant 是压缩包（`qdrant-x86_64-unknown-linux-gnu.tar.gz`），不是解好的二进制，
要先解出来：

```bash
sudo mkdir -p /opt/zhixing-knowledge/qdrant/{storage,snapshots}
tmp=$(mktemp -d)
tar -C "$tmp" -xzf /home/ubuntu/treehole/incoming/ks-offline/qdrant/qdrant-x86_64-unknown-linux-gnu.tar.gz
sudo install -m 0755 "$(find "$tmp" -type f -name qdrant | head -1)" /opt/zhixing-knowledge/qdrant/qdrant
rm -rf "$tmp"
sudo cp /opt/zhixing-knowledge/qdrant.yaml /opt/zhixing-knowledge/qdrant/
sudo chown -R zhixing:zhixing /opt/zhixing-knowledge/qdrant
```

`qdrant.yaml` 里 `http_port` 是 6333，与 `KNOWLEDGE_QDRANT_URL` 一致；storage/snapshots 路径
也已指向上面建的目录。

## 5. 配置

```bash
sudo cp /opt/zhixing-knowledge/knowledge.env.example /opt/zhixing-knowledge/knowledge.env
sudo chmod 600 /opt/zhixing-knowledge/knowledge.env
sudo chown zhixing:zhixing /opt/zhixing-knowledge/knowledge.env
sudo nano /opt/zhixing-knowledge/knowledge.env
```

必须确认或填写：

```text
KNOWLEDGE_DB=/opt/zhixing-knowledge/data/knowledge.db
KNOWLEDGE_RAW_DIR=/opt/zhixing-knowledge/data/raw
KNOWLEDGE_EMBEDDING_MODEL=/opt/zhixing-knowledge/models/bge-m3
KNOWLEDGE_RERANK_MODEL=/opt/zhixing-knowledge/models/bge-reranker-base
KNOWLEDGE_RERANK_THRESHOLD=0.45
KNOWLEDGE_API_KEY=<自行生成，必须与后端 BACKEND_RAG_API_KEY 一致>
```

`KNOWLEDGE_RERANK_THRESHOLD` 的 0.45 是针对上面这个 `bge-reranker-base` 修订、在固定本地
检索用例上标定的。**不要沿用任何来自 `bge-reranker-v2-m3` 的旧值（如 0.05）** —— 两个模型
分数尺度不同，旧值会让几乎所有候选通过，等于重排失效。

`KNOWLEDGE_RAW_DIR` 必须指向真实的 `data/raw`。服务按这个变量定位原始资料，配错会导致原文
回读静默失败：接口仍返回 200，但回答只用到规范正文。

## 6. systemd

```bash
sudo cp /opt/zhixing-knowledge/systemd/qdrant.service \
        /opt/zhixing-knowledge/systemd/zhixing-knowledge.service \
        /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now qdrant
sudo systemctl enable --now zhixing-knowledge
sudo systemctl status qdrant zhixing-knowledge --no-pager
```

官方自动刷新（`zhixing-knowledge-refresh.timer`）**暂不启用**：当前采集发布会覆盖已有状态，
还没区分管理员禁用与解析失败，会把人工下架的资料自动重新发布。论坛同步
（`zhixing-knowledge-community.timer`）需要先填 `KNOWLEDGE_APP_DB` 并给服务用户读取业务库的
权限，首次索引完成后再由你决定是否启用。

## 7. 建立向量索引

SQLite 里有资料，但 Qdrant 是空的，必须建一次索引：

```bash
source /opt/zhixing-knowledge/knowledge.env
curl -fsS -X POST http://127.0.0.1:8091/reindex \
     -H "Authorization: Bearer $KNOWLEDGE_API_KEY"
```

567 篇在 CPU 上建索引耗时较长，建议放 `tmux` 里跑。

## 8. 后端对接

后端配置在 `/home/ubuntu/treehole/shared/config/backend.env`：

```text
BACKEND_RAG_URL=http://127.0.0.1:8091
BACKEND_RAG_API_KEY=<与 KNOWLEDGE_API_KEY 完全一致>
```

改完重启后端：`sudo systemctl restart treehole`。

## 9. 验收

```bash
# 进程是否起来（/health 不需要鉴权）
curl -fsS http://127.0.0.1:8091/health

# 索引状态（需要鉴权）
curl -fsS http://127.0.0.1:8091/status -H "Authorization: Bearer $KNOWLEDGE_API_KEY"

# 检索是否有结果
curl -fsS -X POST http://127.0.0.1:8091/search \
     -H "Authorization: Bearer $KNOWLEDGE_API_KEY" \
     -H 'Content-Type: application/json' \
     -d '{"query":"国家励志奖学金申请条件","limit":5}'
```

**原文回读必须单独验一次**，它失败时不报错：

```bash
# 从上面 search 结果里取一个 documentId
curl -fsS "http://127.0.0.1:8091/documents/<documentId>/content" \
     -H "Authorization: Bearer $KNOWLEDGE_API_KEY" | head -c 400
```

返回的 `content` 应该明显长于该文档在检索结果里的片段。如果两者长度接近，说明
`KNOWLEDGE_RAW_DIR` 配错或 `data/raw/` 没拷全，原文没有真正被读到。
