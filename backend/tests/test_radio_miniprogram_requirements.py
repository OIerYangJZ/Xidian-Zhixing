"""Project-plan-facing mini program backend behavior tests."""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path

backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class FakeHandler:
    def __init__(self, *, body: dict | None = None, token: str = "token") -> None:
        payload = json.dumps(body or {}, ensure_ascii=False).encode("utf-8")
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Length": str(len(payload)),
        }
        self.rfile = io.BytesIO(payload)
        self.wfile = io.BytesIO()
        self.client_address = ("127.0.0.1", 12345)
        self.status_code = 0
        self.response_headers: list[tuple[str, str]] = []

    def send_response(self, code: int) -> None:
        self.status_code = code

    def send_header(self, key: str, value: str) -> None:
        self.response_headers.append((key, value))

    def end_headers(self) -> None:
        pass

    def payload(self) -> dict:
        raw = self.wfile.getvalue().decode("utf-8")
        return json.loads(raw) if raw else {}


def make_db() -> dict:
    import _globals
    from services._db_service import default_db

    _globals.configure()
    db = default_db()
    db["sessions"]["token"] = "u1"
    return db


def test_campus_services_cover_plan_and_exclude_ruisi() -> None:
    from handlers._radio_handler import handle_campus_services

    db = make_db()
    handler = FakeHandler()
    handle_campus_services(handler, db)

    rows = handler.payload()["data"]
    names = {row["name"] for row in rows}
    required = {
        "课表",
        "成绩单",
        "考试安排",
        "实验安排",
        "空闲教室",
        "考勤",
        "体育信息",
        "宿舍电费",
        "宿舍水机",
        "图书馆",
        "校园卡",
        "校园网",
        "校园地图",
        "移动门户跳转",
        "请销假系统",
        "后勤报修",
        "空间预约",
        "双创竞赛",
        "社团推荐",
        "日程提醒",
        "校外访问",
        "自助打印",
        "校园邮箱",
        "正版软件",
    }
    assert handler.status_code == 200
    assert required.issubset(names)
    assert "统一认证" not in names
    assert not any("睿思" in name for name in names)
    assert not any(row.get("groupName") == "快速跳转" for row in rows)
    assert len({row["id"] for row in rows}) == len(rows)


def test_classtable_detail_uses_calendar_action() -> None:
    from handlers._radio_handler import handle_campus_service_detail

    db = make_db()
    handler = FakeHandler()
    handle_campus_service_detail(handler, db, "classtable")

    payload = handler.payload()["data"]
    assert handler.status_code == 200
    assert payload["name"] == "课表"
    assert payload["calendarSource"] == "academic"
    assert payload["actions"][0]["type"] == "calendar"


def test_campus_map_uses_official_gis_url() -> None:
    from handlers._radio_handler import handle_campus_maps

    db = make_db()
    handler = FakeHandler()
    handle_campus_maps(handler, db)

    rows = handler.payload()["data"]
    official_urls = {row.get("officialUrl", "") for row in rows}
    assert handler.status_code == 200
    assert "https://gis.xidian.edu.cn/#/home?campus=21047" in official_urls


def test_calendar_schedules_filters_without_mock_rows() -> None:
    from handlers._radio_handler import handle_campus_calendar_schedules

    db = make_db()
    db["courseSchedules"].append({
        "id": "course-1",
        "title": "信号与系统",
        "date": "2026-06-16",
        "startTime": "08:30",
        "endTime": "10:05",
        "location": "南校区 B 楼 203",
        "teacher": "张老师",
        "section": "1-2 节",
    })
    db["examSchedules"].append({
        "id": "exam-1",
        "title": "大学物理考试",
        "date": "2026-06-16",
        "startTime": "14:00",
        "endTime": "16:00",
        "location": "南校区 C 楼 101",
    })
    handler = FakeHandler()
    handle_campus_calendar_schedules(
        handler,
        db,
        {"startDate": ["2026-06-16"], "days": ["1"], "source": ["courseSchedules"]},
    )

    payload = handler.payload()["data"]
    assert handler.status_code == 200
    assert len(payload["days"]) == 1
    assert [row["id"] for row in payload["days"][0]["items"]] == ["course-1"]


