"""
handlers/_user_handler.py

User profile & social endpoints:
  GET  /api/users/me                           — own profile
  GET  re("/api/users/([^/]+)")                 — public user profile
  PATCH /api/users/me                          — update own profile
  PATCH /api/users/privacy                     — update privacy settings
  POST re("/api/users/([^/]+)/(follow|unfollow)") — follow/unfollow
  GET  /api/users/me/following                  — list following
  GET  /api/users/me/followers                  — list followers
  GET  /api/users/me/friends                    — list mutual follows
"""
from __future__ import annotations

import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    is_valid_student_id,
    json_error,
    normalize_avatar_url,
    read_json_body,
    sanitize_alias,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_id,
    is_user_following,
    latest_account_cancellation_request_for_user,
    latest_user_level_request_for_user,
    list_follower_users,
    list_following_users,
    list_friend_users,
    normalize_optional_bool,
    save_db,
    serialize_account_cancellation_request,
    serialize_public_user_profile,
    serialize_user_level_request_summary,
    user_avatar_url,
    user_nickname,
)


def handle_get_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    uid = str(user.get("id", "")).strip()
    cancellation_req = latest_account_cancellation_request_for_user(db, uid)
    level_req = latest_user_level_request_for_user(db, uid)

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": uid,
                "nickname": user_nickname(user),
                "avatarUrl": user_avatar_url(user),
                "userLevel": user.get("userLevel", _globals.USER_LEVEL_TWO),
                "verified": bool(user.get("verified")),
                "verifiedAt": str(user.get("verifiedAt", "")).strip(),
                "createdAt": str(user.get("createdAt", "")).strip(),
                "email": str(user.get("email", "")).strip(),
                "studentId": str(user.get("studentId", "")).strip(),
                "allowStrangerDm": bool(user.get("allowStrangerDm", True)),
                "showContactable": bool(user.get("showContactable", True)),
                "deleted": bool(user.get("deleted", False)),
                "banned": bool(user.get("banned", False)),
                "muted": bool(user.get("muted", False)),
                "cancellationRequest": serialize_account_cancellation_request(cancellation_req) if cancellation_req else None,
                "levelUpgradeRequest": serialize_user_level_request_summary(level_req) if level_req else None,
            }
        },
    )


def handle_get_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user_id: str,
) -> None:
    """GET /api/users/<id>"""
    auth_user_helper(handler, db)  # ensure auth header is consumed
    target = find_user_by_id(db, user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return

    viewer, _ = auth_user_helper(handler, db)
    viewer_id = str(viewer.get("id", "")) if viewer else ""

    send_json(handler, HTTPStatus.OK, {"data": serialize_public_user_profile(db, target, viewer_id=viewer_id)})


def handle_update_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/me"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    new_nickname = sanitize_alias(str(body.get("nickname", "")), fallback="")
    new_avatar = normalize_avatar_url(str(body.get("avatarUrl", "")), default="")
    new_student_id = str(body.get("studentId", "")).strip()

    if new_student_id and not is_valid_student_id(new_student_id):
        json_error(handler, HTTPStatus.BAD_REQUEST, "学号格式不正确（需为 6-20 位字母或数字）")
        return

    if new_nickname and new_nickname != user_nickname(user):
        user["nickname"] = new_nickname
        user["alias"] = new_nickname
        add_audit_log(db, user["id"], "update_nickname", f"更新昵称为 {new_nickname}")

    if new_avatar:
        user["avatarUrl"] = new_avatar

    if new_student_id:
        user["studentId"] = new_student_id

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "nickname": user_nickname(user)}})


def handle_update_privacy(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/privacy"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    user["allowStrangerDm"] = normalize_optional_bool(body.get("allowStrangerDm"), default=True)
    user["showContactable"] = normalize_optional_bool(body.get("showContactable"), default=True)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_follow(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
) -> None:
    """POST /api/users/<id>/follow"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能关注自己")
        return

    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    already = is_user_following(db, user["id"], target_user_id)
    if already:
        send_json(handler, HTTPStatus.OK, {"data": {"followed": True, "already": True}})
        return

    db["userFollows"].append({
        "followerId": user["id"],
        "followeeId": target_user_id,
        "createdAt": _globals.now_iso(),
    })
    add_audit_log(db, user["id"], "follow", f"关注用户 {target_user_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"followed": True, "already": False}})


def handle_unfollow(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
) -> None:
    """POST /api/users/<id>/unfollow"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    db["userFollows"][:] = [
        f for f in db["userFollows"]
        if not (f.get("followerId") == user["id"] and f.get("followeeId") == target_user_id)
    ]
    add_audit_log(db, user["id"], "unfollow", f"取消关注用户 {target_user_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"followed": False}})


def handle_get_following(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/following"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(handler, HTTPStatus.OK, {"data": list_following_users(db, user["id"])})


def handle_get_followers(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/followers"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(handler, HTTPStatus.OK, {"data": list_follower_users(db, user["id"])})


def handle_get_friends(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/friends"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(handler, HTTPStatus.OK, {"data": list_friend_users(db, user["id"])})
