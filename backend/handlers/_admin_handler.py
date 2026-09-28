"""
handlers/_admin_handler.py

Admin & moderation endpoints:
  POST /api/admin/auth/login                        — admin login
  POST /api/admin/auth/logout                       — admin logout
  GET  /api/admin/auth/me                          — current admin session info
  GET  /api/admin/overview                          — system overview stats
  GET  /api/admin/reviews                           — content review list (post/comment)
  GET  /api/admin/reports                           — user reports list
  GET  /api/admin/images/reviews                   — image moderation list
  GET  /api/admin/users                             — user management list
  GET  /api/admin/post-pin-requests                — pin-top request list
  GET  /api/admin/user-level-requests              — level-upgrade request list
  GET  /api/admin/admin-accounts                    — secondary admin account list
  GET  /api/admin/account-cancellation-requests    — account cancellation list
  GET  /api/admin/appeals                          — appeal list
  GET  /api/admin/export                           — data export
  GET  /api/admin/tags                           — tag list
  GET  /api/admin/config                          — sensitive words & system settings
  GET  /api/admin/announcements                   — published announcements
  POST /api/admin/auth/password                   — change own admin password
  POST /api/admin/announcements                   — publish system announcement
  POST /api/admin/reviews/batch                   — batch approve/reject/delete/risk
  POST /api/admin/reviews/(post|comment)/<id>/(approve|reject|delete|risk) — single review
  POST /api/admin/reports/<id>/handle             — handle a user report
  POST /api/admin/post-pin-requests/<id>/handle   — handle pin-top request
  POST /api/admin/user-level-requests/<id>/handle — handle level-upgrade request
  POST /api/admin/admin-accounts                  — create secondary admin account
  POST /api/admin/admin-accounts/<id>/action       — deactivate/activate admin account
  POST /api/admin/users/<id>/action              — mute/unmute/ban/unban/cancel/restore user
  POST /api/admin/appeals/<id>/handle            — handle appeal
  POST /api/admin/account-cancellation-requests/<id>/handle — handle cancellation
  POST /api/admin/images/<id>/review             — approve/reject/delete/risk image
  POST /api/admin/tags                           — add tag
  PATCH /api/admin/tags/<name>                  — rename tag
  PATCH /api/admin/config                        — update config (sensitive words, rate limits)
  DELETE /api/admin/tags/<name>                  — delete tag
"""
from __future__ import annotations

import copy
import logging
import os
import re
import secrets
import time
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from object_storage import (
    StorageObjectBackup,
    delete_objects_with_backups,
    restore_object_backups,
)
from helpers import (
    RequestBodyTooLarge,
    calc_sha256_hex,
    check_ip_rate_limit,
    consume_rate_limit,
    get_client_ip,
    get_setting_int,
    hash_password,
    is_today_iso,
    is_password_hashed,
    json_error,
    now_iso,
    parse_bool,
    read_json_body,
    sanitize_alias,
    send_json,
    send_rate_limit_error,
    verify_password,
)
from services import (
    add_audit_log,
    auth_admin,
    auth_user as auth_user_helper,
    ban_user_account,
    build_admin_account_rows,
    build_admin_appeal_rows,
    build_admin_post_pin_request_rows,
    build_admin_report_rows,
    build_admin_review_rows,
    build_admin_user_level_request_rows,
    build_admin_user_rows,
    apply_admin_review_action,
    build_export_payload,
    build_overview,
    cancel_user_account,
    clear_admin_sessions_for_account,
    create_notification,
    find_admin_account_by_id,
    find_admin_account_by_username,
    find_user_by_id,
    get_android_release,
    normalize_admin_role,
    next_id,
    normalize_user_level,
    parse_pin_duration_minutes,
    recalc_post_has_image,
    restore_user_account,
    save_db,
    set_android_release,
    serialize_admin_account,
    serialize_admin_auth_payload,
    sync_cancellation_requests_after_admin_cancel,
    target_owner,
    user_level_label,
)


_DUMMY_ADMIN_PASSWORD_HASH = (
    f"{_globals.PASSWORD_HASH_SCHEME}"
    f"${_globals.PASSWORD_HASH_ITERATIONS}"
    f"${'00' * _globals.PASSWORD_SALT_BYTES}"
    f"${'00' * 32}"
)


_logger = logging.getLogger("treehole.admin")


def _rollback_db_and_storage(
    db: dict[str, Any],
    db_snapshot: dict[str, Any],
    storage_backups: list[StorageObjectBackup],
) -> None:
    db.clear()
    db.update(db_snapshot)
    restore_object_backups(_globals.OBJECT_STORAGE, storage_backups)


def _notify_mentions_after_approval(db: dict[str, Any], target_type: str, target_id: str) -> None:
    """Mentions in content that waited for review go out once it is approved.

    Approving a post also releases the mentions in comments made on it while
    it was pending (only its author could comment then).
    """
    from handlers._social_handler import notify_mentions

    target_id = target_id.strip()
    if target_type == "post":
        post = next((p for p in db.get("posts", []) if str(p.get("id", "")) == target_id), None)
        if post is None:
            return
        notify_mentions(db, post)
        for comment in db.get("comments", []):
            if str(comment.get("postId", "")) == target_id:
                notify_mentions(db, post, comment)
    elif target_type == "comment":
        comment = next((c for c in db.get("comments", []) if str(c.get("id", "")) == target_id), None)
        if comment is None:
            return
        post = next((p for p in db.get("posts", []) if p.get("id") == comment.get("postId")), None)
        if post is not None:
            notify_mentions(db, post, comment)


def _require_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    admin, _ = auth_admin(handler, db)
    if admin is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员未登录或登录已过期")
        return None
    return admin


