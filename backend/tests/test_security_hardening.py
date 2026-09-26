"""安全加固回归测试。

每个用例对应一条已修复的审计结论，用来防止这些防护在后续重构中被悄悄改回去。
"""
from __future__ import annotations

import base64
import io
import ipaddress
import json
import re
from http import HTTPStatus
from pathlib import Path

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


def test_forwarded_for_takes_the_rightmost_hop_only():
    """nginx 用 $proxy_add_x_forwarded_for 追加，伪造值会留在最左边。

    只有最右一项是可信代理亲眼看到的地址，客户端无法伪造；左侧全部是
    客户端提供的。早期实现会把"私网地址"当成代理跳过，于是从 10.0.0.5
    连进来的攻击者只要自带 XFF 就能冒充 198.51.100.7。
    """
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="127.0.0.1",
        headers={"X-Forwarded-For": "9.9.9.9, 198.51.100.7, 10.0.0.5"},
    )
    assert get_client_ip(handler) == "10.0.0.5"


def test_private_client_addresses_do_not_collapse_into_one_bucket():
    """校园 NAT / VPN 客户端是普通客户端，不是代理跳。

    把它们当成代理会让 get_client_ip 一路回退到 nginx 的地址，于是所有
    内网用户共用一个限流桶，互相耗尽登录 / 上传 / AI 配额。
    """
    from helpers._rate_limit import get_client_ip

    seen = {
        get_client_ip(
            _FakeHandler(peer="127.0.0.1", headers={"X-Real-IP": address})
        )
        for address in ("10.1.2.3", "10.1.2.4", "192.168.7.7", "172.16.0.9")
    }
    assert seen == {"10.1.2.3", "10.1.2.4", "192.168.7.7", "172.16.0.9"}


