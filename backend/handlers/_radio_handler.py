from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any

import _globals
from helpers import (
    check_ip_rate_limit,
    consume_rate_limit,
    json_error,
    now_iso,
    read_json_body,
    send_json,
    send_rate_limit_error,
)
from rag_service import (
    citations,
    forum_citations,
    index_summary as rag_index_summary,
    rebuild_rag_index,
    retrieve,
)
from services import (
    add_audit_log,
    auth_admin,
    auth_user as auth_user_helper,
    find_user_by_id,
    list_posts,
    next_id,
    save_db,
    serialize_post,
    user_nickname,
)
from services._db_service import ensure_radio_schema


SECTION_TYPES = {"general", "college", "club"}
SCHOOL_TZ = timezone(timedelta(hours=8))


def _require_user(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> dict[str, Any] | None:
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "请先登录")
        return None
    return user


def _require_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> dict[str, Any] | None:
    admin, _ = auth_admin(handler, db)
    if admin is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员未登录或登录已过期")
        return None
    return admin


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _clean(value: Any, limit: int = 2000) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()[:limit]


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _now_timestamp(value: Any) -> float:
    text = str(value or "").strip()
    if not text:
        return 0
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return 0


def add_moderation_task(
    db: dict[str, Any],
    *,
    target_type: str,
    target_id: str,
    title: str,
    content: str,
    risk_reasons: list[str] | None = None,
) -> dict[str, Any]:
    task = {
        "id": next_id(db, "moderationTask", "mt"),
        "targetType": target_type,
        "targetId": target_id,
        "title": _clean(title, 120),
        "content": _clean(content, 1000),
        "riskReasons": risk_reasons or [],
        "status": "pending",
        "result": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db.setdefault("moderationTasks", []).append(task)
    return task


def _serialize_section(section: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(section.get("id", "")),
        "sectionType": str(section.get("sectionType", "")),
        "sectionId": str(section.get("sectionId", "")),
        "sectionName": str(section.get("sectionName") or section.get("name") or ""),
        "name": str(section.get("name") or section.get("sectionName") or ""),
        "description": str(section.get("description", "")),
        "ruleText": str(section.get("ruleText", "")),
        "enabled": bool(section.get("enabled", True)),
        "sortOrder": _safe_int(section.get("sortOrder"), 0),
        "createdAt": str(section.get("createdAt", "")),
        "updatedAt": str(section.get("updatedAt", "")),
    }


def _serialize_club(club: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(club.get("id", "")),
        "name": str(club.get("name", "")),
        "description": str(club.get("description", "")),
        "category": str(club.get("category", "")),
        "ownerUserId": str(club.get("ownerUserId", "")),
        "ownerName": str(club.get("ownerName", "")),
        "sectionId": str(club.get("sectionId", "")),
        "status": str(club.get("status", "active")),
        "createdAt": str(club.get("createdAt", "")),
    }


def _serialize_campus_service(row: dict[str, Any]) -> dict[str, Any]:
    actions = []
    for item in _as_list(row.get("actions")):
        if not isinstance(item, dict):
            continue
        label = str(item.get("label", "")).strip()
        action_type = str(item.get("type", "")).strip()
        if not label or not action_type:
            continue
        actions.append({
            "label": label,
            "type": action_type,
            "url": str(item.get("url", "")).strip(),
            "path": str(item.get("path", "")).strip(),
            "payload": item.get("payload", {}),
        })
    return {
        "id": str(row.get("id", "")),
        "slug": str(row.get("slug", "")),
        "name": str(row.get("name", "")),
        "groupId": str(row.get("groupId", "")),
        "groupName": str(row.get("groupName", "")),
        "kind": str(row.get("kind", "integration")),
        "iconKey": str(row.get("iconKey", "service")),
        "authType": str(row.get("authType", "")),
        "status": str(row.get("status", "待接入")),
        "description": str(row.get("description", "")),
        "requiredAccess": str(row.get("requiredAccess", "")),
        "features": [str(item).strip() for item in _as_list(row.get("features")) if str(item).strip()],
        "dataFields": [str(item).strip() for item in _as_list(row.get("dataFields")) if str(item).strip()],
        "calendarSource": str(row.get("calendarSource", "")),
        "emptyText": str(row.get("emptyText", "")),
        "mapIds": [str(item).strip() for item in _as_list(row.get("mapIds")) if str(item).strip()],
        "actions": actions,
        "path": str(row.get("path", "/pages/campus/service-detail/index")),
        "enabled": bool(row.get("enabled", True)),
        "sortOrder": _safe_int(row.get("sortOrder"), 0),
        "createdAt": str(row.get("createdAt", "")),
        "updatedAt": str(row.get("updatedAt", "")),
    }



def _serialize_source_ref(item: dict[str, Any], source_type: str) -> dict[str, Any]:
    if source_type == "post":
        return {
            "sourceType": "帖子",
            "targetType": "post",
            "targetId": str(item.get("id", "")),
            "title": str(item.get("title") or item.get("displayTitle") or "无标题帖子"),
            "summary": _clean(item.get("content", ""), 90),
            "publishedAt": str(item.get("createdAt", "")),
            "publisher": str(item.get("sectionName") or item.get("channel") or ""),
            "jumpUrl": f"/pages/campus/post-detail/index?id={item.get('id', '')}",
        }
    return {
        "sourceType": "校园知识",
        "targetType": "knowledge",
        "targetId": str(item.get("id", "")),
        "title": str(item.get("title", "")),
        "summary": _clean(item.get("content", ""), 90),
        "publishedAt": str(item.get("createdAt", "")),
        "publisher": str(item.get("sourceName", "")),
        "sourceUrl": str(item.get("sourceUrl", "")),
        "jumpUrl": "",
    }


def handle_get_sections(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [
        _serialize_section(row)
        for row in db.get("sections", [])
        if bool(row.get("enabled", True)) and str(row.get("sectionType", "")).strip().lower() != "school"
    ]
    rows.sort(key=lambda item: (item.get("sortOrder", 0), item.get("name", "")))
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_sections_tree(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [
        _serialize_section(row)
        for row in db.get("sections", [])
        if bool(row.get("enabled", True)) and str(row.get("sectionType", "")).strip().lower() != "school"
    ]
    sections = [row for row in rows if row["sectionType"] in {"general", "college", "club"}]
    tree = {
        "sections": sections,
        "general": [row for row in rows if row["sectionType"] == "general"],
        "colleges": [row for row in rows if row["sectionType"] == "college"],
        "clubs": [row for row in rows if row["sectionType"] == "club"],
    }
    send_json(handler, HTTPStatus.OK, {"data": tree})


def handle_get_section_posts(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    section_id: str,
    query: dict[str, list[str]],
) -> None:
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""
    rows = [
        serialize_post(db, post, viewer_user_id=viewer_user_id)
        for post in list_posts(
            db,
            sort_by=(query.get("sort", ["latest"])[0] or "latest"),
            viewer_user_id=viewer_user_id,
        )
        if str(post.get("sectionId", "")) == section_id or str(post.get("sectionType", "")) == section_id
    ]
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_create_section(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    section_type = str(body.get("sectionType", "")).strip()
    name = _clean(body.get("name") or body.get("sectionName"), 80)
    if section_type not in SECTION_TYPES or not name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "分区类型和名称不能为空")
        return
    section = {
        "id": next_id(db, "section", "sec"),
        "sectionType": section_type,
        "sectionId": str(body.get("sectionId") or name).strip(),
        "sectionName": name,
        "name": name,
        "description": _clean(body.get("description"), 300),
        "ruleText": _clean(body.get("ruleText"), 300),
        "enabled": True,
        "sortOrder": _safe_int(body.get("sortOrder"), 500),
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }
    db.setdefault("sections", []).append(section)
    add_audit_log(db, str(admin.get("adminId", "")), "create_section", name)
    save_db(db)
    send_json(handler, HTTPStatus.CREATED, {"data": _serialize_section(section)})


def handle_update_section(handler: BaseHTTPRequestHandler, db: dict[str, Any], section_id: str) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    section = next((row for row in db.get("sections", []) if str(row.get("id", "")) == section_id), None)
    if section is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "分区不存在")
        return
    body = read_json_body(handler)
    for key in ("sectionName", "name", "description", "ruleText", "sectionId"):
        if key in body:
            section[key] = _clean(body.get(key), 300)
    if "enabled" in body:
        section["enabled"] = bool(body.get("enabled"))
    if "sortOrder" in body:
        section["sortOrder"] = _safe_int(body.get("sortOrder"), _safe_int(section.get("sortOrder"), 0))
    section["updatedAt"] = now_iso()
    add_audit_log(db, str(admin.get("adminId", "")), "update_section", section_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_section(section)})


def handle_get_clubs(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [_serialize_club(row) for row in db.get("clubs", []) if str(row.get("status", "active")) == "active"]
    rows.sort(key=lambda item: (item.get("name", ""), item.get("id", "")))
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_club(handler: BaseHTTPRequestHandler, db: dict[str, Any], club_id: str) -> None:
    club = next((row for row in db.get("clubs", []) if str(row.get("id", "")) == club_id), None)
    if club is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "社团不存在")
        return
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")).strip() if viewer else ""
    member_count = sum(
        1 for row in db.get("clubMembers", [])
        if str(row.get("clubId", "")) == club_id
    )
    posts = [
        serialize_post(db, post, viewer_user_id=viewer_user_id)
        for post in list_posts(
            db,
            sort_by="latest",
            viewer_user_id=viewer_user_id,
        )
        if str(post.get("publisherClubId", "")) == club_id or str(post.get("sectionId", "")) == str(club.get("sectionId", ""))
    ]
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {**_serialize_club(club), "memberCount": member_count, "posts": posts}},
    )


