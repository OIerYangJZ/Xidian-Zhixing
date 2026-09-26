"""Project-plan-facing mini program backend behavior tests."""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest

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


def test_xidian_auth_session_redirects_to_registered_official_callback(monkeypatch) -> None:
    import _globals
    import handlers._auth_handler as auth_handler

    db = make_db()
    monkeypatch.setattr(
        _globals,
        "BACKEND_XIDIAN_PUBLIC_ORIGIN",
        "https://zhixing.xidian.edu.cn",
    )
    handler = FakeHandler(body={"platform": "web", "nextPath": "/"})

    auth_handler.handle_xidian_auth_create_session(handler, db)

    payload = handler.payload()["data"]
    assert handler.status_code == 200
    assert payload["status"] == "pending"
    assert payload["authorizeUrl"].startswith(
        "https://zhixing.xidian.edu.cn/api/auth/xidian/start?attempt=",
    )


def test_xidian_callback_validates_registered_service_and_issues_session(monkeypatch) -> None:
    import _globals
    import handlers._auth_handler as auth_handler
    from helpers._xidian_auth import XidianAuthResult

    db = make_db()
    monkeypatch.setattr(
        _globals,
        "BACKEND_XIDIAN_PUBLIC_ORIGIN",
        "https://zhixing.xidian.edu.cn",
    )
    monkeypatch.setattr(auth_handler, "save_db", lambda _db: None)
    attempt = auth_handler._create_auth_attempt(platform="web", next_path="/")

    def fake_validate(ticket: str, service_url: str) -> XidianAuthResult:
        assert ticket == "ST-registered-ticket"
        assert service_url == "https://zhixing.xidian.edu.cn/api/auth/xidian/callback"
        return XidianAuthResult(
            student_id="2300000000",
            campus_email="2300000000@stu.xidian.edu.cn",
        )

    monkeypatch.setattr(auth_handler, "validate_xidian_service_ticket", fake_validate)
    handler = FakeHandler()
    handler.headers["Cookie"] = f"xdu_whisper_xidian_attempt={attempt['id']}"

    auth_handler.handle_xidian_auth_callback(
        handler,
        db,
        {"ticket": ["ST-registered-ticket"]},
    )

    assert handler.status_code == 302
    headers = dict(handler.response_headers)
    assert headers["Location"].startswith("/?xidianAuthAttempt=")
    result = auth_handler._load_attempt(attempt["id"])
    assert result is not None
    assert result["status"] == "authenticated"
    assert result["token"] in db["sessions"]
    created_user = next(
        user for user in db["users"] if user.get("studentId") == "2300000000"
    )
    assert created_user["password"] == ""


def test_xidian_callback_failure_returns_web_client_to_login(monkeypatch) -> None:
    import _globals
    import handlers._auth_handler as auth_handler
    from helpers._xidian_auth import XidianAuthUnavailableError

    db = make_db()
    monkeypatch.setattr(
        _globals,
        "BACKEND_XIDIAN_PUBLIC_ORIGIN",
        "https://zhixing.xidian.edu.cn",
    )
    attempt = auth_handler._create_auth_attempt(platform="web", next_path="/")

    def fail_validate(_ticket: str, _service_url: str):
        raise XidianAuthUnavailableError("统一认证票据校验失败")

    monkeypatch.setattr(auth_handler, "validate_xidian_service_ticket", fail_validate)
    handler = FakeHandler()
    handler.headers["Cookie"] = f"xdu_whisper_xidian_attempt={attempt['id']}"

    auth_handler.handle_xidian_auth_callback(
        handler,
        db,
        {"ticket": ["ST-invalid-ticket"]},
    )

    assert handler.status_code == 302
    assert dict(handler.response_headers)["Location"].startswith(
        "/?xidianAuthAttempt=",
    )
    result = auth_handler._load_attempt(attempt["id"])
    assert result is not None
    assert result["status"] == "failed"
    assert result["message"] == "统一认证票据校验失败"


def test_password_proxy_login_endpoint_is_not_routed(monkeypatch) -> None:
    import server

    monkeypatch.setattr(server, "load_db", make_db)
    handler = FakeHandler(
        body={"studentId": "2300000000", "password": "secret-pass"},
    )

    server.TreeholeHandler._handle_post(handler, "/api/auth/login")

    assert handler.status_code == 404


def test_empty_xidian_allowlist_allows_every_verified_student(monkeypatch) -> None:
    import _globals

    monkeypatch.setattr(_globals, "AUTH_ALLOWED_STUDENT_IDS", set())

    assert _globals.is_auth_student_id_allowed("2300000000") is True
    assert _globals.is_auth_student_id_allowed("2500000001") is True


