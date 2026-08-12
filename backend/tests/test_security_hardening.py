"""安全加固回归测试。

每个用例对应一条已修复的审计结论，用来防止这些防护在后续重构中被悄悄改回去。
"""
from __future__ import annotations

import base64
import io
import ipaddress
import json
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


@pytest.mark.parametrize(
    "url",
    [
        "http://ehall.xidian.edu.cn/path",
        "https://evil.example/path",
        "https://user@ehall.xidian.edu.cn/path",
        "https://ehall.xidian.edu.cn:8443/path",
    ],
)
def test_campus_redirect_rejects_untrusted_origins_without_requesting_them(url):
    from helpers import _campus_auth

    with pytest.raises(_campus_auth.CampusAuthError, match="不受信任"):
        _campus_auth._validate_campus_redirect(url, {"ehall.xidian.edu.cn"})


def test_physics_login_fails_closed_while_upstream_is_http(monkeypatch):
    from helpers import _campus_auth

    monkeypatch.setattr(
        _campus_auth,
        "_import_requests",
        lambda: pytest.fail("HTTP physics endpoint must not be contacted"),
    )
    with pytest.raises(_campus_auth.CampusAuthError, match="HTTPS"):
        _campus_auth.login_physics("2500001", "password")


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
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    db["aiMessages"] = [{"id": "existing"}]
    saved: list[dict] = []
    monkeypatch.setattr(_radio_handler, "_require_user", lambda _h, _db: user)
    monkeypatch.setattr(_radio_handler, "read_json_body", lambda _h: {"selectedText": "测试"})
    monkeypatch.setattr(_radio_handler, "_search_items", lambda _db, _q: [])
    monkeypatch.setattr(_radio_handler, "save_db", lambda value: saved.append(value))
    handler = _RecordingHandler()

    _radio_handler.handle_ai_post_selection(handler, db)

    assert handler.status_code == HTTPStatus.OK
    assert db["aiMessages"] == [{"id": "existing"}]
    assert saved == []


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


def test_sport_login_fails_closed_while_upstream_is_http(monkeypatch):
    from helpers import _campus_auth

    monkeypatch.setattr(
        _campus_auth,
        "_import_requests",
        lambda: pytest.fail("HTTP sport endpoint must not be contacted"),
    )
    with pytest.raises(_campus_auth.CampusAuthError, match="HTTPS"):
        _campus_auth.login_sport("2500001", "password")


def test_sport_password_form_is_removed_from_all_client_catalogues():
    from services._db_service import default_db

    root = Path(__file__).resolve().parents[2]
    sport = next(
        row for row in default_db()["campusServices"]
        if row.get("slug") == "sport"
    )
    assert sport["authType"] == "unavailable"
    assert all(not str(action.get("url", "")).startswith("http://") for action in sport["actions"])

    flutter_source = (
        root / "flutter_app/lib/features/campus/campus_auth_center_page.dart"
    ).read_text()
    mini_source = (
        root / "miniprogram/pages/campus/auth-center/index.js"
    ).read_text()
    assert "'sport',\n      _AuthType.password" not in flutter_source
    assert "passwordPlaceholder: '体育系统密码'" not in mini_source


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