def test_calendar_schedules_all_source_returns_merged_rows() -> None:
    from handlers._radio_handler import handle_campus_calendar_schedules

    db = make_db()
    db["courseSchedules"].append({
        "id": "course-1",
        "title": "信号与系统",
        "date": "2026-06-16",
        "startTime": "08:30",
        "endTime": "10:05",
        "location": "南校区 B 楼 203",
    })
    db["examSchedules"].append({
        "id": "exam-1",
        "title": "大学物理考试",
        "date": "2026-06-16",
        "startTime": "14:00",
        "endTime": "16:00",
        "location": "南校区 C 楼 101",
    })
    handler = FakeHandler()
    handle_campus_calendar_schedules(
        handler,
        db,
        {"startDate": ["2026-06-16"], "days": ["1"], "source": ["all"]},
    )

    items = handler.payload()["data"]["days"][0]["items"]
    assert handler.status_code == 200
    assert [row["id"] for row in items] == ["course-1", "exam-1"]


def test_calendar_schedules_academic_source_merges_courses_and_exams_only() -> None:
    from handlers._radio_handler import handle_campus_calendar_schedules

    db = make_db()
    db["courseSchedules"].append({
        "id": "course-1",
        "title": "信号与系统",
        "date": "2026-06-16",
        "startTime": "08:30",
        "endTime": "10:05",
        "location": "南校区 B 楼 203",
    })
    db["examSchedules"].append({
        "id": "exam-1",
        "title": "大学物理考试",
        "date": "2026-06-16",
        "startTime": "14:00",
        "endTime": "16:00",
        "location": "南校区 C 楼 101",
    })
    db["experimentSchedules"].append({
        "id": "experiment-1",
        "title": "物理实验",
        "date": "2026-06-16",
        "startTime": "19:00",
        "endTime": "20:35",
        "location": "实验楼",
    })
    handler = FakeHandler()
    handle_campus_calendar_schedules(
        handler,
        db,
        {"startDate": ["2026-06-16"], "days": ["1"], "source": ["academic"]},
    )

    items = handler.payload()["data"]["days"][0]["items"]
    assert handler.status_code == 200
    assert [row["id"] for row in items] == ["course-1", "exam-1"]


def test_calendar_schedules_hides_other_users_private_rows() -> None:
    from handlers._radio_handler import handle_campus_calendar_schedules

    db = make_db()
    db["courseSchedules"].append({
        "id": "mine",
        "ownerUserId": "u1",
        "title": "我的课",
        "date": "2026-06-16",
        "startTime": "08:30",
        "endTime": "10:05",
    })
    db["courseSchedules"].append({
        "id": "other",
        "ownerUserId": "u2",
        "title": "别人的课",
        "date": "2026-06-16",
        "startTime": "10:25",
        "endTime": "12:00",
    })
    db["courseSchedules"].append({
        "id": "public",
        "title": "公共日程",
        "date": "2026-06-16",
        "startTime": "14:00",
        "endTime": "15:00",
    })
    handler = FakeHandler()
    handle_campus_calendar_schedules(
        handler,
        db,
        {"startDate": ["2026-06-16"], "days": ["1"], "source": ["courseSchedules"]},
    )

    items = handler.payload()["data"]["days"][0]["items"]
    assert [row["id"] for row in items] == ["mine", "public"]


def test_apply_ids_academic_data_replaces_current_user_synced_rows() -> None:
    from helpers._campus_auth import apply_ids_academic_data

    db = make_db()
    db["courseSchedules"] = [
        {"id": "old", "ownerUserId": "u1", "sourceProvider": "xidian-ehall"},
        {"id": "manual", "ownerUserId": "u1", "sourceProvider": "manual"},
        {"id": "other", "ownerUserId": "u2", "sourceProvider": "xidian-ehall"},
    ]
    synced = {
        "courseSchedules": [{"id": "new", "ownerUserId": "u1", "sourceProvider": "xidian-ehall"}],
        "examSchedules": [{"id": "exam", "ownerUserId": "u1", "sourceProvider": "xidian-ehall"}],
    }

    counts = apply_ids_academic_data(db, owner_user_id="u1", synced=synced)

    assert counts == {"courseSchedules": 1, "examSchedules": 1}
    assert [row["id"] for row in db["courseSchedules"]] == ["manual", "other", "new"]
    assert [row["id"] for row in db["examSchedules"]] == ["exam"]


