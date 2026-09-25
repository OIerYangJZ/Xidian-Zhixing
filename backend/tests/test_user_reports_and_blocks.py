"""Reporting a person from their profile, and the profile's own-block flag."""
from __future__ import annotations

from http import HTTPStatus

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


@pytest.fixture
def db():
    from services._db_service import default_db

    data = default_db()
    for user_id, number in (("me", 1), ("them", 2)):
        user = _user(user_id, f"2500300{number}@stu.xidian.edu.cn")
        user["notifyReportResult"] = True
        data["users"].append(user)
    data["reports"] = []
    data["notifications"] = []
    return data


def _submit(monkeypatch, db, reporter_id, body):
    from handlers import _post_handler

    reporter = next(u for u in db["users"] if u["id"] == reporter_id)
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: reporter)
    monkeypatch.setattr(_post_handler, "read_json_body", lambda _h: body)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)
    handler = FakeJsonHandler()
    _post_handler.handle_submit_report(handler, db)
    return handler


def _handle(monkeypatch, db, report_id, action):
    from handlers import _admin_handler

    monkeypatch.setattr(
        _admin_handler, "_require_primary_admin", lambda _h, _db: {"id": "", "adminId": "a1"}
    )
    monkeypatch.setattr(
        _admin_handler, "read_json_body", lambda _h: {"action": action, "reviewNote": "骚扰"}
    )
    monkeypatch.setattr(_admin_handler, "save_db", lambda _db: None)
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_report_action(handler, db, report_id)
    return handler


def test_a_user_can_be_reported(monkeypatch, db):
    handler = _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "them", "reason": "人身攻击"})
    assert handler.status_code == HTTPStatus.OK, handler.payload()
    assert db["reports"][0]["targetType"] == "user"


def test_self_and_unknown_users_are_refused(monkeypatch, db):
    assert _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "me", "reason": "其他"}).status_code == HTTPStatus.BAD_REQUEST
    assert _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "ghost", "reason": "其他"}).status_code == HTTPStatus.NOT_FOUND
    assert db["reports"] == []


def test_banning_through_a_user_report_bans_that_user(monkeypatch, db):
    _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "them", "reason": "人身攻击"})
    report_id = db["reports"][0]["id"]

    assert _handle(monkeypatch, db, report_id, "delete").status_code == HTTPStatus.BAD_REQUEST
    assert db["reports"][0]["status"] == "pending"

    handler = _handle(monkeypatch, db, report_id, "ban")
    assert handler.status_code == HTTPStatus.OK, handler.payload()
    them = next(u for u in db["users"] if u["id"] == "them")
    assert them.get("banned") is True
    notice = next(n for n in db["notifications"] if n["userId"] == "them")
    assert "账号" in notice["content"]


def test_profile_reports_only_my_own_block(monkeypatch, db):
    from services._user_service import serialize_public_user_profile

    them = next(u for u in db["users"] if u["id"] == "them")
    me = next(u for u in db["users"] if u["id"] == "me")
    db["userBlocks"] = [{"blockerUserId": "me", "blockedUserId": "them"}]
    assert serialize_public_user_profile(db, target_user=them, viewer_user_id="me")["isBlockedByMe"] is True
    # They see nothing about being blocked.
    assert serialize_public_user_profile(db, target_user=me, viewer_user_id="them")["isBlockedByMe"] is False


@pytest.mark.parametrize(
    "reason",
    # web / Android, then the mini program
    ["垃圾广告", "违法违规", "色情低俗", "虚假信息", "侵犯隐私", "广告引流", "违规内容", "垃圾信息"],
)
def test_every_client_reason_is_accepted(monkeypatch, db, reason):
    handler = _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "them", "reason": reason})
    assert handler.status_code == HTTPStatus.OK, handler.payload()


def test_unknown_reasons_are_still_refused(monkeypatch, db):
    handler = _submit(monkeypatch, db, "me", {"targetType": "user", "targetId": "them", "reason": "看不顺眼"})
    assert handler.status_code == HTTPStatus.BAD_REQUEST
