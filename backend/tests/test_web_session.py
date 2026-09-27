"""Page-gate cookie for the static web frontend (Nginx auth_request)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


@pytest.fixture
def repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Any:
    import _globals
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    repository = SqliteTreeholeRepository(tmp_path / "gate.db")
    repository.initialize(default_db)
    db = repository.load_state()
    live = _user("u-live", "2500400@stu.xidian.edu.cn")
    gone = {**_user("u-gone", "2500401@stu.xidian.edu.cn"), "deleted": True}
    banned = {**_user("u-banned", "2500402@stu.xidian.edu.cn"), "banned": True}
    db["users"].extend([live, gone, banned])
    db["sessions"].update({"tok-live": "u-live", "tok-gone": "u-gone", "tok-banned": "u-banned"})
    repository.save_state(db)
    monkeypatch.setattr(_globals, "REPOSITORY", repository)
    return repository


def _cookies(handler: FakeJsonHandler) -> list[str]:
    return [value for key, value in handler.response_headers if key == "Set-Cookie"]


def _check(cookie: str) -> int:
    from handlers import _web_session_handler

    handler = FakeJsonHandler()
    if cookie:
        handler.headers["Cookie"] = cookie
    _web_session_handler.handle_auth_check(handler)
    return handler.status_code


def test_lookup_session_user_reads_one_row(repo: Any) -> None:
    assert repo.lookup_session_user("tok-live")["id"] == "u-live"
    assert repo.lookup_session_user("nope") is None
    assert repo.lookup_session_user("") is None


def test_lookup_session_user_honours_the_session_age_cutoff(repo: Any) -> None:
    from sql_repository import SESSION_MAX_AGE_DAYS

    stale = (
        datetime.now(timezone.utc) - timedelta(days=SESSION_MAX_AGE_DAYS + 1)
    ).isoformat()
    with repo._connect() as conn:
        conn.execute("UPDATE sessions SET created_at = ? WHERE token = 'tok-live'", (stale,))
    assert repo.lookup_session_user("tok-live") is None
    # auth_user draws on load_state, which applies the same cutoff.
    assert "tok-live" not in repo.load_state()["sessions"]


def test_check_passes_a_live_session_and_a_banned_one(repo: Any) -> None:
    assert _check("zx_session=tok-live") == HTTPStatus.NO_CONTENT
    # Banned accounts still need their pages: the ban notice and the appeal.
    assert _check("other=1; zx_session=tok-banned") == HTTPStatus.NO_CONTENT


@pytest.mark.parametrize("cookie", ["", "zx_session=", "zx_session=nope", "zx_session=tok-gone"])
def test_check_refuses_everything_else(repo: Any, cookie: str) -> None:
    assert _check(cookie) == HTTPStatus.UNAUTHORIZED


def test_check_follows_the_private_beta_allowlist(repo: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    import _globals

    monkeypatch.setattr(_globals, "AUTH_ALLOWED_STUDENT_IDS", {"someone-else"})
    assert _check("zx_session=tok-live") == HTTPStatus.UNAUTHORIZED


def test_check_ignores_the_authorization_header(repo: Any) -> None:
    from handlers import _web_session_handler

    handler = FakeJsonHandler()
    handler.headers["Authorization"] = "Bearer tok-live"
    _web_session_handler.handle_auth_check(handler)
    assert handler.status_code == HTTPStatus.UNAUTHORIZED


def test_create_mirrors_the_bearer_token_into_an_httponly_cookie(
    repo: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    from handlers import _web_session_handler

    user = _user("u-live", "2500400@stu.xidian.edu.cn")
    monkeypatch.setattr(_web_session_handler, "auth_user_helper", lambda _h, _db: (user, "tok-live"))
    handler = FakeJsonHandler()
    _web_session_handler.handle_web_session_create(handler, {})

    assert handler.status_code == HTTPStatus.NO_CONTENT
    [cookie] = _cookies(handler)
    assert cookie.startswith("zx_session=tok-live;")
    assert "HttpOnly" in cookie and "SameSite=Lax" in cookie and "Path=/" in cookie
    assert "Max-Age=2592000" in cookie
    # The cookie it sets is the one the gate accepts.
    assert _check(cookie.split(";", 1)[0]) == HTTPStatus.NO_CONTENT


@pytest.mark.parametrize("auth", [(None, None), (None, "dead-token")])
def test_create_needs_a_live_session(
    monkeypatch: pytest.MonkeyPatch, auth: tuple[Any, Any]
) -> None:
    from handlers import _web_session_handler

    monkeypatch.setattr(_web_session_handler, "auth_user_helper", lambda _h, _db: auth)
    handler = FakeJsonHandler()
    _web_session_handler.handle_web_session_create(handler, {})
    assert handler.status_code == HTTPStatus.UNAUTHORIZED
    assert _cookies(handler) == []


def test_delete_expires_the_cookie() -> None:
    from handlers import _web_session_handler

    handler = FakeJsonHandler()
    _web_session_handler.handle_web_session_delete(handler)
    assert handler.status_code == HTTPStatus.NO_CONTENT
    [cookie] = _cookies(handler)
    assert cookie.startswith("zx_session=;") and "Max-Age=0" in cookie


def test_routes_are_wired_where_the_session_floor_expects() -> None:
    import server

    # Creating the cookie needs a session; clearing it and checking it do not
    # go through the floor at all (they are dispatched before it).
    assert not server._is_session_exempt("/api/auth/web-session")
    assert "/api/auth/web-session" in server._BANNED_ALLOWED_PATHS


@pytest.mark.parametrize(
    ("origin", "secure"),
    [("https://zhixing.xidian.edu.cn", True), ("http://zhixing.xidian.edu.cn", False), ("", False)],
)
def test_cookie_is_secure_only_behind_https(
    monkeypatch: pytest.MonkeyPatch, origin: str, secure: bool
) -> None:
    import _globals
    from handlers import _web_session_handler

    # An unset origin (IDS off, local dev) must not break the gate.
    monkeypatch.setattr(_globals, "BACKEND_XIDIAN_PUBLIC_ORIGIN", origin, raising=False)
    handler = FakeJsonHandler()
    _web_session_handler.handle_web_session_delete(handler)
    [cookie] = _cookies(handler)
    assert ("Secure" in cookie) is secure