def test_real_ip_from_a_trusted_peer_wins_over_forwarded_for():
    """所有部署配置都写死 `X-Real-IP $remote_addr`，会覆盖客户端来值。"""
    from helpers._rate_limit import get_client_ip

    handler = _FakeHandler(
        peer="127.0.0.1",
        headers={
            "X-Real-IP": "198.51.100.7",
            "X-Forwarded-For": "9.9.9.9, 203.0.113.1",
        },
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


def test_rate_limit_subject_table_is_bounded(monkeypatch):
    import _globals
    from helpers._rate_limit import consume_rate_limit
    from services._db_service import default_db

    monkeypatch.setattr(_globals, "RATE_LIMIT_SUBJECT_MAX", 3)
    _globals.RATE_LIMIT_EVENTS.clear()
    db = default_db()
    for index in range(8):
        consume_rate_limit(
            db,
            user_id=f"subject-{index}",
            action="post",
            setting_key="postRateLimit",
            default_limit=20,
        )
    assert len(_globals.RATE_LIMIT_EVENTS) == 3
    _globals.RATE_LIMIT_EVENTS.clear()


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


def test_avatar_urls_are_first_party_and_object_keys_are_canonical():
    from helpers._auth_helpers import (
        extract_local_object_key_from_url,
        normalize_avatar_url,
    )

    assert normalize_avatar_url("https://tracker.example/avatar.png") == ""
    assert normalize_avatar_url("/api/storage/avatars/own.png") == "/api/storage/avatars/own.png"
    assert extract_local_object_key_from_url(
        "https://evil.example/api/storage/avatars/victim.png",
    ) == ""
    assert extract_local_object_key_from_url(
        "/api/storage/avatars/own.png",
    ) == "avatars/own.png"


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


def test_xidian_attempt_can_only_be_claimed_once():
    from handlers import _auth_handler

    attempt = _auth_handler._create_auth_attempt(platform="web")
    try:
        first = _auth_handler._claim_attempt_for_validation(attempt["id"])
        second = _auth_handler._claim_attempt_for_validation(attempt["id"])
        assert first is not None
        assert first["status"] == "validating"
        assert second is None
    finally:
        with _auth_handler._ATTEMPT_LOCK:
            _auth_handler._XIDIAN_AUTH_ATTEMPTS.pop(attempt["id"], None)


def test_xidian_authenticated_result_can_only_be_consumed_once():
    from handlers import _auth_handler

    attempt = _auth_handler._create_auth_attempt(platform="mobile")
    _auth_handler._update_attempt(
        attempt["id"],
        status="authenticated",
        token="secret-session",
    )
    try:
        first, first_delivered = _auth_handler._poll_attempt_once(attempt["id"])
        second, second_delivered = _auth_handler._poll_attempt_once(attempt["id"])
        assert first is not None and first["token"] == "secret-session"
        assert second is not None
        assert first_delivered is True
        assert second_delivered is False
    finally:
        with _auth_handler._ATTEMPT_LOCK:
            _auth_handler._XIDIAN_AUTH_ATTEMPTS.pop(attempt["id"], None)


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


@pytest.mark.parametrize(
    "password",
    ["short", "admin123456", "change-me-now", "replace-me"],
)
def test_runtime_admin_password_policy_matches_production(password):
    import _globals

    assert _globals.admin_password_policy_error(password)


def test_admin_password_policy_accepts_non_placeholder_12_chars():
    import _globals

    assert _globals.admin_password_policy_error("correct-horse-2026") == ""


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


def test_csv_export_neutralizes_formula_cells_but_json_stays_raw():
    from services._db_service import build_export_payload, default_db

    db = default_db()
    db["comments"] = [{
        "id": "c-formula",
        "postId": "p1",
        "userId": "u1",
        "authorAlias": "tester",
        "content": "  =HYPERLINK(\"https://evil.example\")",
        "createdAt": "2026-08-10T00:00:00+08:00",
        "reviewStatus": "approved",
        "deleted": False,
    }]
    csv_payload = build_export_payload(db, scope="comments", export_format="csv")["data"]
    json_payload = json.loads(
        build_export_payload(db, scope="comments", export_format="json")["data"],
    )
    assert "'  =HYPERLINK" in csv_payload
    assert json_payload["rows"][0][4].startswith("  =HYPERLINK")


class _StreamingResponse:
    def __init__(self, chunks: list[bytes], headers: dict[str, str] | None = None) -> None:
        self._chunks = chunks
        self.headers = headers or {}
        self.closed = False

    def iter_content(self, chunk_size: int):
        assert chunk_size > 0
        yield from self._chunks

    def close(self) -> None:
        self.closed = True


def test_campus_response_limit_rejects_declared_and_streamed_oversize():
    from helpers import _campus_auth

    declared = _StreamingResponse([], {"Content-Length": "11"})
    with pytest.raises(_campus_auth.CampusAuthError, match="大小限制"):
        _campus_auth._read_response_bytes(declared, 10)
    assert declared.closed is True

    streamed = _StreamingResponse([b"123456", b"78901"])
    with pytest.raises(_campus_auth.CampusAuthError, match="大小限制"):
        _campus_auth._read_response_bytes(streamed, 10)
    assert streamed.closed is True


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


# --- 2026-08 三端复扫：授权、隐私、资源与部署边界 --------------------------


def test_college_section_authorization_ignores_editable_profile_college(monkeypatch):
    import _globals
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["studentId"] = "2500001"
    user["college"] = "计算机科学与技术学院"
    monkeypatch.setattr(_globals, "AUTH_STUDENT_COLLEGE_SECTIONS", {"2500001": "ee"})
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = _LoginHandler({
        "content": "不能依赖自填学院发帖",
        "sectionType": "college",
        "sectionId": "cs",
    })
    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == HTTPStatus.FORBIDDEN


def test_college_section_authorization_accepts_server_mapping(monkeypatch):
    import _globals
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["studentId"] = "2500001"
    user["college"] = "攻击者自填值"
    monkeypatch.setattr(_globals, "AUTH_STUDENT_COLLEGE_SECTIONS", {"2500001": "ee"})
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = _LoginHandler({
        "content": "可信映射允许的学院帖子",
        "sectionType": "college",
        "sectionId": "ee",
    })
    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == HTTPStatus.OK


def test_club_publisher_cannot_target_another_club_section(monkeypatch):
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    db["clubs"] = [
        {"id": "club-a", "sectionId": "section-a", "name": "社团 A", "status": "active"},
        {"id": "club-b", "sectionId": "section-b", "name": "社团 B", "status": "active"},
    ]
    db["clubMembers"] = [
        {"clubId": "club-a", "userId": user["id"], "role": "manager"},
    ]
    db["sections"] = [
        {"id": "sec-a", "sectionId": "section-a", "sectionType": "club", "sectionName": "社团 A", "enabled": True},
        {"id": "sec-b", "sectionId": "section-b", "sectionType": "club", "sectionName": "社团 B", "enabled": True},
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = _LoginHandler({
        "content": "跨社团注入",
        "publisherType": "club",
        "publisherClubId": "club-a",
        "sectionType": "club",
        "sectionId": "section-b",
    })
    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == HTTPStatus.FORBIDDEN


def test_anonymous_comment_projection_hides_stable_identity():
    from handlers._post_handler import _serialize_comment
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["avatarUrl"] = "/api/storage/avatar/real.png"
    payload = _serialize_comment(db, {
        "id": "anonymous-comment",
        "postId": "p1",
        "userId": user["id"],
        "authorAlias": "匿名同学",
        "content": "匿名内容",
        "isAnonymous": True,
    }, viewer_user_id="")

    assert payload["authorId"] == ""
    assert payload["authorUserId"] == ""
    assert payload["authorAvatarUrl"] == ""
    assert payload["authorAvatar"] == ""


def test_public_club_detail_returns_only_member_count(monkeypatch):
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    db["clubs"] = [{"id": "club-a", "name": "社团 A", "status": "active", "sectionId": "section-a"}]
    db["clubMembers"] = [{"id": "cm1", "clubId": "club-a", "userId": "u1", "role": "owner", "createdAt": "now"}]
    monkeypatch.setattr(_radio_handler, "auth_user_helper", lambda _h, _db: (None, ""))
    handler = _RecordingHandler()
    handler.wfile = io.BytesIO()

    _radio_handler.handle_get_club(handler, db, "club-a")
    payload = json.loads(handler.wfile.getvalue().decode("utf-8"))["data"]

    assert "members" not in payload
    assert payload["memberCount"] == 1


def test_avatar_replacement_tracks_new_object_and_deletes_old(monkeypatch):
    from handlers import _upload_handler
    from object_storage import StoredObject
    from services._db_service import default_db

    class Storage:
        def __init__(self) -> None:
            self.deleted: list[str] = []

        def put_bytes(self, **_kwargs):
            return StoredObject(key="new/avatar.png", url="/api/storage/new/avatar.png", size_bytes=12)

        def delete(self, key: str) -> None:
            self.deleted.append(key)

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["avatarUrl"] = "/api/storage/old/avatar.png"
    storage = Storage()
    monkeypatch.setattr(_upload_handler, "auth_user_helper", lambda _h, _db: (user, "token"))
    monkeypatch.setattr(_upload_handler, "check_ip_rate_limit", lambda _h, _a: (True, 0))
    monkeypatch.setattr(_upload_handler, "consume_rate_limit", lambda *_a, **_k: (True, 0))
    monkeypatch.setattr(_upload_handler, "save_db", lambda _db: None)
    monkeypatch.setattr(_upload_handler._globals, "OBJECT_STORAGE", storage)
    monkeypatch.setattr(_upload_handler, "read_json_body", lambda _h: {
        "avatarDataBase64": base64.b64encode(b"\x89PNG\r\n\x1a\n\x00\x00\x00\x00").decode("ascii"),
        "fileName": "avatar.png",
        "avatarContentType": "image/png",
    })

    handler = _RecordingHandler()
    _upload_handler.handle_upload_avatar(handler, db)

    assert handler.status_code == HTTPStatus.OK
    assert storage.deleted == ["old/avatar.png"]
    assert any(row.get("objectKey") == "new/avatar.png" for row in db["mediaUploads"])


def test_ai_post_selection_does_not_persist_unbounded_history(monkeypatch):
    from handlers import _ai_handler, _radio_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    db["aiMessages"] = [{"id": "existing"}]
    saved: list[dict] = []
    monkeypatch.setattr(_radio_handler, "_require_user", lambda _h, _db: user)
    monkeypatch.setattr(_radio_handler, "read_json_body", lambda _h: {"selectedText": "测试"})
    monkeypatch.setattr(_radio_handler, "save_db", lambda value: saved.append(value))
    handler = _RecordingHandler()
    calls = []

    def chat(h, state, *, body, text_task):
        assert text_task is True
        calls.append(body)
        _radio_handler.send_json(h, HTTPStatus.OK, {"data": {"answer": "模型回答"}})

    monkeypatch.setattr(_ai_handler, "handle_ai_chat", chat)

    _radio_handler.handle_ai_post_selection(handler, db)

    assert handler.status_code == HTTPStatus.OK
    assert db["aiMessages"] == [{"id": "existing"}]
    assert saved == []
    assert calls[0]["messages"] == []
    assert "测试" in calls[0]["content"]


def test_interaction_notifications_are_deduplicated():
    from services._db_service import default_db
    from services._user_service import create_notification

    db = default_db()
    db["notifications"] = []
    for _ in range(2):
        create_notification(
            db,
            user_id="u1",
            notification_type="like",
            title="收到点赞",
            content="帖子",
            related_type="post",
            related_id="p1",
            actor_id="seed-user-1",
        )
    assert len(db["notifications"]) == 1


def test_dorm_water_phone_has_one_canonical_rate_limit_value():
    from helpers import _campus_auth

    assert _campus_auth.normalize_dorm_water_phone("138 0013\t8000") == "13800138000"


def test_nonexistent_admin_still_performs_password_verification(monkeypatch):
    import handlers._admin_handler as admin_handler
    from services._db_service import default_db

    calls: list[tuple[str, str]] = []
    monkeypatch.setattr(
        admin_handler,
        "verify_password",
        lambda stored, candidate: calls.append((stored, candidate)) or False,
    )
    handler = _LoginHandler({"username": "no-such-admin", "password": "wrong-password"})
    admin_handler.handle_admin_auth_login(handler, default_db())

    assert handler.status_code == HTTPStatus.UNAUTHORIZED
    assert len(calls) == 1
    assert calls[0][0].startswith("pbkdf2_sha256$")


def test_ai_provider_response_is_read_with_a_hard_byte_limit(monkeypatch):
    from handlers import _ai_handler

    class Response:
        headers = {}

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self, size: int = -1) -> bytes:
            if size < 0:
                raise AssertionError("provider response must never be read without a byte limit")
            return b"x" * size

    monkeypatch.setattr(_ai_handler, "urlopen", lambda *_a, **_k: Response())
    with pytest.raises(RuntimeError, match="过大"):
        _ai_handler._read_provider_json(object())


def test_release_configs_stream_apk_body_to_backend_before_buffering():
    root = Path(__file__).resolve().parents[2]
    for relative in (
        "deploy/production/nginx-treehole-https.conf.template",
        "deploy/production/nginx-container.conf",
        "deploy/tencent/nginx-xdu-whisperbox.conf",
    ):
        source = (root / relative).read_text()
        block = source.split("location = /api/admin/releases/android", 1)[1].split("}", 1)[0]
        assert "proxy_request_buffering off;" in block
        assert "proxy_request_buffering on;" not in block


def test_offline_install_requires_explicit_tls_nginx_config():
    root = Path(__file__).resolve().parents[2]
    installer = (root / "scripts/install_ubuntu_offline.sh").read_text()
    deploy = (root / "scripts/deploy_tencent.sh").read_text()

    assert "NGINX_CONFIG_PATH" in installer
    assert "listen 443 ssl" in installer
    assert "DEPLOY_NGINX_CONFIG" in deploy
    assert "https://$DEPLOY_HOST/" in deploy


# --- 按作者过滤不得成为匿名帖的归属证明 -------------------------------------


def _db_with_one_anonymous_and_one_named_post():
    from services._db_service import default_db

    db = default_db()
    db["posts"] = [
        {
            "id": "p-named", "title": "实名帖", "content": "named", "channel": "综合",
            "authorId": "u1", "authorAlias": "示范同学", "isAnonymous": False,
            "createdAt": "2026-01-01T00:00:00+00:00", "reviewStatus": "approved",
            "visibility": "public", "deleted": False,
        },
        {
            "id": "p-anon", "title": "匿名帖", "content": "secret", "channel": "综合",
            "authorId": "u1", "authorAlias": "洞主-夜灯", "isAnonymous": True,
            "createdAt": "2026-01-02T00:00:00+00:00", "reviewStatus": "approved",
            "visibility": "public", "deleted": False,
        },
    ]
    return db


def _get_posts_ids(db, *, viewer, author_id):
    from handlers import _post_handler

    handler = _RecordingHandler()
    captured: dict = {}

    def _capture(_handler, _status, payload, **_kwargs):
        captured["payload"] = payload

    original_send_json = _post_handler.send_json
    _post_handler.send_json = _capture
    try:
        _post_handler.handle_get_posts(handler, db, {"authorId": [author_id]})
    finally:
        _post_handler.send_json = original_send_json

    rows = captured["payload"]["data"]
    if isinstance(rows, dict):
        rows = rows.get("items", [])
    return [row["id"] for row in rows]


def test_author_filter_never_confirms_authorship_of_an_anonymous_post(monkeypatch):
    from handlers import _post_handler

    db = _db_with_one_anonymous_and_one_named_post()
    # A different logged-in user probing u1.  Emptying authorUserId in the body
    # is not enough — being returned at all for authorId=u1 is the disclosure.
    monkeypatch.setattr(
        _post_handler, "auth_user_helper", lambda _h, _db: ({"id": "u2"}, "t"),
    )

    assert _get_posts_ids(db, viewer="u2", author_id="u1") == ["p-named"]


def test_author_filter_still_shows_the_author_their_own_anonymous_posts(monkeypatch):
    from handlers import _post_handler

    db = _db_with_one_anonymous_and_one_named_post()
    monkeypatch.setattr(
        _post_handler, "auth_user_helper", lambda _h, _db: ({"id": "u1"}, "t"),
    )

    assert sorted(_get_posts_ids(db, viewer="u1", author_id="u1")) == ["p-anon", "p-named"]


# --- 登录门必须由服务端强制，而不是靠客户端自觉 -----------------------------


def test_content_endpoints_require_a_session_regardless_of_client_header():
    import server

    # Dropping X-Client-Type used to be enough to read the whole forum.
    for path in (
        "/api/posts",
        "/api/posts/p1",
        "/api/announcements",
        "/api/channels",
        "/api/sections",
        "/api/hot-topics",
        "/api/campus/services",
        "/api/users/me",
        "/api/notifications",
    ):
        assert not server._is_session_exempt(path), path


def test_session_gate_exempts_only_the_endpoints_that_cannot_have_one():
    import server

    for path in (
        "/api/health",
        "/api/version",
        "/api/auth/xidian/session",
        "/api/auth/xidian/session/abc123",
        "/api/auth/xidian/start",
        "/api/auth/xidian/callback",
        "/api/releases/android/latest",
        # Separate credential namespaces, enforced by their own handlers.
        "/api/admin/auth/login",
        "/api/admin/overview",
        "/api/appeals",
        # Capability urls: image loaders cannot send Authorization.
        "/api/storage/ab/cdef0123456789",
    ):
        assert server._is_session_exempt(path), path


def test_every_api_dispatch_block_is_gated_and_unlocks_before_responding():
    import inspect

    import server

    for method in (
        server.TreeholeHandler._handle_get,
        server.TreeholeHandler._handle_post,
        server.TreeholeHandler._handle_patch,
        server.TreeholeHandler._handle_delete,
    ):
        source = inspect.getsource(method)
        name = method.__name__
        # The session gate is the floor for every /api route (H2)…
        assert "_require_api_session(self, path, db)" in source, name
        # …and the dispatch block must not hold DB_LOCK across the response
        # write (H3).  Reverting this to a bare `with DB_LOCK:` trips here.
        # The remaining narrow `with DB_LOCK: db = load_db()` uses in these
        # methods are fine — they release before their handler responds.
        assert "with _locked_response(self):" in source, name


def test_session_gate_rejects_missing_deleted_and_banned_accounts(monkeypatch):
    import server

    handler = _RecordingHandler()

    monkeypatch.setattr(server, "auth_user_helper", lambda _h, _db: (None, None))
    assert server._require_api_session(handler, "/api/posts", {}) is False
    assert handler.status_code == HTTPStatus.UNAUTHORIZED

    handler = _RecordingHandler()
    monkeypatch.setattr(
        server, "auth_user_helper", lambda _h, _db: ({"id": "u1", "deleted": True}, "t"),
    )
    assert server._require_api_session(handler, "/api/posts", {}) is False
    assert handler.status_code == HTTPStatus.UNAUTHORIZED

    handler = _RecordingHandler()
    monkeypatch.setattr(
        server, "auth_user_helper", lambda _h, _db: ({"id": "u1", "banned": True}, "t"),
    )
    assert server._require_api_session(handler, "/api/posts", {}) is False
    assert handler.status_code == HTTPStatus.FORBIDDEN

    handler = _RecordingHandler()
    monkeypatch.setattr(
        server, "auth_user_helper", lambda _h, _db: ({"id": "u1"}, "t"),
    )
    assert server._require_api_session(handler, "/api/posts", {}) is True


# --- DB_LOCK 不得在响应写 socket 期间被持有 ---------------------------------


class _LockProbingWriter:
    """Records whether DB_LOCK was free at the moment bytes hit the socket."""

    def __init__(self, lock) -> None:
        self._lock = lock
        self.chunks: list[bytes] = []
        self.lock_was_free: list[bool] = []

    def write(self, data: bytes) -> None:
        acquired = self._lock.acquire(blocking=False)
        self.lock_was_free.append(acquired)
        if acquired:
            self._lock.release()
        self.chunks.append(bytes(data))


def test_response_is_written_to_the_socket_after_db_lock_is_released():
    import server

    handler = _RecordingHandler()
    probe = _LockProbingWriter(server.DB_LOCK)
    handler.wfile = probe

    with server._locked_response(handler):
        # Stand-in for a handler body: writes its response while holding the
        # lock.  Those writes must land in the buffer, not on the socket.
        assert server.DB_LOCK.locked()
        handler.wfile.write(b"chunk-one")
        handler.wfile.write(b"chunk-two")
        assert probe.chunks == []

    assert probe.chunks == [b"chunk-onechunk-two"]
    assert probe.lock_was_free == [True]


def test_stalled_socket_write_does_not_surface_as_a_server_error():
    import server

    class _BrokenPipe:
        def write(self, _data):
            raise BrokenPipeError(32, "Broken pipe")

    handler = _RecordingHandler()
    handler.wfile = _BrokenPipe()
    handler.close_connection = False

    # A client that disconnects mid-response is not a 500.
    with server._locked_response(handler):
        handler.wfile.write(b"payload")

    assert handler.close_connection is True


def test_large_uploads_are_drained_before_the_lock_is_taken():
    import inspect

    import server
    from handlers import _admin_handler

    source = inspect.getsource(server.TreeholeHandler._handle_post)
    drain_at = source.index("read_multipart_form")
    lock_at = source.index("_locked_response")
    assert drain_at < lock_at, "APK 上传必须在取 DB_LOCK 之前读完"

    # The handler replays whatever the pre-read hit, so its error responses
    # (413 "安装包大小不能超过 300MB") stay intact.
    class _Handler:
        pass

    handler = _Handler()
    handler._cached_multipart_error = RequestBodyTooLargeStub()
    with pytest.raises(RequestBodyTooLargeStub):
        _admin_handler.read_multipart_form(handler)

    handler = _Handler()
    handler._cached_multipart_form = {"versionName": "1.0.0"}
    assert _admin_handler.read_multipart_form(handler) == {"versionName": "1.0.0"}


class RequestBodyTooLargeStub(Exception):
    pass


# --- nginx: 安全响应头不得被 location 级 add_header 抵消 ---------------------


_NGINX_CONFIGS = (
    "deploy/production/nginx-container.conf",
    "deploy/production/nginx-treehole-https.conf.template",
    "deploy/tencent/nginx-xdu-whisperbox.conf",
)


def _nginx_location_blocks(source: str):
    """Yield (header_line, body) for every `location ... {` block."""
    for index, line in enumerate(source.splitlines()):
        if not line.strip().startswith("location "):
            continue
        depth = 0
        body: list[str] = []
        for following in source.splitlines()[index:]:
            depth += following.count("{") - following.count("}")
            body.append(following)
            if depth == 0 and body:
                break
        yield line.strip(), "\n".join(body)


@pytest.mark.parametrize("relative", _NGINX_CONFIGS)
def test_no_location_block_shadows_the_inherited_security_headers(relative):
    """nginx 的 add_header 不继承：location 自带一条就会丢掉 server 级全部。

    修复前 `location = /index.html` 为了写 Cache-Control 用了 add_header，
    于是主文档在几乎每次加载时都没有 CSP / HSTS / X-Frame-Options。
    """
    source = (Path(__file__).resolve().parents[2] / relative).read_text()
    offenders = [
        header
        for header, body in _nginx_location_blocks(source)
        if "add_header" in body
    ]
    assert offenders == [], f"{relative}: {offenders}"


@pytest.mark.parametrize("relative", _NGINX_CONFIGS)
def test_server_level_security_headers_are_complete(relative):
    source = (Path(__file__).resolve().parents[2] / relative).read_text()
    for directive in (
        'add_header X-Content-Type-Options "nosniff" always;',
        'add_header X-Frame-Options "SAMEORIGIN" always;',
        'add_header Referrer-Policy "strict-origin-when-cross-origin" always;',
        "add_header Permissions-Policy ",
        "add_header Content-Security-Policy ",
    ):
        assert directive in source, f"{relative} 缺少 {directive}"

    csp = source.split("add_header Content-Security-Policy \"", 1)[1].split('"', 1)[0]
    for directive in (
        "default-src 'self'",
        "base-uri 'self'",
        "object-src 'none'",
        "frame-ancestors 'self'",
        "form-action 'self'",
    ):
        assert directive in csp, f"{relative} CSP 缺少 {directive}"


def test_web_build_pins_canvaskit_to_our_own_origin():
    """CanvasKit 走 gstatic CDN 时 CSP 无法收紧，也多一个第三方运行时依赖。"""
    root = Path(__file__).resolve().parents[2]
    build = (root / "scripts/build_web_production.sh").read_text()
    assert "--no-web-resources-cdn" in build


# --- 管理端最小权限 ---------------------------------------------------------


def test_full_user_roster_with_pii_is_primary_admin_only(monkeypatch):
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    handler = _RecordingHandler()
    # A secondary admin cannot act on users at all, so it must not be able to
    # read every account's email + studentId either.
    monkeypatch.setattr(
        _admin_handler,
        "auth_admin",
        lambda _h, _db: ({"role": "secondary", "username": "sub"}, "t"),
    )
    _admin_handler.handle_admin_users(handler, db)
    assert handler.status_code == HTTPStatus.FORBIDDEN


def test_admin_user_rows_still_reach_a_primary_admin(monkeypatch):
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    handler = _RecordingHandler()
    monkeypatch.setattr(
        _admin_handler,
        "auth_admin",
        lambda _h, _db: ({"role": "primary", "username": "admin"}, "t"),
    )
    _admin_handler.handle_admin_users(handler, db)
    assert handler.status_code == HTTPStatus.OK


# --- 上游 AI 报错正文不得回传给客户端 ---------------------------------------


def test_ai_provider_error_body_is_logged_but_never_returned(monkeypatch, caplog):
    import logging
    from urllib.error import HTTPError

    from handlers import _ai_handler

    secret = "invalid api key sk-live-abcdef0123456789 for org acme-prod"

    def _raise(_request, timeout=0):
        raise HTTPError("https://provider.example/v1/chat", 401, "Unauthorized", {}, None)

    monkeypatch.setattr(_ai_handler, "urlopen", _raise)
    monkeypatch.setattr(_ai_handler, "_read_provider_body", lambda _r: secret.encode())

    with caplog.at_level(logging.WARNING, logger="treehole.ai"):
        with pytest.raises(RuntimeError) as raised:
            _ai_handler._read_provider_json(object())

    message = str(raised.value)
    assert "401" in message
    assert secret not in message
    assert "sk-live" not in message
    assert "provider.example" not in message
    # …but an operator can still diagnose it from the log.
    assert any(secret in record.getMessage() or secret in str(
        getattr(record, "structured", "")
    ) for record in caplog.records)


# --- Android 备份通道不得带走会话令牌 ---------------------------------------


def test_android_backup_channels_are_disabled():
    root = Path(__file__).resolve().parents[2]
    manifest = (root / "flutter_app/android/app/src/main/AndroidManifest.xml").read_text()
    assert 'android:allowBackup="false"' in manifest
    assert 'android:fullBackupContent="false"' in manifest
    assert 'android:dataExtractionRules="@xml/data_extraction_rules"' in manifest

    rules = (
        root / "flutter_app/android/app/src/main/res/xml/data_extraction_rules.xml"
    ).read_text()
    for section in ("<cloud-backup>", "<device-transfer>"):
        assert section in rules
    assert rules.count('<exclude domain="sharedpref" />') == 2


# --- 已下线的口令代理链路不得复活 -------------------------------------------


def test_retired_password_proxy_systems_are_gone_from_the_backend():
    """所有代收校园口令去替用户登录的链路都已下线。

    payment 索取统一认证密码却只回一个 `codeReceived` 布尔量，零数据；
    physics / sport 的上游只有 HTTP 地址，早已 fail-closed；ids 依赖下面
    那套绕验证码的代码才能跑通，随其一并移除。
    """
    import inspect

    import server
    from helpers import _campus_auth

    for name in (
        "login_ids",
        "login_payment",
        "login_physics",
        "login_sport",
        "_sport_sign",
        "_login_ids_for_service",
        "fetch_ids_academic_data",
    ):
        assert not hasattr(_campus_auth, name), name

    source = inspect.getsource(_campus_auth)
    for constant in (
        "PAYMENT_SERVICE_URL",
        "PHYSICS_LOGIN_URL",
        "SPORT_BASE_URL",
        "_SPORT_PUBLIC_KEY",
        "EHALL_HOME_SERVICE_URL",
    ):
        assert constant not in source, constant

    routes = inspect.getsource(server.TreeholeHandler._handle_post)
    for path in (
        "/api/campus/auth/ids",
        "/api/campus/auth/payment",
        "/api/campus/auth/physics",
        "/api/campus/auth/sport",
    ):
        assert path not in routes, path
    # 保留的两条：验证码图片交给用户自己填，不存在自动绕过。
    assert "/api/campus/auth/schoolnet/login" in routes
    assert "/api/campus/auth/dorm-water/login" in routes


def test_ids_slider_captcha_bypass_is_gone():
    """不得再程序化对抗学校统一认证的反自动化控制。

    移除的是：滑块缺口的 NCC 模板匹配求解，以及为规避行为检测而合成的
    拟人鼠标轨迹（sigmoid 加速曲线 + 随机抖动 + 随机分段耗时）。

    用户登录不受影响——它走的是 CAS 票据校验，从不碰验证码。
    """
    import inspect

    from helpers import _xidian_auth

    for name in (
        "_solve_slider_captcha",
        "_solve_slider_offset",
        "_generate_slider_tracks",
        "_verify_slider_tracks",
        "_verify_slider_answer",
        "_captcha_aes_sign",
        "_load_slider_payload",
        "_calc_ncc",
        "_normalized_template",
        "_find_alpha_bounding_box",
        "_encrypt_ids_password",
        "login_via_xidian_ids",
        "XidianAuthCaptchaError",
    ):
        assert not hasattr(_xidian_auth, name), name

    source = inspect.getsource(_xidian_auth)
    for marker in (
        "openSliderCaptcha",
        "verifySliderCaptcha",
        "IDS_CAPTCHA_MOVE_DELTAS",
        "moveLength",
        "tracks",
        "subprocess",
    ):
        assert marker not in source, marker

    # 真实用户登录的那条路径必须完好。
    assert hasattr(_xidian_auth, "validate_xidian_service_ticket")
    assert "p3/serviceValidate" in source


def test_retired_password_proxy_systems_are_gone_from_all_clients():
    root = Path(__file__).resolve().parents[2]
    sources = {
        relative: (root / relative).read_text()
        for relative in (
            "flutter_app/lib/features/campus/campus_auth_center_page.dart",
            "flutter_app/lib/repositories/campus_repository.dart",
            "miniprogram/pages/campus/auth-center/index.js",
            "miniprogram/api/campus.js",
        )
    }
    for relative, source in sources.items():
        for symbol in (
            "loginPayment",
            "loginPhysics",
            "loginSport",
            "loginIds",
            "loginCampusIds",
            "loginCampusPayment",
            "loginCampusPhysics",
            "loginCampusSport",
            "campus/auth/ids",
            "campus/auth/payment",
            "campus/auth/physics",
            "campus/auth/sport",
            "物理实验密码",
            "体育系统密码",
            "统一认证密码",
        ):
            assert symbol not in source, f"{relative} 仍引用 {symbol}"


# --- N1: 追加型写入必须计量 -------------------------------------------------


def _exhaust(fn, attempts: int):
    """Call fn(handler) repeatedly, return the status codes it produced."""
    codes = []
    for _ in range(attempts):
        handler = _LoginHandler({})
        fn(handler)
        codes.append(handler.status_code)
    return codes


def test_club_application_is_rate_limited_and_deduplicated(monkeypatch):
    """每次提交都追加一行并触发整库重写，未计量的入口就是 O(库大小) 放大器。"""
    import _globals
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    monkeypatch.setattr(_radio_handler, "_require_user", lambda _h, _db: user)
    monkeypatch.setattr(_radio_handler, "save_db", lambda _db: None)
    _globals.RATE_LIMIT_EVENTS.clear()
    _globals.IP_RATE_LIMIT_EVENTS.clear()

    limit = int(_globals.DEFAULT_SETTINGS["clubApplicationRateLimit"])
    codes = []
    for index in range(limit + 3):
        handler = _LoginHandler({"name": f"社团{index}", "description": "说明"})
        _radio_handler.handle_apply_club(handler, db)
        codes.append(handler.status_code)

    assert codes[:limit] == [HTTPStatus.CREATED] * limit
    assert all(code == HTTPStatus.TOO_MANY_REQUESTS for code in codes[limit:])
    assert len(db["clubApplications"]) == limit

    # 同名重复提交（连点）应被挡下，而不是再追加一行。
    _globals.RATE_LIMIT_EVENTS.clear()
    _globals.IP_RATE_LIMIT_EVENTS.clear()
    handler = _LoginHandler({"name": "社团0", "description": "说明"})
    _radio_handler.handle_apply_club(handler, db)
    assert handler.status_code == HTTPStatus.CONFLICT
    assert len(db["clubApplications"]) == limit
    _globals.RATE_LIMIT_EVENTS.clear()
    _globals.IP_RATE_LIMIT_EVENTS.clear()


def test_pin_request_is_rate_limited(monkeypatch):
    import _globals
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["userLevel"] = _globals.USER_LEVEL_TWO
    db["posts"] = [
        {
            "id": f"p-own-{index}", "title": f"帖子{index}", "content": "x",
            "channel": "综合", "authorId": "u1", "authorAlias": "示范同学",
            "isAnonymous": False, "createdAt": "2026-01-01T00:00:00+00:00",
            "reviewStatus": "approved", "visibility": "public", "deleted": False,
        }
        for index in range(40)
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: user)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)
    _globals.RATE_LIMIT_EVENTS.clear()
    _globals.IP_RATE_LIMIT_EVENTS.clear()

    limit = int(_globals.DEFAULT_SETTINGS["pinRequestRateLimit"])
    codes = []
    for index in range(limit + 3):
        handler = _LoginHandler({"durationMinutes": 60, "reason": "置顶"})
        _post_handler.handle_pin_request(handler, db, f"p-own-{index}")
        codes.append(handler.status_code)

    assert codes[:limit] == [HTTPStatus.CREATED] * limit
    assert all(code == HTTPStatus.TOO_MANY_REQUESTS for code in codes[limit:])
    _globals.RATE_LIMIT_EVENTS.clear()
    _globals.IP_RATE_LIMIT_EVENTS.clear()


