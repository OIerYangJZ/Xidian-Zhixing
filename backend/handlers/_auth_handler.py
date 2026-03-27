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
from datetime import timedelta
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    decode_base64_payload,
    detect_image_type,
    hash_password,
    is_campus_email,
    is_password_hashed,
    is_valid_student_id,
    normalize_avatar_url,
    now_iso,
    now_utc,
    parse_iso,
    random_code,
    sanitize_alias,
    student_id_from_email,
    verify_password,
    json_error,
    read_json_body,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_email,
    find_user_by_student_id,
    save_db,
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


def _login_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    identifier: str,
    password: str,
) -> None:
    """Shared login logic used by POST /api/auth/login."""
    login_email = ""
    login_student_id = ""
    user: dict[str, Any] | None = None

    if "@" in identifier:
        login_email = identifier.lower()
        if not is_campus_email(login_email):
            json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
            return
        user = find_user_by_email(db, login_email, include_deleted=True)
    else:
        login_student_id = identifier
        if not is_valid_student_id(login_student_id):
            json_error(handler, HTTPStatus.BAD_REQUEST, "请输入有效学号")
            return
        user = find_user_by_student_id(db, login_student_id, include_deleted=True)
        if user is not None:
            login_email = str(user.get("email", "")).strip().lower()

    if not password:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码不能为空")
        return

    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return
    if not login_email:
        login_email = str(user.get("email", "")).strip().lower()
    if not login_student_id:
        login_student_id = str(user.get("studentId", "")).strip() or student_id_from_email(login_email)

    stored_password = str(user.get("password", ""))
    if not stored_password:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "账号未设置密码，请先注册")
        return
    if not verify_password(stored_password, password):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "账号或密码错误")
        return
    if not is_password_hashed(stored_password):
        user["password"] = hash_password(password)

    if user.get("banned"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被封禁")
        return

    smtp_enabled = _globals.smtp_configured()

    if not user.get("verified", False):
        if login_email not in db["emailCodes"]:
            code = random_code() if smtp_enabled else "123456"
            if smtp_enabled:
                try:
                    from helpers import send_verification_email
                    send_verification_email(to_email=login_email, code=code, expires_in_minutes=10)
                except Exception as error:
                    from helpers import verification_send_error_message
                    json_error(
                        handler,
                        HTTPStatus.SERVICE_UNAVAILABLE,
                        verification_send_error_message(error),
                    )
                    return
            db["emailCodes"][login_email] = {
                "code": code,
                "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
            }
        from helpers import send_verification_email, verification_send_error_message
        save_db(db)
        response_data: dict[str, Any] = {
            "verified": False,
            "needVerify": True,
            "email": login_email,
            "studentId": login_student_id,
        }
        if not smtp_enabled or _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE:
            current_code = (
                str(db["emailCodes"].get(login_email, {}).get("code", "")).strip()
                or "123456"
            )
            response_data["debugCode"] = current_code
        send_json(handler, HTTPStatus.OK, {"data": response_data})
        return

    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
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
    from helpers import send_verification_email, verification_send_error_message, extract_local_object_key_from_url

    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    password = str(body.get("password", "")).strip()
    nickname = sanitize_alias(str(body.get("nickname", "")), fallback="")
    student_id = student_id_from_email(email)
    avatar_url = normalize_avatar_url(str(body.get("avatarUrl", "")))
    avatar_data_base64 = str(body.get("avatarDataBase64", "")).strip()
    avatar_file_name = str(body.get("avatarFileName", "avatar.png")).strip() or "avatar.png"
    avatar_content_type = str(body.get("avatarContentType", "")).strip().lower()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    if len(password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "密码长度至少 6 位")
        return
    if not nickname:
        json_error(handler, HTTPStatus.BAD_REQUEST, "昵称不能为空")
        return
    if not is_valid_student_id(student_id):
        json_error(handler, HTTPStatus.BAD_REQUEST, "邮箱前缀不符合学号格式（需为 6-20 位字母或数字）")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is not None and user.get("verified"):
        json_error(handler, HTTPStatus.CONFLICT, "账号已存在，请直接登录")
        return
    existing_student = find_user_by_student_id(db, student_id, include_deleted=False)
    if (
        existing_student is not None
        and str(existing_student.get("email", "")).strip().lower() != email
    ):
        json_error(handler, HTTPStatus.CONFLICT, "该学号已绑定其他账号")
        return

    uploaded_avatar_key = ""
    if avatar_data_base64:
        try:
            avatar_bytes = decode_base64_payload(avatar_data_base64)
        except Exception:
            json_error(handler, HTTPStatus.BAD_REQUEST, "头像图片数据格式错误")
            return
        if not avatar_bytes:
            json_error(handler, HTTPStatus.BAD_REQUEST, "头像图片不能为空")
            return
        detected_content_type = detect_image_type(avatar_bytes)
        if detected_content_type is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
            return
        avatar_ct = detected_content_type
        if avatar_content_type and avatar_content_type in _globals.ALLOWED_IMAGE_TYPES:
            avatar_ct = avatar_content_type

        max_bytes = int(_globals.DEFAULT_SETTINGS.get("imageMaxMB", 5)) * 1024 * 1024
        if len(avatar_bytes) > max_bytes:
            json_error(
                handler,
                HTTPStatus.BAD_REQUEST,
                f"头像图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
            )
            return
        try:
            stored_avatar = _globals.OBJECT_STORAGE.put_bytes(
                data=avatar_bytes,
                file_name=avatar_file_name,
                content_type=avatar_ct,
            )
        except Exception:
            json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "头像上传失败，请稍后重试")
            return
        avatar_url = stored_avatar.url
        uploaded_avatar_key = stored_avatar.key

    old_avatar_key = ""
    if user is not None:
        old_avatar_key = extract_local_object_key_from_url(normalize_avatar_url(str(user.get("avatarUrl", ""))))

    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_verification_email(to_email=email, code=code, expires_in_minutes=10)
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return

    if user is None:
        user = {
            "id": _next_id(db, "user", "u"),
            "email": email,
            "password": hash_password(password),
            "alias": nickname,
            "nickname": nickname,
            "studentId": student_id,
            "avatarUrl": avatar_url,
            "userLevel": _globals.USER_LEVEL_TWO,
            "verified": False,
            "verifiedAt": "",
            "allowStrangerDm": True,
            "showContactable": True,
            "createdAt": now_iso(),
            "deleted": False,
            "isAdmin": False,
            "banned": False,
            "muted": False,
        }
        db["users"].append(user)
    else:
        user["password"] = hash_password(password)
        user["alias"] = nickname
        user["nickname"] = nickname
        user["studentId"] = student_id
        user["avatarUrl"] = avatar_url

    db["emailCodes"][email] = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }

    save_db(db)
    if old_avatar_key and uploaded_avatar_key and old_avatar_key != uploaded_avatar_key:
        try:
            _globals.OBJECT_STORAGE.delete(old_avatar_key)
        except Exception:
            pass
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "注册成功，请完成邮箱验证"
            if smtp_enabled
            else "注册成功，邮件服务未配置，内测验证码为 123456",
            "data": {
                "needVerify": True,
                "verified": False,
                "email": email,
                "studentId": student_id,
                **(
                    {"debugCode": code}
                    if (_globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled)
                    else {}
                ),
            },
        },
    )


