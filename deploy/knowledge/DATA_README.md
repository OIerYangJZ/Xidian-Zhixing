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

## 从应用库补回已采集正文

如果应用库 `KNOWLEDGE_APP_DB` 的 `radioState.knowledgeDocuments` 比此部署快照完整，先用快照导入补回官方文章、附件和标题可识别的校园服务页。这个模式直接读取应用库中已保存的标题与正文，不访问学校网站；已存在的来源 URL 会跳过，以保留当前知识库里的禁用状态和人工修订：

```bash
python -m knowledge_service.ingest \
  --db /opt/zhixing-knowledge/data/knowledge.db \
  --app-db /path/to/treehole.db \
  --from-app-snapshot \
  --report /tmp/knowledge-snapshot-import.json
```

导入会让旧向量索引失效。随后从捕获的原始文件重新切片，再调用一次 `POST /reindex`：

```bash
KNOWLEDGE_DB=/opt/zhixing-knowledge/data/knowledge.db \
KNOWLEDGE_RAW_DIR=/opt/zhixing-knowledge/data/raw \
python -m knowledge_service.reparse \
  --db /opt/zhixing-knowledge/data/knowledge.db \
  --report /tmp/knowledge-reparse.json
```

先核对导入报告中的 `skippedInvalid` 和新增来源，再检查重新切片报告中的 `failed` 项，最后重建向量索引。快照导入的文档保留在 SQLite 正文中；这些文档没有单独的 HTML 原始文件，原文接口会直接返回已保存正文。
