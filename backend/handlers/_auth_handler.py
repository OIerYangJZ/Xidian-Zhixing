"""
handlers/_auth_handler.py

Authentication & user session endpoints:
  POST /api/auth/login
  POST /api/auth/register
  POST /api/auth/verify
  POST /api/auth/logout
  POST /api/auth/password/send-code
  POST /api/auth/password/reset
  POST /api/auth/send-code  (alias for resend)
  POST /api/auth/resend-code (alias)
"""
from __future__ import annotations

import secrets
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    is_campus_email,
    is_valid_student_id,
    normalize_avatar_url,
    now_iso,
    sanitize_alias,
    student_id_from_email,
    json_error,
    read_json_body,
    send_json,
)
from helpers._xidian_auth import (
    XidianAuthCaptchaError,
    XidianAuthDependencyError,
    XidianAuthPasswordError,
    XidianAuthUnavailableError,
    login_via_xidian_ids,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_student_id,
    save_db,
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


def _default_user_nickname(student_id: str) -> str:
    suffix = student_id.strip()[-4:]
    return sanitize_alias(f"西电同学{suffix}", fallback="西电同学")


def _unified_auth_only(handler: BaseHTTPRequestHandler, *, action: str) -> None:
    json_error(
        handler,
        HTTPStatus.BAD_REQUEST,
        f"普通用户已改为西电统一认证登录，暂不支持{action}，请直接使用学号和统一认证密码登录",
    )


def _login_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    identifier: str,
    password: str,
) -> None:
    """Shared user login logic via Xidian IDS."""
    login_email = ""
    login_student_id = ""

    if "@" in identifier:
        login_email = identifier.lower()
        if not is_campus_email(login_email):
            json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
            return
        login_student_id = student_id_from_email(login_email)
    else:
        login_student_id = identifier
        if not is_valid_student_id(login_student_id):
            json_error(handler, HTTPStatus.BAD_REQUEST, "请输入有效学号")
            return
        login_email = f"{login_student_id}@stu.xidian.edu.cn"

    if not password:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码不能为空")
        return

    try:
        login_result = login_via_xidian_ids(
            login_student_id,
            password,
            email_hint=login_email,
        )
    except XidianAuthPasswordError as error:
        json_error(handler, HTTPStatus.UNAUTHORIZED, str(error))
        return
    except XidianAuthCaptchaError as error:
        json_error(handler, HTTPStatus.SERVICE_UNAVAILABLE, str(error))
        return
    except (XidianAuthUnavailableError, XidianAuthDependencyError) as error:
        json_error(handler, HTTPStatus.SERVICE_UNAVAILABLE, str(error))
        return

    login_student_id = login_result.student_id
    login_email = login_result.campus_email
    user = find_user_by_student_id(db, login_student_id, include_deleted=True)

    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        nickname = _default_user_nickname(login_student_id)
        created_at = now_iso()
        user = {
            "id": _next_id(db, "user", "u"),
            "email": login_email,
            "password": "",
            "alias": nickname,
            "nickname": nickname,
            "studentId": login_student_id,
            "avatarUrl": "",
            "userLevel": _globals.USER_LEVEL_TWO,
            "verified": True,
            "verifiedAt": created_at,
            "allowStrangerDm": True,
            "showContactable": True,
            "notifyComment": True,
            "notifyReply": True,
            "notifyLike": True,
            "notifyFavorite": True,
            "notifyReportResult": True,
            "notifySystem": True,
            "createdAt": created_at,
            "deleted": False,
            "isAdmin": False,
            "banned": False,
            "muted": False,
        }
        db["users"].append(user)
        add_audit_log(db, user["id"], "register_by_xidian_ids", f"统一认证首次登录 {login_student_id}")
    else:
        existing_email = str(user.get("email", "")).strip().lower()
        if not existing_email or not is_campus_email(existing_email):
            user["email"] = login_email
        user["studentId"] = login_student_id
        user["verified"] = True
        if not str(user.get("verifiedAt", "")).strip():
            user["verifiedAt"] = now_iso()
        nickname = sanitize_alias(
            str(user.get("nickname", "")).strip() or str(user.get("alias", "")).strip(),
            fallback=_default_user_nickname(login_student_id),
        )
        user["nickname"] = nickname
        user["alias"] = nickname
        user["avatarUrl"] = normalize_avatar_url(str(user.get("avatarUrl", "")))
        for key in (
            "notifyComment",
            "notifyReply",
            "notifyLike",
            "notifyFavorite",
            "notifyReportResult",
            "notifySystem",
        ):
            if key not in user:
                user[key] = True

    if user.get("banned"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被封禁")
        return

    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
    add_audit_log(db, user.get("id", "-"), "login_by_xidian_ids", f"统一认证登录 {login_student_id}")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "token": token,
                "verified": True,
                "isAdmin": bool(user.get("isAdmin", False)),
                "email": login_email,
                "studentId": login_student_id,
            }
        },
    )


# ---------------------------------------------------------------------------
# Public handler functions (called from TreeholeHandler._handle_post)
# ---------------------------------------------------------------------------


def handle_login(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    identifier = (
        str(
            body.get(
                "identifier",
                body.get("studentId", body.get("email", "")),
            )
        )
        .strip()
    )
    password = str(body.get("password", "")).strip()
    _login_user(handler, db, identifier, password)


def handle_register(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="注册")


def handle_verify(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="邮箱验证码确认")


def handle_logout(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user, token = auth_user_helper(handler, db)
    if token:
        db["sessions"].pop(token, None)
    if user:
        add_audit_log(db, user.get("id", "-"), "logout", "用户退出登录")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "已退出登录", "data": {"ok": True}})


def handle_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="发送邮箱验证码")


def handle_password_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="发送密码重置验证码")


def handle_password_reset(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    _unified_auth_only(handler, action="本地密码重置")
