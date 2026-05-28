from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any

from helpers import json_error, now_iso, read_json_body, send_json
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
ANNOUNCEMENT_TYPES = {
    "school",
    "college",
    "major",
    "competition",
    "club",
    "service",
    "other",
}
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


def _serialize_announcement(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row.get("id", "")),
        "title": str(row.get("title", "")),
        "content": str(row.get("content", "")),
        "summary": str(row.get("summary") or _clean(row.get("content", ""), 90)),
        "aiSummary": str(row.get("aiSummary", "")),
        "publishedAt": str(row.get("publishedAt") or row.get("createdAt") or ""),
        "createdAt": str(row.get("createdAt") or row.get("publishedAt") or ""),
        "publisher": str(row.get("publisher", "")),
        "sourceType": str(row.get("sourceType", "other")),
        "sourceName": str(row.get("sourceName", "")),
        "type": str(row.get("type", "")),
        "college": str(row.get("college", "")),
        "major": str(row.get("major", "")),
        "tags": [str(tag) for tag in _as_list(row.get("tags")) if str(tag).strip()],
        "isImportant": bool(row.get("isImportant", False)),
        "originalUrl": str(row.get("originalUrl", "")),
        "jumpUrl": str(row.get("jumpUrl", "")),
        "reviewStatus": str(row.get("reviewStatus", "approved")),
    }