def test_feedback_endpoint_is_rate_limited():
    """/api/feedback 内联在 server.py 里，容易在加限流时被漏掉。"""
    import inspect

    import server

    source = inspect.getsource(server.TreeholeHandler._handle_post)
    block = source.split('if path == "/api/feedback":', 1)[1]
    block = block.split("match_action = ", 1)[0]
    assert 'check_ip_rate_limit(self, "feedback")' in block
    assert 'setting_key="feedbackRateLimit"' in block
    # 限流必须在 append 之前发生，否则形同虚设。
    assert block.index("consume_rate_limit") < block.index('db.setdefault("feedbacks"')


def test_every_appending_user_endpoint_is_metered():
    """守住这条不变量：用户可反复调用、且会 append 永久行的接口必须限流。

    save_db 会 DELETE 全表再全量重写，所以未计量的追加入口既漏存储也是
    O(数据库大小) 的 CPU/IO 放大器。
    """
    import _globals

    for key in (
        "clubApplicationRateLimit",
        "feedbackRateLimit",
        "pinRequestRateLimit",
    ):
        assert key in _globals.DEFAULT_SETTINGS, key
    for action in ("club_application", "feedback", "pin_request"):
        assert action in _globals.RATE_LIMIT_WINDOWS_SECONDS, action
        assert action in _globals.IP_RATE_LIMITS, action