def handle_apply_club(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    body = read_json_body(handler)
    name = _clean(body.get("name"), 80)
    description = _clean(body.get("description"), 600)
    if not name or not description:
        json_error(handler, HTTPStatus.BAD_REQUEST, "社团名称和申请说明不能为空")
        return

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "club_application")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="社团申请",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=str(user.get("id", "")).strip(),
        action="club_application",
        setting_key="clubApplicationRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["clubApplicationRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="社团申请",
            retry_after_seconds=retry_after,
        )
        return

    # A second submission for the same club while the first is still pending is
    # a double-tap, not a new application.  Different club names stay allowed.
    duplicate = next(
        (
            row
            for row in db.get("clubApplications", [])
            if str(row.get("applicantUserId", "")) == str(user.get("id", ""))
            and _clean(row.get("name"), 80) == name
            and str(row.get("status", "pending")).strip().lower() == "pending"
        ),
        None,
    )
    if duplicate is not None:
        json_error(handler, HTTPStatus.CONFLICT, "该社团申请已提交，请等待审核")
        return

    application = {
        "id": next_id(db, "clubApplication", "ca"),
        "name": name,
        "description": description,
        "category": _clean(body.get("category"), 60),
        "applicantUserId": str(user.get("id", "")),
        "applicantName": user_nickname(user),
        "contact": _clean(body.get("contact"), 120),
        "status": "pending",
        "reviewNote": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
        "clubId": "",
    }
    db.setdefault("clubApplications", []).append(application)
    add_audit_log(db, str(user.get("id", "")), "apply_club", name)
    save_db(db)
    send_json(handler, HTTPStatus.CREATED, {"data": application})