def test_nonempty_xidian_allowlist_restricts_verified_students(monkeypatch) -> None:
    import _globals

    monkeypatch.setattr(
        _globals,
        "AUTH_ALLOWED_STUDENT_IDS",
        {"2300000000"},
    )

    assert _globals.is_auth_student_id_allowed("2300000000") is True
    assert _globals.is_auth_student_id_allowed("2500000001") is False


def test_production_env_validator_accepts_empty_xidian_allowlist() -> None:
    from scripts.validate_production_env import validate

    values = {
        "BACKEND_ENV": "production",
        "BACKEND_HOST": "127.0.0.1",
        "BACKEND_PORT": "8080",
        "BACKEND_ADMIN_USERNAME": "admin",
        "BACKEND_ADMIN_PASSWORD": "NotARealProductionPassword-2026",
        "BACKEND_DB_FILE": "/home/ubuntu/treehole/shared/data/treehole.db",
        "BACKEND_STORAGE_DIR": "/home/ubuntu/treehole/shared/storage/objects",
        "BACKEND_WEB_ROOT": "/home/ubuntu/treehole/current/web",
        "BACKEND_OBJECT_STORAGE_BACKEND": "local",
        "BACKEND_ALLOW_DEBUG_VERIFY_CODE": "false",
        "BACKEND_INCLUDE_DEBUG_CODE": "false",
        "BACKEND_SEED_DEMO_DATA": "false",
        "BACKEND_CORS_ALLOWED_ORIGINS": "https://zhixing.xidian.edu.cn",
        "BACKEND_AUTH_ALLOWED_STUDENT_IDS": "",
        "BACKEND_ENABLE_XIDIAN_AUTH": "true",
        "BACKEND_MAX_REQUEST_BODY_MB": "20",
        "BACKEND_XIDIAN_PUBLIC_ORIGIN": "https://zhixing.xidian.edu.cn",
    }

    assert validate(values) == []


def test_production_env_validator_checks_nonempty_xidian_allowlist() -> None:
    from scripts.validate_production_env import validate

    values = {
        "BACKEND_ENV": "production",
        "BACKEND_HOST": "127.0.0.1",
        "BACKEND_PORT": "8080",
        "BACKEND_ADMIN_USERNAME": "admin",
        "BACKEND_ADMIN_PASSWORD": "NotARealProductionPassword-2026",
        "BACKEND_DB_FILE": "/home/ubuntu/treehole/shared/data/treehole.db",
        "BACKEND_STORAGE_DIR": "/home/ubuntu/treehole/shared/storage/objects",
        "BACKEND_WEB_ROOT": "/home/ubuntu/treehole/current/web",
        "BACKEND_OBJECT_STORAGE_BACKEND": "local",
        "BACKEND_ALLOW_DEBUG_VERIFY_CODE": "false",
        "BACKEND_INCLUDE_DEBUG_CODE": "false",
        "BACKEND_SEED_DEMO_DATA": "false",
        "BACKEND_CORS_ALLOWED_ORIGINS": "https://zhixing.xidian.edu.cn",
        "BACKEND_AUTH_ALLOWED_STUDENT_IDS": "invalid-student-id!",
        "BACKEND_ENABLE_XIDIAN_AUTH": "true",
        "BACKEND_MAX_REQUEST_BODY_MB": "20",
        "BACKEND_XIDIAN_PUBLIC_ORIGIN": "https://zhixing.xidian.edu.cn",
    }

    assert (
        "BACKEND_AUTH_ALLOWED_STUDENT_IDS must contain valid student IDs"
        in validate(values)
    )


def test_production_env_validator_rejects_invalid_college_mapping() -> None:
    from scripts.validate_production_env import validate

    values = {
        "BACKEND_ENV": "production",
        "BACKEND_HOST": "127.0.0.1",
        "BACKEND_PORT": "8080",
        "BACKEND_ADMIN_USERNAME": "admin",
        "BACKEND_ADMIN_PASSWORD": "NotARealProductionPassword-2026",
        "BACKEND_DB_FILE": "/home/ubuntu/treehole/shared/data/treehole.db",
        "BACKEND_STORAGE_DIR": "/home/ubuntu/treehole/shared/storage/objects",
        "BACKEND_WEB_ROOT": "/home/ubuntu/treehole/current/web",
        "BACKEND_OBJECT_STORAGE_BACKEND": "local",
        "BACKEND_ALLOW_DEBUG_VERIFY_CODE": "false",
        "BACKEND_INCLUDE_DEBUG_CODE": "false",
        "BACKEND_SEED_DEMO_DATA": "false",
        "BACKEND_CORS_ALLOWED_ORIGINS": "https://zhixing.xidian.edu.cn",
        "BACKEND_AUTH_ALLOWED_STUDENT_IDS": "",
        "BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS": "2023000001",
        "BACKEND_ENABLE_XIDIAN_AUTH": "true",
        "BACKEND_MAX_REQUEST_BODY_MB": "20",
        "BACKEND_XIDIAN_PUBLIC_ORIGIN": "https://zhixing.xidian.edu.cn",
    }

    assert (
        "BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS must contain studentId=sectionId pairs"
        in validate(values)
    )