# --- N2: 二级管理员可读的队列不得带出 PII ----------------------------------


def test_pin_request_queue_carries_no_requester_email():
    """置顶申请是唯一 secondary admin 可读的申请队列。

    审批置顶需要帖子和理由，不需要申请人的校园邮箱；其余队列
    （申诉 / 等级 / 注销）都是 primary-only，保留 userEmail。
    """
    import inspect

    from handlers import _admin_handler
    from services._db_service import default_db
    from services._user_service import serialize_admin_post_pin_request

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    assert user["email"], "前置条件：示例用户有邮箱"
    payload = serialize_admin_post_pin_request(db, {
        "id": "pin1", "postId": "p1", "userId": "u1",
        "durationMinutes": 60, "reason": "想置顶", "status": "pending",
    })
    assert "userEmail" not in payload
    assert user["email"] not in str(payload)
    # 仍要能定位到人。
    assert payload["userId"] == "u1"
    assert payload["userNickname"]

    # 这条队列确实对二级管理员开放，所以上面的约束是必要的。
    listing = inspect.getsource(_admin_handler.handle_admin_post_pin_requests)
    assert "_require_admin(handler, db)" in listing
    assert "_require_primary_admin" not in listing


def test_primary_only_queues_still_expose_the_requester_email():
    from services._db_service import default_db
    from services._user_service import serialize_appeal

    db = default_db()
    payload = serialize_appeal(db, {
        "id": "ap1", "userId": "u1", "userEmail": "demo@stu.xidian.edu.cn",
        "appealType": "ban_revoke", "content": "申诉", "status": "pending",
    })
    assert payload["userEmail"] == "demo@stu.xidian.edu.cn"


