from __future__ import annotations

from typing import Any

from rag_service import rebuild_rag_index, retrieve


def _db() -> dict[str, Any]:
    import server

    return server.default_db()


def test_rag_retrieves_knowledge_and_forum_posts() -> None:
    db = _db()
    rows = retrieve(db, "B楼204怎么走，附近哪里可以打印", limit=10)

    assert any(row["type"] == "post" and "B 楼" in row["title"] for row in rows)
    assert any(row["type"] == "knowledge" for row in rows)


def test_rag_excludes_private_deleted_and_unreviewed_posts() -> None:
    db = _db()
    for suffix, changes in (
        ("private", {"visibility": "private"}),
        ("deleted", {"deleted": True}),
        ("pending", {"reviewStatus": "pending"}),
    ):
        db["posts"].append({
            "id": f"hidden-{suffix}",
            "title": f"隐藏地点测试 {suffix}",
            "content": "紫竹秘密打印点只在这里出现",
            "tags": ["打印"],
            "createdAt": "2026-07-20T00:00:00+00:00",
            "updatedAt": "2026-07-20T00:00:00+00:00",
            "reviewStatus": "approved",
            "deleted": False,
            "visibility": "public",
            **changes,
        })

    rows = retrieve(db, "紫竹秘密打印点", limit=20)

    assert not any(str(row.get("id", "")).startswith("hidden-") for row in rows)


def test_rag_index_refreshes_after_post_update() -> None:
    db = _db()
    post = next(row for row in db["posts"] if "B 楼 204" in row.get("title", ""))
    rebuild_rag_index(db)

    before = retrieve(db, "北门咖啡打印", limit=10)
    assert not any(row.get("id") == post["id"] for row in before)

    post["content"] += " 北门咖啡打印是新补充的测试信息。"
    post["updatedAt"] = "2026-07-21T00:00:00+00:00"
    after = retrieve(db, "北门咖啡打印", limit=10)

    assert any(row.get("id") == post["id"] for row in after)


def test_rebuild_keeps_knowledge_chunks() -> None:
    db = _db()
    before = len(db["knowledgeChunks"])

    index = rebuild_rag_index(db)

    assert len(db["knowledgeChunks"]) == before
    assert index["knowledgeCount"] == before
    assert index["postCount"] > 0


def test_ai_provider_configuration_is_server_owned(monkeypatch) -> None:
    import handlers._ai_handler as ai_handler

    monkeypatch.setattr(ai_handler._globals, "AI_BASE_URL", "https://server.example/v1")
    monkeypatch.setattr(ai_handler._globals, "AI_API_KEY", "server-secret")
    monkeypatch.setattr(ai_handler._globals, "AI_MODEL", "server-model")

    assert ai_handler._configured_provider() == (
        "https://server.example/v1",
        "server-secret",
        "server-model",
    )


# --- N3: 索引不再每请求重建、不再截断文档 ----------------------------------


def _cjk_post(post_id: str, body: str) -> dict[str, Any]:
    return {
        "id": post_id,
        "title": f"标题 {post_id}",
        "content": body,
        "channel": "综合",
        "tags": ["学习"],
        "authorId": "u1",
        "authorAlias": "示范同学",
        "createdAt": "2026-01-01T00:00:00+00:00",
        "updatedAt": "2026-01-01T00:00:00+00:00",
        "reviewStatus": "approved",
        "visibility": "public",
        "deleted": False,
    }


def test_documents_keep_their_whole_vocabulary() -> None:
    """文档曾被截断到 80 个 token，中文帖子等于只按单字建索引。

    结果是 '打印店' 这类词根本不在索引里，且所有文档 length 相同，
    BM25 的长度归一化退化成常数。
    """
    from rag_service import MAX_QUERY_TERMS, _tokenize, MAX_DOCUMENT_TERMS

    body = (
        "最近在南校区 B 楼上课，想问一下附近哪里可以打印资料。教学区有自助打印点，"
        "但是彩印和装订好像要去海棠附近的打印店。有同学知道营业时间吗？"
    )
    tokens = _tokenize(body, limit=MAX_DOCUMENT_TERMS)

    assert len(tokens) > MAX_QUERY_TERMS
    assert "打印店" in tokens
    assert "南校区" in tokens
    # 查询侧仍然保持短，避免噪声。
    assert len(_tokenize(body, limit=MAX_QUERY_TERMS)) == MAX_QUERY_TERMS


