#!/usr/bin/env bash
# 小电知识服务：首次安装到 /opt/zhixing-knowledge
#
#   sudo bash /home/ubuntu/treehole/incoming/install-knowledge.sh
#
# 不做的事：不建立向量索引（耗时长，单独跑）、不改后端 backend.env、
# 不启用官方刷新与论坛同步 timer。这三件由人另外决定。
set -euo pipefail

KS=/opt/zhixing-knowledge
INCOMING=/home/ubuntu/treehole/incoming
OFFLINE="$INCOMING/ks-offline"
# 包名带构建哈希，而这个脚本自己也在包里，写死名字必然会过期。
# 默认取 incoming/ 里最新的那个，也可以显式指定。
PKG="${1:-$(ls -t "$INCOMING"/zhixing-knowledge-*.tar.gz 2>/dev/null | head -1)}"
[ -n "$PKG" ] || { echo "!! $INCOMING 里找不到 zhixing-knowledge-*.tar.gz" >&2; exit 1; }
echo "使用安装包：$PKG"

[ "$(id -u)" -eq 0 ] || { echo "!! 需要 root：sudo bash $0" >&2; exit 1; }

echo "=== 0. 前置检查 ==="

if [ -e "$KS" ]; then
  echo "!! $KS 已存在。这个脚本只用于首次安装；" >&2
  echo "!! 要重装请先自行确认并移走旧目录，避免覆盖已有数据和索引。" >&2
  exit 1
fi

for path in "$PKG" "$PKG.sha256" \
            "$OFFLINE/install.sh" \
            "$OFFLINE/models/bge-m3" \
            "$OFFLINE/models/bge-reranker-base" \
            "$OFFLINE/qdrant/qdrant-x86_64-unknown-linux-gnu.tar.gz"; do
  [ -e "$path" ] || { echo "!! 缺少：$path" >&2; exit 1; }
done

# sha256 旁文件里的名字是相对的，必须在同目录校验
(cd "$INCOMING" && sha256sum -c "$(basename "$PKG").sha256")

python3 -c "import sys; assert sys.version_info[:2]==(3,10), sys.version" \
  || { echo "!! 需要 Python 3.10（离线 wheel 是按 3.10 解析的）" >&2; exit 1; }

echo "前置检查通过"

echo
echo "=== 1. 服务用户 ==="
if id zhixing >/dev/null 2>&1; then
  echo "zhixing 已存在，跳过"
else
  # systemd 单元里写的是 User=zhixing；这台机器上原本没有这个用户。
  useradd --system --home-dir "$KS" --no-create-home --shell /usr/sbin/nologin zhixing
  echo "已建立系统用户 zhixing（nologin）"
fi

echo
echo "=== 2. 解包代码与数据 ==="
mkdir -p "$KS"
tar -C /opt -xzf "$PKG"
echo "已解包到 $KS"
echo "  已发布文档：$(sqlite3 "$KS/data/knowledge.db" "SELECT count(*) FROM documents WHERE status='published';" 2>/dev/null || echo '需要 sqlite3 才能显示')"
echo "  原始资料：$(find "$KS/data/raw" -type f | wc -l) 份"

echo
echo "=== 3. 模型（用主机上已有的，不重新传输）==="
cp -a "$OFFLINE/models" "$KS/models"
for m in bge-m3 bge-reranker-base; do
  echo "  $m: $(du -sh "$KS/models/$m" | cut -f1)"
done

echo
echo "=== 4. Qdrant ==="
mkdir -p "$KS/qdrant/storage" "$KS/qdrant/snapshots"
tmp="$(mktemp -d)"
tar -C "$tmp" -xzf "$OFFLINE/qdrant/qdrant-x86_64-unknown-linux-gnu.tar.gz"
bin="$(find "$tmp" -maxdepth 2 -type f -name qdrant | head -1)"
[ -n "$bin" ] || { echo "!! 压缩包里找不到 qdrant 可执行文件" >&2; rm -rf "$tmp"; exit 1; }
install -m 0755 "$bin" "$KS/qdrant/qdrant"
rm -rf "$tmp"
cp "$KS/qdrant.yaml" "$KS/qdrant/qdrant.yaml"
file "$KS/qdrant/qdrant" 2>/dev/null || true
echo "Qdrant 已就位"

