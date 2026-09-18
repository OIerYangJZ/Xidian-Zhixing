# 知识库数据快照

本目录包含可直接部署的官方知识库数据快照：

- `data/knowledge.db`：SQLite 规范知识库
- `data/raw/`：知识库中引用的官方原始资料
- `HANDOFF.json`：交接包校验信息和文档统计

部署到目标主机时，将 `data/` 目录复制为：

```text
/opt/zhixing-knowledge/data/
```

知识服务的环境变量应指向：

```text
KNOWLEDGE_DB=/opt/zhixing-knowledge/data/knowledge.db
KNOWLEDGE_RAW_DIR=/opt/zhixing-knowledge/data/raw
```

启动 Qdrant 和知识服务后，使用受控的 `KNOWLEDGE_API_KEY` 调用一次 `POST /reindex`，把 SQLite 中的资料重新建立为当前向量索引。模型权重、Qdrant 二进制和运行密钥不放在 Git 仓库中，需按 `knowledge.env.example` 在目标主机单独安装和配置。