def test_ids_course_sync_uses_graduate_classtable_when_ehall_has_no_rows(monkeypatch) -> None:
    import helpers._campus_auth as campus_auth

    class FakeResponse:
        def __init__(self, payload: dict) -> None:
            self._payload = payload
            self.status_code = 200

        def raise_for_status(self) -> None:
            pass

        def json(self) -> dict:
            return self._payload

    class FakeGraduateSession:
        def post(self, url: str, **kwargs):
            if url.endswith("/queryRcap.do"):
                return FakeResponse({"xnxq": "第2周"})
            if url.endswith("/xspkjgcx.do"):
                return FakeResponse({
                    "code": "0",
                    "datas": {
                        "xspkjgcx": {
                            "rows": [{
                                "KCMC": "矩阵论",
                                "KCDM": "MATH701",
                                "KSJCDM": 1,
                                "JSJCDM": 2,
                                "XQ": 3,
                                "ZCBH": "11",
                                "JSXM": "李老师",
                                "JASMC": "南校区 A-101",
                            }]
                        }
                    },
                })
            raise AssertionError(url)

    class FakeRequests:
        class RequestException(Exception):
            pass

    def fake_post_ehall_json(_session, url, data=None):
        if url.endswith("/cxjcs.do"):
            return {"datas": {"cxjcs": {"rows": [{"XQKSRQ": "2026-03-02"}]}}}
        if url.endswith("/xskcb.do"):
            return {"datas": {"xskcb": {"extParams": {"code": 1}, "rows": []}}}
        raise AssertionError(url)

    monkeypatch.setattr(campus_auth, "_open_ehall_app", lambda *args, **kwargs: None)
    monkeypatch.setattr(campus_auth, "_post_ehall_json", fake_post_ehall_json)
    monkeypatch.setattr(campus_auth, "_login_ids_for_service", lambda *_args, **_kwargs: (FakeGraduateSession(), ""))
    monkeypatch.setattr(campus_auth, "_follow_redirects", lambda *_args, **_kwargs: "")
    monkeypatch.setattr(campus_auth, "_import_requests", lambda: FakeRequests())
    monkeypatch.setattr(campus_auth, "datetime", type(
        "FakeDateTime",
        (),
        {
            "now": staticmethod(lambda: __import__("datetime").datetime(2026, 3, 10, 12, 0, 0)),
            "fromisoformat": staticmethod(__import__("datetime").datetime.fromisoformat),
        },
    ))

    rows = campus_auth._sync_course_schedules(
        object(),
        student_id="2300000000",
        password="secret-pass",
        owner_user_id="u1",
        semester_code="2025-2026-2",
    )

    assert len(rows) == 2
    assert rows[0]["title"] == "矩阵论"
    assert rows[0]["date"] == "2026-03-04"
    assert rows[1]["date"] == "2026-03-11"
    assert rows[0]["startTime"] == "08:30"
    assert rows[0]["endTime"] == "10:05"
    assert rows[0]["location"] == "南校区 A-101"


def test_xidian_official_guides_seed_ai_knowledge() -> None:
    from handlers._radio_handler import handle_ai_search

    db = make_db()
    handler = FakeHandler(body={"query": "校外访问 零信任 自助打印 校园网"})
    handle_ai_search(handler, db)

    rows = handler.payload()["data"]["items"]
    assert handler.status_code == 200
    assert any("信息网络技术中心" in row["summary"] or "校外访问" in row["summary"] for row in rows)
    assert any(row.get("sourceUrl") for row in rows if row["targetType"] == "knowledge")


