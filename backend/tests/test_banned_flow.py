"""A banned account learns it at sign-in, so clients can go straight to the appeal screen."""
from __future__ import annotations

import time

import pytest

from tests.test_logic_regressions import FakeJsonHandler


def _authenticated_attempt(monkeypatch: pytest.MonkeyPatch, **values: object) -> None:
    from handlers import _auth_handler

    attempt = {
        "id": "a1",
        "status": "authenticated",
        "platform": "mobile",
        "token": "tok",
        "email": "2500300@stu.xidian.edu.cn",
        "studentId": "2500300",
        "consumed": False,
        "expiresAtTs": time.time() + 60,
        **values,
    }
    monkeypatch.setitem(_auth_handler._XIDIAN_AUTH_ATTEMPTS, "a1", attempt)


@pytest.mark.parametrize("banned", [True, False])
def test_session_poll_reports_whether_the_account_is_banned(
    monkeypatch: pytest.MonkeyPatch,
    banned: bool,
) -> None:
    from handlers import _auth_handler

    _authenticated_attempt(monkeypatch, banned=banned)
    handler = FakeJsonHandler()
    _auth_handler.handle_xidian_auth_get_session(handler, {}, "a1")

    data = handler.payload()["data"]
    assert data["token"] == "tok"
    assert data["banned"] is banned


def test_a_used_result_says_so_instead_of_handing_out_the_token_again(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _auth_handler

    _authenticated_attempt(monkeypatch, consumed=True, banned=True)
    handler = FakeJsonHandler()
    _auth_handler.handle_xidian_auth_get_session(handler, {}, "a1")

    data = handler.payload()["data"]
    assert "token" not in data
    assert data["message"] == "登录结果已使用，请重新发起登录"


def test_the_ticket_callback_stores_the_ban_on_the_attempt(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from types import SimpleNamespace

    from handlers import _auth_handler

    _authenticated_attempt(monkeypatch, status="pending", token="", banned=None)
    monkeypatch.setattr(_auth_handler, "_read_cookie", lambda _h, _name: "a1")
    monkeypatch.setattr(_auth_handler, "_web_callback_service_url", lambda _h: "https://x/cb")
    monkeypatch.setattr(
        _auth_handler,
        "validate_xidian_service_ticket",
        lambda _t, _s: SimpleNamespace(student_id="2500300", campus_email="2500300@stu.xidian.edu.cn"),
    )
    monkeypatch.setattr(
        _auth_handler,
        "_issue_auth_payload_with_lock",
        lambda _db, **_k: {
            "token": "tok", "verified": True, "isAdmin": False,
            "email": "2500300@stu.xidian.edu.cn", "studentId": "2500300", "banned": True,
        },
    )
    handler = FakeJsonHandler()
    _auth_handler.handle_xidian_auth_callback(handler, {}, {"ticket": ["ST-1"]})

    assert _auth_handler._XIDIAN_AUTH_ATTEMPTS["a1"]["banned"] is True
