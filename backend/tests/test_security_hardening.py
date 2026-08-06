"""安全加固回归测试。

每个用例对应一条已修复的审计结论，用来防止这些防护在后续重构中被悄悄改回去。
"""
from __future__ import annotations

import ipaddress
from http import HTTPStatus

import pytest


class _FakeHeaders(dict):
    def get(self, key, default=""):  # type: ignore[override]
        for existing, value in self.items():
            if existing.lower() == str(key).lower():
                return value
        return default


class _FakeHandler:
    def __init__(self, *, peer: str = "127.0.0.1", headers: dict | None = None) -> None:
        self.client_address = (peer, 12345)
        self.headers = _FakeHeaders(headers or {})


@pytest.fixture(autouse=True)
def _configured():
    import _globals

    _globals.configure()
    yield


# --- H1: X-Forwarded-For 只在可信代理后面才被采信 ---------------------------


def test_forwarded_for_ignored_from_untrusted_peer():
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="203.0.113.9",
        headers={"X-Forwarded-For": "1.2.3.4", "X-Real-IP": "5.6.7.8"},
    )
    assert get_client_ip(handler) == "203.0.113.9"


def test_forwarded_for_honoured_from_trusted_proxy():
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="127.0.0.1",
        headers={"X-Forwarded-For": "198.51.100.7"},
    )
    assert get_client_ip(handler) == "198.51.100.7"


def test_forwarded_for_takes_rightmost_untrusted_hop():
    """nginx 用 $proxy_add_x_forwarded_for 追加，伪造值会留在最左边。"""
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="127.0.0.1",
        headers={"X-Forwarded-For": "9.9.9.9, 198.51.100.7, 10.0.0.5"},
    )
    assert get_client_ip(handler) == "198.51.100.7"


def test_dual_stack_peer_is_recognised_as_trusted_proxy():
    """A ::ffff:127.0.0.1 peer must match 127.0.0.1/32.

    ipaddress compares versions before ranges, so without normalisation the
    local nginx would look untrusted and every client would share one bucket.
    """
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="::ffff:127.0.0.1",
        headers={"X-Forwarded-For": "198.51.100.7"},
    )
    assert get_client_ip(handler) == "198.51.100.7"


def test_ip_bucket_overflow_evicts_instead_of_clearing():
    """A flood must not be able to reset everyone else's quota."""
    import _globals
    from collections import deque
    from helpers import _rate_limit

    events = _globals.IP_RATE_LIMIT_EVENTS
    events.clear()
    now = 10_000.0
    # One long-idle bucket plus a flood of fresher ones.
    events["10.9.9.9"] = {"post": deque([now - 1])}
    for index in range(_rate_limit._IP_RATE_LIMIT_MAX_TRACKED_IPS + 50):
        events[f"flood-{index}"] = {"post": deque([now])}

    _rate_limit._IP_RATE_LIMIT_LAST_PRUNE = 0.0
    with _globals.IP_RATE_LIMIT_LOCK:
        _rate_limit._prune_ip_rate_limit_events(now)

    assert events, "overflow must evict, never wipe the whole table"
    assert len(events) <= _rate_limit._IP_RATE_LIMIT_MAX_TRACKED_IPS
    events.clear()


def test_rate_limit_queue_cap_never_hides_a_higher_configured_limit():
    """Admins can set a limit above RATE_LIMIT_EVENT_MAX from the config page.

    If the per-bucket queue were truncated below that, len(queue) >= limit would
    be unreachable and the limit would silently stop applying.
    """
    import _globals
    from helpers._rate_limit import consume_rate_limit
    from services._db_service import default_db

    limit = _globals.RATE_LIMIT_EVENT_MAX + 100
    db = default_db()
    db.setdefault("settings", {})["postRateLimit"] = limit

    allowed_count = 0
    for _ in range(limit + 20):
        allowed, _retry = consume_rate_limit(
            db,
            user_id="overflow-user",
            action="post",
            setting_key="postRateLimit",
            default_limit=20,
        )
        if allowed:
            allowed_count += 1
    assert allowed_count == limit


def test_trusted_proxy_networks_parsed_from_env():
    import _globals

    assert _globals.TRUSTED_PROXY_NETWORKS
    assert all(
        isinstance(net, (ipaddress.IPv4Network, ipaddress.IPv6Network))
        for net in _globals.TRUSTED_PROXY_NETWORKS
    )


# --- L9: 明文口令记录一律不被接受 ------------------------------------------