def handle_verify(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    code = str(body.get("code", "")).strip()
    password = str(body.get("password", "")).strip()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    if len(code) != 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码格式错误")
        return

    code_row = db["emailCodes"].get(email)
    if not code_row:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先发送验证码")
        return
    if code_row.get("code") != code and not (_globals.verify_code_debug_enabled() and code == "123456"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码错误")
        return

    expires_at = parse_iso(code_row.get("expiresAt", ""))
    if expires_at is None or now_utc() > expires_at:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码已过期")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return

    if password:
        user["password"] = hash_password(password)
    user["verified"] = True
    user["verifiedAt"] = now_iso()
    user["nickname"] = user.get("nickname") or user.get("alias") or "匿名同学"
    user["alias"] = user["nickname"]
    user["studentId"] = str(user.get("studentId", "")).strip() or student_id_from_email(email)
    user["avatarUrl"] = normalize_avatar_url(str(user.get("avatarUrl", "")))

    db["emailCodes"].pop(email, None)
    token = secrets.token_urlsafe(24)
    db["sessions"][token] = user["id"]
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "token": token,
                "verified": True,
                "isAdmin": bool(user.get("isAdmin", False)),
            }
        },
    )


def handle_logout(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user, token = auth_user_helper(handler, db)
    if token:
        db["sessions"].pop(token, None)
    if user:
        add_audit_log(db, user.get("id", "-"), "logout", "用户退出登录")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "已退出登录", "data": {"ok": True}})