def test_campus_auth_routes_require_login_and_dispatch(monkeypatch) -> None:
    import server

    monkeypatch.setattr(server, "load_db", make_db)
    handler = FakeHandler(body={"identifier": "2300000000", "password": "secret-pass"}, token="bad-token")
    server.TreeholeHandler._handle_post(handler, "/api/campus/auth/ids")

    assert handler.status_code == 401

    def fake_fetch_ids(identifier, password, **_kwargs):
        assert not server.DB_LOCK.locked()
        return (
            identifier,
            {"semesterCode": "2026-1", "courseSchedules": [], "examSchedules": []},
        )

    monkeypatch.setattr(
        server._campus_auth,
        "fetch_ids_academic_data",
        fake_fetch_ids,
    )
    monkeypatch.setattr(server, "save_db", lambda _db: None)
    authed_handler = FakeHandler(body={"identifier": "2300000000", "password": "secret-pass"})
    server.TreeholeHandler._handle_post(authed_handler, "/api/campus/auth/ids")

    assert authed_handler.status_code == 200
    assert authed_handler.payload()["data"]["system"] == "ids"


def test_xidian_password_login_returns_campus_auth_result_without_token(monkeypatch) -> None:
    import handlers._auth_handler as auth_handler
    from helpers._xidian_auth import XidianAuthResult

    def fake_login(student_id: str, password: str, *, email_hint: str = "") -> XidianAuthResult:
        assert student_id == "2300000000"
        assert password == "secret-pass"
        return XidianAuthResult(student_id=student_id, campus_email=f"{student_id}@stu.xidian.edu.cn")

    db = make_db()
    monkeypatch.setattr(auth_handler, "login_via_xidian_ids", fake_login)
    monkeypatch.setattr(auth_handler, "save_db", lambda _db: None)
    handler = FakeHandler(body={"identifier": "2300000000", "password": "secret-pass"})

    auth_handler.handle_xidian_password_login(handler, db)

    payload = handler.payload()["data"]
    assert handler.status_code == 200
    assert "token" not in payload
    assert payload["system"] == "ids"
    assert payload["status"] == "authenticated"
    assert payload["studentId"] == "2300000000"
    assert payload["email"] == "2300000000@stu.xidian.edu.cn"


def test_xidian_password_network_handler_runs_outside_database_lock(
    monkeypatch,
) -> None:
    import server

    monkeypatch.setattr(server, "load_db", make_db)

    def fake_handler(handler, db) -> None:
        assert not server.DB_LOCK.locked()
        server.send_json(
            handler,
            200,
            {"data": {"system": "ids", "status": "authenticated"}},
        )

    monkeypatch.setattr(
        server._auth_handler,
        "handle_xidian_password_login",
        fake_handler,
    )
    handler = FakeHandler(
        body={"identifier": "2300000000", "password": "secret-pass"},
    )

    server.TreeholeHandler._handle_post(handler, "/api/auth/xidian/password")

    assert handler.status_code == 200


def test_xidian_slider_solver_uses_signed_tracks_and_expanded_delta(monkeypatch) -> None:
    import helpers._xidian_auth as xidian_auth

    verify_moves: list[int] = []

    monkeypatch.setattr(
        xidian_auth,
        "_load_slider_payload",
        lambda _session: {"bigImage": "big", "smallImage": "small"},
    )
    monkeypatch.setattr(
        xidian_auth,
        "_decode_image",
        lambda value: b"captcha-image-key!" if value == "small" else b"big-image",
    )
    monkeypatch.setattr(xidian_auth, "_solve_slider_offset", lambda _big, _small: 100 / 280)

    def fake_verify(_session, *, move_length: int, key_bytes: bytes) -> bool:
        verify_moves.append(move_length)
        assert key_bytes == b"ptcha-image-key!"
        return move_length == 90

    monkeypatch.setattr(xidian_auth, "_verify_slider_tracks", fake_verify)

    xidian_auth._solve_slider_captcha(object(), retry_count=1)

    assert 90 in verify_moves
    assert 96 in verify_moves


