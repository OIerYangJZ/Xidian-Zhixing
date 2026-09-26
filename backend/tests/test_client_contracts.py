"""Endpoints answer the way the mini program, web and Android clients read them."""
from __future__ import annotations

from http import HTTPStatus
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


def _post_db(author: dict[str, Any], **post: Any) -> dict[str, Any]:
    from services._db_service import default_db

    db = default_db()
    db["users"].append(author)
    db["posts"] = [{
        "id": "p1",
        "authorId": author["id"],
        "authorAlias": author["nickname"],
        "title": "标题",
        "content": "正文",
        "deleted": False,
        "allowComment": True,
        "reviewStatus": "approved",
        **post,
    }]
    db["likes"] = []
    db["favorites"] = []
    db["comments"] = []
    return db


def _as(monkeypatch: pytest.MonkeyPatch, user: dict[str, Any], body: dict[str, Any]) -> None:
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_post_handler, "auth_user_helper", lambda _h, _db: (user, "token"))
    monkeypatch.setattr(_post_handler, "read_json_body", lambda _h: dict(body))
    monkeypatch.setattr(_post_handler, "_enforce_interaction_rate_limit", lambda *_a: True)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)


@pytest.mark.parametrize("already_liked", [False, True])
def test_like_with_a_target_state_is_idempotent(
    monkeypatch: pytest.MonkeyPatch,
    already_liked: bool,
) -> None:
    """A stale client asking to like an already-liked post must not unlike it."""
    from handlers import _post_handler

    author = _user("author", "2500200@stu.xidian.edu.cn")
    viewer = _user("viewer", "2500201@stu.xidian.edu.cn")
    db = _post_db(author)
    db["users"].append(viewer)
    if already_liked:
        db["likes"].append({"userId": viewer["id"], "postId": "p1"})
    _as(monkeypatch, viewer, {"liked": True})

    handler = FakeJsonHandler()
    _post_handler.handle_toggle_like(handler, db, "p1")

    assert handler.payload()["data"] == {"liked": True, "likeCount": 1}


def test_like_without_a_target_state_still_toggles(monkeypatch: pytest.MonkeyPatch) -> None:
    """Released mini program builds send an empty body."""
    from handlers import _post_handler

    author = _user("author", "2500202@stu.xidian.edu.cn")
    viewer = _user("viewer", "2500203@stu.xidian.edu.cn")
    db = _post_db(author)
    db["users"].append(viewer)
    db["likes"].append({"userId": viewer["id"], "postId": "p1"})
    _as(monkeypatch, viewer, {})

    handler = FakeJsonHandler()
    _post_handler.handle_toggle_like(handler, db, "p1")

    assert handler.payload()["data"] == {"liked": False, "likeCount": 0}


