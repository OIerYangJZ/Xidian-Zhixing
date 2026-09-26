"""Admins read and answer user feedback (信箱); the user sees the answer."""
from __future__ import annotations

from http import HTTPStatus

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _patch_admin, _user


def _db_with_feedback():
    from services._db_service import default_db

    db = default_db()
    user = _user("fb-user", "2500400@stu.xidian.edu.cn")
    user["notifySystem"] = True
    db["users"].append(user)
    db["feedbacks"] = [
        {"id": "fb-1", "userId": user["id"], "content": "食堂太挤", "category": "校园建议",
         "status": "pending", "schoolReply": "", "createdAt": "2026-09-25T00:00:00+00:00"},
        {"id": "fb-2", "userId": user["id"], "content": "旧反馈", "category": "其他反馈",
         "status": "closed", "schoolReply": "", "createdAt": "2026-09-01T00:00:00+00:00"},
    ]
    return db, user


def test_list_filters_by_status_newest_first(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler

    db, _user_row = _db_with_feedback()
    _patch_admin(monkeypatch, {})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedbacks(handler, db, {"status": ["all"]})
    assert [row["id"] for row in handler.payload()["data"]] == ["fb-1", "fb-2"]

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedbacks(handler, db, {"status": ["pending"]})
    assert [row["id"] for row in handler.payload()["data"]] == ["fb-1"]
    assert handler.payload()["data"][0]["studentId"] == "2500400"

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedbacks(handler, db, {"status": ["bogus"]})
    assert handler.status_code == HTTPStatus.BAD_REQUEST


def test_reply_resolves_and_notifies_the_user(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler

    db, user = _db_with_feedback()
    _patch_admin(monkeypatch, {"action": "reply", "reply": "已协调错峰开放"})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedback_action(handler, db, "fb-1")

    assert handler.status_code == HTTPStatus.OK
    row = db["feedbacks"][0]
    assert row["status"] == "resolved"
    assert row["schoolReply"] == "已协调错峰开放"
    assert row["handledAt"]
    notices = [n for n in db["notifications"] if n.get("userId") == user["id"]]
    assert len(notices) == 1
    assert notices[0]["relatedType"] == "feedback"
    assert notices[0]["relatedId"] == "fb-1"


@pytest.mark.parametrize("body", [
    {"action": "reply", "reply": ""},
    {"action": "reply", "reply": "字" * 1001},
    {"action": "approve", "reply": "x"},
])
def test_invalid_actions_are_refused(monkeypatch: pytest.MonkeyPatch, body: dict) -> None:
    from handlers import _admin_handler

    db, _user_row = _db_with_feedback()
    _patch_admin(monkeypatch, body)

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedback_action(handler, db, "fb-1")

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert db["feedbacks"][0]["status"] == "pending"


def test_close_without_reply_and_no_second_handling(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler

    db, _user_row = _db_with_feedback()
    _patch_admin(monkeypatch, {"action": "close"})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedback_action(handler, db, "fb-1")
    assert handler.status_code == HTTPStatus.OK
    assert db["feedbacks"][0]["status"] == "closed"

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_feedback_action(handler, db, "fb-1")
    assert handler.status_code == HTTPStatus.CONFLICT


def test_overview_counts_pending_feedback() -> None:
    from services._db_service import build_overview

    db, _user_row = _db_with_feedback()
    assert build_overview(db)["pendingFeedbacks"] == 1