def test_xidian_ids_password_post_keeps_service_param(monkeypatch) -> None:
    import helpers._xidian_auth as xidian_auth

    class FakeResponse:
        status_code = 200
        text = (
            '<form><input name="pwdEncryptSalt" value="1234567890123456">'
            '<input name="lt" value=""><input name="execution" value="e1s1"></form>'
        )
        headers: dict[str, str] = {}

    class FakeRedirect:
        status_code = 302
        text = ""
        headers = {
            "Location": (
                "https://ehall.xidian.edu.cn/login"
                "?service=https://ehall.xidian.edu.cn/new/index.html"
                "&ticket=ST-test"
            )
        }

    class FakeSession:
        def __init__(self) -> None:
            self.headers = {}
            self.post_params = None

        def get(self, *args, **kwargs):
            return FakeResponse()

        def post(self, *args, **kwargs):
            self.post_params = kwargs.get("params")
            return FakeRedirect()

    session = FakeSession()

    class FakeRequests:
        Session = lambda self=None: session
        class RequestException(Exception):
            pass

    monkeypatch.setattr(xidian_auth, "_import_requests", lambda: FakeRequests())
    monkeypatch.setattr(xidian_auth, "_encrypt_ids_password", lambda password, key: "encrypted")
    monkeypatch.setattr(xidian_auth, "_solve_slider_captcha", lambda _session: None)
    monkeypatch.setattr(
        xidian_auth,
        "validate_xidian_service_ticket",
        lambda ticket, service_url: xidian_auth.XidianAuthResult(
            student_id="2300000000",
            campus_email="2300000000@stu.xidian.edu.cn",
        ),
    )

    result = xidian_auth.login_via_xidian_ids("2300000000", "secret-pass")

    assert result.student_id == "2300000000"
    assert session.post_params == {"service": xidian_auth.EHALL_SERVICE_URL}


def test_xidian_ids_error_page_maps_to_password_error(monkeypatch) -> None:
    import pytest
    import helpers._xidian_auth as xidian_auth

    class FakeLoginPage:
        status_code = 200
        text = (
            '<form><input name="pwdEncryptSalt" value="1234567890123456">'
            '<input name="lt" value=""><input name="execution" value="e1s1"></form>'
        )
        headers: dict[str, str] = {}

    class FakeErrorPage:
        status_code = 200
        text = '<div id="showErrorTip">用户名或密码错误</div>'
        headers: dict[str, str] = {}

    class FakeSession:
        def __init__(self) -> None:
            self.headers = {}

        def get(self, *args, **kwargs):
            return FakeLoginPage()

        def post(self, *args, **kwargs):
            return FakeErrorPage()

    class FakeRequests:
        Session = lambda self=None: FakeSession()
        class RequestException(Exception):
            pass

    monkeypatch.setattr(xidian_auth, "_import_requests", lambda: FakeRequests())
    monkeypatch.setattr(xidian_auth, "_encrypt_ids_password", lambda password, key: "encrypted")
    monkeypatch.setattr(xidian_auth, "_solve_slider_captcha", lambda _session: None)

    with pytest.raises(xidian_auth.XidianAuthPasswordError) as error:
        xidian_auth.login_via_xidian_ids("2300000000", "bad-pass")

    assert str(error.value) == "学号或统一认证密码错误"


def test_my_feedbacks_returns_only_current_user_rows() -> None:
    from handlers._user_handler import handle_my_feedbacks

    db = make_db()
    db["feedbacks"] = [
        {"id": "fb1", "userId": "u1", "content": "我的建议", "category": "学校服务意见", "status": "pending", "createdAt": "2026-06-01T00:00:00+08:00"},
        {"id": "fb2", "userId": "seed-user-1", "content": "别人的建议", "category": "其他反馈", "status": "pending", "createdAt": "2026-06-01T00:00:00+08:00"},
    ]
    handler = FakeHandler()
    handle_my_feedbacks(handler, db)

    rows = handler.payload()["data"]
    assert handler.status_code == 200
    assert [row["id"] for row in rows] == ["fb1"]