# --- M7: 选择性重写不得丢数据 ----------------------------------------------


def _clone_sqlite(source, target):
    """WAL 模式下 shutil.copy 会漏掉未 checkpoint 的内容。"""
    import sqlite3

    src = sqlite3.connect(source)
    dst = sqlite3.connect(target)
    src.backup(dst)
    dst.commit()
    src.close()
    dst.close()


def _seeded_pair(tmp_path):
    from sql_repository import SqliteTreeholeRepository
    from services._db_service import default_db

    now = "2026-01-01T00:00:00+00:00"
    seed = SqliteTreeholeRepository(tmp_path / "seed.db")
    seed.initialize(default_db)
    db = seed.load_state()
    db["posts"] += [
        {
            "id": f"bp{index}", "title": f"t{index}", "content": "x", "channel": "综合",
            "tags": ["学习"], "authorId": "u1", "authorAlias": "a", "createdAt": now,
            "updatedAt": now, "reviewStatus": "approved", "visibility": "public",
            "deleted": False,
        }
        for index in range(30)
    ]
    db["comments"] += [
        {
            "id": f"bc{index}", "postId": "bp1", "userId": "u1", "authorAlias": "a",
            "content": "c", "createdAt": now, "reviewStatus": "approved",
        }
        for index in range(10)
    ]
    db["favorites"] += [
        {"userId": "u1", "postId": f"bp{index}", "createdAt": now} for index in range(5)
    ]
    seed.save_state(db)
    _clone_sqlite(tmp_path / "seed.db", tmp_path / "selective.db")
    _clone_sqlite(tmp_path / "seed.db", tmp_path / "full.db")
    return (
        SqliteTreeholeRepository(tmp_path / "selective.db"),
        SqliteTreeholeRepository(tmp_path / "full.db"),
    )


