"""屏蔽 hides the blocked user's content; a recalled message stays as a placeholder."""
from __future__ import annotations

from http import HTTPStatus
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


def _post(post_id: str, author_id: str, **extra: Any) -> dict[str, Any]:
    return {
        "id": post_id,
        "authorId": author_id,
        "authorAlias": author_id,
        "title": post_id,
        "content": "正文",
        "deleted": False,
        "reviewStatus": "approved",
        "createdAt": f"2026-09-26T00:00:0{post_id[-1]}+00:00",
        **extra,
    }


def _feed(monkeypatch: pytest.MonkeyPatch, db: dict[str, Any], viewer: dict[str, Any], query: dict[str, list[str]]) -> Any:
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "auth_user_helper", lambda _h, _db: (viewer, "token"))
    handler = FakeJsonHandler()
    _post_handler.handle_get_posts(handler, db, query)
    assert handler.status_code == HTTPStatus.OK
    return handler.payload()["data"]


def _blocking_db() -> tuple[dict[str, Any], dict[str, Any]]:
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500300@stu.xidian.edu.cn")
    blocked = _user("blocked", "2500301@stu.xidian.edu.cn")
    other = _user("other", "2500302@stu.xidian.edu.cn")
    db["users"].extend([viewer, blocked, other])
    db["posts"] = [
        _post("p1", blocked["id"]),
        _post("p2", blocked["id"], isAnonymous=True, authorAlias="匿名猫"),
        _post("p3", other["id"]),
    ]
    db["comments"] = [
        {"id": "cm1", "postId": "p3", "userId": blocked["id"], "deleted": False,
         "reviewStatus": "approved", "createdAt": "2026-09-26T00:00:01+00:00"},
        {"id": "cm2", "postId": "p3", "userId": other["id"], "deleted": False,
         "reviewStatus": "approved", "createdAt": "2026-09-26T00:00:02+00:00"},
    ]
    db["userBlocks"] = [{"blockerUserId": viewer["id"], "blockedUserId": blocked["id"]}]
    return db, viewer


def test_blocked_users_posts_leave_the_feed_anonymous_ones_too(monkeypatch: pytest.MonkeyPatch) -> None:
    db, viewer = _blocking_db()
    rows = _feed(monkeypatch, db, viewer, {})
    assert [row["id"] for row in rows] == ["p3"]


def test_blocked_users_comments_are_hidden(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    db, viewer = _blocking_db()
    monkeypatch.setattr(_post_handler, "auth_user_helper", lambda _h, _db: (viewer, "token"))
    handler = FakeJsonHandler()
    _post_handler.handle_get_post_comments(handler, db, "p3", {})
    assert [row["id"] for row in handler.payload()["data"]] == ["cm2"]


def test_legacy_posts_count_as_general(monkeypatch: pytest.MonkeyPatch) -> None:
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500303@stu.xidian.edu.cn")
    db["users"].append(viewer)
    db["posts"] = [
        _post("p1", viewer["id"]),
        _post("p2", viewer["id"], sectionType="college", sectionId="cs"),
    ]
    rows = _feed(monkeypatch, db, viewer, {"sectionType": ["general"], "sectionId": ["general"]})
    assert [row["id"] for row in rows] == ["p1"]


def test_pages_report_totals_from_the_filtered_list(monkeypatch: pytest.MonkeyPatch) -> None:
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500304@stu.xidian.edu.cn")
    db["users"].append(viewer)
    db["posts"] = [_post(f"p{i}", viewer["id"]) for i in range(1, 6)]
    page = _feed(monkeypatch, db, viewer, {"page": ["2"], "limit": ["2"]})
    assert [row["id"] for row in page["items"]] == ["p3", "p2"]
    assert page["total"] == 5
    assert page["hasMore"] is True


def test_list_counts_match_the_tables() -> None:
    from services._db_service import default_db, list_posts

    db = default_db()
    db["posts"] = [_post("p1", "a"), _post("p2", "a")]
    db["likes"] = [{"userId": "x", "postId": "p1"}, {"userId": "y", "postId": "p1"},
                   {"userId": "x", "commentId": "cm1"}]
    db["favorites"] = [{"userId": "x", "postId": "p2"}]
    db["comments"] = [
        {"id": "cm1", "postId": "p1", "userId": "x", "deleted": False, "reviewStatus": "approved"},
        {"id": "cm2", "postId": "p1", "userId": "y", "deleted": False, "reviewStatus": "pending"},
        {"id": "cm3", "postId": "p1", "userId": "z", "deleted": True},
    ]
    counts = {
        p["id"]: (p["likeCount"], p["commentCount"], p["favoriteCount"])
        for p in list_posts(db, viewer_user_id="y")
    }
    # y sees their own pending comment.
    assert counts == {"p1": (2, 2, 0), "p2": (0, 0, 1)}


def test_more_than_nine_images_are_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    author = _user("author", "2500305@stu.xidian.edu.cn")
    db["users"].append(author)
    monkeypatch.setattr(_post_handler, "auth_user_helper", lambda _h, _db: (author, "token"))
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: author)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"content": "图", "imageUploadIds": [f"u{i}" for i in range(10)]},
    )
    handler = FakeJsonHandler()
    _post_handler.handle_create_post(handler, db)
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert "最多 9 张图片" in handler.payload()["message"]