def test_plaintext_password_record_is_rejected():
    from helpers._auth_helpers import hash_password, verify_password

    assert verify_password("hunter2", "hunter2") is False
    assert verify_password("", "hunter2") is False
    assert verify_password(hash_password("hunter2"), "hunter2") is True
    assert verify_password(hash_password("hunter2"), "wrong") is False


# --- M7: 登录回跳只允许本站单斜杠路径 --------------------------------------


@pytest.mark.parametrize(
    "value",
    [
        "//evil.example.com",
        "/\\evil.example.com",
        "\\\\evil.example.com",
        "/\\/evil.example.com",
        "https://evil.example.com",
        "/ok\r\nLocation: https://evil.example.com",
    ],
)
def test_next_path_rejects_offsite_redirects(value):
    from handlers._auth_handler import _sanitize_next_path

    assert _sanitize_next_path(value) == "/"


def test_next_path_keeps_local_paths():
    from handlers._auth_handler import _sanitize_next_path

    assert _sanitize_next_path("/profile/auth") == "/profile/auth"
    assert _sanitize_next_path("") == "/"


# --- M5: 附件下载不得在本域被当作可执行内容 --------------------------------


class _RecordingHandler:
    def __init__(self) -> None:
        self.status_code = None
        self.sent_headers: list[tuple[str, str]] = []
        self.wfile = _Sink()
        self.headers = _FakeHeaders()

    def send_response(self, code):
        self.status_code = code

    def send_header(self, key, value):
        self.sent_headers.append((key, str(value)))

    def end_headers(self):
        pass

    def header_value(self, key):
        for name, value in self.sent_headers:
            if name.lower() == key.lower():
                return value
        return None


class _Sink:
    def write(self, _data):
        return None


def test_binary_download_is_sandboxed_and_not_sniffable():
    from helpers._http_helpers import send_binary

    handler = _RecordingHandler()
    send_binary(handler, HTTPStatus.OK, b"<svg onload=alert(1)>", "image/svg+xml")

    assert handler.header_value("X-Content-Type-Options") == "nosniff"
    csp = handler.header_value("Content-Security-Policy") or ""
    assert "sandbox" in csp
    assert "script-src" not in csp or "'unsafe-inline'" not in csp.split("script-src")[1][:40]
    assert handler.header_value("X-Frame-Options") == "DENY"
    assert (handler.header_value("Content-Disposition") or "").startswith("attachment")


def test_binary_download_filename_cannot_break_the_header():
    from helpers._http_helpers import send_binary

    handler = _RecordingHandler()
    send_binary(
        handler,
        HTTPStatus.OK,
        b"data",
        "application/octet-stream",
        filename='../../etc/passwd"\r\nX-Injected: 1',
    )

    disposition = handler.header_value("Content-Disposition") or ""
    assert "\r" not in disposition and "\n" not in disposition
    assert "../" not in disposition
    assert "X-Injected" not in disposition.split(";")[0]


# --- M6: 管理端会话会过期 ---------------------------------------------------


def test_admin_session_expires_after_max_age(monkeypatch):
    import _globals
    from services._db_service import auth_admin, default_db

    db = default_db()
    admin = db["adminAccounts"][0]
    token = "expiring-admin-token"

    handler = _FakeHandler(headers={"Authorization": f"Bearer {token}"})

    with _globals.ADMIN_SESSION_LOCK:
        _globals.ADMIN_SESSIONS[token] = str(admin["id"])
        _globals.ADMIN_SESSION_ISSUED_AT[token] = 1000.0

    try:
        monkeypatch.setattr("services._db_service.time.time", lambda: 1000.0 + 60)
        resolved, _ = auth_admin(handler, db)
        assert resolved is not None

        monkeypatch.setattr(
            "services._db_service.time.time",
            lambda: 1000.0 + _globals.ADMIN_SESSION_MAX_AGE_SECONDS + 1,
        )
        expired, _ = auth_admin(handler, db)
        assert expired is None
        assert token not in _globals.ADMIN_SESSIONS
        assert token not in _globals.ADMIN_SESSION_ISSUED_AT
    finally:
        with _globals.ADMIN_SESSION_LOCK:
            _globals.ADMIN_SESSIONS.pop(token, None)
            _globals.ADMIN_SESSION_ISSUED_AT.pop(token, None)


# --- 审计日志与失败登录不得被用作放大写入 -----------------------------------