def _require_primary_admin(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    admin = _require_admin(handler, db)
    if admin is None:
        return None
    if normalize_admin_role(admin.get("role")) != _globals.ADMIN_ROLE_PRIMARY:
        json_error(handler, HTTPStatus.FORBIDDEN, "需要一级管理员权限")
        return None
    return admin


ANDROID_RELEASE_MAX_BYTES = 300 * 1024 * 1024


def read_multipart_form(
    handler: BaseHTTPRequestHandler,
    *,
    max_bytes: int | None = None,
) -> dict[str, Any]:
    """Parse a multipart body, reusing what server.py already drained.

    server.py reads large uploads off the socket *before* taking DB_LOCK, so a
    slow uploader cannot stall the process.  Any failure it hit is replayed
    here, keeping this handler's specific error responses intact.
    """
    cached_error = getattr(handler, "_cached_multipart_error", None)
    if cached_error is not None:
        raise cached_error
    cached_form = getattr(handler, "_cached_multipart_form", None)
    if isinstance(cached_form, dict):
        return cached_form

    content_type = handler.headers.get("Content-Type", "")
    match = re.search(r'boundary=(?:"([^"]+)"|([^;]+))', content_type)
    if match is None:
        raise ValueError("missing multipart boundary")
    boundary = (match.group(1) or match.group(2) or "").encode("utf-8")
    if not boundary:
        raise ValueError("invalid multipart boundary")

    try:
        content_length = max(0, int(handler.headers.get("Content-Length", "0")))
    except ValueError as exc:
        raise ValueError("invalid content length") from exc

    # Enforce the ceiling before buffering: multipart must not be a way around
    # the JSON body limit, and we must not allocate a caller-chosen size first
    # and validate afterwards.
    limit = _globals.MAX_REQUEST_BODY_BYTES if max_bytes is None else max_bytes
    if content_length > limit:
        raise RequestBodyTooLarge(
            f"request body exceeds {limit} bytes",
        )

    raw_body = handler.rfile.read(content_length) if content_length > 0 else b""
    delimiter = b"--" + boundary
    result: dict[str, Any] = {}
    for chunk in raw_body.split(delimiter):
        if not chunk:
            continue
        if chunk.startswith(b"\r\n"):
            chunk = chunk[2:]
        if chunk == b"--" or chunk == b"--\r\n":
            continue
        if chunk.endswith(b"--\r\n"):
            chunk = chunk[:-4]
        elif chunk.endswith(b"--"):
            chunk = chunk[:-2]
        if chunk.endswith(b"\r\n"):
            chunk = chunk[:-2]
        if not chunk:
            continue

        header_blob, separator, body = chunk.partition(b"\r\n\r\n")
        if not separator:
            continue

        headers: dict[str, str] = {}
        for header_line in header_blob.decode("utf-8", errors="ignore").split("\r\n"):
            if ":" not in header_line:
                continue
            key, value = header_line.split(":", 1)
            headers[key.strip().lower()] = value.strip()

        disposition = headers.get("content-disposition", "")
        name_match = re.search(r'name="([^"]+)"', disposition)
        if name_match is None:
            continue
        field_name = name_match.group(1).strip()
        filename_match = re.search(r'filename="([^"]*)"', disposition)
        if filename_match is not None:
            result[field_name] = {
                "filename": filename_match.group(1),
                "contentType": headers.get("content-type", "application/octet-stream"),
                "data": body,
            }
        else:
            result[field_name] = body.decode("utf-8", errors="ignore").strip()
    return result


def _multipart_value(form: dict[str, Any], key: str) -> str:
    value = form.get(key)
    if isinstance(value, str):
        return value.strip()
    return ""


# ===========================================================================
# POST handlers (auth)
# ===========================================================================


def handle_admin_auth_login(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/login"""
    from helpers import read_json_body
    body = read_json_body(handler)
    username = str(body.get("username", "")).strip()
    password = str(body.get("password", "")).strip()
    if not username or not password:
        json_error(handler, HTTPStatus.BAD_REQUEST, "管理员账号和密码不能为空")
        return
    # Both values are unauthenticated and only bounded by the 20MB body limit.
    # They must not reach a dict key, an audit-log row or a hash function at
    # that size.
    if len(username) > 64 or len(password) > 256:
        json_error(handler, HTTPStatus.BAD_REQUEST, "管理员账号或密码格式不正确")
        return

    # Throttle before touching credentials: this endpoint hands out full
    # backoffice access, so it must not be brute-forceable.
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "admin_login")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="管理员登录",
            retry_after_seconds=ip_retry_after,
        )
        return
    # Hash the username into the bucket key: RATE_LIMIT_EVENTS is never pruned,
    # so a raw attacker-supplied string here would be a permanent allocation per
    # distinct username tried.
    username_bucket = calc_sha256_hex(username.lower().encode("utf-8"))[:32]
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=f"admin_login::{username_bucket}",
        action="admin_login",
        setting_key="adminLoginRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["adminLoginRateLimit"]),
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="管理员登录",
            retry_after_seconds=retry_after,
        )
        return

    def _reject_invalid_credentials() -> None:
        # Deliberately no add_audit_log/save_db here.  save_db rewrites the
        # entire database while DB_LOCK is held, so auditing a failed login
        # would let an unauthenticated caller force a full-table rewrite (and
        # an unbounded, never-trimmed auditLogs row) on every wrong password.
        # Failed attempts are recorded in the application log instead.
        _logger.warning(
            "admin login failed for username=%r from ip=%s",
            username[:64],
            get_client_ip(handler),
        )
        json_error(handler, HTTPStatus.UNAUTHORIZED, "管理员账号或密码错误")

    account = find_admin_account_by_username(db, username, include_inactive=True)
    if account is None:
        verify_password(_DUMMY_ADMIN_PASSWORD_HASH, password)
        _reject_invalid_credentials()
        return
    if not verify_password(str(account.get("passwordHash", "")), password):
        _reject_invalid_credentials()
        return
    if not bool(account.get("active", True)):
        json_error(handler, HTTPStatus.FORBIDDEN, "该管理员账号已注销，请联系一级管理员")
        return

    token = secrets.token_urlsafe(24)
    with _globals.ADMIN_SESSION_LOCK:
        _globals.ADMIN_SESSIONS[token] = str(account.get("id", "")).strip()
        _globals.ADMIN_SESSION_ISSUED_AT[token] = time.time()
    admin_payload = serialize_admin_auth_payload(account)
    add_audit_log(
        db,
        "",
        "admin_login",
        f"管理员登录:{account.get('username', '')}:{admin_payload.get('role', '')}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"token": token, **admin_payload}},
    )


def handle_admin_auth_logout(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/logout"""
    admin, token = auth_admin(handler, db)
    if admin is None:
        # Already signed out (expired, or dropped by a restart): logging out is
        # done, and the client still needs a reply to clear its token.
        send_json(handler, HTTPStatus.OK, {"message": "管理员会话已失效", "data": {"ok": True}})
        return
    if token:
        with _globals.ADMIN_SESSION_LOCK:
            _globals.ADMIN_SESSIONS.pop(token, None)
            _globals.ADMIN_SESSION_ISSUED_AT.pop(token, None)
    add_audit_log(db, "", "admin_logout", f"管理员退出: {admin.get('username', '')}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "管理员已退出", "data": {"ok": True}})


# ===========================================================================
# GET handlers
# ===========================================================================


def handle_admin_auth_me(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/auth/me"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_auth_payload(admin)})


def handle_admin_overview(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/overview"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_overview(db)})


def handle_admin_reviews(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/reviews"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    target_type = (query.get("type", [""])[0] or "").strip().lower()
    status = (query.get("status", [""])[0] or "").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": build_admin_review_rows(db, target_type=target_type, status=status, keyword=keyword)},
    )


def handle_admin_reports(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/reports"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", [""])[0] or "").strip().lower()
    reason = (query.get("reason", [""])[0] or "").strip()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": build_admin_report_rows(db, status=status, reason=reason, keyword=keyword)},
    )


def handle_admin_images_reviews(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/images/reviews"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    # No status means the review queue (pending + risk), which is what the
    # mini program asks for; the web console filters by one status or all.
    requested_status = (query.get("status", [""])[0] or "").strip().lower()
    status_filters: dict[str, set[str] | None] = {
        "": {"pending", "risk"},
        "all": None,
        "pending": {"pending"},
        "approved": {"approved"},
        "rejected": {"rejected"},
        "risk": {"risk"},
    }
    if requested_status not in status_filters:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的图片状态")
        return
    wanted_statuses = status_filters[requested_status]
    rows = []
    keyword = (query.get("keyword", [""])[0] or "").strip().lower()
    for upload in db.get("mediaUploads", []):
        if upload.get("deleted"):
            continue
        status = str(upload.get("status", "pending")).lower()
        if wanted_statuses is not None and status not in wanted_statuses:
            continue
        uploader = find_user_by_id(db, str(upload.get("uploaderId", "")))
        item = {
            "id": upload.get("id", ""),
            "url": upload.get("url", ""),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "sizeBytes": int(upload.get("sizeBytes", 0)),
            "status": status,
            "moderationReason": upload.get("moderationReason", ""),
            "reviewNote": upload.get("reviewNote", ""),
            "createdAt": upload.get("createdAt", ""),
            "postId": upload.get("postId", ""),
            "uploaderId": upload.get("uploaderId", ""),
            "uploaderAlias": uploader.get("nickname", "未知用户") if uploader else "未知用户",
        }
        if keyword:
            text = f"{item['uploaderAlias']} {item['fileName']}".lower()
            if keyword not in text:
                continue
        rows.append(item)
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_admin_users(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/users"""
    # Every row carries email + studentId for the whole user base.  A secondary
    # admin only handles pin requests and announcements and cannot act on users
    # at all (handle_admin_user_action is primary-only), so handing them the
    # full roster was privilege they had no use for.
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_admin_user_rows(db, include_deleted=True)})


def handle_admin_post_pin_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/post-pin-requests"""
    admin = _require_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_post_pin_request_rows(db, status=status, keyword=keyword)})


def handle_admin_user_level_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/user-level-requests"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_user_level_request_rows(db, status=status, keyword=keyword)})


def handle_admin_admin_accounts(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/admin-accounts"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": build_admin_account_rows(db)})


def handle_admin_account_cancellation_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/account-cancellation-requests"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    from services import build_admin_account_cancellation_rows
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_account_cancellation_rows(db, status=status, keyword=keyword)})