_NOW = "2026-01-01T00:00:00+00:00"
_WRITE_SCENARIOS = {
    "like": lambda db, i: db["likes"].append(
        {"userId": "u1", "postId": f"bp{i}", "commentId": "", "createdAt": _NOW},
    ),
    "edit_post": lambda db, i: db["posts"][0].__setitem__("viewCount", i + 1),
    "edit_user": lambda db, i: db["users"][0].__setitem__("bio", f"bio{i}"),
    "add_comment": lambda db, i: db["comments"].append(
        {
            "id": f"nc{i}", "postId": "bp1", "userId": "u1", "authorAlias": "a",
            "content": "x", "createdAt": _NOW, "reviewStatus": "approved",
        },
    ),
    "add_favorite": lambda db, i: db["favorites"].append(
        {"userId": "u1", "postId": f"bp{10 + i}", "createdAt": _NOW},
    ),
    "edit_settings": lambda db, i: db["settings"].__setitem__("postRateLimit", 10 + i),
    "add_audit_log": lambda db, i: db["auditLogs"].append(
        {"id": f"na{i}", "userId": "u1", "action": "a", "detail": "", "createdAt": _NOW},
    ),
    "soft_delete_post": lambda db, i: db["posts"][1].__setitem__("deleted", True),
    "add_session": lambda db, i: db["sessions"].__setitem__(f"tok{i}", "u1"),
}