def handle_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    from helpers import send_verification_email, verification_send_error_message

    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_verification_email(to_email=email, code=code, expires_in_minutes=10)
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return
    db["emailCodes"][email] = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }
    save_db(db)
    data: dict[str, Any] = {
        "email": email,
        "expiresInSeconds": 600,
    }
    if _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
        data["debugCode"] = code
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "验证码已发送" if smtp_enabled else "邮件服务未配置，已启用内测验证码",
            "data": data,
        },
    )


def handle_password_send_code(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    from helpers import send_password_reset_email, verification_send_error_message

    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return
    smtp_enabled = _globals.smtp_configured()
    code = random_code() if smtp_enabled else "123456"
    if smtp_enabled:
        try:
            send_password_reset_email(to_email=email, code=code, expires_in_minutes=10)
        except Exception as error:
            json_error(
                handler,
                HTTPStatus.SERVICE_UNAVAILABLE,
                verification_send_error_message(error),
            )
            return
    db["emailCodes"][f"{_globals.PASSWORD_RESET_CODE_PREFIX}{email}"] = {
        "code": code,
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
    }
    save_db(db)
    data: dict[str, Any] = {
        "email": email,
        "expiresInSeconds": 600,
    }
    if _globals.INCLUDE_DEBUG_CODE_IN_RESPONSE or not smtp_enabled:
        data["debugCode"] = code
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "message": "重置密码验证码已发送"
            if smtp_enabled
            else "邮件服务未配置，已启用内测验证码",
            "data": data,
        },
    )


def handle_password_reset(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    code = str(body.get("code", "")).strip()
    new_password = str(body.get("newPassword", "")).strip()
    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电校内邮箱")
        return
    if len(code) != 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码格式错误")
        return
    if len(new_password) < 6:
        json_error(handler, HTTPStatus.BAD_REQUEST, "新密码长度至少 6 位")
        return

    user = find_user_by_email(db, email, include_deleted=True)
    if user is not None and user.get("deleted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已注销，请联系管理员恢复")
        return
    if user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "账号不存在，请先注册")
        return

    code_row = db["emailCodes"].get(f"{_globals.PASSWORD_RESET_CODE_PREFIX}{email}")
    if not code_row:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请先发送重置验证码")
        return
    if code_row.get("code") != code and not (_globals.verify_code_debug_enabled() and code == "123456"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码错误")
        return

    expires_at = parse_iso(code_row.get("expiresAt", ""))
    if expires_at is None or now_utc() > expires_at:
        json_error(handler, HTTPStatus.BAD_REQUEST, "验证码已过期")
        return

    user["password"] = hash_password(new_password)
    db["emailCodes"].pop(f"{_globals.PASSWORD_RESET_CODE_PREFIX}{email}", None)
    add_audit_log(db, user["id"], "reset_password_by_email", f"邮箱重置密码 {email}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "密码重置成功", "data": {"ok": True}})