def _announcement_matches(row: dict[str, Any], query: dict[str, list[str]]) -> bool:
    filters = {
        "college": str(row.get("college", "")),
        "major": str(row.get("major", "")),
        "type": str(row.get("type", "")),
        "sourceType": str(row.get("sourceType", "")),
    }
    for key, row_value in filters.items():
        wanted = (query.get(key, [""])[0] or "").strip()
        if wanted and row_value != wanted:
            return False
    keyword = (query.get("keyword", [""])[0] or "").strip().lower()
    if keyword:
        text = f"{row.get('title', '')} {row.get('content', '')} {row.get('publisher', '')}".lower()
        if keyword not in text:
            return False
    start_date = (query.get("startDate", [""])[0] or "").strip()
    end_date = (query.get("endDate", [""])[0] or "").strip()
    published = str(row.get("publishedAt") or row.get("createdAt") or "")
    if start_date and published[:10] < start_date:
        return False
    if end_date and published[:10] > end_date:
        return False
    if (query.get("competition", [""])[0] or "").strip() and row.get("sourceType") != "competition":
        return False
    if (query.get("club", [""])[0] or "").strip() and row.get("sourceType") != "club":
        return False
    return True


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
    if source_type == "announcement":
        return {
            "sourceType": "公告",
            "targetType": "announcement",
            "targetId": str(item.get("id", "")),
            "title": str(item.get("title", "")),
            "summary": str(item.get("summary") or _clean(item.get("content", ""), 90)),
            "publishedAt": str(item.get("publishedAt") or item.get("createdAt") or ""),
            "publisher": str(item.get("publisher", "")),
            "jumpUrl": f"/pages/announcements/detail/index?id={item.get('id', '')}",
        }
    return {
        "sourceType": "校园知识",
        "targetType": "knowledge",
        "targetId": str(item.get("id", "")),
        "title": str(item.get("title", "")),
        "summary": _clean(item.get("content", ""), 90),
        "publishedAt": str(item.get("createdAt", "")),
        "publisher": str(item.get("sourceName", "")),
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
        for post in list_posts(db, sort_by=(query.get("sort", ["latest"])[0] or "latest"))
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
    members = [row for row in db.get("clubMembers", []) if str(row.get("clubId", "")) == club_id]
    posts = [
        serialize_post(db, post, viewer_user_id="")
        for post in list_posts(db, sort_by="latest")
        if str(post.get("publisherClubId", "")) == club_id or str(post.get("sectionId", "")) == str(club.get("sectionId", ""))
    ]
    send_json(handler, HTTPStatus.OK, {"data": {**_serialize_club(club), "members": members, "posts": posts}})


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
            "sectionId": section["id"],
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


def _announcement_rows(db: dict[str, Any], query: dict[str, list[str]]) -> list[dict[str, Any]]:
    rows = [
        _serialize_announcement(row)
        for row in db.get("announcements", [])
        if str(row.get("reviewStatus", "approved")) in {"approved", "resolved"} and _announcement_matches(row, query)
    ]
    preferred_college = (query.get("preferredCollege", [""])[0] or "").strip()
    rows.sort(
        key=lambda item: (
            1 if preferred_college and item.get("college") == preferred_college else 0,
            1 if item.get("isImportant") else 0,
            str(item.get("publishedAt", "")),
        ),
        reverse=True,
    )
    return rows


def handle_get_announcements(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    ensure_radio_schema(db)
    send_json(handler, HTTPStatus.OK, {"data": _announcement_rows(db, query)})


def handle_admin_get_announcements(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": _announcement_rows(db, query)})


def handle_get_announcement(handler: BaseHTTPRequestHandler, db: dict[str, Any], announcement_id: str) -> None:
    row = next((item for item in db.get("announcements", []) if str(item.get("id", "")) == announcement_id), None)
    if row is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "公告不存在")
        return
    send_json(handler, HTTPStatus.OK, {"data": _serialize_announcement(row)})


def handle_announcement_filters(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    rows = [_serialize_announcement(row) for row in db.get("announcements", [])]
    data = {
        "colleges": sorted({row["college"] for row in rows if row["college"]}),
        "majors": sorted({row["major"] for row in rows if row["major"]}),
        "types": sorted({row["type"] for row in rows if row["type"]}),
        "sourceTypes": sorted({row["sourceType"] for row in rows if row["sourceType"]}),
        "tags": sorted({tag for row in rows for tag in row["tags"]}),
    }
    send_json(handler, HTTPStatus.OK, {"data": data})


def _build_daily_summary(db: dict[str, Any]) -> dict[str, Any]:
    today = now_iso()[:10]
    rows = [
        _serialize_announcement(row)
        for row in db.get("announcements", [])
        if str(row.get("publishedAt") or row.get("createdAt") or "")[:10] == today
    ]
    if not rows:
        rows = [_serialize_announcement(row) for row in db.get("announcements", [])][:6]
    important = [row for row in rows if row.get("isImportant")]
    lines = [f"{row['title']}：{row['summary']}" for row in (important or rows)[:6]]
    summary = "今日重点：" + "；".join(lines) if lines else "今日暂无公告。"
    item = {
        "id": f"daily-{today}",
        "date": today,
        "title": "每日公告摘要",
        "summary": summary,
        "items": rows,
        "reviewStatus": "pending",
        "createdAt": now_iso(),
    }
    existing = next((row for row in db.get("dailySummaries", []) if row.get("id") == item["id"]), None)
    if existing is None:
        db.setdefault("dailySummaries", []).append(item)
        add_moderation_task(db, target_type="daily_summary", target_id=item["id"], title=item["title"], content=summary)
    else:
        existing.update(item)
    return item


def handle_daily_summary(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    item = _build_daily_summary(db)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": item})


def handle_admin_create_announcement(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    title = _clean(body.get("title"), 120)
    content = _clean(body.get("content"), 5000)
    if not title or not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标题和正文不能为空")
        return
    source_type = str(body.get("sourceType", "other")).strip()
    if source_type not in ANNOUNCEMENT_TYPES:
        source_type = "other"
    row = {
        "id": next_id(db, "announcement", "ann"),
        "title": title,
        "content": content,
        "summary": _clean(body.get("summary") or content, 120),
        "aiSummary": _clean(body.get("aiSummary"), 600),
        "publishedAt": str(body.get("publishedAt") or now_iso()),
        "createdAt": now_iso(),
        "publisher": _clean(body.get("publisher") or "电台管理员", 80),
        "sourceType": source_type,
        "sourceName": _clean(body.get("sourceName"), 80),
        "type": _clean(body.get("type") or source_type, 40),
        "college": _clean(body.get("college"), 80),
        "major": _clean(body.get("major"), 80),
        "tags": [str(tag).strip() for tag in _as_list(body.get("tags")) if str(tag).strip()],
        "isImportant": bool(body.get("isImportant", False)),
        "originalUrl": str(body.get("originalUrl", "")).strip(),
        "jumpUrl": str(body.get("jumpUrl", "")).strip(),
        "reviewStatus": "approved",
    }
    db.setdefault("announcements", []).append(row)
    add_audit_log(db, str(admin.get("adminId", "")), "create_announcement", title)
    save_db(db)
    send_json(handler, HTTPStatus.CREATED, {"data": _serialize_announcement(row)})


def handle_seed_demo_announcements(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    before = len(db.get("announcements", []))
    db["announcements"] = [row for row in db.get("announcements", []) if not str(row.get("id", "")).startswith("ann-")]
    from services._db_service import _default_announcements

    db["announcements"].extend(_default_announcements(now_iso()))
    add_audit_log(db, str(admin.get("adminId", "")), "seed_demo_announcements", str(before))
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "count": len(db.get("announcements", []))}})


def handle_campus_services(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [row for row in db.get("campusServices", []) if bool(row.get("enabled", True))]
    rows.sort(key=lambda item: _safe_int(item.get("sortOrder"), 0))
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_campus_maps(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    send_json(handler, HTTPStatus.OK, {"data": db.get("campusMaps", [])})


def handle_campus_quick_links(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    rows = [row for row in db.get("campusServices", []) if row.get("groupId") == "quick" and bool(row.get("enabled", True))]
    rows.sort(key=lambda item: _safe_int(item.get("sortOrder"), 0))
    send_json(handler, HTTPStatus.OK, {"data": rows})


def _time_minutes(value: str) -> int:
    hour, minute = str(value).split(":")
    return int(hour) * 60 + int(minute)


def handle_campus_today_schedules(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    ensure_radio_schema(db)
    now = datetime.now(SCHOOL_TZ)
    today = now.date().isoformat()
    now_minutes = now.hour * 60 + now.minute
    sources = [
        ("courseSchedules", "课表"),
        ("examSchedules", "考试安排"),
        ("experimentSchedules", "实验安排"),
    ]
    rows: list[dict[str, Any]] = []
    for source_key, source_label in sources:
        for row in db.get(source_key, []):
            if str(row["date"]) != today:
                continue
            item = {
                "id": str(row["id"]),
                "source": source_key,
                "sourceLabel": source_label,
                "title": str(row["title"]),
                "startTime": str(row["startTime"]),
                "endTime": str(row["endTime"]),
                "location": str(row["location"]),
                "date": str(row["date"]),
            }
            item["startMinutes"] = _time_minutes(item["startTime"])
            item["endMinutes"] = _time_minutes(item["endTime"])
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
    for rank, post in enumerate(sorted(list_posts(db, sort_by="latest"), key=lambda item: _hot_score(db, item), reverse=True)[:50], start=1):
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


def handle_get_hot_topics(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    if not db.get("hotTopics"):
        rebuild_hot_topics(db)
        save_db(db)
    rows = [row for row in db.get("hotTopics", []) if row.get("reviewStatus") in {"approved", "pending", "resolved"}]
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
    terms = [term for term in re.findall(r"[\w\u4e00-\u9fff]{2,}", query_text.lower()) if term]
    rows: list[tuple[int, dict[str, Any]]] = []

    def score(text: str) -> int:
        haystack = text.lower()
        return sum(1 + len(term) for term in terms if term in haystack)

    for announcement in db.get("announcements", []):
        text = f"{announcement.get('title', '')} {announcement.get('content', '')} {announcement.get('publisher', '')}"
        value = score(text)
        if value > 0 or not terms:
            rows.append((value, _serialize_source_ref(announcement, "announcement")))
    for post in list_posts(db, sort_by="latest"):
        text = f"{post.get('title', '')} {post.get('content', '')} {post.get('channel', '')} {' '.join(post.get('tags', []))}"
        value = score(text)
        if value > 0:
            rows.append((value, _serialize_source_ref(post, "post")))
    for chunk in db.get("knowledgeChunks", []):
        text = f"{chunk.get('title', '')} {chunk.get('content', '')}"
        value = score(text)
        if value > 0:
            rows.append((value, _serialize_source_ref(chunk, "knowledge")))
    rows.sort(key=lambda item: item[0], reverse=True)
    return [item[1] for item in rows[:12]]


def handle_ai_search(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    body = read_json_body(handler)
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
    selected_text = _clean(body.get("selectedText") or body.get("content"), 1200)
    question = _clean(body.get("question") or "解释这段内容并给出校园相关线索", 300)
    if not selected_text:
        json_error(handler, HTTPStatus.BAD_REQUEST, "选中文本不能为空")
        return
    citations = _search_items(db, f"{question} {selected_text}")[:6]
    answer = f"已根据选中文本整理：{selected_text[:160]}。建议结合原帖语境判断，相关来源见引用。"
    message = {
        "id": next_id(db, "aiMessage", "aim"),
        "userId": str(user.get("id", "")),
        "role": "assistant",
        "content": answer,
        "citations": citations,
        "createdAt": now_iso(),
    }
    db.setdefault("aiMessages", []).append(message)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"answer": answer, "citations": citations, "relatedActions": [], "usage": {"sourceCount": len(citations)}, "reviewStatus": "approved"}})


def handle_ai_announcement_summary(handler: BaseHTTPRequestHandler, db: dict[str, Any], announcement_id: str) -> None:
    user = _require_user(handler, db)
    if user is None:
        return
    row = next((item for item in db.get("announcements", []) if str(item.get("id", "")) == announcement_id), None)
    if row is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "公告不存在")
        return
    summary = f"{row.get('title', '')}：{_clean(row.get('content', ''), 180)}"
    row["aiSummary"] = summary
    row["reviewStatus"] = "pending"
    add_moderation_task(db, target_type="announcement_summary", target_id=announcement_id, title=str(row.get("title", "")), content=summary)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"answer": summary, "citations": [_serialize_source_ref(row, "announcement")], "reviewStatus": "pending"}})


def handle_ai_daily_summary(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    item = _build_daily_summary(db)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"answer": item["summary"], "citations": [_serialize_source_ref(row, "announcement") for row in item.get("items", [])], "reviewStatus": item["reviewStatus"]}})