def test_selective_rewrite_matches_a_full_rewrite(tmp_path):
    """跳过未变化的表之后，最终状态必须和整库重写逐字节一致。

    这是这项优化唯一重要的性质：一旦某张表被错误地跳过，它的行就永久
    消失了（wipe 发生了，对应的 re-INSERT 没有）。
    """
    selective, full = _seeded_pair(tmp_path)
    assert json.dumps(selective.load_state(), sort_keys=True, default=str) == json.dumps(
        full.load_state(), sort_keys=True, default=str,
    )

    for index, mutate in enumerate(_WRITE_SCENARIOS.values()):
        for repo, force in ((selective, False), (full, True)):
            db = repo.load_state()
            mutate(db, index)
            if force:
                repo._persisted_fingerprints = None  # 强制走旧的整库重写
            repo.save_state(db)

        left = selective.load_state()
        right = full.load_state()
        differing = [
            key
            for key in set(left) | set(right)
            if json.dumps(left.get(key), sort_keys=True, default=str)
            != json.dumps(right.get(key), sort_keys=True, default=str)
        ]
        assert not differing, f"步骤 {index} 之后出现差异: {differing}"


def test_foreign_key_children_are_rewritten_with_their_parent(tmp_path):
    """删除父表行会 CASCADE 掉子表行（或把外键 SET NULL）。

    因此父表被重写时，子表即使自身没变也必须一起重写，否则子表的行会在
    wipe 阶段消失、而 re-INSERT 被跳过。
    """
    import sqlite3

    from sql_repository import TABLE_SOURCE_KEYS

    selective, _full = _seeded_pair(tmp_path)
    with sqlite3.connect(tmp_path / "selective.db") as conn:
        conn.row_factory = sqlite3.Row
        # 只有 posts 变化时，posts 的子表不能被跳过。
        unchanged = set(TABLE_SOURCE_KEYS) - {"posts", "post_tags"}
        skipped = selective._close_over_foreign_keys(conn, unchanged)
        for child in ("comments", "favorites", "post_pin_requests", "media_uploads"):
            assert child not in skipped, child

        # users 是几乎所有表的父表，改它等于整库重写。
        unchanged = set(TABLE_SOURCE_KEYS) - {"users"}
        skipped = selective._close_over_foreign_keys(conn, unchanged)
        for child in ("sessions", "posts", "comments", "notifications", "conversations"):
            assert child not in skipped, child

        # 完全没有变化时，所有表都可以跳过。
        assert selective._close_over_foreign_keys(
            conn, set(TABLE_SOURCE_KEYS),
        ) == set(TABLE_SOURCE_KEYS)


def test_wipe_list_and_source_mapping_stay_in_sync():
    """两边必须一一对应。

    映射里多出一张 wipe 列表里没有的表，会让它被当成"可跳过"而其实根本
    没人写它；反过来漏掉一张表只是失去优化（skipped 由映射的键集合导出，
    未映射的表永远走重写），但同样说明有人改了 schema 却没更新映射。
    """
    import ast
    import inspect
    import textwrap

    from sql_repository import SqliteTreeholeRepository, TABLE_SOURCE_KEYS

    source = textwrap.dedent(inspect.getsource(SqliteTreeholeRepository._save_state_tx))
    tree = ast.parse(source)
    # 独立地从 `for table in [...]:` 这句里取出被清空的表名，不引用映射本身，
    # 否则删掉一条映射时两边会一起变、断言恒成立。
    wiped: set[str] = set()
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.For)
            and isinstance(node.target, ast.Name)
            and node.target.id == "table"
            and isinstance(node.iter, ast.List)
        ):
            wiped = {
                element.value
                for element in node.iter.elts
                if isinstance(element, ast.Constant) and isinstance(element.value, str)
            }
            break

    assert wiped, "未能从 _save_state_tx 里解析出被清空的表列表"
    assert wiped == set(TABLE_SOURCE_KEYS), (
        f"wipe 列表与 TABLE_SOURCE_KEYS 不一致: {wiped ^ set(TABLE_SOURCE_KEYS)}"
    )


def test_a_repeated_save_of_unchanged_state_writes_nothing(tmp_path):
    from sql_repository import TABLE_SOURCE_KEYS, table_fingerprints

    selective, _full = _seeded_pair(tmp_path)
    db = selective.load_state()
    assert table_fingerprints(db) == selective._persisted_fingerprints
    selective.save_state(db)
    # 存盘之后指纹应保持一致，第二次保存无事可做。
    assert table_fingerprints(db) == selective._persisted_fingerprints
    assert len(selective._persisted_fingerprints) == len(TABLE_SOURCE_KEYS)


# --- M8: 管理后台不进公开 web 包 --------------------------------------------


def _flutter(relative: str) -> str:
    return (Path(__file__).resolve().parents[2] / "flutter_app" / relative).read_text()