echo
echo "=== 5. Python 环境（离线，会先校验 3.2 GB 离线包，需要几分钟）==="
bash "$OFFLINE/install.sh" "$KS/venv"

echo
echo "=== 6. 配置 ==="
cp "$KS/knowledge.env.example" "$KS/knowledge.env"
key="$(openssl rand -hex 32)"
sed -i "s|^KNOWLEDGE_API_KEY=.*|KNOWLEDGE_API_KEY=$key|" "$KS/knowledge.env"
chmod 600 "$KS/knowledge.env"
echo "已生成 knowledge.env（权限 600），KNOWLEDGE_API_KEY 已填随机值"
echo
echo "  !! 记下这个密钥，第 9 步要把同一个值写进后端 backend.env："
echo "  $key"
echo
echo "  KNOWLEDGE_APP_DB 仍是占位符。它只被论坛同步用到，本次不启用，可暂不填。"

echo
echo "=== 7. 归属与 systemd ==="
chown -R zhixing:zhixing "$KS"
cp "$KS/systemd/qdrant.service" "$KS/systemd/zhixing-knowledge.service" /etc/systemd/system/
# refresh/community 的单元先不装：官方刷新会覆盖人工下架状态，论坛同步还需要业务库权限。
systemctl daemon-reload
echo "已安装 qdrant.service 与 zhixing-knowledge.service"
echo "（refresh/community 的 service/timer 故意没装，见 INSTALL.md 第 6 步）"

echo
echo "=== 8. 启动 ==="
# 起不来时要看到日志再退出，否则 set -e 会在最需要信息的时候静默结束。
show_state() {
  systemctl status qdrant zhixing-knowledge --no-pager -l 2>&1 | sed -n '1,40p' || true
  echo "--- zhixing-knowledge 最近日志 ---"
  journalctl -u zhixing-knowledge -n 40 --no-pager 2>&1 || true
}
if ! systemctl enable --now qdrant; then
  echo "!! qdrant 启动失败" >&2; show_state; exit 1
fi
sleep 3
if ! systemctl enable --now zhixing-knowledge; then
  echo "!! zhixing-knowledge 启动失败" >&2; show_state; exit 1
fi
sleep 5
if ! systemctl is-active --quiet zhixing-knowledge; then
  echo "!! zhixing-knowledge 启动后又退出了" >&2; show_state; exit 1
fi
show_state

echo
echo "=== 安装完成。还没做的三件事 ==="
cat <<NEXT

1) 建立向量索引（SQLite 里有资料，Qdrant 还是空的）。567 篇在 CPU 上较慢，放 tmux 里跑：

   source $KS/knowledge.env
   curl -fsS --max-time 7200 -X POST http://127.0.0.1:8091/reindex \\
        -H "Authorization: Bearer \$KNOWLEDGE_API_KEY"

2) 后端对接。编辑 /home/ubuntu/treehole/shared/config/backend.env：

   BACKEND_RAG_URL=http://127.0.0.1:8091
   BACKEND_RAG_API_KEY=$key

   然后：sudo systemctl restart treehole

3) 验收（第三条失败时不报错，必须单独验）：

   curl -fsS http://127.0.0.1:8091/health
   curl -fsS http://127.0.0.1:8091/status -H "Authorization: Bearer \$KNOWLEDGE_API_KEY"
   curl -fsS -X POST http://127.0.0.1:8091/search \\
        -H "Authorization: Bearer \$KNOWLEDGE_API_KEY" \\
        -H 'Content-Type: application/json' \\
        -d '{"query":"国家励志奖学金申请条件","limit":5}'

   # 取上面结果里的 documentId，确认原文回读真的读到了原始文件：
   curl -fsS "http://127.0.0.1:8091/documents/<documentId>/content" \\
        -H "Authorization: Bearer \$KNOWLEDGE_API_KEY" | head -c 400

   返回的 content 应当明显长于检索片段。两者长度接近说明原文没读到。
NEXT