def test_college_section_post_requires_matching_user_college() -> None:
    from handlers._post_handler import handle_create_post

    db = make_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["college"] = "电子工程学院"
    handler = FakeHandler(body={
        "content": "想在计算机学院分区发一条帖子",
        "sectionType": "college",
        "sectionId": "cs",
        "sectionName": "计算机科学与技术学院",
    })

    handle_create_post(handler, db)

    assert handler.status_code == 403
    assert "只能在本学院分区发帖" in handler.payload()["message"]


def test_miniprogram_does_not_persist_or_replay_campus_passwords() -> None:
    miniprogram_dir = backend_dir.parent / "miniprogram"
    campus_auth_source = (miniprogram_dir / "utils" / "campus_auth.js").read_text()
    app_source = (miniprogram_dir / "app.js").read_text()
    auth_center_source = (
        miniprogram_dir / "pages" / "campus" / "auth-center" / "index.js"
    ).read_text()

    assert "setStorageSync(CAMPUS_AUTH_SECRET_KEY" not in campus_auth_source
    assert "getCampusAuthSecrets" not in app_source
    assert "loginCampusIds" not in app_source
    assert "saveCampusAuthSecret" not in auth_center_source


def test_miniprogram_logout_clears_account_scoped_campus_state() -> None:
    miniprogram_dir = backend_dir.parent / "miniprogram"
    auth_guard_source = (miniprogram_dir / "utils" / "auth_guard.js").read_text()
    settings_source = (
        miniprogram_dir / "pages" / "profile" / "settings" / "index.js"
    ).read_text()
    account_security_source = (
        miniprogram_dir
        / "pages"
        / "profile"
        / "account-security"
        / "index.js"
    ).read_text()

    assert "clearCampusAuthSession();" in auth_guard_source
    assert "clearLocalSession();" in settings_source
    assert "clearLocalSession();" in account_security_source


def test_miniprogram_campus_api_rejects_malformed_success_responses() -> None:
    miniprogram_dir = backend_dir.parent / "miniprogram"
    source = (miniprogram_dir / "api" / "campus.js").read_text()

    assert "requireAuthResponse" in source
    assert "result.data.status !== 'authenticated'" in source
    assert "今日课表响应 items 不是数组" in source
    assert "'校园网验证码'," in source
    assert "['attemptId', 'imageBase64', 'imageContentType']" in source
    assert "'宿舍水机验证码'," in source
    assert "['sessionId', 'imageBase64', 'imageContentType']" in source


def test_miniprogram_failed_lists_offer_retry_instead_of_empty_state() -> None:
    miniprogram_dir = backend_dir.parent / "miniprogram"
    pages = [
        ("pages/treehole/index.wxml", "retryFeed"),
        ("pages/campus/post-detail/index.wxml", "retryLoadDetail"),
        ("pages/campus/tag-posts/index.wxml", "retryLoad"),
        ("pages/profile/notifications/index.wxml", "retryLoad"),
        ("pages/profile/conversations/index.wxml", "retryLoad"),
        ("pages/profile/chat/index.wxml", "retryLoadMessages"),
        ("pages/profile/my-comments/index.wxml", "retryLoad"),
        ("pages/profile/my-posts/index.wxml", "retryLoad"),
        ("pages/profile/favorites/index.wxml", "retryLoad"),
        ("pages/profile/public-user/index.wxml", "retryLoad"),
        ("pages/profile/social-list/index.wxml", "retryLoad"),
        ("pages/profile/my-reports/index.wxml", "loadData"),
        ("pages/profile/report-detail/index.wxml", "loadDetail"),
        ("pages/profile/account-security/index.wxml", "loadProfile"),
        ("pages/profile/privacy/index.wxml", "loadProfile"),
        ("pages/profile/notification-settings/index.wxml", "loadProfile"),
        ("pages/profile/privacy/blocklist/index.wxml", "loadBlocks"),
        ("pages/profile/edit-profile/index.wxml", "loadProfile"),
        ("pages/profile/settings/index.wxml", "fetchUserInfo"),
        ("pages/campus/search/index.wxml", "search"),
        ("pages/admin/index.wxml", "loadActiveTab"),
    ]

    for relative_path, retry_handler in pages:
        source = (miniprogram_dir / relative_path).read_text()
        assert "errorMessage" in source
        assert retry_handler in source