def test_admin_console_is_off_unless_a_build_opts_in():
    """必须是编译期常量，dart2js 才能把整棵后台子树剪掉而不只是隐藏。"""
    source = _flutter("lib/core/config/app_config.dart")
    assert "static const bool adminConsoleEnabled = bool.fromEnvironment(" in source
    block = source.split("adminConsoleEnabled", 1)[1].split(");", 1)[0]
    assert "'ENABLE_ADMIN_CONSOLE'" in block
    assert "defaultValue: false" in block


def test_web_entry_points_to_the_admin_console_are_all_guarded():
    """公开 web 包里进入后台的每一条路都要在编译期常量后面。"""
    app = _flutter("lib/app.dart")
    assert "AppConfig.adminConsoleEnabled &&\n        AdminAuthStore.instance.isAuthenticated" in app

    login = _flutter("lib/features/auth/login_page.dart")
    # 登录页的「管理员登录」按钮
    assert "if (AppConfig.adminConsoleEnabled) ...<Widget>[" in login
    assert login.count("onAdminLogin") >= 2, "the button calls the guarded route"
    # 以及跳转本身，避免只藏按钮、路由仍可达
    assert "if (!AppConfig.adminConsoleEnabled) {\n      return;\n    }" in login

    # web 端引用后台页面的文件只有这两个，新增入口必须同步加守卫。
    web_files = [
        path
        for path in (Path(__file__).resolve().parents[2] / "flutter_app/lib").rglob("*.dart")
        if "/mobile/" not in path.as_posix() and "/features/admin/" not in path.as_posix()
        and ("admin_portal_page.dart" in path.read_text()
             or "admin/admin_login_page.dart" in path.read_text())
    ]
    assert {path.name for path in web_files} == {"app.dart", "login_page.dart"}


def test_admin_console_exposure_is_explicit_and_overridable():
    """公开产物现在带管理台，但这必须是显式选择，而不是默默继承默认值。

    此前这里断言公开构建不得出现 ENABLE_ADMIN_CONSOLE。策略已改：登录页底部
    的管理员入口是既有设计，管理员只有几个人、没有独立域名可去，而授权始终由
    服务端的 _require_admin 把关，登录端点按 IP 与账号双重限流。保留下来的不
    变量是产物隔离：另一种部署方式（公开产物不带后台、后台单独发布）仍然可用，
    两份产物绝不能落在同一目录。
    """
    root = Path(__file__).resolve().parents[2]
    public = (root / "scripts/build_web_production.sh").read_text()
    admin = (root / "scripts/build_web_admin.sh").read_text()
    build_args = public.split("flutter build web", 1)[1]
    # 必须显式传递，且取值可由环境变量收回。
    assert "--dart-define=ENABLE_ADMIN_CONSOLE=" in build_args
    assert 'ENABLE_ADMIN_CONSOLE="${ENABLE_ADMIN_CONSOLE:-true}"' in public
    # 默认值只能写在这一处，避免两个地方各说一套。
    assert public.count("ENABLE_ADMIN_CONSOLE:-") == 1
    assert "--dart-define=ENABLE_ADMIN_CONSOLE=true" in admin
    # 两份产物必须落在不同目录，避免管理台覆盖公开站点。
    assert "build/web-admin" in admin
    assert "build/web-admin" not in public


def test_admin_token_is_not_stored_beside_the_user_token_on_web():
    """web 上 SharedPreferences 就是 localStorage：同源任意脚本都能读到。

    后台令牌是这个应用持有的最高权限凭证，改放 sessionStorage —— 只属于
    登录它的那个标签页，关掉即失效。
    """
    store = _flutter("lib/core/auth/admin_auth_store.dart")
    web_impl = _flutter("lib/core/auth/admin_token_storage_web.dart")

    code_only = "\n".join(
        line for line in web_impl.splitlines() if not line.strip().startswith("//")
    )
    assert "html.window.sessionStorage" in code_only
    assert "localStorage" not in code_only
    # 非 web 路径仍走 Keychain / Keystore
    assert "FlutterSecureStorage" in store
    # web 分支不得再写 SharedPreferences，并且要清掉旧版本留下的值
    web_branch = store.split("if (!_useSecureStorage) {", 1)[1].split("return;", 1)[0]
    assert "web_storage.readAdminToken" in web_branch
    assert "_prefs?.remove(_tokenKey)" in web_branch
    assert "_prefs?.setString" not in store

    # 普通用户令牌走的是另一套存储，两者不会共处一地。
    user_store = _flutter("lib/core/auth/auth_store.dart")
    assert "sessionStorage" not in user_store


# --- nginx: CanvasKit 的 .wasm 必须以 application/wasm 发出 -------------------


@pytest.mark.parametrize("relative", _NGINX_CONFIGS)
def test_wasm_is_served_with_the_type_webassembly_requires(relative):
    """nginx 自带的 mime.types 没有 wasm 条目。

    少了这条覆盖，CanvasKit 的 .wasm 会以 default_type（application/octet-stream）
    发出，浏览器抛 "Incorrect response MIME type. Expected 'application/wasm'"。
    那是个 unhandled promise rejection，页面不报错、只是永远停在启动画面 ——
    2026-09-07 网页端就是这样停了两小时。

    `types { }` 必须是空的：写成 `types { application/wasm wasm; }` 会替换掉
    整张继承来的映射表，连 js/css 都变成 octet-stream。
    """
    source = (Path(__file__).resolve().parents[2] / relative).read_text()

    blocks = dict(_nginx_location_blocks(source))
    header = next(
        (line for line in blocks if line.startswith("location ~* \\.wasm$")),
        None,
    )
    assert header is not None, f"{relative}: 没有 .wasm 专用 location"

    body = blocks[header]
    assert "default_type application/wasm;" in body, f"{relative}: {body}"
    assert re.search(r"types\s*\{\s*\}", body), f"{relative}: types 必须为空"


@pytest.mark.parametrize("relative", _NGINX_CONFIGS)
def test_the_wasm_location_precedes_anything_else_matching_it(relative):
    """nginx 取第一个匹配的正则 location，所以顺序即语义。

    通用静态规则 `~* \\.(?:js|css|...|wasm)$` 也匹配 .wasm；它排在前面的话
    专用覆盖永远不生效，而配置看起来完全正确。
    """
    source = (Path(__file__).resolve().parents[2] / relative).read_text()
    lines = source.splitlines()

    def first_index(predicate) -> int | None:
        return next(
            (i for i, line in enumerate(lines) if predicate(line.strip())),
            None,
        )

    wasm_at = first_index(lambda s: s.startswith("location ~* \\.wasm$"))
    assert wasm_at is not None, f"{relative}: 没有 .wasm 专用 location"

    shadow_at = first_index(
        lambda s: s.startswith("location ~")
        and "\\.wasm$" not in s
        and "wasm" in s
    )
    if shadow_at is not None:
        assert wasm_at < shadow_at, (
            f"{relative}: .wasm location 在第 {wasm_at + 1} 行，"
            f"但第 {shadow_at + 1} 行有更早的规则也匹配 .wasm"
        )
