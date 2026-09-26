"""Fixes from the second client/backend audit."""
from __future__ import annotations

from http import HTTPStatus
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


def _banned_user(db: dict[str, Any]) -> dict[str, Any]:
    from services._user_service import ban_user_account

    user = _user("banned", "2500400@stu.xidian.edu.cn")
    db["users"].append(user)
    ban_user_account(db, user)
    return user


def _appeal(user: dict[str, Any], status: str, created_at: str) -> dict[str, Any]:
    return {"id": f"ap-{status}-{created_at}", "userId": user["id"], "appealType": "ban_revoke",
            "status": status, "createdAt": created_at}


def _submit_appeal(monkeypatch: pytest.MonkeyPatch, db: dict[str, Any], user: dict[str, Any]) -> FakeJsonHandler:
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "read_json_body", lambda _h: {
        "email": user["email"], "appealType": "ban_revoke", "content": "请复核"})
    monkeypatch.setattr(_post_handler, "auth_user_helper", lambda _h, _db: (user, "token"))
    monkeypatch.setattr(_post_handler, "check_ip_rate_limit", lambda *_a: (True, 0))
    monkeypatch.setattr(_post_handler, "consume_rate_limit", lambda *_a, **_k: (True, 0))
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)
    handler = FakeJsonHandler()
    _post_handler.handle_submit_appeal(handler, db)
    return handler


def test_a_ban_gets_one_in_app_appeal(monkeypatch: pytest.MonkeyPatch) -> None:
    from services._db_service import default_db

    db = default_db()
    user = _banned_user(db)
    db["appeals"] = [_appeal(user, "rejected", "2999-01-01T00:00:00+00:00")]

    handler = _submit_appeal(monkeypatch, db, user)

    assert handler.status_code == HTTPStatus.CONFLICT
    assert "本次封禁的站内申诉已用完" in handler.payload()["message"]


def test_a_new_ban_gets_a_new_appeal(monkeypatch: pytest.MonkeyPatch) -> None:
    """An appeal turned down during an earlier ban does not use this one up."""
    from services._db_service import default_db

    db = default_db()
    user = _banned_user(db)
    db["appeals"] = [_appeal(user, "rejected", "2000-01-01T00:00:00+00:00")]

    handler = _submit_appeal(monkeypatch, db, user)

    assert handler.status_code == HTTPStatus.OK


def test_my_appeal_says_whether_the_form_applies(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    user = _banned_user(db)
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)

    handler = FakeJsonHandler()
    _post_handler.handle_my_latest_appeal(handler, db)
    assert handler.payload()["data"]["canSubmit"] is True

    db["appeals"] = [_appeal(user, "rejected", "2999-01-01T00:00:00+00:00")]
    handler = FakeJsonHandler()
    _post_handler.handle_my_latest_appeal(handler, db)
    assert handler.payload()["data"]["canSubmit"] is False


def test_notifications_from_a_blocked_user_leave_the_list(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _notification_handler
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500401@stu.xidian.edu.cn")
    db["users"].append(viewer)
    db["notifications"] = [
        {"id": "n1", "userId": viewer["id"], "type": "like", "actorId": "blocked", "createdAt": "1"},
        {"id": "n2", "userId": viewer["id"], "type": "like", "actorId": "friend", "createdAt": "2"},
    ]
    db["userBlocks"] = [{"blockerUserId": viewer["id"], "blockedUserId": "blocked"}]
    monkeypatch.setattr(_notification_handler, "auth_user_helper", lambda _h, _db: (viewer, "token"))

    handler = FakeJsonHandler()
    _notification_handler.handle_get_notifications(handler, db)

    assert [row["id"] for row in handler.payload()["data"]["items"]] == ["n2"]


def test_comment_count_leaves_out_blocked_users() -> None:
    from services._db_service import default_db, serialize_post

    db = default_db()
    viewer = _user("viewer", "2500402@stu.xidian.edu.cn")
    db["users"].append(viewer)
    post = {"id": "p1", "authorId": "someone", "deleted": False}
    db["posts"] = [post]
    db["comments"] = [
        {"id": "c1", "postId": "p1", "userId": "blocked", "deleted": False},
        {"id": "c2", "postId": "p1", "userId": "friend", "deleted": False},
    ]
    db["userBlocks"] = [{"blockerUserId": viewer["id"], "blockedUserId": "blocked"}]

    assert serialize_post(db, post, viewer_user_id=viewer["id"])["commentCount"] == 1


def test_ai_refuses_a_banned_session_with_the_account_state(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _ai_handler
    from services._db_service import default_db

    db = default_db()
    user = _banned_user(db)
    monkeypatch.setattr(_ai_handler, "auth_user_helper", lambda _h, _db: (user, "token"))

    handler = FakeJsonHandler()
    assert _ai_handler._require_auth(handler, db) is None
    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert handler.payload()["data"] == {"accountState": "banned"}


def test_a_deleted_knowledge_document_is_neither_listed_nor_edited(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _knowledge_handler

    docs = {"live": {"id": "live", "title": "a", "status": "published"},
            "gone": {"id": "gone", "title": "b", "status": "archived"}}
    upserts: list[Any] = []

    def fake_request(path: str, payload: Any = None, timeout: int = 0) -> Any:
        if path == "/documents" and payload is None:
            return {"items": list(docs.values())}
        if path == "/status":
            return {}
        if path.startswith("/documents/"):
            return docs[path.rsplit("/", 1)[-1]]
        upserts.append(payload)
        return {"document": payload}

    monkeypatch.setattr(_knowledge_handler, "knowledge_request", fake_request)
    monkeypatch.setattr(_knowledge_handler, "_require_admin", lambda _h, _db: {"id": "admin"})
    monkeypatch.setattr(_knowledge_handler, "read_json_body", lambda _h: {"name": "改名"})

    handler = FakeJsonHandler()
    _knowledge_handler.list_sources(handler, {})
    assert [row["id"] for row in handler.payload()["data"]["items"]] == ["live"]

    handler = FakeJsonHandler()
    _knowledge_handler.write_source(handler, {}, "gone")
    assert handler.status_code == HTTPStatus.CONFLICT
    assert upserts == []


@pytest.mark.parametrize("method,allowed", [("GET", True), ("PATCH", False), ("DELETE", False)])
def test_a_banned_session_may_read_but_not_edit_its_profile(method: str, allowed: bool) -> None:
    import server
    from services._db_service import default_db

    db = default_db()
    user = _banned_user(db)
    handler = FakeJsonHandler()
    handler.command = method
    handler.headers = {"Authorization": "Bearer t"}
    db["sessions"]["t"] = user["id"]

    assert server._require_api_session(handler, "/api/users/me", db) is allowed


def test_a_wrong_campus_password_is_not_a_dead_session() -> None:
    from helpers._campus_auth import CampusAuthCredentialError, map_campus_auth_error

    status, _ = map_campus_auth_error(CampusAuthCredentialError("密码错误"))
    assert status == 400


def test_a_deleted_default_tag_stays_deleted() -> None:
    import _globals
    from services._db_service import migrate_db

    db = {"tags": [tag for tag in _globals.DEFAULT_TAGS if tag != "食堂"] or ["x"]}
    migrate_db(db)
    assert "食堂" not in db["tags"]