def handle_ai_hot_summary(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    if not db.get("hotTopics"):
        rebuild_hot_topics(db)
    topics = sorted(db.get("hotTopics", []), key=lambda item: _safe_int(item.get("rank"), 0))[:8]
    answer = "热榜总结：" + "；".join(f"{item.get('rank')}. {item.get('title')}" for item in topics) if topics else "暂无热榜内容。"
    summary = {
        "id": next_id(db, "hotTopicSummary", "hts"),
        "title": "热榜 AI 总结",
        "content": answer,
        "reviewStatus": "pending",
        "createdAt": now_iso(),
    }
    db.setdefault("hotTopicSummaries", []).append(summary)
    add_moderation_task(db, target_type="hot_topic_summary", target_id=summary["id"], title=summary["title"], content=answer)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"answer": answer, "citations": topics, "reviewStatus": "pending"}})


def handle_admin_knowledge_source(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    name = _clean(body.get("name"), 80)
    content = _clean(body.get("content"), 8000)
    if not name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "知识来源名称不能为空")
        return
    source = {
        "id": next_id(db, "knowledgeSource", "ks"),
        "name": name,
        "sourceType": _clean(body.get("sourceType") or "other", 40),
        "createdAt": now_iso(),
    }
    document = {
        "id": next_id(db, "knowledgeDocument", "kd"),
        "sourceId": source["id"],
        "title": name,
        "content": content,
        "createdAt": now_iso(),
    }
    db.setdefault("knowledgeSources", []).append(source)
    db.setdefault("knowledgeDocuments", []).append(document)
    if content:
        for index, chunk in enumerate(re.findall(r".{1,500}", content), start=1):
            db.setdefault("knowledgeChunks", []).append({
                "id": next_id(db, "knowledgeChunk", "kc"),
                "sourceId": source["id"],
                "documentId": document["id"],
                "title": f"{name} {index}",
                "content": chunk,
                "createdAt": now_iso(),
            })
    add_audit_log(db, str(admin.get("adminId", "")), "create_knowledge_source", name)
    save_db(db)
    send_json(handler, HTTPStatus.CREATED, {"data": source})


def handle_admin_reindex(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    chunks = []
    for row in db.get("announcements", []):
        chunks.append({
            "id": next_id(db, "knowledgeChunk", "kc"),
            "sourceId": "ks-announcements",
            "documentId": str(row.get("id", "")),
            "title": str(row.get("title", "")),
            "content": str(row.get("content", "")),
            "createdAt": now_iso(),
        })
    db["knowledgeChunks"] = chunks
    add_audit_log(db, str(admin.get("adminId", "")), "reindex_knowledge", str(len(chunks)))
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "chunkCount": len(chunks)}})
