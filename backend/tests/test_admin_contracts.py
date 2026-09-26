"""Admin endpoints return and accept what the admin consoles use."""
from __future__ import annotations

from http import HTTPStatus

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _patch_admin, _user


def test_config_round_trips_the_enforced_limits(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler
    from helpers import get_setting_int
    from services._db_service import default_db

    db = default_db()
    _patch_admin(monkeypatch, {"settings": {"postRateLimit": 7, "imageMaxMB": 3}})
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_update_config(handler, db)
    assert handler.status_code == HTTPStatus.OK
    assert get_setting_int(db, "postRateLimit", 5) == 7

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_config(handler, db)
    settings = handler.payload()["data"]["settings"]
    assert settings["postRateLimit"] == 7
    assert settings["imageMaxMB"] == 3
    assert settings["commentRateLimit"] == 20


@pytest.mark.parametrize("body", [
    {"settings": {"noSuchLimit": 3}},
    {"settings": {"postRateLimit": 0}},
    {"settings": {"postRateLimit": "7"}},
])
def test_config_rejects_unknown_or_invalid_limits(
    monkeypatch: pytest.MonkeyPatch,
    body: dict,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    _patch_admin(monkeypatch, body)
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_update_config(handler, db)
    assert handler.status_code == HTTPStatus.BAD_REQUEST


def test_image_reviews_filter_by_status(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    db["mediaUploads"] = [
        {"id": f"u-{status}", "status": status, "uploaderId": "", "url": "/api/storage/x"}
        for status in ("pending", "risk", "approved", "rejected")
    ]
    _patch_admin(monkeypatch, {})

    def ids(query: dict) -> set[str]:
        handler = FakeJsonHandler()
        _admin_handler.handle_admin_images_reviews(handler, db, query)
        assert handler.status_code == HTTPStatus.OK
        return {row["id"] for row in handler.payload()["data"]}

    assert ids({}) == {"u-pending", "u-risk"}
    assert ids({"status": ["approved"]}) == {"u-approved"}
    assert ids({"status": ["all"]}) == {"u-pending", "u-risk", "u-approved", "u-rejected"}


def test_pin_and_level_notes_are_stored_where_they_are_read(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db
    from services._user_service import (
        serialize_admin_post_pin_request,
        serialize_admin_user_level_request,
    )

    db = default_db()
    user = _user("lvl-user", "2500301@stu.xidian.edu.cn")
    db["users"].append(user)
    db["userLevelRequests"] = [{
        "id": "lr-1", "userId": user["id"], "currentLevel": 2, "targetLevel": 1,
        "status": "pending", "createdAt": "2026-09-01T00:00:00+00:00",
    }]
    _patch_admin(monkeypatch, {"action": "reject", "reviewNote": "资料不足"})
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_user_level_request_action(handler, db, "lr-1")
    assert handler.status_code == HTTPStatus.OK
    row = serialize_admin_user_level_request(db, db["userLevelRequests"][0])
    assert row["adminNote"] == "资料不足"
    assert row["userDeleted"] is False
    assert row["userCurrentLevel"] == 2
    assert row["userCurrentLevelLabel"]

    pin_row = serialize_admin_post_pin_request(db, {
        "id": "pr-1", "postId": "missing", "userId": user["id"],
        "durationMinutes": 60, "status": "pending",
    })
    assert pin_row["postDeleted"] is True
    assert pin_row["postPinned"] is False
    assert pin_row["durationLabel"]
    assert pin_row["userLevel"] == 2


def test_cancellation_note_is_kept(monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    user = _user("cr-user", "2500302@stu.xidian.edu.cn")
    db["users"].append(user)
    db["accountCancellationRequests"] = [{
        "id": "cr-1", "userId": user["id"], "status": "pending",
    }]
    _patch_admin(monkeypatch, {"action": "reject", "note": "有未处理的举报"})
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_cancellation_action(handler, db, "cr-1")
    assert handler.status_code == HTTPStatus.OK
    assert db["accountCancellationRequests"][0]["reviewNote"] == "有未处理的举报"


def test_admin_logout_answers_a_dead_session() -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    handler = FakeJsonHandler()
    handler.headers = {"Authorization": "Bearer expired-token"}
    _admin_handler.handle_admin_auth_logout(handler, default_db())
    assert handler.status_code == HTTPStatus.OK


def test_overview_and_export_carry_the_console_fields() -> None:
    from services._db_service import build_export_payload, build_overview, default_db

    overview = build_overview(default_db())
    for key in (
        "todayNewUsers", "todayPosts", "todayComments", "todayReports",
        "pendingReviews", "pendingCancellationRequests",
        "activeUsers", "bannedUsers", "mutedUsers",
    ):
        assert isinstance(overview[key], int), key

    export = build_export_payload(default_db(), scope="users", export_format="csv")
    assert export["fileName"].endswith(".csv")
    assert export["contentType"].startswith("text/csv")
    assert isinstance(export["rowCount"], int)
    assert isinstance(export["data"], str)
