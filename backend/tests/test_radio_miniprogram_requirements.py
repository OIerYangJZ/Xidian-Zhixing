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
        "统一认证",
        "社团推荐",
        "日程提醒",
        "校外访问",
        "自助打印",
        "校园邮箱",
        "正版软件",
    }
    assert handler.status_code == 200
    assert required.issubset(names)
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
    assert payload["calendarSource"] == "courseSchedules"
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

    monkeypatch.setattr(
        server._campus_auth,
        "login_ids",
        lambda identifier, password: {"system": "ids", "studentId": identifier, "message": "ok"},
    )
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