def handle_my_club_applications(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    rows = [
        row for row in db.get("clubApplications", [])
        if str(row.get("applicantUserId", "")) == str(user.get("id", ""))
    ]
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_admin_club_applications(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", [""])[0] or "").strip()
    rows = [row for row in db.get("clubApplications", []) if not status or row.get("status") == status]
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_admin_club_application_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    application_id: str,
) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    application = next((row for row in db.get("clubApplications", []) if str(row.get("id", "")) == application_id), None)
    if application is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "社团申请不存在")
        return
    if application.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "社团申请已处理")
        return
    if action not in {"approve", "reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的审批动作")
        return
    applicant = find_user_by_id(
        db,
        str(application.get("applicantUserId", "")).strip(),
    )
    if action == "approve" and (
        applicant is None or applicant.get("banned")
    ):
        json_error(handler, HTTPStatus.NOT_FOUND, "申请人账号不存在或不可用")
        return
    application["status"] = "approved" if action == "approve" else "rejected"
    application["reviewNote"] = _clean(body.get("reviewNote") or body.get("reason"), 300)
    application["handledAt"] = now_iso()
    application["handledBy"] = str(admin.get("adminId", ""))
    if action == "approve":
        section = {
            "id": next_id(db, "section", "sec"),
            "sectionType": "club",
            "sectionId": application_id,
            "sectionName": str(application.get("name", "")),
            "name": str(application.get("name", "")),
            "description": str(application.get("description", "")),
            "ruleText": "社团负责人可使用社团名义发布招新、活动、项目和日常信息。",
            "enabled": True,
            "sortOrder": 300,
            "createdAt": now_iso(),
            "updatedAt": now_iso(),
        }
        club = {
            "id": next_id(db, "club", "club"),
            "name": str(application.get("name", "")),
            "description": str(application.get("description", "")),
            "category": str(application.get("category", "")),
            "ownerUserId": str(application.get("applicantUserId", "")),
            "ownerName": str(application.get("applicantName", "")),
            "sectionId": section["sectionId"],
            "status": "active",
            "createdAt": now_iso(),
        }
        member = {
            "id": next_id(db, "clubMember", "cmem"),
            "clubId": club["id"],
            "userId": club["ownerUserId"],
            "role": "owner",
            "createdAt": now_iso(),
        }
        application["clubId"] = club["id"]
        db.setdefault("sections", []).append(section)
        db.setdefault("clubs", []).append(club)
        db.setdefault("clubMembers", []).append(member)
    add_audit_log(db, str(admin.get("adminId", "")), f"club_application_{action}", application_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": application})



def handle_campus_services(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [row for row in db.get("campusServices", []) if bool(row.get("enabled", True))]
    rows.sort(key=lambda item: _safe_int(item.get("sortOrder"), 0))
    send_json(handler, HTTPStatus.OK, {"data": [_serialize_campus_service(row) for row in rows]})


def handle_campus_service_detail(handler: BaseHTTPRequestHandler, db: dict[str, Any], service_id: str) -> None:
    ensure_radio_schema(db)
    row = next(
        (
            item
            for item in db.get("campusServices", [])
            if str(item.get("id", "")) == service_id or str(item.get("slug", "")) == service_id
        ),
        None,
    )
    if row is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "校园服务不存在")
        return
    payload = _serialize_campus_service(row)
    map_ids = set(payload.get("mapIds") or [])
    maps = db.get("campusMaps", [])
    payload["maps"] = [item for item in maps if str(item.get("id", "")) in map_ids] if map_ids else []
    send_json(handler, HTTPStatus.OK, {"data": payload})


def handle_campus_maps(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    send_json(handler, HTTPStatus.OK, {"data": db.get("campusMaps", [])})


def handle_campus_quick_links(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [
        row
        for row in db.get("campusServices", [])
        if row.get("groupId") in {"quick", "tools"} and bool(row.get("enabled", True))
    ]
    rows.sort(key=lambda item: _safe_int(item.get("sortOrder"), 0))
    send_json(handler, HTTPStatus.OK, {"data": [_serialize_campus_service(row) for row in rows]})


def _time_minutes(value: str) -> int:
    hour, minute = str(value).split(":")
    return int(hour) * 60 + int(minute)


def _serialize_schedule_row(row: dict[str, Any], source_key: str, source_label: str) -> dict[str, Any]:
    item = {
        "id": str(row.get("id", "")),
        "ownerUserId": str(row.get("ownerUserId", "")),
        "source": source_key,
        "sourceLabel": source_label,
        "title": str(row.get("title", "")),
        "startTime": str(row.get("startTime", "")),
        "endTime": str(row.get("endTime", "")),
        "location": str(row.get("location", "")),
        "date": str(row.get("date", "")),
        "teacher": str(row.get("teacher", "")),
        "section": str(row.get("section", "")),
        "kind": str(row.get("kind", "")),
        "seatNo": str(row.get("seatNo", "")),
        "examType": str(row.get("examType", "")),
    }
    item["timeRange"] = f"{item['startTime']}-{item['endTime']}".strip("-")
    return item


def _campus_schedule_rows(db: dict[str, Any], *, owner_user_id: str = "") -> list[dict[str, Any]]:
    sources = [
        ("courseSchedules", "课表"),
        ("examSchedules", "考试安排"),
        ("experimentSchedules", "实验安排"),
    ]
    rows: list[dict[str, Any]] = []
    for source_key, source_label in sources:
        for row in db.get(source_key, []):
            row_owner = str(row.get("ownerUserId", ""))
            if row_owner and row_owner != owner_user_id:
                continue
            item = _serialize_schedule_row(row, source_key, source_label)
            if not item["date"]:
                continue
            rows.append(item)
    rows.sort(key=lambda item: (item["date"], item["startTime"], item["endTime"], item["id"]))
    return rows


def handle_campus_today_schedules(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    user, _ = auth_user_helper(handler, db)
    owner_user_id = str((user or {}).get("id", ""))
    now = datetime.now(SCHOOL_TZ)
    today = now.date().isoformat()
    now_minutes = now.hour * 60 + now.minute
    rows: list[dict[str, Any]] = []
    for item in _campus_schedule_rows(db, owner_user_id=owner_user_id):
        if item["date"] != today:
            continue
        try:
            item["startMinutes"] = _time_minutes(item["startTime"])
            item["endMinutes"] = _time_minutes(item["endTime"])
        except (ValueError, TypeError):
            item["startMinutes"] = 0
            item["endMinutes"] = 0
        item["isActive"] = item["startMinutes"] <= now_minutes < item["endMinutes"]
        rows.append(item)
    rows.sort(key=lambda item: (item["startMinutes"], item["endMinutes"], item["id"]))
    active_rows = [item for item in rows if item["isActive"]]
    next_rows = [item for item in rows if item["startMinutes"] > now_minutes]
    emphasized_id = active_rows[0]["id"] if active_rows else (next_rows[0]["id"] if next_rows else "")
    for item in rows:
        item["isEmphasized"] = item["id"] == emphasized_id
        item["timeRange"] = f"{item['startTime']}-{item['endTime']}"
        item.pop("startMinutes")
        item.pop("endMinutes")
    send_json(handler, HTTPStatus.OK, {"data": {"date": today, "items": rows}})


def handle_campus_calendar_schedules(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    ensure_radio_schema(db)
    user, _ = auth_user_helper(handler, db)
    owner_user_id = str((user or {}).get("id", ""))
    today = datetime.now(SCHOOL_TZ).date()
    start_text = (query.get("startDate", [""])[0] or "").strip()
    try:
        start_date = datetime.fromisoformat(start_text).date() if start_text else today - timedelta(days=today.weekday())
    except ValueError:
        start_date = today - timedelta(days=today.weekday())
    days_count = max(1, min(_safe_int((query.get("days", ["7"])[0] or "7"), 7), 31))
    source_filter = (query.get("source", [""])[0] or "").strip()
    if source_filter == "all":
        source_filter = ""
    wanted_sources = {"courseSchedules", "examSchedules"} if source_filter == "academic" else set()
    wanted_dates = [(start_date + timedelta(days=offset)).isoformat() for offset in range(days_count)]
    rows = [
        item
        for item in _campus_schedule_rows(db, owner_user_id=owner_user_id)
        if item["date"] in wanted_dates
        and (
            bool(wanted_sources and item["source"] in wanted_sources)
            or (not wanted_sources and (not source_filter or item["source"] == source_filter))
        )
    ]
    day_payload = []
    for date_text in wanted_dates:
        day_items = [item for item in rows if item["date"] == date_text]
        day_payload.append({
            "date": date_text,
            "weekday": "一二三四五六日"[(datetime.fromisoformat(date_text).weekday())],
            "isToday": date_text == today.isoformat(),
            "items": day_items,
        })
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "startDate": wanted_dates[0],
                "endDate": wanted_dates[-1],
                "days": day_payload,
            }
        },
    )


def _hot_score(db: dict[str, Any], post: dict[str, Any]) -> float:
    post_id = str(post.get("id", ""))
    view_count = _safe_int(post.get("viewCount"), 0)
    like_count = sum(1 for like in db.get("likes", []) if str(like.get("postId", "")) == post_id)
    comment_count = sum(1 for comment in db.get("comments", []) if not comment.get("deleted") and str(comment.get("postId", "")) == post_id)
    favorite_count = sum(1 for favorite in db.get("favorites", []) if str(favorite.get("postId", "")) == post_id)
    share_count = _safe_int(post.get("shareCount"), 0)
    age_seconds = max(0, datetime.now(timezone.utc).timestamp() - _now_timestamp(post.get("createdAt")))
    recency = max(0, 24 - age_seconds / 3600)
    return view_count * 1 + like_count * 4 + comment_count * 6 + favorite_count * 5 + share_count * 3 + recency


def rebuild_hot_topics(db: dict[str, Any]) -> list[dict[str, Any]]:
    day = now_iso()[:10]
    rows = []
    for rank, post in enumerate(
        sorted(
            list_posts(db, sort_by="latest", viewer_user_id=""),
            key=lambda item: _hot_score(db, item),
            reverse=True,
        )[:50],
        start=1,
    ):
        item = {
            "id": f"hot-{day}-{post.get('id')}",
            "date": day,
            "rank": rank,
            "postId": str(post.get("id", "")),
            "title": str(post.get("title") or _clean(post.get("content"), 30)),
            "summary": _clean(post.get("content"), 120),
            "hotScore": round(_hot_score(db, post), 2),
            "sectionName": str(post.get("sectionName") or post.get("channel") or ""),
            "reviewStatus": "pending",
            "createdAt": now_iso(),
        }
        rows.append(item)
    db["hotTopics"] = [row for row in db.get("hotTopics", []) if row.get("date") != day] + rows
    for item in rows[:10]:
        add_moderation_task(db, target_type="hot_topic", target_id=item["id"], title=item["title"], content=item["summary"])
    return rows


def _public_hot_topics(db: dict[str, Any]) -> list[dict[str, Any]]:
    posts_by_id = {
        str(post.get("id", "")).strip(): post
        for post in db.get("posts", [])
        if str(post.get("id", "")).strip()
    }
    rows: list[dict[str, Any]] = []
    for row in db.get("hotTopics", []):
        post = posts_by_id.get(str(row.get("postId", "")).strip())
        if (
            post is None
            or post.get("deleted")
            or str(post.get("visibility", "public")).strip().lower() == "private"
            or str(post.get("reviewStatus", "approved")).strip().lower()
            not in {"approved", "resolved"}
        ):
            continue
        if row.get("reviewStatus") not in {"approved", "pending", "resolved"}:
            continue
        rows.append(row)
    return rows


def handle_get_hot_topics(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    if not db.get("hotTopics"):
        rebuild_hot_topics(db)
        save_db(db)
    rows = _public_hot_topics(db)
    rows.sort(key=lambda item: (_safe_int(item.get("rank"), 0), str(item.get("createdAt", ""))))
    send_json(handler, HTTPStatus.OK, {"data": rows[:50]})


def handle_rebuild_hot_topics(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    rows = rebuild_hot_topics(db)
    add_audit_log(db, str(admin.get("adminId", "")), "rebuild_hot_topics", str(len(rows)))
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def _search_items(db: dict[str, Any], query_text: str) -> list[dict[str, Any]]:
    return citations(retrieve(db, query_text, include_posts=True, limit=12))


def handle_ai_search(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    body = read_json_body(handler)

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "ai_search")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="AI 检索",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=str(user.get("id", "")).strip(),
        action="ai_search",
        setting_key="aiSearchRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["aiSearchRateLimit"]),
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="AI 检索",
            retry_after_seconds=retry_after,
        )
        return
    query_text = _clean(body.get("query") or body.get("content"), 300)
    if not query_text:
        json_error(handler, HTTPStatus.BAD_REQUEST, "检索内容不能为空")
        return
    rows = _search_items(db, query_text)
    send_json(handler, HTTPStatus.OK, {"data": {"items": rows, "citations": rows}})


def handle_ai_post_selection(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    body = read_json_body(handler)

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "ai_search")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="AI 检索",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=str(user.get("id", "")).strip(),
        action="ai_search",
        setting_key="aiSearchRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["aiSearchRateLimit"]),
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="AI 检索",
            retry_after_seconds=retry_after,
        )
        return
    selected_text = _clean(body.get("selectedText") or body.get("content"), 1200)
    question = _clean(body.get("question") or "解释这段内容并给出校园相关线索", 300)
    if not selected_text:
        json_error(handler, HTTPStatus.BAD_REQUEST, "选中文本不能为空")
        return
    citations = forum_citations(retrieve(db, f"{question} {selected_text}", include_posts=True, limit=6))
    answer = f"已根据选中文本整理：{selected_text[:160]}。如涉及论坛讨论，相关原帖会在下方提供。"
    send_json(handler, HTTPStatus.OK, {"data": {"answer": answer, "citations": citations, "relatedActions": [], "usage": {"sourceCount": len(citations)}, "reviewStatus": "approved"}})



def handle_ai_hot_summary(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    topics = sorted(
        _public_hot_topics(db),
        key=lambda item: _safe_int(item.get("rank"), 0),
    )[:8]
    answer = "热榜总结：" + "；".join(f"{item.get('rank')}. {item.get('title')}" for item in topics) if topics else "暂无热榜内容。"
    send_json(handler, HTTPStatus.OK, {"data": {"answer": answer, "citations": topics, "reviewStatus": "approved"}})


def handle_admin_knowledge_source(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    name = _clean(body.get("name"), 80)
    content = _clean(body.get("content"), 12000)
    if not name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "知识来源名称不能为空")
        return
    source = {
        "id": next_id(db, "knowledgeSource", "ks"),
        "name": name,
        "sourceType": _clean(body.get("sourceType") or "other", 40),
        "authority": _clean(body.get("authority") or "curated", 24),
        "sourceUrl": _clean(body.get("sourceUrl"), 1000),
        "status": "published",
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }
    document = {
        "id": next_id(db, "knowledgeDocument", "kd"),
        "sourceId": source["id"],
        "title": name,
        "content": content,
        "sourceUrl": source.get("sourceUrl", ""),
        "status": "published",
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }
    db.setdefault("knowledgeSources", []).append(source)
    db.setdefault("knowledgeDocuments", []).append(document)
    if content:
        for index, chunk in enumerate(re.findall(r".{1,700}(?:\s|$)", content), start=1):
            db.setdefault("knowledgeChunks", []).append({
                "id": next_id(db, "knowledgeChunk", "kc"),
                "sourceId": source["id"],
                "documentId": document["id"],
                "title": f"{name} {index}",
                "content": chunk,
                "sourceUrl": source.get("sourceUrl", ""),
                "authority": source.get("authority", "curated"),
                "status": "published",
                "createdAt": now_iso(),
                "updatedAt": now_iso(),
            })
    add_audit_log(db, str(admin.get("adminId", "")), "create_knowledge_source", name)
    index = rebuild_rag_index(db)
    save_db(db)
    send_json(handler, HTTPStatus.CREATED, {"data": {**source, "documentId": document["id"], "chunkCount": len([row for row in db.get("knowledgeChunks", []) if row.get("documentId") == document["id"]]), "indexCount": index.get("documentCount", 0)}})


def handle_admin_list_knowledge_sources(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    if _require_admin(handler, db) is None:
        return
    documents = db.get("knowledgeDocuments", [])
    chunks = db.get("knowledgeChunks", [])
    rows = []
    for source in db.get("knowledgeSources", []):
        source_id = str(source.get("id", ""))
        source_documents = [row for row in documents if str(row.get("sourceId", "")) == source_id]
        source_document_ids = {str(row.get("id", "")) for row in source_documents}
        source_chunks = [row for row in chunks if str(row.get("documentId", "")) in source_document_ids]
        rows.append({
            **source,
            "documentCount": len(source_documents),
            "chunkCount": len(source_chunks),
            "contentLength": sum(len(str(row.get("content", ""))) for row in source_documents),
        })
    rows.sort(key=lambda item: str(item.get("updatedAt") or item.get("createdAt") or ""), reverse=True)
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"items": rows, "index": rag_index_summary()}},
    )


def _replace_source_chunks(db: dict[str, Any], source: dict[str, Any], document: dict[str, Any]) -> int:
    document_id = str(document.get("id", ""))
    db["knowledgeChunks"] = [
        row for row in db.get("knowledgeChunks", [])
        if str(row.get("documentId", "")) != document_id
    ]
    content = str(document.get("content", ""))
    count = 0
    for index, chunk in enumerate(re.findall(r".{1,700}(?:\s|$)", content), start=1):
        db.setdefault("knowledgeChunks", []).append({
            "id": next_id(db, "knowledgeChunk", "kc"),
            "sourceId": source["id"],
            "documentId": document_id,
            "title": f"{document.get('title') or source.get('name')} {index}",
            "content": chunk,
            "sourceUrl": source.get("sourceUrl", ""),
            "authority": source.get("authority", "curated"),
            "status": source.get("status", "published"),
            "createdAt": now_iso(),
            "updatedAt": now_iso(),
        })
        count += 1
    return count


def handle_admin_update_knowledge_source(handler: BaseHTTPRequestHandler, db: dict[str, Any], source_id: str) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    source = next((row for row in db.get("knowledgeSources", []) if str(row.get("id")) == source_id), None)
    if source is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "知识来源不存在")
        return
    body = read_json_body(handler)
    for key, limit in (("name", 80), ("sourceType", 40), ("authority", 24), ("sourceUrl", 1000), ("status", 24)):
        if key in body:
            source[key] = _clean(body.get(key), limit)
    source["updatedAt"] = now_iso()
    source_documents = [row for row in db.get("knowledgeDocuments", []) if str(row.get("sourceId")) == source_id]
    document = source_documents[0] if source_documents else None
    if "content" in body:
        if document is None:
            document = {
                "id": next_id(db, "knowledgeDocument", "kd"),
                "sourceId": source_id,
                "createdAt": now_iso(),
            }
            db.setdefault("knowledgeDocuments", []).append(document)
        document.update({
            "title": source.get("name", "校园资料"),
            "content": _clean(body.get("content"), 12000),
            "sourceUrl": source.get("sourceUrl", ""),
            "status": source.get("status", "published"),
            "updatedAt": now_iso(),
        })
        _replace_source_chunks(db, source, document)
    index = rebuild_rag_index(db)
    add_audit_log(db, str(admin.get("adminId", "")), "update_knowledge_source", source_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {**source, "indexCount": index.get("documentCount", 0)}})


