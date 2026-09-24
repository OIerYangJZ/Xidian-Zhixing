"""GET /api/users/me carries the counts shown on 个人资料与设置."""
from __future__ import annotations

from http import HTTPStatus

from tests.test_logic_regressions import FakeJsonHandler, _user


def test_me_reports_own_post_and_follow_counts(monkeypatch):
    from handlers import _user_handler
    from services._db_service import default_db

    db = default_db()
    me = _user("me", "25002001@stu.xidian.edu.cn")
    a = _user("a", "25002002@stu.xidian.edu.cn")
    b = _user("b", "25002003@stu.xidian.edu.cn")
    db["users"].extend([me, a, b])
    db["posts"] = [
        {"id": "p1", "authorId": "me", "deleted": False, "reviewStatus": "approved"},
        # Anonymous and pending posts are still 我的帖子.
        {"id": "p2", "authorId": "me", "deleted": False, "reviewStatus": "pending",
         "isAnonymous": True},
        {"id": "p3", "authorId": "me", "deleted": True, "reviewStatus": "approved"},
        {"id": "p4", "authorId": "a", "deleted": False, "reviewStatus": "approved"},
    ]
    db["userFollows"] = [
        {"followerUserId": "me", "followeeUserId": "a"},
        {"followerUserId": "a", "followeeUserId": "me"},
        {"followerUserId": "b", "followeeUserId": "me"},
    ]
    monkeypatch.setattr(_user_handler, "auth_user_helper", lambda _h, _db: (me, None))

    handler = FakeJsonHandler()
    _user_handler.handle_get_me(handler, db)

    assert handler.status_code == HTTPStatus.OK
    data = handler.payload()["data"]
    assert data["postCount"] == 2
    assert data["followingCount"] == 1
    assert data["followerCount"] == 2
