"""
handlers/_notification_handler.py

Notification endpoints:
  GET  /api/notifications                        — list notifications + unread count
  POST /api/notifications/read-all               — mark all as read
  GET  re("/api/notifications/([^/]+)/read")     — mark single notification as read
"""
from __future__ import annotations

from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import json_error, read_json_body, send_json
from services import (
    auth_user as auth_user_helper,
    find_user_by_id,
    is_user_blocked,
    load_db,
    save_db,
    serialize_notification,
    user_avatar_url,
)


def _serialize_notification_with_actor_avatar(
    db: dict[str, Any],
    row: dict[str, Any],
) -> dict[str, Any]:
    payload = serialize_notification(row)
    actor_id = str(row.get("actorId", "")).strip()
    actor = find_user_by_id(db, actor_id, include_deleted=True) if actor_id else None
    payload["actorAvatarUrl"] = user_avatar_url(actor)
    return payload


# Categories the clients filter by. Every stored type maps onto one of them.
NOTIFICATION_CATEGORIES = ("comment", "reply", "like", "favorite", "report_result", "system")


def notification_category(notification_type: Any) -> str:
    normalized = str(notification_type or "").strip().lower()
    return normalized if normalized in NOTIFICATION_CATEGORIES else "system"


def handle_get_notifications(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/notifications"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    user_id = str(user.get("id", "")).strip()
    # Blocking also hides what the blocked user sent before the block.
    rows = [
        _serialize_notification_with_actor_avatar(db, row)
        for row in db.get("notifications", [])
        if str(row.get("userId", "")).strip() == user_id
        and not row.get("deleted")
        and not is_user_blocked(db, user_id, str(row.get("actorId", "")))
    ]
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    unread_count = sum(1 for item in rows if not item.get("isRead"))
    unread_by_type = {category: 0 for category in NOTIFICATION_CATEGORIES}
    for item in rows:
        if not item.get("isRead"):
            unread_by_type[notification_category(item.get("type"))] += 1
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {
            "items": rows,
            "unreadCount": unread_count,
            "unreadByType": unread_by_type,
        }},
    )


def handle_mark_all_notifications_read(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/notifications/read-all {type?}

    Without a type, marks everything read. With one of
    NOTIFICATION_CATEGORIES, marks only that category, so 全部已读 on a
    filtered list leaves the other categories unread.
    """
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler) or {}
    requested = str(body.get("type") or "").strip().lower()
    if requested and requested not in NOTIFICATION_CATEGORIES:
        json_error(handler, HTTPStatus.BAD_REQUEST, "未知的通知类型")
        return

    user_id = str(user.get("id", "")).strip()
    now = _globals.now_iso()
    marked = 0
    for notif in db.get("notifications", []):
        if str(notif.get("userId", "")).strip() != user_id or notif.get("deleted"):
            continue
        if requested and notification_category(notif.get("type")) != requested:
            continue
        if not notif.get("isRead"):
            notif["isRead"] = True
            notif["readAt"] = now
            marked += 1

    if marked:
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "marked": marked}})


def handle_mark_notification_read(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    notification_id: str,
) -> None:
    """GET /api/notifications/<id>/read"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    user_id = str(user.get("id", "")).strip()
    now = _globals.now_iso()
    target = None
    for notif in db.get("notifications", []):
        if notif.get("id") == notification_id and str(notif.get("userId", "")).strip() == user_id:
            target = notif
            break

    if target is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "通知不存在")
        return

    if not target.get("isRead"):
        target["isRead"] = True
        target["readAt"] = now
        save_db(db)

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": _serialize_notification_with_actor_avatar(db, target)},
    )