def handle_admin_delete_knowledge_source(handler: BaseHTTPRequestHandler, db: dict[str, Any], source_id: str) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    source = next((row for row in db.get("knowledgeSources", []) if str(row.get("id")) == source_id), None)
    if source is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "知识来源不存在")
        return
    document_ids = {
        str(row.get("id")) for row in db.get("knowledgeDocuments", [])
        if str(row.get("sourceId")) == source_id
    }
    db["knowledgeSources"] = [row for row in db.get("knowledgeSources", []) if str(row.get("id")) != source_id]
    db["knowledgeDocuments"] = [row for row in db.get("knowledgeDocuments", []) if str(row.get("sourceId")) != source_id]
    db["knowledgeChunks"] = [row for row in db.get("knowledgeChunks", []) if str(row.get("documentId")) not in document_ids]
    rebuild_rag_index(db)
    add_audit_log(db, str(admin.get("adminId", "")), "delete_knowledge_source", source_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": source_id}})


def handle_admin_reindex(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    index = rebuild_rag_index(db)
    add_audit_log(db, str(admin.get("adminId", "")), "reindex_knowledge", str(index.get("documentCount", 0)))
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "documentCount": index.get("documentCount", 0), "knowledgeCount": index.get("knowledgeCount", 0), "postCount": index.get("postCount", 0), "updatedAt": index.get("updatedAt", "")}})