def test_audit_log_rows_are_bounded():
    """save_db rewrites every table, so auditLogs must not grow without limit."""
    from services._db_service import add_audit_log, default_db

    db = default_db()
    add_audit_log(db, "", "x" * 500, "y" * 100_000)
    row = db["auditLogs"][-1]
    assert len(row["detail"]) <= 512
    assert len(row["action"]) <= 64


def test_failed_admin_login_does_not_write_to_the_database():
    """An unauthenticated wrong password must not trigger a full-DB rewrite."""
    import handlers._admin_handler as admin_handler

    saved: list[object] = []
    original_save = admin_handler.save_db
    admin_handler.save_db = lambda db: saved.append(db)
    try:
        from services._db_service import default_db

        db = default_db()
        before_logs = len(db["auditLogs"])
        handler = _LoginHandler({"username": "no-such-admin", "password": "nope"})
        admin_handler.handle_admin_auth_login(handler, db)

        assert handler.status_code == 401
        assert saved == [], "failed login must not call save_db"
        assert len(db["auditLogs"]) == before_logs
    finally:
        admin_handler.save_db = original_save


def test_oversized_admin_credentials_are_rejected_before_any_work():
    import handlers._admin_handler as admin_handler
    from services._db_service import default_db

    db = default_db()
    handler = _LoginHandler({"username": "a" * 5000, "password": "b" * 5000})
    admin_handler.handle_admin_auth_login(handler, db)
    assert handler.status_code == 400


class _LoginHandler(_RecordingHandler):
    def __init__(self, body: dict) -> None:
        super().__init__()
        import json

        raw = json.dumps(body).encode("utf-8")
        self._payload = raw
        self.headers = _FakeHeaders({"Content-Length": str(len(raw))})
        self.client_address = ("203.0.113.50", 1234)
        self.rfile = _ByteReader(raw)


class _ByteReader:
    def __init__(self, data: bytes) -> None:
        self._data = data

    def read(self, size: int) -> bytes:
        chunk, self._data = self._data[:size], self._data[size:]
        return chunk


# --- 统一认证票据解析不接受 DTD（实体展开炸弹） -----------------------------


def test_service_validate_rejects_dtd():
    from helpers import _xidian_auth

    bomb = (
        '<?xml version="1.0"?><!DOCTYPE lolz ['
        '<!ENTITY lol "lol">'
        '<!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;">'
        ']><lolz>&lol1;</lolz>'
    )
    with pytest.raises(_xidian_auth.XidianAuthUnavailableError):
        _xidian_auth._parse_service_validate_result(bomb)


# --- 审计日志回滚必须按 id，而非按下标 --------------------------------------


def test_audit_log_rollback_is_exact_when_the_table_is_full():
    """Positional rollback silently misbehaves once the cap starts trimming.

    At the cap, append+trim leaves len() unchanged, so `del rows[saved_len:]`
    removes nothing and the row the caller meant to undo survives.  Rolling back
    by id must remove exactly that row and nothing else.
    """
    from services import _db_service
    from services._db_service import add_audit_log, default_db, remove_audit_log

    db = default_db()
    # Seed ids must not collide with what next_id() will mint, or the assertion
    # below would trip over the duplicate rather than a real bug.
    db["auditLogs"] = [
        {
            "id": f"seed-{i}",
            "actorId": "",
            "action": "seed",
            "detail": "d",
            "createdAt": "",
        }
        for i in range(_db_service._AUDIT_LOG_MAX_ROWS)
    ]
    saved_len = len(db["auditLogs"])

    entry_id = add_audit_log(db, "", "upload_avatar", "更换头像")
    # The cap held the length steady, which is exactly what defeats a slice.
    assert len(db["auditLogs"]) == saved_len
    assert db["auditLogs"][-1]["id"] == entry_id

    assert remove_audit_log(db, entry_id) is True
    assert all(row["id"] != entry_id for row in db["auditLogs"])
    assert len(db["auditLogs"]) == saved_len - 1


def test_audit_log_rollback_removes_only_the_named_row():
    from services._db_service import add_audit_log, default_db, remove_audit_log

    db = default_db()
    db["auditLogs"] = []
    first = add_audit_log(db, "", "one", "a")
    target = add_audit_log(db, "", "two", "b")
    last = add_audit_log(db, "", "three", "c")

    assert remove_audit_log(db, target) is True
    assert [row["id"] for row in db["auditLogs"]] == [first, last]
    # Idempotent: a second rollback is a no-op, not a corruption.
    assert remove_audit_log(db, target) is False
    assert [row["id"] for row in db["auditLogs"]] == [first, last]