def test_favorite_with_a_target_state_is_idempotent(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    author = _user("author", "2500204@stu.xidian.edu.cn")
    viewer = _user("viewer", "2500205@stu.xidian.edu.cn")
    db = _post_db(author)
    db["users"].append(viewer)
    db["favorites"].append({"userId": viewer["id"], "postId": "p1"})
    _as(monkeypatch, viewer, {"favorited": True})

    handler = FakeJsonHandler()
    _post_handler.handle_toggle_favorite(handler, db, "p1")

    assert handler.payload()["data"]["favorited"] is True
    assert handler.payload()["data"]["favoriteCount"] == 1


def test_unfavorite_reports_the_favorited_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    author = _user("author", "2500206@stu.xidian.edu.cn")
    db = _post_db(author)
    db["favorites"].append({"userId": author["id"], "postId": "p1"})
    _as(monkeypatch, author, {})

    handler = FakeJsonHandler()
    _post_handler.handle_remove_favorite(handler, db, "p1")

    assert handler.payload()["data"]["favorited"] is False
    assert handler.payload()["data"]["favoriteCount"] == 0


def test_comment_unlike_never_likes(monkeypatch: pytest.MonkeyPatch) -> None:
    """DELETE /api/comments/<id>/like on a comment not liked used to like it."""
    from handlers import _post_handler

    author = _user("author", "2500207@stu.xidian.edu.cn")
    db = _post_db(author)
    db["comments"] = [{"id": "cm1", "postId": "p1", "userId": author["id"], "deleted": False}]
    _as(monkeypatch, author, {})

    handler = FakeJsonHandler()
    _post_handler.handle_toggle_comment_like(handler, db, "cm1", requested=False)

    assert handler.payload()["data"] == {"liked": False}
    assert db["likes"] == []


def test_author_may_open_their_own_pending_post_without_counting_a_view(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler

    author = _user("author", "2500208@stu.xidian.edu.cn")
    db = _post_db(author, reviewStatus="pending", viewCount=0)
    _as(monkeypatch, author, {})
    monkeypatch.setattr(_post_handler, "consume_rate_limit", lambda *_a, **_k: (True, 0))

    handler = FakeJsonHandler()
    _post_handler.handle_increment_view(handler, db, "p1")

    assert handler.status_code == HTTPStatus.OK
    assert db["posts"][0]["viewCount"] == 0


def test_anonymous_post_author_comments_under_the_post_alias(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler

    author = _user("author", "2500209@stu.xidian.edu.cn")
    db = _post_db(author, isAnonymous=True, authorAlias="树洞里的猫")
    _as(monkeypatch, author, {"content": "补充一下"})
    monkeypatch.setattr(_post_handler, "check_ip_rate_limit", lambda *_a: (True, 0))
    monkeypatch.setattr(_post_handler, "consume_rate_limit", lambda *_a, **_k: (True, 0))
    monkeypatch.setattr(_post_handler, "assess_text_risk", lambda *_a: (False, False, []))

    handler = FakeJsonHandler()
    _post_handler.handle_create_comment(handler, db, "p1")

    comment = handler.payload()["data"]
    assert comment["isAnonymous"] is True
    assert comment["isPostAuthor"] is True
    assert comment["authorAlias"] == "树洞里的猫"
    assert comment["authorUserId"] == ""
    assert comment["authorAvatarUrl"] == ""


def test_comments_mark_the_post_author(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    author = _user("author", "2500210@stu.xidian.edu.cn")
    other = _user("other", "2500211@stu.xidian.edu.cn")
    db = _post_db(author)
    db["users"].append(other)
    db["comments"] = [
        {"id": "cm1", "postId": "p1", "userId": author["id"], "deleted": False,
         "reviewStatus": "approved", "createdAt": "2026-09-26T00:00:00+00:00"},
        {"id": "cm2", "postId": "p1", "userId": other["id"], "deleted": False,
         "reviewStatus": "approved", "createdAt": "2026-09-26T00:01:00+00:00"},
    ]
    _as(monkeypatch, other, {})

    handler = FakeJsonHandler()
    _post_handler.handle_get_post_comments(handler, db, "p1", {})

    marks = {row["id"]: row["isPostAuthor"] for row in handler.payload()["data"]}
    assert marks == {"cm1": True, "cm2": False}


@pytest.mark.parametrize("handler_name,table", [
    ("handle_level_upgrade_request", "userLevelRequests"),
    ("handle_cancel_account_request", "accountCancellationRequests"),
])
def test_a_rejected_request_can_be_submitted_again(
    monkeypatch: pytest.MonkeyPatch,
    handler_name: str,
    table: str,
) -> None:
    from handlers import _comment_handler
    from services._db_service import default_db

    db = default_db()
    user = _user("requester", "2500212@stu.xidian.edu.cn")
    db["users"].append(user)
    db[table] = [{"id": "old", "userId": user["id"], "status": "rejected",
                  "createdAt": "2026-09-01T00:00:00+00:00"}]
    monkeypatch.setattr(_comment_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_comment_handler, "read_json_body", lambda _h: {"reason": "再试一次"})
    monkeypatch.setattr(_comment_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    getattr(_comment_handler, handler_name)(handler, db)

    assert handler.status_code in {HTTPStatus.OK, HTTPStatus.CREATED}
    assert len(db[table]) == 2


def test_session_poll_reports_validation_as_pending(monkeypatch: pytest.MonkeyPatch) -> None:
    """Clients accept only pending / authenticated / failed."""
    from handlers import _auth_handler

    monkeypatch.setattr(
        _auth_handler,
        "_poll_attempt_once",
        lambda _id: ({"id": "a1", "status": "validating", "platform": "mobile"}, False),
    )
    handler = FakeJsonHandler()
    _auth_handler.handle_xidian_auth_get_session(handler, {}, "a1")

    assert handler.payload()["data"]["status"] == "pending"


def test_club_list_says_which_clubs_the_viewer_may_post_as(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500213@stu.xidian.edu.cn")
    db["users"].append(viewer)
    db["clubs"] = [
        {"id": "c-own", "name": "甲", "status": "active"},
        {"id": "c-member", "name": "乙", "status": "active"},
    ]
    db["clubMembers"] = [
        {"clubId": "c-own", "userId": viewer["id"], "role": "manager"},
        {"clubId": "c-member", "userId": viewer["id"], "role": "member"},
    ]
    monkeypatch.setattr(_radio_handler, "auth_user_helper", lambda _h, _db: (viewer, "token"))

    handler = FakeJsonHandler()
    _radio_handler.handle_get_clubs(handler, db)

    can = {row["id"]: row["canPublishAs"] for row in handler.payload()["data"]}
    assert can == {"c-own": True, "c-member": False}


def test_hot_list_is_the_latest_rebuild_ranked_from_one(monkeypatch: pytest.MonkeyPatch) -> None:
    """Rebuilds on different days used to be mixed into one ranking."""
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    db["posts"] = [
        {"id": pid, "deleted": False, "reviewStatus": "approved"}
        for pid in ("old", "a", "hidden", "b")
    ]
    db["posts"][2]["deleted"] = True
    db["hotTopics"] = [
        {"date": "2026-09-25", "rank": 1, "postId": "old", "reviewStatus": "approved"},
        {"date": "2026-09-26", "rank": 1, "postId": "hidden", "reviewStatus": "approved"},
        {"date": "2026-09-26", "rank": 3, "postId": "b", "reviewStatus": "approved"},
        {"date": "2026-09-26", "rank": 2, "postId": "a", "reviewStatus": "approved"},
    ]

    handler = FakeJsonHandler()
    _radio_handler.handle_get_hot_topics(handler, db)

    rows = handler.payload()["data"]
    assert [(row["postId"], row["rank"]) for row in rows] == [("a", 1), ("b", 2)]