def test_tokenizer_dedup_is_not_quadratic() -> None:
    """判重必须走 set。

    早期实现用 `token not in tokens` 对 list 线性扫描，复杂度 O(词数²)：
    一篇 2400 字的帖子光分词就要 88 ms，而整个语料每次 AI 请求都要重新分。

    这里比较的是**增长率**而不是绝对耗时，避免机器快慢导致的抖动：输入放大
    4 倍，线性实现约 4 倍耗时，二次实现约 14 倍。
    """
    import random
    import time

    from rag_service import MAX_DOCUMENT_TERMS, _tokenize

    # 高多样性文本，否则去重后词表太小、二次行为体现不出来。
    random.seed(20260101)
    pool = [chr(0x4E00 + offset) for offset in range(0, 3000, 3)]

    def sample(size: int) -> str:
        return "".join(random.choice(pool) for _ in range(size))

    def measure(text: str) -> float:
        best = float("inf")
        for _ in range(3):
            started = time.perf_counter()
            _tokenize(text, limit=MAX_DOCUMENT_TERMS)
            best = min(best, time.perf_counter() - started)
        return best

    small, large = sample(300), sample(1200)
    growth = measure(large) / max(measure(small), 1e-9)
    assert growth < 8.0, (
        f"输入放大 4 倍，耗时放大 {growth:.1f} 倍，疑似退回 list 线性扫描判重"
    )


def test_index_is_not_rebuilt_on_every_retrieve(monkeypatch) -> None:
    """索引此前存在 db 里、又从不被保存，于是每次 AI 请求都重建一次再丢掉。"""
    import rag_service

    rag_service.reset_index_cache()
    db = {
        "posts": [_cjk_post(f"p{i}", "图书馆 插座 座位 自习" * 20) for i in range(40)],
        "knowledgeChunks": [],
        "knowledgeSources": [],
    }

    added: list[str] = []
    original = rag_service._add_document
    monkeypatch.setattr(
        rag_service,
        "_add_document",
        lambda index, row: (added.append(row["key"]), original(index, row))[1],
    )

    rag_service.retrieve(db, "图书馆 插座")
    first_pass = len(added)
    assert first_pass == 40

    added.clear()
    rag_service.retrieve(db, "自习 座位")
    assert added == [], "语料没变时不应重新索引任何文档"

    # 新增一篇只应索引这一篇，而不是整个语料。
    db["posts"].append(_cjk_post("new", "北门咖啡打印是新补充的内容"))
    added.clear()
    rag_service.retrieve(db, "北门咖啡打印")
    assert added == ["post:new"]


def test_index_stays_out_of_the_application_state() -> None:
    """索引留在 db 里意味着每个请求都要从 settings blob 里 JSON 解一遍。"""
    import rag_service

    rag_service.reset_index_cache()
    db = {
        "posts": [_cjk_post(f"p{i}", "图书馆 插座" * 10) for i in range(5)],
        "knowledgeChunks": [],
        "knowledgeSources": [],
    }
    rag_service.retrieve(db, "图书馆")
    assert rag_service.INDEX_KEY not in db

    rag_service.rebuild_rag_index(db)
    assert rag_service.INDEX_KEY not in db
    # 管理台的索引摘要改从缓存读。
    assert rag_service.index_summary()["documentCount"] == 5


def test_removed_posts_drop_out_of_the_index() -> None:
    """增量更新必须真的把旧 posting 摘掉，否则会检索到已删除的内容。"""
    import rag_service

    rag_service.reset_index_cache()
    secret = "紫竹秘密打印点"
    db = {
        "posts": [_cjk_post("keep", "图书馆 插座"), _cjk_post("gone", secret)],
        "knowledgeChunks": [],
        "knowledgeSources": [],
    }
    assert any(row["id"] == "gone" for row in rag_service.retrieve(db, secret))

    db["posts"] = [row for row in db["posts"] if row["id"] != "gone"]
    assert not any(row["id"] == "gone" for row in rag_service.retrieve(db, secret))
    assert rag_service.index_summary()["documentCount"] == 1


def test_ai_retrieval_endpoints_are_rate_limited_and_outside_the_db_lock() -> None:
    """检索是纯 Python CPU：放在 DB_LOCK 里、又不限流，任何登录用户都能冻结整站。"""
    import inspect

    import _globals
    import server
    from handlers import _radio_handler

    for name in ("handle_ai_search", "handle_ai_post_selection"):
        source = inspect.getsource(getattr(_radio_handler, name))
        assert 'check_ip_rate_limit(handler, "ai_search")' in source, name
        assert 'setting_key="aiSearchRateLimit"' in source, name

    assert "aiSearchRateLimit" in _globals.DEFAULT_SETTINGS
    assert "ai_search" in _globals.RATE_LIMIT_WINDOWS_SECONDS
    assert "ai_search" in _globals.IP_RATE_LIMITS

    dispatch = inspect.getsource(server.TreeholeHandler._handle_post)
    locked = dispatch.split("with _locked_response(self):", 1)[1]
    for path in ("/api/ai/search", "/api/ai/post-selection", "/api/ai/chat"):
        assert path not in locked, f"{path} 不应在 DB_LOCK 覆盖的分发块内"
        assert path in dispatch, path
