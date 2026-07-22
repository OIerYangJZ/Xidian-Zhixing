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
