"""Reply notifications and per-type unread counts / mark-read."""
from __future__ import annotations

from http import HTTPStatus
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


def _notifying_user(user_id: str, number: int) -> dict[str, Any]:
    user = _user(user_id, f"{2500200 + number}@stu.xidian.edu.cn")
    for key in ("notifyComment", "notifyReply", "notifyLike", "notifyFavorite",
                "notifyReportResult", "notifySystem"):
        user[key] = True
    return user


@pytest.fixture
def thread(monkeypatch: pytest.MonkeyPatch):
    """Post p1 by `op`, with comment c1 by `commenter`."""
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    op = _notifying_user("op", 1)
    commenter = _notifying_user("commenter", 2)
    replier = _notifying_user("replier", 3)
    db["users"].extend([op, commenter, replier])
    db["posts"] = [{"id": "p1", "authorId": "op", "deleted": False, "allowComment": True,
                    "reviewStatus": "approved", "status": "ongoing"}]
    db["comments"] = [{"id": "c1", "postId": "p1", "userId": "commenter",
                       "deleted": False, "reviewStatus": "approved"}]
    db["notifications"] = []
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)
    return db, {"op": op, "commenter": commenter, "replier": replier}


def _comment(monkeypatch, db, author, body):
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: author)
    monkeypatch.setattr(_post_handler, "read_json_body", lambda _h: body)
    handler = FakeJsonHandler()
    _post_handler.handle_create_comment(handler, db, "p1")
    assert handler.status_code == HTTPStatus.OK, handler.payload()


def _types_for(db, user_id):
    return sorted(n["type"] for n in db["notifications"] if n["userId"] == user_id)


def test_reply_notifies_the_parent_comment_author(monkeypatch, thread):
    db, users = thread
    _comment(monkeypatch, db, users["replier"], {"content": "同意", "parentId": "c1"})

    assert _types_for(db, "commenter") == ["reply"]
    assert _types_for(db, "op") == ["comment"]
    reply = next(n for n in db["notifications"] if n["type"] == "reply")
    assert reply["postId"] == "p1"
    assert reply["relatedType"] == "comment"


def test_post_author_replied_to_gets_only_the_reply(monkeypatch, thread):
    db, users = thread
    db["comments"].append({"id": "c2", "postId": "p1", "userId": "op",
                           "deleted": False, "reviewStatus": "approved"})
    _comment(monkeypatch, db, users["replier"], {"content": "回洞主", "parentId": "c2"})

    assert _types_for(db, "op") == ["reply"]


def test_replying_to_yourself_notifies_nobody_twice(monkeypatch, thread):
    db, users = thread
    _comment(monkeypatch, db, users["commenter"], {"content": "补充", "parentId": "c1"})

    assert _types_for(db, "commenter") == []
    assert _types_for(db, "op") == ["comment"]


def _notification(n_id, user_id, n_type, read=False):
    # Stored the way the handlers write it: isRead plus readAt, which is what
    # serialize_notification reads.
    return {"id": n_id, "userId": user_id, "type": n_type, "isRead": read,
            "readAt": "2026-09-24T01:00:00+00:00" if read else "",
            "deleted": False, "createdAt": f"2026-09-24T00:00:0{n_id[-1]}+00:00",
            "title": "t", "content": "c"}


def _as(monkeypatch, user):
    from handlers import _notification_handler

    monkeypatch.setattr(_notification_handler, "auth_user_helper",
                        lambda _h, _db: (user, "token"))


def test_list_reports_unread_counts_per_type(monkeypatch):
    from handlers import _notification_handler
    from services._db_service import default_db

    db = default_db()
    me = _notifying_user("me", 4)
    db["users"].append(me)
    db["notifications"] = [
        _notification("n1", "me", "comment"),
        _notification("n2", "me", "reply"),
        _notification("n3", "me", "reply"),
        _notification("n4", "me", "like", read=True),
        _notification("n5", "me", "system_announcement"),
        _notification("n6", "other", "comment"),
    ]
    _as(monkeypatch, me)
    handler = FakeJsonHandler()
    _notification_handler.handle_get_notifications(handler, db)

    data = handler.payload()["data"]
    assert data["unreadCount"] == 4
    assert data["unreadByType"] == {"comment": 1, "reply": 2, "like": 0, "favorite": 0,
                                    "repost": 0, "mention": 0, "report_result": 0, "system": 1}


def _read_all(monkeypatch, db, user, body):
    from handlers import _notification_handler

    _as(monkeypatch, user)
    monkeypatch.setattr(_notification_handler, "read_json_body", lambda _h: body)
    monkeypatch.setattr(_notification_handler, "save_db", lambda _db: None)
    handler = FakeJsonHandler()
    _notification_handler.handle_mark_all_notifications_read(handler, db)
    return handler


def _unread_ids(db):
    return sorted(n["id"] for n in db["notifications"] if not n["isRead"])


def test_read_all_can_be_limited_to_one_type(monkeypatch):
    from services._db_service import default_db

    db = default_db()
    me = _notifying_user("me", 5)
    db["notifications"] = [
        _notification("n1", "me", "comment"),
        _notification("n2", "me", "reply"),
        _notification("n3", "other", "reply"),
    ]
    handler = _read_all(monkeypatch, db, me, {"type": "reply"})

    assert handler.payload()["data"]["marked"] == 1
    assert _unread_ids(db) == ["n1", "n3"], "only my replies are marked"


def test_read_all_without_a_type_still_marks_everything(monkeypatch):
    from services._db_service import default_db

    db = default_db()
    me = _notifying_user("me", 6)
    db["notifications"] = [_notification("n1", "me", "comment"),
                           _notification("n2", "me", "system")]
    _read_all(monkeypatch, db, me, {})

    assert _unread_ids(db) == []


def test_read_all_rejects_unknown_types(monkeypatch):
    from services._db_service import default_db

    db = default_db()
    me = _notifying_user("me", 7)
    db["notifications"] = [_notification("n1", "me", "comment")]
    handler = _read_all(monkeypatch, db, me, {"type": "everything"})

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert _unread_ids(db) == ["n1"]