def handle_admin_appeals(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/appeals"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    keyword = (query.get("keyword", [""])[0] or "").strip()
    send_json(handler, HTTPStatus.OK, {"data": build_admin_appeal_rows(db, status=status, keyword=keyword)})


def handle_admin_export(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/export"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    scope = (query.get("scope", ["users"])[0] or "users").strip().lower()
    export_format = (query.get("format", ["csv"])[0] or "csv").strip().lower()
    review_type = (query.get("reviewType", ["all"])[0] or "all").strip().lower()
    review_status = (query.get("reviewStatus", ["all"])[0] or "all").strip().lower()
    report_status = (query.get("reportStatus", ["all"])[0] or "all").strip().lower()
    appeal_status = (query.get("appealStatus", ["all"])[0] or "all").strip().lower()
    payload = build_export_payload(
        db,
        scope=scope,
        export_format=export_format,
        review_type=review_type,
        review_status=review_status,
        report_status=report_status,
        appeal_status=appeal_status,
    )
    send_json(handler, HTTPStatus.OK, {"data": payload})


def handle_admin_tags(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/tags — the tag list."""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "tags": db.get("tags", []),
            }
        },
    )


def handle_admin_config(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/config"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "sensitiveWords": db.get("sensitiveWords", []),
                "settings": _admin_editable_settings(db),
            }
        },
    )


def _admin_editable_settings(db: dict[str, Any]) -> dict[str, int]:
    """The enforced numeric limits (rate limits, imageMaxMB), as currently in effect."""
    return {
        key: get_setting_int(db, key, int(default), minimum=1)
        for key, default in _globals.DEFAULT_SETTINGS.items()
        if isinstance(default, int) and not isinstance(default, bool)
    }


def _serialize_announcement(row: dict[str, Any]) -> dict[str, Any]:
    created_at = str(row.get("publishedAt", row.get("createdAt", ""))).strip()
    return {
        "id": str(row.get("id", "")).strip(),
        "title": str(row.get("title", "")).strip(),
        "content": str(row.get("content", "")).strip(),
        "summary": str(row.get("summary", "")).strip(),
        "aiSummary": str(row.get("aiSummary", "")).strip(),
        "publishedAt": created_at,
        "createdAt": str(row.get("createdAt", created_at)).strip(),
        "publisher": str(row.get("publisher", "SeeRadio")).strip(),
        "sourceName": str(row.get("sourceName", "系统公告")).strip(),
        "type": str(row.get("type", "系统公告")).strip(),
        "isImportant": bool(row.get("isImportant", False)),
        "originalUrl": str(row.get("originalUrl", "")).strip(),
        "createdBy": str(row.get("createdBy", "")).strip(),
        "timeText": created_at,
    }


def _published_announcements(db: dict[str, Any]) -> list[dict[str, Any]]:
    rows = [
        _serialize_announcement(row)
        for row in db.get("announcements", [])
        if isinstance(row, dict) and not row.get("deleted")
    ]
    rows.sort(
        key=lambda row: (row.get("publishedAt", ""), row.get("id", "")),
        reverse=True,
    )
    return rows


def handle_public_announcements(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    announcement_type = str((query.get("type") or [""])[0]).strip()
    rows = _published_announcements(db)
    if announcement_type:
        rows = [row for row in rows if row.get("type") == announcement_type]
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_public_announcement_detail(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    announcement_id: str,
) -> None:
    row = next(
        (
            item
            for item in _published_announcements(db)
            if item.get("id") == announcement_id
        ),
        None,
    )
    if row is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "公告不存在")
        return
    send_json(handler, HTTPStatus.OK, {"data": row})


def handle_public_announcement_filters(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    types = sorted(
        {
            str(row.get("type", "")).strip()
            for row in _published_announcements(db)
            if str(row.get("type", "")).strip()
        }
    )
    send_json(handler, HTTPStatus.OK, {"data": {"types": types}})


def handle_public_announcement_daily_summary(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    today_rows = [
        row
        for row in _published_announcements(db)
        if is_today_iso(str(row.get("publishedAt", "")))
    ]
    summary = (
        "；".join(str(row.get("title", "")).strip() for row in today_rows)
        if today_rows
        else "今日暂无新公告"
    )
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"title": "今日公告摘要", "summary": summary}},
    )


def handle_admin_announcements(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    admin = _require_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": _published_announcements(db)})


def handle_admin_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/admin/releases/android"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": get_android_release(db)})


def handle_public_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/releases/android/latest"""
    release = get_android_release(db)
    if release is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "当前暂无已发布的 Android 安装包")
        return
    send_json(handler, HTTPStatus.OK, {"data": release})



# ===========================================================================
# POST handlers
# ===========================================================================


def handle_admin_publish_announcement(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    title = str(body.get("title", "")).strip()
    content = str(body.get("content", "")).strip()
    announcement_type = str(body.get("type", "系统公告")).strip() or "系统公告"
    if not title:
        json_error(handler, HTTPStatus.BAD_REQUEST, "公告标题不能为空")
        return
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "公告内容不能为空")
        return

    created_at = now_iso()
    row = {
        "id": next_id(db, "announcement", "ann"),
        "title": title,
        "content": content,
        "summary": content[:120],
        "aiSummary": "",
        "publishedAt": created_at,
        "createdAt": created_at,
        "publisher": "SeeRadio",
        "sourceName": "系统公告",
        "type": announcement_type,
        "isImportant": parse_bool(body.get("isImportant", False)) is True,
        "originalUrl": "",
        "createdBy": str(admin.get("username", "")).strip(),
        "deleted": False,
    }
    db.setdefault("announcements", []).append(row)
    add_audit_log(
        db,
        str(admin.get("adminId", "")),
        "publish_announcement",
        f"发布公告 {row['id']}",
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_announcement(row)})


def handle_admin_change_password(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/auth/password"""
    admin = _require_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    old_password = str(body.get("oldPassword", "")).strip()
    new_password = str(body.get("newPassword", "")).strip()

    password_error = _globals.admin_password_policy_error(new_password)
    if password_error:
        json_error(handler, HTTPStatus.BAD_REQUEST, password_error)
        return

    account = find_admin_account_by_id(db, str(admin.get("adminId", "")))
    if account is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "管理员账号不存在")
        return

    stored_hash = str(account.get("passwordHash", "")).strip()
    if stored_hash and not verify_password(stored_hash, old_password):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "原密码错误")
        return

    account["passwordHash"] = hash_password(new_password)
    account["updatedAt"] = now_iso()
    clear_admin_sessions_for_account(str(admin.get("adminId", "")))
    add_audit_log(db, admin.get("adminId", "-"), "admin_change_password", "修改管理员密码")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"message": "密码修改成功，请重新登录", "data": {"ok": True}})



def handle_admin_upload_android_release(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/releases/android"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    content_type = handler.headers.get("Content-Type", "").lower()
    if "multipart/form-data" not in content_type:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请使用表单上传 APK 文件")
        return

    try:
        form = read_multipart_form(handler, max_bytes=ANDROID_RELEASE_MAX_BYTES)
    except RequestBodyTooLarge:
        json_error(
            handler,
            HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
            "安装包大小不能超过 300MB",
        )
        return
    except Exception:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包表单解析失败")
        return

    version_name = _multipart_value(form, "versionName")
    version_code_raw = _multipart_value(form, "versionCode")
    release_notes = _multipart_value(form, "releaseNotes")
    force_update_raw = _multipart_value(form, "forceUpdate")

    if not version_name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请输入版本名称")
        return
    try:
        version_code = int(version_code_raw)
    except ValueError:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请输入合法的版本号")
        return
    if version_code <= 0:
        json_error(handler, HTTPStatus.BAD_REQUEST, "版本号必须大于 0")
        return

    file_field = form.get("file")
    if not isinstance(file_field, dict) or not str(file_field.get("filename", "")).strip():
        json_error(handler, HTTPStatus.BAD_REQUEST, "请选择要上传的 APK 文件")
        return

    file_name = os.path.basename(str(file_field.get("filename", "")).strip()) or "app-release.apk"
    if not file_name.lower().endswith(".apk"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持上传 .apk 安装包")
        return

    file_bytes = file_field.get("data", b"")
    if not isinstance(file_bytes, (bytes, bytearray)) or not file_bytes:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包内容不能为空")
        return
    if len(file_bytes) > ANDROID_RELEASE_MAX_BYTES:
        json_error(handler, HTTPStatus.BAD_REQUEST, "安装包大小不能超过 300MB")
        return

    try:
        stored = _globals.OBJECT_STORAGE.put_bytes(
            data=bytes(file_bytes),
            file_name=file_name,
            content_type="application/vnd.android.package-archive",
        )
    except Exception:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "安装包上传失败，请稍后重试")
        return

    db_snapshot = copy.deepcopy(db)
    previous_release = get_android_release(db)
    previous_object_key = (
        str(previous_release.get("objectKey", "")).strip()
        if previous_release
        else ""
    )
    release = set_android_release(
        db,
        {
            "versionName": version_name,
            "versionCode": version_code,
            "releaseNotes": release_notes,
            "forceUpdate": parse_bool(force_update_raw) is True,
            "fileName": file_name,
            "contentType": "application/vnd.android.package-archive",
            "sizeBytes": len(file_bytes),
            "sha256": calc_sha256_hex(bytes(file_bytes)),
            "downloadUrl": stored.url,
            "objectKey": stored.key,
            "uploadedAt": now_iso(),
            "uploadedBy": str(admin.get("adminId", "")).strip(),
            "uploadedByUsername": str(admin.get("username", "")).strip(),
        },
    )
    add_audit_log(
        db,
        "",
        "publish_android_release",
        f"发布 Android 安装包 {release['versionName']} ({release['versionCode']})",
    )
    try:
        save_db(db)
    except Exception:
        db.clear()
        db.update(db_snapshot)
        try:
            _globals.OBJECT_STORAGE.delete(stored.key)
        except Exception as cleanup_error:
            raise RuntimeError(
                "安装包记录保存失败，且新安装包清理失败"
            ) from cleanup_error
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "安装包发布记录保存失败")
        return
    if previous_object_key and previous_object_key != stored.key:
        try:
            delete_objects_with_backups(
                _globals.OBJECT_STORAGE,
                [previous_object_key],
            )
        except Exception:
            db.clear()
            db.update(db_snapshot)
            save_db(db)
            _globals.OBJECT_STORAGE.delete(stored.key)
            json_error(handler, HTTPStatus.BAD_GATEWAY, "旧安装包清理失败，发布已回滚")
            return
    send_json(handler, HTTPStatus.OK, {"data": release})


def handle_admin_review_batch(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/reviews/batch"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    items: list[dict[str, str]] = body.get("items", [])
    if not items:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少待处理项目")
        return

    db_snapshot = copy.deepcopy(db)
    storage_backups: list[StorageObjectBackup] = []
    results = []
    for item in items:
        target_type = str(item.get("type", "")).strip().lower()
        target_id = str(item.get("id", "")).strip()
        action = str(item.get("action", "")).strip().lower()
        try:
            storage_backups.extend(
                apply_admin_review_action(
                    db,
                    target_type=target_type,
                    target_id=target_id,
                    action=action,
                )
            )
            if action == "approve":
                _notify_mentions_after_approval(db, target_type, target_id)
            results.append({"id": target_id, "ok": True})
        except (ValueError, LookupError, RuntimeError) as e:
            results.append({"id": target_id, "ok": False, "error": str(e)})

    add_audit_log(db, admin.get("adminId", "-"), "batch_review", f"批量审核 {len(items)} 个项目")
    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "审核结果保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"results": results}})


def handle_admin_single_review(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_type: str,
    target_id: str,
    action: str,
) -> None:
    """POST /api/admin/reviews/(post|comment)/<id>/(approve|reject|delete|risk)"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    db_snapshot = copy.deepcopy(db)
    try:
        storage_backups = apply_admin_review_action(
            db,
            target_type=target_type,
            target_id=target_id,
            action=action,
        )
    except (ValueError, LookupError) as e:
        json_error(handler, HTTPStatus.BAD_REQUEST, str(e))
        return
    except RuntimeError as error:
        json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
        return
    if action.strip().lower() == "approve":
        _notify_mentions_after_approval(db, target_type.strip().lower(), target_id)

    add_audit_log(db, admin.get("adminId", "-"), f"review_{action}", f"{target_type} {target_id} -> {action}")
    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "审核结果保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_report_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    report_id: str,
) -> None:
    """POST /api/admin/reports/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    requested_action = str(body.get("action", "")).strip().lower()
    action = {
        "delete_content": "delete",
        "warn_user": "warn",
        "ban_user": "ban",
        "mark_misreport": "misreport",
    }.get(requested_action, requested_action)
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()

    report = next((r for r in db["reports"] if r.get("id") == report_id), None)
    if report is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "举报不存在")
        return
    if str(report.get("status", "pending")).strip().lower() != "pending":
        json_error(handler, HTTPStatus.CONFLICT, "举报已处理，不能重复操作")
        return

    action_map = {
        "resolve": "已处理",
        "delete": "已删除内容",
        "warn": "已警告",
        "ban": "已封禁",
        "misreport": "恶意举报",
    }
    if action in action_map:
        next_status = "misreport" if action == "misreport" else "resolved"
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    target_type = str(report.get("targetType", "")).strip()
    target_id = str(report.get("targetId", "")).strip()
    if target_type == "user":
        # A reported person: warn and ban reach them; there is no content.
        if action == "delete":
            json_error(handler, HTTPStatus.BAD_REQUEST, "用户举报没有可删除的内容")
            return
        owner_id = target_id if find_user_by_id(db, target_id) else ""
    else:
        owner = target_owner(db, target_id)
        owner_id = str(owner.get("authorId", "")).strip() if owner else ""

    db_snapshot = copy.deepcopy(db)
    storage_backups: list[StorageObjectBackup] = []
    if action == "delete":
        try:
            storage_backups = apply_admin_review_action(
                db,
                target_type=target_type,
                target_id=target_id,
                action="delete",
            )
        except (ValueError, LookupError) as error:
            json_error(handler, HTTPStatus.BAD_REQUEST, str(error))
            return
        except RuntimeError as error:
            json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
            return

    report["handledAt"] = now_iso()
    # reports.handled_by references users; dedicated admin accounts live in a
    # separate table, so only user-admin IDs can be stored in this column.
    report["handledBy"] = str(admin.get("id", "")).strip()
    report["result"] = review_note
    report["status"] = next_status

    if owner_id and action in {"delete", "warn", "ban"}:
        notif_title = "内容处理通知"
        notif_content = (
            f"您的账号因「{review_note}」被处理，请注意社区规范。"
            if target_type == "user"
            else f"您发布的内容因「{review_note}」被处理，请注意社区规范。"
        )
        if action == "ban":
            target_user = find_user_by_id(db, owner_id)
            if target_user:
                ban_user_account(db, target_user)
        
        notif_post_id = ""
        if target_type == "post":
            notif_post_id = target_id
        elif target_type == "comment":
            comment = next((c for c in db.get("comments", []) if c.get("id") == target_id), None)
            if comment:
                notif_post_id = str(comment.get("postId", "")).strip()
        notif_related_type, notif_related_id = target_type, target_id
        # Deleted content is not there to open: a deleted post links nowhere,
        # a deleted comment links to its post.
        if action == "delete" and target_type == "post":
            notif_related_type, notif_related_id, notif_post_id = "", "", ""
        elif action == "delete" and target_type == "comment":
            notif_related_type, notif_related_id = ("post", notif_post_id) if notif_post_id else ("", "")

        create_notification(
            db,
            user_id=owner_id,
            notification_type="report_result",
            title=notif_title,
            content=notif_content,
            related_type=notif_related_type,
            related_id=notif_related_id,
            post_id=notif_post_id,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_report_{action}", f"处理举报 {report_id}: {action}")
    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "举报处理结果保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_post_pin_request_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/post-pin-requests/<id>/handle"""
    admin = _require_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()
    if action not in {"approve", "reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    req = next((r for r in db.get("postPinRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    post_id = str(req.get("postId", "")).strip()
    post = next((p for p in db["posts"] if p.get("id") == post_id), None)
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return
    duration_minutes = parse_pin_duration_minutes(req.get("durationMinutes"))
    if action == "approve" and duration_minutes is None:
        json_error(handler, HTTPStatus.BAD_REQUEST, "置顶时长无效")
        return
    if action == "approve" and (post is None or post.get("deleted")):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标帖子不存在或已被删除")
        return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()
    req["adminNote"] = review_note or ""

    if post and action == "approve":
        from services import apply_post_pin
        apply_post_pin(
            post,
            duration_minutes=duration_minutes,
        )

    owner_id = str(post.get("authorId", "")) if post else ""
    if owner_id:
        title = "置顶申请已通过" if action == "approve" else "置顶申请已驳回"
        content = f"您对帖子「{post.get('title', '未知')}」的置顶申请已被{'通过' if action == 'approve' else '驳回'}。"
        create_notification(
            db,
            user_id=owner_id,
            notification_type="system",
            title=title,
            content=content,
            related_type="post",
            related_id=post_id,
            post_id=post_id,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_pin_request_{action}", f"处理置顶申请 {request_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_user_level_request_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/user-level-requests/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()
    if action not in {"approve", "reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    req = next((r for r in db.get("userLevelRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    user_id = str(req.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id)

    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return
    if action == "approve" and target_user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在或不可用")
        return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()
    req["adminNote"] = review_note or ""

    if target_user and action == "approve":
        target_user["userLevel"] = _globals.USER_LEVEL_ONE

    if target_user:
        title = "升级申请已通过" if action == "approve" else "升级申请已驳回"
        content = f"您的一级用户升级申请已被{'通过' if action == 'approve' else '驳回'}。"
        create_notification(
            db,
            user_id=user_id,
            notification_type="system",
            title=title,
            content=content,
            actor_id=str(admin.get("adminId", "")),
            actor_alias="管理员",
        )

    add_audit_log(db, admin.get("adminId", "-"), f"handle_level_request_{action}", f"处理升级申请 {request_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_create_account(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/admin-accounts"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    username = str(body.get("username", "")).strip()
    password = str(body.get("password", "")).strip()

    if not re.fullmatch(r"[A-Za-z0-9_.-]{3,32}", username):
        json_error(handler, HTTPStatus.BAD_REQUEST, "用户名格式不正确（3-32位字母数字下划线）")
        return
    password_error = _globals.admin_password_policy_error(password)
    if password_error:
        json_error(handler, HTTPStatus.BAD_REQUEST, password_error)
        return

    if find_admin_account_by_username(db, username) is not None:
        json_error(handler, HTTPStatus.CONFLICT, "用户名已存在")
        return

    from services import build_admin_account, next_id as svc_next_id
    account = build_admin_account(
        admin_id=svc_next_id(db, "adminAccount", "adm"),
        username=username,
        password_hash=hash_password(password),
        role=_globals.ADMIN_ROLE_SECONDARY,
        active=True,
        created_at=now_iso(),
        updated_at=now_iso(),
        created_by=str(admin.get("adminId", "")),
    )
    db["adminAccounts"].append(account)
    add_audit_log(db, admin.get("adminId", "-"), "create_admin_account", f"创建管理员账号 {username}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_account(account)})


def handle_admin_account_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    account_id: str,
) -> None:
    """POST /api/admin/admin-accounts/<id>/action"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()

    account = find_admin_account_by_id(db, account_id, include_inactive=True)
    if account is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "管理员账号不存在")
        return

    if action == "deactivate":
        account["active"] = False
        account["updatedAt"] = now_iso()
        clear_admin_sessions_for_account(account_id)
        add_audit_log(db, admin.get("adminId", "-"), "deactivate_admin", f"注销管理员账号 {account_id}")
    elif action == "activate":
        account["active"] = True
        account["updatedAt"] = now_iso()
        add_audit_log(db, admin.get("adminId", "-"), "activate_admin", f"激活管理员账号 {account_id}")
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的动作")
        return

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": serialize_admin_account(account)})


def handle_admin_user_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user_id: str,
) -> None:
    """POST /api/admin/users/<id>/action"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()

    target_user = find_user_by_id(db, user_id, include_deleted=True)
    if target_user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return

    db_snapshot = copy.deepcopy(db)
    storage_backups: list[StorageObjectBackup] = []
    if action == "mute":
        target_user["muted"] = True
        add_audit_log(db, admin.get("adminId", "-"), "mute_user", f"禁言用户 {user_id}: {review_note}")
    elif action == "unmute":
        target_user["muted"] = False
        add_audit_log(db, admin.get("adminId", "-"), "unmute_user", f"解除禁言用户 {user_id}")
    elif action == "ban":
        ban_user_account(db, target_user)
        add_audit_log(db, admin.get("adminId", "-"), "ban_user", f"封禁用户 {user_id}: {review_note}")
    elif action == "unban":
        target_user["banned"] = False
        add_audit_log(db, admin.get("adminId", "-"), "unban_user", f"解封用户 {user_id}")
    elif action == "cancel":
        try:
            storage_backups = cancel_user_account(
                db,
                target_user,
                actor_id=admin.get("adminId", "-"),
                detail=f"管理员注销账号 {review_note}",
            )
        except RuntimeError as error:
            json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
            return
        add_audit_log(db, admin.get("adminId", "-"), "cancel_user_account", f"注销用户 {user_id}: {review_note}")
    elif action == "restore":
        restore_user_account(db, target_user)
        add_audit_log(db, admin.get("adminId", "-"), "restore_user", f"恢复用户 {user_id}: {review_note}")
    elif action == "grant_admin":
        target_user["isAdmin"] = True
        add_audit_log(db, admin.get("adminId", "-"), "grant_user_admin", f"设为管理员 {user_id}: {review_note}")
    elif action == "revoke_admin":
        if str(admin.get("id", "")).strip() == str(target_user.get("id", "")).strip():
            json_error(handler, HTTPStatus.BAD_REQUEST, "不能移除自己的管理员权限")
            return
        target_user["isAdmin"] = False
        add_audit_log(db, admin.get("adminId", "-"), "revoke_user_admin", f"移除管理员 {user_id}: {review_note}")
    else:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的动作")
        return

    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "用户操作保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_appeal_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    appeal_id: str,
) -> None:
    """POST /api/admin/appeals/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()
    if action not in {"approve", "approve_restore", "reject", "close"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    appeal = next((a for a in db.get("appeals", []) if a.get("id") == appeal_id), None)
    if appeal is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申诉不存在")
        return

    user_id = str(appeal.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id, include_deleted=True)

    if appeal.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申诉已被处理")
        return
    if (
        action == "approve_restore"
        and str(appeal.get("appealType", "")).strip() != "account_restore"
    ):
        json_error(handler, HTTPStatus.BAD_REQUEST, "该申诉不支持恢复账号")
        return
    if action in {"approve", "approve_restore"} and target_user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申诉账号不存在")
        return

    appeal["status"] = (
        "approved"
        if action in {"approve", "approve_restore"}
        else ("closed" if action == "close" else "rejected")
    )
    appeal["handledAt"] = now_iso()
    appeal["handledBy"] = str(admin.get("adminId", "")).strip()
    appeal["adminNote"] = review_note

    if action == "approve_restore" or (action == "approve" and appeal.get("appealType") == "account_restore"):
        if target_user:
            restore_user_account(db, target_user)
            create_notification(
                db,
                user_id=user_id,
                notification_type="system",
                title="账号已恢复",
                content=f"您的账号申诉已通过，账号已恢复使用。",
                actor_id=str(admin.get("adminId", "")),
                actor_alias="管理员",
            )
        add_audit_log(db, admin.get("adminId", "-"), "appeal_approve_restore", f"申诉通过并恢复账号 {user_id}")
    elif action == "approve" and appeal.get("appealType") == "ban_revoke":
        # Approving this used to mark the appeal handled and leave the ban in
        # place, so the account stayed locked out with nothing left to submit.
        # Only the ban is cleared: a mute or a cancellation is a separate
        # decision and must not ride along with it.
        if target_user:
            target_user["banned"] = False
            create_notification(
                db,
                user_id=user_id,
                notification_type="system",
                title="账号已解封",
                content="您的解封申诉已通过，账号已恢复正常使用。",
                actor_id=str(admin.get("adminId", "")),
                actor_alias="管理员",
            )
        add_audit_log(db, admin.get("adminId", "-"), "appeal_approve_unban", f"申诉通过并解封账号 {user_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_cancellation_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/admin/account-cancellation-requests/<id>/handle"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    note = str(body.get("note", "")).strip()
    if action not in {"approve", "reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return

    req = next((r for r in db.get("accountCancellationRequests", []) if r.get("id") == request_id), None)
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "申请不存在")
        return

    user_id = str(req.get("userId", "")).strip()
    target_user = find_user_by_id(db, user_id, include_deleted=True)

    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "申请已被处理")
        return
    if action == "approve" and target_user is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "注销账号不存在")
        return

    db_snapshot = copy.deepcopy(db)
    storage_backups: list[StorageObjectBackup] = []
    if action == "approve" and target_user:
        try:
            storage_backups = cancel_user_account(
                db,
                target_user,
                actor_id=admin.get("adminId", "-"),
                detail="账号注销申请通过",
            )
        except RuntimeError as error:
            json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
            return

    req["status"] = action == "approve" and "approved" or "rejected"
    req["handledAt"] = now_iso()
    req["handledBy"] = str(admin.get("adminId", "")).strip()
    req["reviewNote"] = note or ("账号注销申请通过" if action == "approve" else "")

    if action == "reject":
        add_audit_log(db, admin.get("adminId", "-"), "reject_cancellation", f"驳回账号注销申请 {user_id}: {note}")
    if action == "approve" and target_user:
        sync_cancellation_requests_after_admin_cancel(
            db,
            user_id=user_id,
            handled_by=str(admin.get("adminId", "")).strip(),
            review_note="账号注销申请通过",
        )
        add_audit_log(db, admin.get("adminId", "-"), "approve_cancellation", f"通过账号注销申请 {user_id}")

    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "注销申请处理保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_image_review(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    upload_id: str,
) -> None:
    """POST /api/admin/images/<id>/review"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    review_note = str(body.get("reviewNote", body.get("result", body.get("note", body.get("reason", ""))))).strip()

    upload = next((u for u in db.get("mediaUploads", []) if u.get("id") == upload_id), None)
    if upload is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "图片不存在")
        return

    action_map = {
        "approve": "approved",
        "reject": "rejected",
        "delete": "deleted",
        "risk": "risk",
    }
    if action not in action_map:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的审核动作")
        return
    current_status = str(upload.get("status", "approved")).strip().lower()
    if upload.get("deleted") or current_status in {"rejected", "deleted"}:
        json_error(handler, HTTPStatus.CONFLICT, "图片已被移除，不能再次审核")
        return

    post_id = str(upload.get("postId", "")).strip()
    storage_backups: list[StorageObjectBackup] = []
    if action in {"reject", "delete"}:
        object_key = str(upload.get("objectKey", "")).strip()
        try:
            if object_key:
                storage_backups = delete_objects_with_backups(
                    _globals.OBJECT_STORAGE,
                    [object_key],
                )
        except Exception:
            json_error(handler, HTTPStatus.BAD_GATEWAY, "图片存储删除失败，审核状态未变更")
            return

    db_snapshot = copy.deepcopy(db)
    new_status = action_map[action]
    upload["status"] = new_status
    if action == "delete":
        upload["deleted"] = True
    upload["reviewedBy"] = str(admin.get("adminId", "")).strip()
    upload["reviewedAt"] = now_iso()
    upload["reviewNote"] = review_note

    if post_id:
        recalc_post_has_image(db, post_id)

    add_audit_log(db, admin.get("adminId", "-"), f"image_review_{action}", f"审核图片 {upload_id}")
    try:
        save_db(db)
    except Exception:
        _rollback_db_and_storage(db, db_snapshot, storage_backups)
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "图片审核结果保存失败，已回滚")
        return
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_add_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/admin/tags"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    tag = str(body.get("tag", "")).strip()
    if not tag:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签不能为空")
        return
    if tag in db.get("tags", []):
        json_error(handler, HTTPStatus.CONFLICT, "标签已存在")
        return

    db["tags"].append(tag)
    add_audit_log(db, admin.get("adminId", "-"), "add_tag", f"添加标签 {tag}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


# ===========================================================================
# PATCH handlers
# ===========================================================================


def handle_admin_rename_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    old_name: str,
) -> None:
    """PATCH /api/admin/tags/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    new_name = str(body.get("tag", "")).strip()
    if not new_name or new_name == old_name:
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签不能为空或与原名称相同")
        return
    if new_name in db.get("tags", []):
        json_error(handler, HTTPStatus.CONFLICT, "新标签已存在")
        return

    tags = db.get("tags", [])
    idx = next((i for i, t in enumerate(tags) if t == old_name), -1)
    if idx < 0:
        json_error(handler, HTTPStatus.NOT_FOUND, "标签不存在")
        return

    tags[idx] = new_name
    for post in db.get("posts", []):
        post_tags = post.get("tags", [])
        if old_name in post_tags:
            post_tags = [t if t != old_name else new_name for t in post_tags]
            post["tags"] = post_tags

    add_audit_log(db, admin.get("adminId", "-"), "rename_tag", f"重命名标签 {old_name} -> {new_name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_admin_update_config(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/admin/config"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    body = read_json_body(handler)
    words = body.get("sensitiveWords", [])
    if isinstance(words, list):
        db["sensitiveWords"] = [str(w).strip() for w in words if str(w).strip()]

    requested_settings = body.get("settings")
    if requested_settings is not None:
        if not isinstance(requested_settings, dict):
            json_error(handler, HTTPStatus.BAD_REQUEST, "settings 必须是对象")
            return
        editable = _admin_editable_settings(db)
        updates: dict[str, int] = {}
        for key, value in requested_settings.items():
            if key not in editable:
                json_error(handler, HTTPStatus.BAD_REQUEST, f"不支持的配置项：{key}")
                return
            if isinstance(value, bool) or not isinstance(value, int) or value < 1:
                json_error(handler, HTTPStatus.BAD_REQUEST, f"{key} 必须是正整数")
                return
            updates[key] = value
        if not isinstance(db.get("settings"), dict):
            db["settings"] = {}
        db["settings"].update(updates)

    add_audit_log(db, admin.get("adminId", "-"), "update_config", "更新系统配置")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


# ===========================================================================
# DELETE handlers
# ===========================================================================


def handle_admin_delete_tag(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    name: str,
) -> None:
    """DELETE /api/admin/tags/<name>"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return

    tags = db.get("tags", [])
    if name not in tags:
        json_error(handler, HTTPStatus.NOT_FOUND, "标签不存在")
        return

    tags.remove(name)
    for post in db.get("posts", []):
        post_tags = post.get("tags", [])
        if name in post_tags:
            post["tags"] = [t for t in post_tags if t != name]

    add_audit_log(db, admin.get("adminId", "-"), "delete_tag", f"删除标签 {name}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


# ---------------------------------------------------------------------------
# Feedback (信箱)
# ---------------------------------------------------------------------------

_FEEDBACK_STATUSES = {"pending", "resolved", "closed"}
_MAX_FEEDBACK_REPLY_CHARS = 1000


def _serialize_admin_feedback(db: dict[str, Any], row: dict[str, Any]) -> dict[str, Any]:
    user = find_user_by_id(db, str(row.get("userId", "")), include_deleted=True)
    return {
        "id": str(row.get("id", "")),
        "userId": str(row.get("userId", "")),
        "userEmail": str(row.get("userEmail", "")),
        "userNickname": str(row.get("userNickname", "")),
        "studentId": str(user.get("studentId", "")) if user else "",
        "userDeleted": user is None or bool(user.get("deleted")),
        "category": str(row.get("category", "其他反馈")),
        "content": str(row.get("content", "")),
        "contact": str(row.get("contact", "")),
        "status": str(row.get("status", "pending")),
        "schoolReply": str(row.get("schoolReply", "")),
        "createdAt": str(row.get("createdAt", "")),
        "handledAt": str(row.get("handledAt", "")),
    }


def handle_admin_feedbacks(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/admin/feedbacks?status=pending|resolved|closed|all"""
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    status = (query.get("status", ["all"])[0] or "all").strip().lower()
    if status != "all" and status not in _FEEDBACK_STATUSES:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的反馈状态")
        return
    rows = [
        _serialize_admin_feedback(db, row)
        for row in db.get("feedbacks", [])
        if status == "all" or str(row.get("status", "pending")) == status
    ]
    rows.sort(key=lambda item: (item["createdAt"], item["id"]), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_admin_feedback_action(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    feedback_id: str,
) -> None:
    """POST /api/admin/feedbacks/<id>/handle  body: {action: reply|close, reply}

    reply answers the user (status resolved, 已回复); close ends it without an
    answer being required (status closed). Either way the user is notified.
    """
    admin = _require_primary_admin(handler, db)
    if admin is None:
        return
    body = read_json_body(handler)
    action = str(body.get("action", "")).strip().lower()
    reply = str(body.get("reply", "")).strip()
    if action not in {"reply", "close"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的处理动作")
        return
    if action == "reply" and not reply:
        json_error(handler, HTTPStatus.BAD_REQUEST, "回复内容不能为空")
        return
    if len(reply) > _MAX_FEEDBACK_REPLY_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"回复不能超过 {_MAX_FEEDBACK_REPLY_CHARS} 字")
        return

    feedback = next((row for row in db.get("feedbacks", []) if row.get("id") == feedback_id), None)
    if feedback is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "反馈不存在")
        return
    if str(feedback.get("status", "pending")) != "pending":
        json_error(handler, HTTPStatus.CONFLICT, "反馈已处理，不能重复操作")
        return

    feedback["status"] = "resolved" if action == "reply" else "closed"
    feedback["schoolReply"] = reply
    feedback["handledAt"] = now_iso()
    # feedbacks.handled_by references users, like reports.handled_by: only a
    # user-admin id fits; the audit log records which admin account it was.
    feedback["handledBy"] = str(admin.get("id", "")).strip()

    create_notification(
        db,
        user_id=str(feedback.get("userId", "")),
        notification_type="system",
        title="反馈已回复" if action == "reply" else "反馈已处理",
        content=reply or "你的反馈已处理完毕，感谢你的意见。",
        related_type="feedback",
        related_id=feedback_id,
        actor_alias="管理员",
    )
    add_audit_log(
        db,
        str(admin.get("adminId", "")),
        f"feedback_{action}",
        f"{feedback_id}: {reply}" if reply else feedback_id,
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_admin_feedback(db, feedback)})