def _chat_db() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    import _globals
    from services._db_service import default_db

    db = default_db()
    me = _user("me", "2500306@stu.xidian.edu.cn")
    peer = _user("peer", "2500307@stu.xidian.edu.cn")
    db["users"].extend([me, peer])
    key = _globals.conversation_key_for_users(me["id"], peer["id"])
    db["conversations"] = [
        {"id": "c-me", "userId": me["id"], "peerUserId": peer["id"], "deleted": False},
        {"id": "c-peer", "userId": peer["id"], "peerUserId": me["id"], "deleted": False},
    ]
    db["directMessages"] = [
        {"id": "m1", "conversationKey": key, "senderUserId": me["id"], "receiverUserId": peer["id"],
         "content": "你好", "createdAt": "2026-09-26T00:00:01+00:00", "deleted": False},
        {"id": "m2", "conversationKey": key, "senderUserId": peer["id"], "receiverUserId": me["id"],
         "content": "说错了", "createdAt": "2026-09-26T00:00:02+00:00", "deleted": True},
        {"id": "m3", "conversationKey": key, "senderUserId": me["id"], "receiverUserId": peer["id"],
         "content": "好的", "replyToId": "m2", "replyToSender": "peer", "replyToContent": "说错了",
         "createdAt": "2026-09-26T00:00:03+00:00", "deleted": False},
    ]
    return db, me, peer


def test_a_recalled_message_comes_back_as_a_placeholder(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _message_handler

    db, me, _peer = _chat_db()
    monkeypatch.setattr(_message_handler, "_require_auth", lambda _h, _db: me)
    monkeypatch.setattr(_message_handler, "save_db", lambda _db: None)
    handler = FakeJsonHandler()
    _message_handler.handle_get_messages(handler, db, "c-me")

    rows = {row["id"]: row for row in handler.payload()["data"]}
    assert list(rows) == ["m1", "m2", "m3"]
    assert rows["m2"]["recalled"] is True
    assert rows["m2"]["content"] == ""
    assert rows["m2"]["canRecall"] is False
    assert rows["m1"]["recalled"] is False
    # A quote of the recalled message no longer carries its text.
    assert rows["m3"]["replyToContent"] == "该消息已撤回"


def test_the_preview_says_who_recalled() -> None:
    from services._user_service import refresh_conversation_pair_metadata

    db, me, peer = _chat_db()
    db["directMessages"][2]["deleted"] = True  # I recall my last message.
    refresh_conversation_pair_metadata(
        db, left_user_id=me["id"], right_user_id=peer["id"], updated_at="",
    )
    previews = {row["id"]: row["lastMessage"] for row in db["conversations"]}
    assert previews == {"c-me": "你撤回了一条消息", "c-peer": "对方撤回了一条消息"}


def test_a_blocked_user_sends_no_notifications() -> None:
    from services._db_service import default_db
    from services._user_service import create_notification

    db = default_db()
    target = _user("target", "2500300@stu.xidian.edu.cn")
    actor = _user("actor", "2500301@stu.xidian.edu.cn")
    target["notifyLike"] = True
    db["users"].extend([target, actor])
    db["userBlocks"] = [{"blockerUserId": target["id"], "blockedUserId": actor["id"]}]

    created = create_notification(
        db, user_id=target["id"], notification_type="like", title="收到点赞",
        content="", actor_id=actor["id"],
    )

    assert created is None
    assert db.get("notifications", []) == []