@pytest.mark.parametrize(
    "path",
    [
        "/api/auth/register",
        "/api/auth/verify",
        "/api/auth/send-code",
        "/api/auth/password/send-code",
        "/api/auth/password/reset",
    ],
)
def test_legacy_email_auth_endpoints_are_not_routed(monkeypatch, path) -> None:
    import server

    monkeypatch.setattr(server, "load_db", make_db)
    handler = FakeHandler(body={})

    server.TreeholeHandler._handle_post(handler, path)

    assert handler.status_code == 404
    assert handler.payload()["message"] == "Not Found"


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


def test_college_section_post_requires_matching_server_mapping(monkeypatch) -> None:
    import _globals
    from handlers._post_handler import handle_create_post

    db = make_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["college"] = "电子工程学院"
    monkeypatch.setattr(
        _globals,
        "AUTH_STUDENT_COLLEGE_SECTIONS",
        {str(user["studentId"]): "college-ee"},
    )
    db["sections"].append({
        "id": "cs",
        "sectionType": "college",
        "sectionName": "计算机科学与技术学院",
        "enabled": True,
    })
    handler = FakeHandler(body={
        "content": "想在计算机学院分区发一条帖子",
        "sectionType": "college",
        "sectionId": "cs",
        "sectionName": "",
    })

    handle_create_post(handler, db)

    assert handler.status_code == 403
    assert "只能在本学院分区发帖" in handler.payload()["message"]


def test_college_section_post_persists_server_canonical_fields(monkeypatch) -> None:
    import _globals
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    db = make_db()
    user = next(row for row in db["users"] if row["id"] == "u1")
    user["college"] = "电子工程学院"
    monkeypatch.setattr(
        _globals,
        "AUTH_STUDENT_COLLEGE_SECTIONS",
        {str(user["studentId"]): "college-ee"},
    )
    handler = FakeHandler(body={
        "content": "本学院帖子",
        "sectionType": "college",
        "sectionId": "college-ee",
        "sectionName": "攻击者提供的名称",
    })

    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == 200
    created = next(row for row in db["posts"] if row["content"] == "本学院帖子")
    assert created["sectionId"] == "ee"
    assert created["sectionName"] == "电子工程学院"


@pytest.mark.parametrize(
    "body,message",
    [
        ({"content": "x" * 10001}, "帖子正文"),
        ({
            "content": "正文",
            "contentFormat": "markdown",
            "markdownSource": "![tracking](https://tracker.example/pixel.png)",
        }, "本站上传地址"),
        ({"content": "正文", "tags": [f"tag-{index}" for index in range(11)]}, "标签"),
    ],
)
def test_create_post_rejects_unbounded_or_remote_media_fields(body, message) -> None:
    from handlers._post_handler import handle_create_post

    db = make_db()
    handler = FakeHandler(body=body)
    handle_create_post(handler, db)

    assert handler.status_code == 400
    assert message in handler.payload()["message"]


def test_hot_summary_get_is_read_only() -> None:
    from copy import deepcopy
    from handlers._radio_handler import handle_ai_hot_summary

    db = make_db()
    before = deepcopy(db)
    handler = FakeHandler()
    handle_ai_hot_summary(handler, db)

    assert handler.status_code == 200
    assert handler.payload()["data"]["reviewStatus"] == "approved"
    assert db == before


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


def test_miniprogram_create_post_displays_moderation_rejection_reason() -> None:
    miniprogram_dir = backend_dir.parent / "miniprogram"
    api_source = (miniprogram_dir / "api" / "posts.js").read_text()
    create_source = (
        miniprogram_dir / "pages" / "campus" / "create-post" / "index.js"
    ).read_text()

    assert "silentErrorToast: true" in api_source
    assert "POST_CONTENT_REJECTED" in create_source
    assert "发布被自动审核拦截" in create_source
    assert "responseData && responseData.message" in create_source


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
        ("pages/profile/notifications/index.wxml", "retryLoad"),
        ("pages/messages/index.wxml", "retryLoad"),
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
