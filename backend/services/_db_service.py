from __future__ import annotations

import json
import logging
import os
import time
from typing import Any, Callable

import _globals
from object_storage import (
    StorageObjectBackup,
    delete_objects_with_backups,
)
from helpers._auth_helpers import (
    hash_password,
    is_password_hashed,
    normalize_avatar_url,
    normalize_media_url,
    sanitize_alias,
    student_id_from_email,
)
from helpers._datetime_helpers import is_today_iso, now_iso, now_utc, parse_iso

logger = logging.getLogger(__name__)


def next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db.setdefault("seq", {})
    if key not in db["seq"]:
        db["seq"][key] = 0
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


# save_db rewrites every table on each write, so an unbounded auditLogs table
# makes every subsequent write slower — it has to stay capped.
_AUDIT_LOG_MAX_ROWS = 20000
_AUDIT_LOG_DETAIL_MAX_CHARS = 512
_AUDIT_LOG_ACTION_MAX_CHARS = 64


def add_audit_log(db: dict[str, Any], actor_id: str, action: str, detail: str) -> str:
    """Append one audit row and return its id.

    Callers that may have to undo their write should keep the returned id and
    pass it to remove_audit_log().  Do not roll back by slicing on a saved
    length: this function also trims the head of the table once it is full, so
    positional indexes are not stable across the call.
    """
    normalized_actor_id = str(actor_id).strip()
    actor_is_user = any(
        str(user.get("id", "")).strip() == normalized_actor_id
        for user in db.get("users", [])
    )
    normalized_detail = str(detail)
    if normalized_actor_id and not actor_is_user:
        normalized_detail = f"[actor={normalized_actor_id}] {normalized_detail}"
        normalized_actor_id = ""
    entry_id = next_id(db, "audit", "a")
    db["auditLogs"].append(
        {
            "id": entry_id,
            "actorId": normalized_actor_id,
            # Details routinely embed user-supplied names/ids.  Bound each row
            # so one oversized field cannot bloat every subsequent full-database
            # rewrite, and bound the table so it cannot grow without limit.
            "action": str(action)[:_AUDIT_LOG_ACTION_MAX_CHARS],
            "detail": normalized_detail[:_AUDIT_LOG_DETAIL_MAX_CHARS],
            "createdAt": now_iso(),
        }
    )
    if len(db["auditLogs"]) > _AUDIT_LOG_MAX_ROWS:
        del db["auditLogs"][:-_AUDIT_LOG_MAX_ROWS]
    return entry_id


def remove_audit_log(db: dict[str, Any], entry_id: str) -> bool:
    """Drop exactly the row add_audit_log() created, by id.

    Returns True if a row was removed.  A False result is not an error: the row
    may already have been trimmed away by the table cap.
    """
    target = str(entry_id).strip()
    if not target:
        return False
    rows = db.get("auditLogs")
    if not isinstance(rows, list):
        return False
    for index in range(len(rows) - 1, -1, -1):
        if str(rows[index].get("id", "")).strip() == target:
            del rows[index]
            return True
    return False


def _safe_int(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return default
    return default


def _safe_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "1", "yes", "on"}:
            return True
        if normalized in {"false", "0", "no", "off"}:
            return False
    return default


# ---------------------------------------------------------------------------
# Admin account helpers
# ---------------------------------------------------------------------------


def build_admin_account(
    *,
    admin_id: str,
    username: str,
    password_hash: str,
    role: str,
    active: bool = True,
    created_at: str,
    updated_at: str,
    created_by: str = "",
) -> dict[str, Any]:
    return {
        "id": admin_id,
        "username": normalize_admin_username(username) or normalize_admin_username(_globals.DEFAULT_ADMIN_USERNAME),
        "passwordHash": password_hash,
        "role": normalize_admin_role(role),
        "active": bool(active),
        "createdAt": created_at,
        "updatedAt": updated_at,
        "createdBy": created_by.strip(),
    }


def normalize_admin_username(value: str) -> str:
    return value.strip().lower()


def is_valid_admin_username(value: str) -> bool:
    import re
    return bool(re.fullmatch(r"[A-Za-z0-9_.-]{3,32}", value.strip()))


def normalize_admin_role(value: Any) -> str:
    role = str(value).strip().lower()
    if role == _globals.ADMIN_ROLE_PRIMARY:
        return _globals.ADMIN_ROLE_PRIMARY
    return _globals.ADMIN_ROLE_SECONDARY


def admin_role_label(role: str) -> str:
    return "一级管理员" if normalize_admin_role(role) == _globals.ADMIN_ROLE_PRIMARY else "二级管理员"


def find_admin_account_by_username(
    db: dict[str, Any],
    username: str,
    *,
    include_inactive: bool = False,
) -> dict[str, Any] | None:
    target = normalize_admin_username(username)
    if not target:
        return None
    for account in db.get("adminAccounts", []):
        if normalize_admin_username(str(account.get("username", ""))) != target:
            continue
        if not include_inactive and not bool(account.get("active", True)):
            continue
        return account
    return None


def find_admin_account_by_id(
    db: dict[str, Any],
    admin_id: str,
    *,
    include_inactive: bool = False,
) -> dict[str, Any] | None:
    target = str(admin_id).strip()
    if not target:
        return None
    for account in db.get("adminAccounts", []):
        if str(account.get("id", "")).strip() != target:
            continue
        if not include_inactive and not bool(account.get("active", True)):
            continue
        return account
    return None


def clear_admin_sessions_for_account(admin_id: str) -> None:
    target = str(admin_id).strip()
    if not target:
        return
    with _globals.ADMIN_SESSION_LOCK:
        expired_tokens = [
            token
            for token, session_admin_id in _globals.ADMIN_SESSIONS.items()
            if str(session_admin_id).strip() == target
        ]
        for token in expired_tokens:
            _globals.ADMIN_SESSIONS.pop(token, None)
            _globals.ADMIN_SESSION_ISSUED_AT.pop(token, None)


def auth_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    """Extract Bearer token, validate session, return (user, token) or (None, None)."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[7:].strip()
    if not token:
        return None, None
    user_id = db["sessions"].get(token)
    if not user_id:
        return None, token
    user = _find_user_by_id_unsafe(db, user_id)
    if user is not None and not _globals.is_auth_student_id_allowed(
        str(user.get("studentId", "")),
    ):
        return None, token
    return user, token


def _find_user_by_id_unsafe(db: dict[str, Any], user_id: str) -> dict[str, Any] | None:
    """Internal: find user by id without deleted check (caller decides)."""
    for user in db.get("users", []):
        if str(user.get("id", "")) == str(user_id):
            return user
    return None


def auth_admin(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> tuple[dict[str, Any] | None, str | None]:
    """Extract Bearer token, validate admin or user-admin session."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[7:].strip()
    if not token:
        return None, None
    with _globals.ADMIN_SESSION_LOCK:
        admin_id = _globals.ADMIN_SESSIONS.get(token)
        if admin_id:
            issued_at = _globals.ADMIN_SESSION_ISSUED_AT.get(token)
            if (
                issued_at is None
                or time.time() - issued_at > _globals.ADMIN_SESSION_MAX_AGE_SECONDS
            ):
                _globals.ADMIN_SESSIONS.pop(token, None)
                _globals.ADMIN_SESSION_ISSUED_AT.pop(token, None)
                admin_id = None
    if admin_id:
        account = find_admin_account_by_id(db, str(admin_id), include_inactive=True)
        if account is None or not bool(account.get("active", True)):
            with _globals.ADMIN_SESSION_LOCK:
                _globals.ADMIN_SESSIONS.pop(token, None)
                _globals.ADMIN_SESSION_ISSUED_AT.pop(token, None)
            return None, token
        return build_authenticated_admin(account), token

    user_id = db.get("sessions", {}).get(token)
    if not user_id:
        return None, token
    user = _find_user_by_id_unsafe(db, str(user_id))
    if (
        user is None
        or bool(user.get("deleted", False))
        or bool(user.get("banned", False))
        or not bool(user.get("isAdmin", False))
    ):
        return None, token
    return build_authenticated_user_admin(user), token


def build_authenticated_admin(account: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(account.get("role"))
    return {
        "id": "",
        "adminId": str(account.get("id", "")).strip(),
        "username": normalize_admin_username(str(account.get("username", ""))),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == _globals.ADMIN_ROLE_PRIMARY,
        "isAdmin": True,
    }


def build_authenticated_user_admin(user: dict[str, Any]) -> dict[str, Any]:
    role = _globals.ADMIN_ROLE_SECONDARY
    nickname = str(
        user.get("nickname")
        or user.get("alias")
        or user.get("studentId")
        or user.get("email")
        or "admin",
    ).strip()
    return {
        "id": str(user.get("id", "")).strip(),
        "adminId": str(user.get("id", "")).strip(),
        "username": nickname,
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": False,
        "isAdmin": True,
        "fromUserAccount": True,
    }


def serialize_admin_auth_payload(admin: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(admin.get("role"))
    return {
        "username": str(admin.get("username", "")).strip(),
        "role": role,
        "roleLabel": admin_role_label(role),
        "isPrimary": role == _globals.ADMIN_ROLE_PRIMARY,
        "authenticated": True,
    }


def serialize_admin_account(account: dict[str, Any]) -> dict[str, Any]:
    role = normalize_admin_role(account.get("role"))
    active = bool(account.get("active", True))
    return {
        "id": str(account.get("id", "")).strip(),
        "username": normalize_admin_username(str(account.get("username", ""))),
        "role": role,
        "roleLabel": admin_role_label(role),
        "active": active,
        "statusLabel": "启用中" if active else "已注销",
        "createdAt": str(account.get("createdAt", "")).strip(),
        "updatedAt": str(account.get("updatedAt", "")).strip(),
        "createdBy": str(account.get("createdBy", "")).strip(),
    }


def ensure_admin_auth_settings(db: dict[str, Any]) -> bool:
    settings = db.get("settings")
    if not isinstance(settings, dict):
        settings = {}
        db["settings"] = settings
    changed = False
    username = str(settings.get(_globals.ADMIN_USERNAME_SETTING_KEY, "")).strip()
    if not username:
        settings[_globals.ADMIN_USERNAME_SETTING_KEY] = _globals.DEFAULT_ADMIN_USERNAME
        changed = True
    stored_password = str(settings.get(_globals.ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not stored_password:
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(_globals.DEFAULT_ADMIN_PASSWORD)
        changed = True
    elif not is_password_hashed(stored_password):
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = hash_password(stored_password)
        changed = True
    return changed


def get_admin_auth_credentials(db: dict[str, Any]) -> tuple[str, str]:
    ensure_admin_auth_settings(db)
    settings = db.get("settings", {})
    username = str(settings.get(_globals.ADMIN_USERNAME_SETTING_KEY, _globals.DEFAULT_ADMIN_USERNAME)).strip() or _globals.DEFAULT_ADMIN_USERNAME
    password_hash = str(settings.get(_globals.ADMIN_PASSWORD_HASH_SETTING_KEY, "")).strip()
    if not password_hash:
        password_hash = hash_password(_globals.DEFAULT_ADMIN_PASSWORD)
        settings[_globals.ADMIN_PASSWORD_HASH_SETTING_KEY] = password_hash
    return username, password_hash


def build_admin_account_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    rows = [
        serialize_admin_account(account)
        for account in db.get("adminAccounts", [])
        if normalize_admin_role(account.get("role")) == _globals.ADMIN_ROLE_SECONDARY
    ]
    rows.sort(
        key=lambda item: (
            0 if bool(item.get("active")) else 1,
            str(item.get("createdAt", "")),
            str(item.get("id", "")),
        ),
        reverse=False,
    )
    return rows


# ---------------------------------------------------------------------------
# Admin list row builders (used by _admin_handler)
# ---------------------------------------------------------------------------

def build_admin_user_rows(
    db: dict[str, Any],
    *,
    include_deleted: bool = False,
) -> list[dict[str, Any]]:
    """Return serialised user rows for admin user management."""
    from services._user_service import (
        current_user_level,
        latest_account_cancellation_request_for_user,
        latest_pending_appeal_for_user,
        latest_user_level_request_for_user,
        user_avatar_url,
        user_level_label,
        user_nickname,
    )

    rows: list[dict[str, Any]] = []
    for user in db.get("users", []):
        if user.get("deleted") and not include_deleted:
            continue
        uid = str(user.get("id", "")).strip()
        pending_cancellation = latest_account_cancellation_request_for_user(
            db,
            uid,
            status="pending",
        )
        pending_appeal = latest_pending_appeal_for_user(db, uid)
        pending_level_request = latest_user_level_request_for_user(
            db,
            uid,
            status="pending",
        )
        post_count = sum(
            1
            for post in db.get("posts", [])
            if not post.get("deleted") and str(post.get("authorId", "")).strip() == uid
        )
        comment_count = sum(
            1
            for comment in db.get("comments", [])
            if not comment.get("deleted") and str(comment.get("userId", "")).strip() == uid
        )
        report_count = sum(
            1
            for report in db.get("reports", [])
            if str(report.get("userId", "")).strip() == uid
        )
        level = current_user_level(user)
        rows.append(
            {
                "id": uid,
                "email": user.get("email", ""),
                "studentId": str(user.get("studentId", "")),
                "alias": user_nickname(user),
                "avatarUrl": user_avatar_url(user),
                "verified": bool(user.get("verified", False)),
                "isAdmin": bool(user.get("isAdmin", False)),
                "userLevel": level,
                "userLevelLabel": user_level_label(level),
                "banned": bool(user.get("banned", False)),
                "muted": bool(user.get("muted", False)),
                "deleted": bool(user.get("deleted", False)),
                "postCount": post_count,
                "commentCount": comment_count,
                "reportCount": report_count,
                "createdAt": user.get("createdAt", ""),
                "hasPendingCancellationRequest": pending_cancellation is not None,
                "hasPendingAppeal": pending_appeal is not None,
                "hasPendingLevelUpgradeRequest": pending_level_request is not None,
            }
        )
    rows.sort(
        key=lambda item: (
            0 if item.get("deleted") else 1,
            str(item.get("createdAt", "")),
        ),
        reverse=True,
    )
    return rows


def build_admin_report_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    reason: str = "",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return serialised report rows for admin."""
    normalized_status = status.strip().lower() or "all"
    normalized_reason = reason.strip()
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for report in db.get("reports", []):
        row_status = str(report.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_reason and str(report.get("reason", "")) != normalized_reason:
            continue
        
        row = {
            "id": report.get("id", ""),
            "targetType": report.get("targetType", "other"),
            "targetId": report.get("targetId", "unknown"),
            "reason": report.get("reason", "其他"),
            "description": report.get("description", ""),
            "status": row_status,
            "result": report.get("result", ""),
            "reporterAlias": report.get("reporterAlias", "匿名同学"),
            "createdAt": report.get("createdAt", ""),
            "handledAt": report.get("handledAt", ""),
            "handledBy": report.get("handledBy", ""),
        }

        if normalized_keyword:
            merged = " ".join([
                str(row.get("id", "")).lower(),
                str(row.get("reason", "")).lower(),
                str(row.get("description", "")).lower(),
                str(row.get("reporterAlias", "")).lower(),
                str(row.get("targetId", "")).lower(),
                str(row.get("result", "")).lower(),
            ])
            if normalized_keyword not in merged:
                continue
        
        rows.append(row)
    
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    rows.sort(key=lambda x: 0 if x.get("status") == "pending" else 1)
    return rows


def build_admin_account_cancellation_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    from services._user_service import serialize_account_cancellation_request

    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("accountCancellationRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_keyword:
            merged = " ".join(
                [
                    str(request.get("userNickname", "")).lower(),
                    str(request.get("userEmail", "")).lower(),
                    str(request.get("studentId", "")).lower(),
                    str(request.get("reason", "")).lower(),
                    str(request.get("userId", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialize_account_cancellation_request(request))
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_appeal_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return serialised appeal rows for admin."""
    from services._user_service import serialize_appeal

    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for appeal in db.get("appeals", []):
        row_status = str(appeal.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        if normalized_keyword:
            merged = " ".join(
                [
                    str(appeal.get("userEmail", "")).lower(),
                    str(appeal.get("studentId", "")).lower(),
                    str(appeal.get("userNickname", "")).lower(),
                    str(appeal.get("appealType", "")).lower(),
                    str(appeal.get("title", "")).lower(),
                    str(appeal.get("content", "")).lower(),
                    str(appeal.get("targetId", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialize_appeal(db, appeal))
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_review_rows(
    db: dict[str, Any],
    *,
    target_type: str = "",
    status: str = "",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return combined review rows (posts + comments)."""
    from services._user_service import find_user_by_id, user_nickname

    normalized_type = target_type.strip().lower() or "post"
    normalized_status = status.strip().lower() or "pending"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []

    if normalized_type == "post":
        for post in db.get("posts", []):
            row_status = str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
            if normalized_status != "all" and row_status != normalized_status:
                continue
            
            author_user = find_user_by_id(
                db,
                str(post.get("authorId", "")).strip(),
                include_deleted=True,
            )
            
            row = {
                "id": post.get("id", ""),
                "targetType": "post",
                "title": post.get("title", ""),
                "content": post.get("content", ""),
                "authorAlias": post.get("authorAlias", "匿名同学"),
                "authorUserId": str(post.get("authorId", "")),
                "authorNickname": user_nickname(author_user),
                "authorEmail": str(author_user.get("email", "")) if author_user else "",
                "authorStudentId": str(author_user.get("studentId", "")) if author_user else "",
                "createdAt": post.get("createdAt", ""),
                "reviewStatus": row_status,
                "riskMarked": bool(post.get("riskMarked", False)),
                "deleted": bool(post.get("deleted", False)),
            }

            if normalized_keyword:
                merged = " ".join([
                    str(row["id"]).lower(),
                    str(row["title"]).lower(),
                    str(row["content"]).lower(),
                    str(row["authorNickname"]).lower(),
                    str(row["authorEmail"]).lower(),
                    str(row["authorStudentId"]).lower(),
                ])
                if normalized_keyword not in merged:
                    continue
            
            rows.append(row)
        
        rows.sort(key=lambda x: str(x.get("createdAt", "")), reverse=True)
        return rows

    if normalized_type == "comment":
        for comment in db.get("comments", []):
            row_status = str(comment.get("reviewStatus", "approved")).strip().lower() or "approved"
            if normalized_status != "all" and row_status != normalized_status:
                continue
            
            author_user = find_user_by_id(
                db,
                str(comment.get("userId", "")).strip(),
                include_deleted=True,
            )
            
            row = {
                "id": comment.get("id", ""),
                "targetType": "comment",
                "title": f"评论 @ 帖子 {comment.get('postId', '-')}",
                "content": comment.get("content", ""),
                "authorAlias": comment.get("authorAlias", "匿名同学"),
                "authorUserId": str(comment.get("userId", "")),
                "authorNickname": user_nickname(author_user),
                "authorEmail": str(author_user.get("email", "")) if author_user else "",
                "authorStudentId": str(author_user.get("studentId", "")) if author_user else "",
                "createdAt": comment.get("createdAt", ""),
                "reviewStatus": row_status,
                "riskMarked": bool(comment.get("riskMarked", False)),
                "deleted": bool(comment.get("deleted", False)),
            }

            if normalized_keyword:
                merged = " ".join([
                    str(row["id"]).lower(),
                    str(row["content"]).lower(),
                    str(row["authorNickname"]).lower(),
                    str(row["authorEmail"]).lower(),
                    str(row["authorStudentId"]).lower(),
                ])
                if normalized_keyword not in merged:
                    continue

            rows.append(row)
        
        rows.sort(key=lambda x: str(x.get("createdAt", "")), reverse=True)
        return rows

    raise ValueError("type 仅支持 post/comment")


def build_admin_user_level_request_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return user level upgrade request rows."""
    from services._user_service import serialize_admin_user_level_request

    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("userLevelRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        serialized = serialize_admin_user_level_request(db, request)
        if normalized_keyword:
            merged = " ".join(
                [
                    str(serialized.get("userId", "")).lower(),
                    str(serialized.get("userEmail", "")).lower(),
                    str(serialized.get("studentId", "")).lower(),
                    str(serialized.get("userNickname", "")).lower(),
                    str(serialized.get("reason", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialized)
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


def build_admin_post_pin_request_rows(
    db: dict[str, Any],
    *,
    status: str = "all",
    keyword: str = "",
) -> list[dict[str, Any]]:
    """Return post pin request rows."""
    from services._user_service import serialize_admin_post_pin_request

    normalized_status = status.strip().lower() or "all"
    normalized_keyword = keyword.strip().lower()
    rows: list[dict[str, Any]] = []
    for request in db.get("postPinRequests", []):
        row_status = str(request.get("status", "pending")).strip().lower() or "pending"
        if normalized_status != "all" and row_status != normalized_status:
            continue
        serialized = serialize_admin_post_pin_request(db, request)
        if normalized_keyword:
            merged = " ".join(
                [
                    str(serialized.get("postId", "")).lower(),
                    str(serialized.get("postTitle", "")).lower(),
                    str(serialized.get("userId", "")).lower(),
                    str(serialized.get("userEmail", "")).lower(),
                    str(serialized.get("userNickname", "")).lower(),
                    str(serialized.get("reason", "")).lower(),
                ]
            )
            if normalized_keyword not in merged:
                continue
        rows.append(serialized)
    rows.sort(key=lambda item: str(item.get("createdAt", "")), reverse=True)
    rows.sort(key=lambda item: 0 if item.get("status") == "pending" else 1)
    return rows


# ---------------------------------------------------------------------------
# Admin overview / stats
# ---------------------------------------------------------------------------

def build_overview(db: dict[str, Any]) -> dict[str, Any]:
    """Return admin overview stats."""
    users = [u for u in db.get("users", []) if not u.get("deleted")]
    posts = [p for p in db.get("posts", []) if not p.get("deleted")]
    reports_pending = [r for r in db.get("reports", []) if r.get("status") == "pending"]
    pending_reviews = [
        *[p for p in posts if str(p.get("reviewStatus", "approved")).lower() == "pending"],
        *[
            c
            for c in db.get("comments", [])
            if not c.get("deleted") and str(c.get("reviewStatus", "approved")).lower() == "pending"
        ],
    ]
    pending_images = [
        u
        for u in db.get("mediaUploads", [])
        if not u.get("deleted") and str(u.get("status", "approved")).lower() in {"pending", "risk"}
    ]
    comments = [c for c in db.get("comments", []) if not c.get("deleted")]
    pending_cancellations = [
        r
        for r in db.get("accountCancellationRequests", [])
        if str(r.get("status", "pending")).strip().lower() == "pending"
    ]
    return {
        "todayNewUsers": sum(1 for u in users if is_today_iso(u.get("createdAt"))),
        "todayPosts": sum(1 for p in posts if is_today_iso(p.get("createdAt"))),
        "todayComments": sum(1 for c in comments if is_today_iso(c.get("createdAt"))),
        "todayReports": sum(1 for r in db.get("reports", []) if is_today_iso(r.get("createdAt"))),
        "pendingCancellationRequests": len(pending_cancellations),
        "pendingFeedbacks": sum(
            1 for f in db.get("feedbacks", []) if str(f.get("status", "pending")) == "pending"
        ),
        "activeUsers": sum(1 for u in users if not u.get("banned")),
        "bannedUsers": sum(1 for u in users if u.get("banned")),
        "mutedUsers": sum(1 for u in users if u.get("muted")),
        "totalUsers": len(users),
        "totalPosts": len(posts),
        "totalReports": len(db.get("reports", [])),
        "pendingReports": len(reports_pending),
        "pendingReportCount": len(reports_pending),
        "pendingReviews": len(pending_reviews),
        "pendingReviewCount": len(pending_reviews),
        "pendingImages": len(pending_images),
        "pendingImageCount": len(pending_images),
        "totalComments": len(comments),
        "tags": list(db.get("tags", [])),
    }


def target_owner(db: dict[str, Any], post_id: str) -> dict[str, Any] | None:
    """Return the owner (authorId, authorAlias) of a post or comment."""
    for post in db.get("posts", []):
        if post.get("id") == post_id:
            return {
                "authorId": post.get("authorId", ""),
                "authorAlias": post.get("authorAlias", ""),
            }
    for comment in db.get("comments", []):
        if comment.get("id") == post_id:
            return {
                "authorId": comment.get("userId", ""),
                "authorAlias": comment.get("authorAlias", ""),
            }
    return None


def apply_admin_review_action(
    db: dict[str, Any],
    *,
    target_type: str,
    target_id: str,
    action: str,
) -> list[StorageObjectBackup]:
    normalized_type = target_type.strip().lower()
    normalized_action = action.strip().lower()
    if normalized_type not in {"post", "comment"}:
        raise ValueError("无效的审核内容类型")
    if normalized_action not in {"approve", "reject", "delete", "risk"}:
        raise ValueError("无效的审核动作")

    collection_name = "posts" if normalized_type == "post" else "comments"
    target = next(
        (
            row
            for row in db.get(collection_name, [])
            if str(row.get("id", "")).strip() == target_id.strip()
        ),
        None,
    )
    if target is None:
        raise LookupError("审核内容不存在")
    if target.get("deleted"):
        raise ValueError("内容已删除，不能再次审核")

    storage_backups: list[StorageObjectBackup] = []
    if normalized_action == "delete" and normalized_type == "post":
        uploads = [
            upload
            for upload in db.get("mediaUploads", [])
            if str(upload.get("postId", "")).strip() == target_id.strip()
            and not upload.get("deleted")
        ]
        object_keys = [
            str(upload.get("objectKey", "")).strip()
            for upload in uploads
            if str(upload.get("objectKey", "")).strip()
        ]
        try:
            storage_backups = delete_objects_with_backups(
                _globals.OBJECT_STORAGE,
                object_keys,
            )
        except Exception as error:
            raise RuntimeError("帖子图片存储删除失败，内容状态未变更") from error

    if normalized_action == "approve":
        target["reviewStatus"] = "approved"
        target["riskMarked"] = False
    elif normalized_action == "reject":
        target["reviewStatus"] = "rejected"
    elif normalized_action == "risk":
        target["reviewStatus"] = "pending"
        target["riskMarked"] = True
    else:
        target["deleted"] = True
        target["reviewStatus"] = "rejected"
        if normalized_type == "post":
            for upload in db.get("mediaUploads", []):
                if (
                    str(upload.get("postId", "")).strip() == target_id.strip()
                    and not upload.get("deleted")
                ):
                    upload["deleted"] = True
    return storage_backups


# ---------------------------------------------------------------------------
# List helpers used by post / comment handlers
# ---------------------------------------------------------------------------

def list_posts(
    db: dict[str, Any],
    *,
    keyword: str = "",
    has_image: bool | None = None,
    author_id: str = "",
    viewer_user_id: str = "",
    sort_by: str = "latest",
    include_rejected: bool = False,
) -> list[dict[str, Any]]:
    """Return filtered post rows."""
    viewer = str(viewer_user_id).strip()
    # 屏蔽: whoever the viewer blocked disappears from every list, anonymous
    # posts included (filtered here, so nothing says who wrote them).
    blocked_author_ids = {
        str(row.get("blockedUserId", "")).strip()
        for row in db.get("userBlocks", [])
        if viewer and str(row.get("blockerUserId", "")).strip() == viewer
    }
    # Counted once for the whole list: per post, this was a scan of every
    # like, comment and favorite.
    like_counts: dict[str, int] = {}
    for like in db.get("likes", []):
        key = str(like.get("postId", "")).strip()
        if key:
            like_counts[key] = like_counts.get(key, 0) + 1
    comment_counts: dict[str, int] = {}
    for comment in db.get("comments", []):
        if comment.get("deleted"):
            continue
        visible = (
            (str(comment.get("reviewStatus", "approved")).strip().lower() or "approved")
            in {"approved", "resolved"}
            or str(comment.get("userId", "")).strip() == viewer
        )
        if not visible:
            continue
        key = str(comment.get("postId", "")).strip()
        comment_counts[key] = comment_counts.get(key, 0) + 1
    favorite_counts: dict[str, int] = {}
    for favorite_row in db.get("favorites", []):
        key = str(favorite_row.get("postId", "")).strip()
        favorite_counts[key] = favorite_counts.get(key, 0) + 1

    posts = []
    for post in db.get("posts", []):
        if post.get("deleted"):
            continue
        if blocked_author_ids and str(post.get("authorId", "")).strip() in blocked_author_ids:
            continue
        if (
            str(post.get("visibility", "public")).strip().lower() == "private"
            and str(post.get("authorId", "")).strip()
            != str(viewer_user_id).strip()
        ):
            continue
        if not include_rejected and post.get("reviewStatus") not in ("approved", "resolved"):
            continue
        if has_image is True and not post.get("hasImage"):
            continue
        if has_image is False and post.get("hasImage"):
            continue
        if author_id and post.get("authorId") != author_id:
            continue
        if keyword:
            title = str(post.get("title", "")).lower()
            content = str(post.get("content", "")).lower()
            if keyword not in title and keyword not in content:
                continue
        post_id = str(post.get("id", "")).strip()
        post["likeCount"] = like_counts.get(post_id, 0)
        post["commentCount"] = comment_counts.get(post_id, 0)
        post["favoriteCount"] = favorite_counts.get(post_id, 0)
        post["viewCount"] = max(0, int(post.get("viewCount", 0) or 0))
        posts.append(post)
    if sort_by != "hot":
        posts.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return posts


def list_comments(
    db: dict[str, Any],
    post_id: str,
    viewer_user_id: str = "",
) -> list[dict[str, Any]]:
    """Return comments for a post."""
    viewer = str(viewer_user_id).strip()
    # 屏蔽 hides the blocked user's comments too.
    blocked_user_ids = {
        str(row.get("blockedUserId", "")).strip()
        for row in db.get("userBlocks", [])
        if viewer and str(row.get("blockerUserId", "")).strip() == viewer
    }
    comments = []
    for comment in db.get("comments", []):
        if comment.get("postId") != post_id:
            continue
        if comment.get("deleted"):
            continue
        if blocked_user_ids and str(comment.get("userId", "")).strip() in blocked_user_ids:
            continue
        status = (
            str(comment.get("reviewStatus", "approved")).strip().lower()
            or "approved"
        )
        is_owner = (
            bool(str(viewer_user_id).strip())
            and str(comment.get("userId", "")).strip()
            == str(viewer_user_id).strip()
        )
        if status not in {"approved", "resolved"} and not is_owner:
            continue
        comments.append(comment)
    comments.sort(key=lambda x: str(x.get("createdAt", "") or ""))
    return comments


def build_export_payload(
    db: dict[str, Any],
    *,
    scope: str = "users",
    export_format: str = "csv",
    review_type: str = "all",
    review_status: str = "all",
    report_status: str = "all",
    appeal_status: str = "all",
) -> dict[str, Any]:
    """Build export payload for admin data export."""
    import csv
    import io
    import json

    def spreadsheet_safe(value: object) -> str:
        text = str(value)
        if text.lstrip(" \t\r\n").startswith(("=", "+", "-", "@")):
            return "'" + text
        return text

    rows: list[list[str]] = []
    headers: list[str] = []
    
    normalized_scope = scope.strip().lower() or "users"
    
    if normalized_scope == "users":
        headers = ["id", "email", "nickname", "studentId", "userLevel", "verified", "banned", "createdAt"]
        for user in db.get("users", []):
            if user.get("deleted"):
                continue
            rows.append([
                str(user.get("id", "")),
                str(user.get("email", "")),
                str(user.get("nickname", "")),
                str(user.get("studentId", "")),
                str(user.get("userLevel", 2)),
                str(bool(user.get("verified"))),
                str(bool(user.get("banned"))),
                str(user.get("createdAt", "")),
            ])
            
    elif normalized_scope == "posts" or (normalized_scope == "reviews" and review_type == "post"):
        headers = ["id", "title", "sectionName", "authorId", "authorAlias", "createdAt", "reviewStatus", "deleted"]
        for post in db.get("posts", []):
            status = str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
            if review_status != "all" and status != review_status:
                continue
            rows.append([
                str(post.get("id", "")),
                str(post.get("title", "")),
                str(post.get("sectionName", "")),
                str(post.get("authorId", "")),
                str(post.get("authorAlias", "")),
                str(post.get("createdAt", "")),
                status,
                str(bool(post.get("deleted"))),
            ])

    elif normalized_scope == "comments" or (normalized_scope == "reviews" and review_type == "comment"):
        headers = ["id", "postId", "userId", "authorAlias", "content", "createdAt", "reviewStatus", "deleted"]
        for comment in db.get("comments", []):
            status = str(comment.get("reviewStatus", "approved")).strip().lower() or "approved"
            if review_status != "all" and status != review_status:
                continue
            rows.append([
                str(comment.get("id", "")),
                str(comment.get("postId", "")),
                str(comment.get("userId", "")),
                str(comment.get("authorAlias", "")),
                str(comment.get("content", "")),
                str(comment.get("createdAt", "")),
                status,
                str(bool(comment.get("deleted"))),
            ])

    elif normalized_scope == "reports":
        headers = ["id", "user_id", "reporterAlias", "targetType", "targetId", "reason", "status", "createdAt"]
        for report in db.get("reports", []):
            status = str(report.get("status", "pending")).strip().lower()
            if report_status != "all" and status != report_status:
                continue
            rows.append([
                str(report.get("id", "")),
                str(report.get("userId", "")),
                str(report.get("reporterAlias", "")),
                str(report.get("targetType", "")),
                str(report.get("targetId", "")),
                str(report.get("reason", "")),
                status,
                str(report.get("createdAt", "")),
            ])

    elif normalized_scope == "cancellations":
        headers = ["id", "userId", "reason", "status", "createdAt"]
        for req in db.get("accountCancellationRequests", []):
            rows.append([
                str(req.get("id", "")),
                str(req.get("userId", "")),
                str(req.get("reason", "")),
                str(req.get("status", "")),
                str(req.get("createdAt", "")),
            ])

    elif normalized_scope == "appeals":
        headers = ["id", "userId", "userEmail", "appealType", "targetType", "targetId", "title", "content", "status", "createdAt"]
        for appeal in db.get("appeals", []):
            status = str(appeal.get("status", "pending")).strip().lower()
            if appeal_status != "all" and status != appeal_status:
                continue
            rows.append([
                str(appeal.get("id", "")),
                str(appeal.get("userId", "")),
                str(appeal.get("userEmail", "")),
                str(appeal.get("appealType", "")),
                str(appeal.get("targetType", "")),
                str(appeal.get("targetId", "")),
                str(appeal.get("title", "")),
                str(appeal.get("content", "")),
                status,
                str(appeal.get("createdAt", "")),
            ])

    elif normalized_scope == "userlevelrequests":
        headers = ["id", "userId", "targetLevel", "reason", "status", "createdAt"]
        for req in db.get("userLevelRequests", []):
            rows.append([
                str(req.get("id", "")),
                str(req.get("userId", "")),
                str(req.get("targetLevel", "")),
                str(req.get("reason", "")),
                str(req.get("status", "")),
                str(req.get("createdAt", "")),
            ])

    elif normalized_scope == "postpinrequests":
        headers = ["id", "postId", "userId", "durationMinutes", "reason", "status", "createdAt"]
        for req in db.get("postPinRequests", []):
            rows.append([
                str(req.get("id", "")),
                str(req.get("postId", "")),
                str(req.get("userId", "")),
                str(req.get("durationMinutes", "")),
                str(req.get("reason", "")),
                str(req.get("status", "")),
                str(req.get("createdAt", "")),
            ])

    elif normalized_scope == "auditlogs":
        headers = ["id", "actorId", "action", "detail", "createdAt"]
        for log in db.get("auditLogs", []):
            rows.append([
                str(log.get("id", "")),
                str(log.get("actorId", "")),
                str(log.get("action", "")),
                str(log.get("detail", "")),
                str(log.get("createdAt", "")),
            ])

    output = ""
    if export_format == "csv":
        si = io.StringIO()
        writer = csv.writer(si)
        writer.writerow([spreadsheet_safe(value) for value in headers])
        writer.writerows([[spreadsheet_safe(value) for value in row] for row in rows])
        output = si.getvalue()
    else:
        output = json.dumps({"headers": headers, "rows": rows}, ensure_ascii=False)

    is_csv = export_format == "csv"
    return {
        "format": "csv" if is_csv else "json",
        "fileName": f"{normalized_scope}-{now_utc().strftime('%Y%m%d-%H%M%S')}.{'csv' if is_csv else 'json'}",
        "contentType": "text/csv; charset=utf-8" if is_csv else "application/json; charset=utf-8",
        "rowCount": len(rows),
        "data": output,
    }


# ---------------------------------------------------------------------------
# Legacy stubs / aliases (handlers expect these at module level)
# ---------------------------------------------------------------------------

# Backward-compat constant
IS_SQL_DB = False


# Public system settings for unauthenticated endpoints
def public_system_settings(db: dict[str, Any]) -> dict[str, Any]:
    """Return public system settings (tags, rate limits)."""
    return {
        "tags": list(db.get("tags", [])),
        "settings": dict(db.get("settings", {})),
    }


def serialize_android_release(raw: dict[str, Any]) -> dict[str, Any]:
    return {
        "platform": "android",
        "versionName": str(raw.get("versionName", "")).strip(),
        "versionCode": _safe_int(raw.get("versionCode"), 0),
        "releaseNotes": str(raw.get("releaseNotes", "")).strip(),
        "forceUpdate": _safe_bool(raw.get("forceUpdate"), False),
        "fileName": str(raw.get("fileName", "")).strip(),
        "contentType": str(
            raw.get("contentType", "application/vnd.android.package-archive"),
        ).strip()
        or "application/vnd.android.package-archive",
        "sizeBytes": max(0, _safe_int(raw.get("sizeBytes"), 0)),
        "sha256": str(raw.get("sha256", "")).strip().lower(),
        "downloadUrl": normalize_media_url(
            str(raw.get("downloadUrl", raw.get("url", ""))).strip(),
        ),
        "objectKey": str(raw.get("objectKey", "")).strip(),
        "uploadedAt": str(raw.get("uploadedAt", raw.get("createdAt", ""))).strip(),
        "uploadedBy": str(raw.get("uploadedBy", "")).strip(),
        "uploadedByUsername": str(raw.get("uploadedByUsername", "")).strip(),
    }


def get_android_release(db: dict[str, Any]) -> dict[str, Any] | None:
    settings = db.get("settings", {})
    if not isinstance(settings, dict):
        return None
    raw = settings.get("androidRelease")
    if not isinstance(raw, dict):
        return None
    release = serialize_android_release(raw)
    if not release.get("versionName") or not release.get("downloadUrl"):
        return None
    return release


def set_android_release(db: dict[str, Any], release: dict[str, Any]) -> dict[str, Any]:
    db.setdefault("settings", {})
    if not isinstance(db["settings"], dict):
        db["settings"] = {}
    serialized = serialize_android_release(release)
    db["settings"]["androidRelease"] = serialized
    return serialized


# Pagination metadata builder
def build_pagination_meta(
    total: int,
    page: int = 1,
    per_page: int = 20,
) -> dict[str, Any]:
    """Build pagination metadata dict."""
    total_pages = max(1, (total + per_page - 1) // per_page)
    return {
        "total": total,
        "page": page,
        "perPage": per_page,
        "totalPages": total_pages,
    }


# Admin report serialiser
def serialize_admin_report(report: dict[str, Any]) -> dict[str, Any]:
    """Serialize a report row for admin display."""
    return {
        "id": report.get("id", ""),
        "reporterAlias": str(report.get("reporterAlias", "匿名")),
        "reportedAlias": str(report.get("reportedAlias", "匿名")),
        "reason": str(report.get("reason", "")),
        "status": str(report.get("status", "pending")),
        "createdAt": str(report.get("createdAt", "")),
    }


# Admin image row builders
def build_admin_image_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised image upload rows for admin moderation."""
    rows = []
    for upload in db.get("mediaUploads", []):
        rows.append({
            "id": upload.get("id", ""),
            "url": normalize_media_url(str(upload.get("url", ""))),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "status": upload.get("status", "pending"),
            "uploaderId": upload.get("uploaderId", ""),
            "postId": upload.get("postId", ""),
            "createdAt": upload.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


def build_image_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised image rows (public-facing)."""
    rows = []
    for upload in db.get("mediaUploads", []):
        status = str(upload.get("status", ""))
        if status not in ("approved", ""):
            continue
        rows.append({
            "id": upload.get("id", ""),
            "url": normalize_media_url(str(upload.get("url", ""))),
            "fileName": upload.get("fileName", ""),
            "contentType": upload.get("contentType", ""),
            "sizeBytes": int(upload.get("sizeBytes", 0)),
            "createdAt": upload.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


# Image upload serialiser
def serialize_image_upload(upload: dict[str, Any]) -> dict[str, Any]:
    """Serialize an image upload row."""
    return {
        "id": upload.get("id", ""),
        "url": normalize_media_url(str(upload.get("url", ""))),
        "fileName": upload.get("fileName", ""),
        "contentType": upload.get("contentType", ""),
        "sizeBytes": int(upload.get("sizeBytes", 0)),
        "status": upload.get("status", "pending"),
        "createdAt": upload.get("createdAt", ""),
        "postId": upload.get("postId", ""),
        "uploaderId": upload.get("uploaderId", ""),
    }


# Appeal row builder (lighter variant used by server.py handlers)
def build_appeal_rows(db: dict[str, Any]) -> list[dict[str, Any]]:
    """Return serialised appeal rows for admin."""
    rows = []
    for appeal in db.get("appeals", []):
        rows.append({
            "id": appeal.get("id", ""),
            "userId": appeal.get("userId", ""),
            "reason": appeal.get("reason", ""),
            "status": appeal.get("status", "pending"),
            "createdAt": appeal.get("createdAt", ""),
        })
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    return rows


# Handlers also reference get_setting_int from services
def get_setting_int(db: dict[str, Any], key: str, default: int, *, minimum: int = 1) -> int:
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        try:
            return max(minimum, int(settings.get(key, default)))
        except (TypeError, ValueError):
            return max(minimum, default)
    return max(minimum, default)


# Serialize helpers for post/comment handlers
def visible_mentions(db: dict[str, Any], mentions: Any) -> list[dict[str, str]]:
    """Stored @-mentions minus accounts that are gone, with current nicknames."""
    from services._user_service import user_nickname

    rows: list[dict[str, str]] = []
    for mention in mentions if isinstance(mentions, list) else []:
        if not isinstance(mention, dict):
            continue
        user_id = str(mention.get("userId", "")).strip()
        user = next(
            (row for row in db.get("users", []) if str(row.get("id", "")).strip() == user_id),
            None,
        )
        if user is None or user.get("deleted"):
            continue
        # The text keeps the nickname as typed; the link follows the account.
        rows.append({"userId": user_id, "nickname": str(mention.get("nickname", "")) or user_nickname(user)})
    return rows


def serialize_post(
    db: dict[str, Any],
    post: dict[str, Any],
    viewer_user_id: str = "",
    *,
    include_unapproved_images: bool = False,
) -> dict[str, Any]:
    from services._user_service import (
        can_request_dm_to_user,
        effective_post_allow_dm,
        is_post_anonymous,
        is_post_pin_active,
        is_post_private,
        is_user_following,
        parse_pin_duration_minutes,
        pin_duration_label,
        user_avatar_url,
    )

    post_id = str(post.get("id", "")).strip()
    author_id = str(post.get("authorId", "")).strip()
    is_anonymous = is_post_anonymous(db, post)
    is_private = is_post_private(post)
    author_user = None
    for user in db.get("users", []):
        if str(user.get("id", "")).strip() == author_id:
            author_user = user
            break

    # Matches list_comments: a blocked user's comments are not shown, so they
    # are not counted either.
    blocked_by_viewer = {
        str(row.get("blockedUserId", "")).strip()
        for row in db.get("userBlocks", [])
        if viewer_user_id and str(row.get("blockerUserId", "")).strip() == viewer_user_id
    }
    comment_count = sum(
        1
        for comment in db.get("comments", [])
        if not comment.get("deleted")
        and str(comment.get("postId", "")).strip() == post_id
        and str(comment.get("userId", "")).strip() not in blocked_by_viewer
        and (
            (
                str(comment.get("reviewStatus", "approved")).strip().lower()
                or "approved"
            )
            in {"approved", "resolved"}
            or (
                viewer_user_id
                and str(comment.get("userId", "")).strip() == viewer_user_id
            )
        )
    )
    like_count = sum(
        1
        for like in db.get("likes", [])
        if str(like.get("postId", "")).strip() == post_id
    )
    favorite_count = sum(
        1
        for favorite_row in db.get("favorites", [])
        if str(favorite_row.get("postId", "")).strip() == post_id
    )
    liked = bool(
        viewer_user_id
        and any(
            x
            for x in db.get("likes", [])
            if x.get("userId") == viewer_user_id and x.get("postId") == post_id
        )
    )
    favorited = bool(
        viewer_user_id
        and any(
            x
            for x in db.get("favorites", [])
            if x.get("userId") == viewer_user_id and x.get("postId") == post_id
        )
    )

    repost_count = sum(
        1 for row in db.get("reposts", []) if str(row.get("postId", "")).strip() == post_id
    )
    reposted = bool(
        viewer_user_id
        and any(
            row for row in db.get("reposts", [])
            if row.get("userId") == viewer_user_id and row.get("postId") == post_id
        )
    )

    image_urls: list[str] = []
    uploaded_image_ids: list[str] = []
    for upload in db.get("mediaUploads", []):
        if str(upload.get("postId", "")).strip() != post_id:
            continue
        if upload.get("deleted"):
            continue
        status = str(upload.get("status", "")).strip().lower()
        if status not in {"", "approved"} and not include_unapproved_images:
            continue
        upload_id = str(upload.get("id", "")).strip()
        upload_url = normalize_media_url(str(upload.get("url", "")).strip())
        if upload_id:
            uploaded_image_ids.append(upload_id)
        if upload_url:
            image_urls.append(upload_url)

    can_view_author_profile = bool(
        viewer_user_id
        and not is_anonymous
        and not is_private
        and author_id
        and author_user is not None
    )
    can_follow_author = bool(
        can_view_author_profile and viewer_user_id != author_id
    )
    is_following_author = bool(
        can_follow_author and is_user_following(db, viewer_user_id, author_id)
    )
    can_message_author = bool(
        can_view_author_profile
        and viewer_user_id != author_id
        and effective_post_allow_dm(db, post)
        and can_request_dm_to_user(
            db,
            viewer_user_id=viewer_user_id,
            target_user_id=author_id,
        )
    )

    return {
        "id": post_id,
        "title": post.get("title", ""),
        "content": post.get("content", ""),
        "contentFormat": "markdown" if str(post.get("contentFormat", "")).strip().lower() == "markdown" else "plain",
        "markdownSource": str(post.get("markdownSource", "")),
        "tags": post.get("tags", []),
        "authorAlias": post.get("authorAlias", "匿名同学"),
        "isAnonymous": is_anonymous,
        "authorAvatarUrl": "" if is_anonymous else user_avatar_url(author_user),
        "authorUserId": author_id if can_view_author_profile else "",
        "createdAt": post.get("createdAt", ""),
        "updatedAt": post.get("updatedAt", ""),
        "hasImage": bool(image_urls),
        "imageUrls": image_urls,
        "uploadedImageIds": uploaded_image_ids,
        "commentCount": comment_count,
        "likeCount": like_count,
        "favoriteCount": favorite_count,
        "viewCount": max(0, int(post.get("viewCount", 0) or 0)),
        "shareCount": max(0, int(post.get("shareCount", 0) or 0)),
        "sectionType": str(post.get("sectionType", "")),
        "sectionId": str(post.get("sectionId", "")),
        "sectionName": str(post.get("sectionName", "")),
        "publisherType": str(post.get("publisherType", "user") or "user"),
        "publisherClubId": str(post.get("publisherClubId", "")),
        "liked": liked,
        "favorited": favorited,
        "repostCount": repost_count,
        "reposted": reposted,
        "mentions": visible_mentions(db, post.get("mentions")),
        "editedAt": str(post.get("editedAt", "") or ""),
        "status": post.get("status", "ongoing"),
        # pending / rejected are only ever seen on one's own posts, where the
        # card shows 待审核 / 未通过审核.
        "reviewStatus": str(post.get("reviewStatus", "approved") or "approved").strip().lower(),
        "allowComment": bool(post.get("allowComment", True)),
        "allowDm": effective_post_allow_dm(db, post),
        "visibility": str(post.get("visibility", "public")),
        "isPrivate": is_private,
        "isPinned": is_post_pin_active(post),
        "pinStartedAt": post.get("pinStartedAt", ""),
        "pinExpiresAt": post.get("pinExpiresAt", ""),
        "pinDurationMinutes": parse_pin_duration_minutes(post.get("pinDurationMinutes")) or 0,
        "pinDurationLabel": pin_duration_label(post.get("pinDurationMinutes")),
        "canViewAuthorProfile": can_view_author_profile,
        "canFollowAuthor": can_follow_author,
        "isFollowingAuthor": is_following_author,
        "canMessageAuthor": can_message_author,
        "isOwnPost": bool(viewer_user_id and viewer_user_id == author_id),
    }


def serialize_comment(db: dict[str, Any], comment: dict[str, Any], viewer_user_id: str = "") -> dict[str, Any]:
    from services._user_service import user_avatar_url

    author_id = str(comment.get("userId", "")).strip()
    author_user = None
    for u in db.get("users", []):
        if str(u.get("id", "")) == author_id:
            author_user = u
            break
    liked = bool(
        viewer_user_id
        and any(
            x for x in db.get("likes", [])
            if x.get("userId") == viewer_user_id and x.get("commentId") == comment.get("id")
        )
    )
    is_anonymous = bool(comment.get("isAnonymous", False))
    public_author_id = "" if is_anonymous else author_id
    # 洞主: whether whoever wrote the post wrote this comment. Only the flag
    # is exposed, never the id, so anonymous posts stay anonymous.
    post_id = str(comment.get("postId", "")).strip()
    post = next((p for p in db.get("posts", []) if str(p.get("id", "")).strip() == post_id), None)
    is_post_author = bool(
        post is not None and author_id and str(post.get("authorId", "")).strip() == author_id
    )
    return {
        "id": comment.get("id", ""),
        "postId": comment.get("postId", ""),
        "isPostAuthor": is_post_author,
        "content": comment.get("content", ""),
        "authorAlias": comment.get("authorAlias", "匿名同学"),
        "authorId": public_author_id,
        "authorAvatarUrl": (
            "" if is_anonymous else user_avatar_url(author_user) if author_user else ""
        ),
        "authorUserId": public_author_id,
        "likeCount": max(0, int(comment.get("likeCount", 0) or 0)),
        "liked": liked,
        "createdAt": comment.get("createdAt", ""),
        "isAnonymous": is_anonymous,
        "reviewStatus": str(comment.get("reviewStatus", "approved")),
    }


def ensure_admin_accounts(db: dict[str, Any]) -> bool:
    changed = False
    seq = db.get("seq")
    if not isinstance(seq, dict):
        seq = {}
        db["seq"] = seq
        changed = True
    if "adminAccount" not in seq:
        seq["adminAccount"] = 0
        changed = True
    raw_accounts = db.get("adminAccounts")
    if not isinstance(raw_accounts, list):
        raw_accounts = []
        db["adminAccounts"] = raw_accounts
        changed = True

    sanitized_accounts: list[dict[str, Any]] = []
    seen_usernames: set[str] = set()
    timestamp = now_iso()
    for row in raw_accounts:
        if not isinstance(row, dict):
            changed = True
            continue
        admin_id = str(row.get("id", "")).strip()
        username = normalize_admin_username(str(row.get("username", "")))
        password_hash = str(row.get("passwordHash", "")).strip()
        if not admin_id or not username or not password_hash:
            changed = True
            continue
        if not is_password_hashed(password_hash):
            password_hash = hash_password(password_hash)
            changed = True
        if username in seen_usernames:
            changed = True
            continue
        seen_usernames.add(username)
        role = normalize_admin_role(row.get("role"))
        active = bool(row.get("active", True))
        created_at = str(row.get("createdAt", "")).strip() or timestamp
        updated_at = str(row.get("updatedAt", "")).strip() or created_at
        created_by = str(row.get("createdBy", "")).strip()
        sanitized_accounts.append(
            build_admin_account(
                admin_id=admin_id,
                username=username,
                password_hash=password_hash,
                role=role,
                active=active,
                created_at=created_at,
                updated_at=updated_at,
                created_by=created_by,
            )
        )
        if (
            username != str(row.get("username", "")).strip()
            or password_hash != str(row.get("passwordHash", "")).strip()
            or role != str(row.get("role", "")).strip().lower()
            or created_at != str(row.get("createdAt", "")).strip()
            or updated_at != str(row.get("updatedAt", "")).strip()
            or created_by != str(row.get("createdBy", "")).strip()
            or active != bool(row.get("active", True))
        ):
            changed = True

    db["adminAccounts"] = sanitized_accounts

    legacy_username, legacy_password_hash = get_admin_auth_credentials(db)
    legacy_username = normalize_admin_username(legacy_username) or normalize_admin_username(_globals.DEFAULT_ADMIN_USERNAME)
    if not is_password_hashed(legacy_password_hash):
        legacy_password_hash = hash_password(legacy_password_hash)
        changed = True

    if not db["adminAccounts"]:
        db["adminAccounts"].append(
            build_admin_account(
                admin_id=next_id(db, "adminAccount", "adm"),
                username=legacy_username,
                password_hash=legacy_password_hash,
                role=_globals.ADMIN_ROLE_PRIMARY,
                active=True,
                created_at=timestamp,
                updated_at=timestamp,
                created_by="system",
            )
        )
        changed = True

    default_admin = find_admin_account_by_username(
        db,
        _globals.DEFAULT_ADMIN_USERNAME,
        include_inactive=True,
    )
    if default_admin is not None:
        if normalize_admin_role(default_admin.get("role")) != _globals.ADMIN_ROLE_PRIMARY:
            default_admin["role"] = _globals.ADMIN_ROLE_PRIMARY
            default_admin["updatedAt"] = timestamp
            changed = True
        if not bool(default_admin.get("active", True)):
            default_admin["active"] = True
            default_admin["updatedAt"] = timestamp
            changed = True

    if not any(
        normalize_admin_role(account.get("role")) == _globals.ADMIN_ROLE_PRIMARY
        for account in db.get("adminAccounts", [])
    ):
        first_account = db["adminAccounts"][0]
        first_account["role"] = _globals.ADMIN_ROLE_PRIMARY
        first_account["updatedAt"] = timestamp
        changed = True

    return changed


# ---------------------------------------------------------------------------
# Database service — schema migration, seeding, persistence
# ---------------------------------------------------------------------------

RADIO_STATE_KEYS = [
    "sections",
    "clubs",
    "clubApplications",
    "clubMembers",
    "campusServices",
    "campusMaps",
    "courseSchedules",
    "examSchedules",
    "experimentSchedules",
    "hotTopics",
    "hotTopicSummaries",
    "knowledgeSources",
    "knowledgeDocuments",
    "knowledgeChunks",
    "ragCrawlRuns",
    "ragRetrievalLogs",
    "aiConversations",
    "aiMessages",
    "aiCitations",
    "dailySummaries",
    "moderationTasks",
    "announcements",
]


def _default_sections(created: str) -> list[dict[str, Any]]:
    colleges = [
        ("college-cs", "计算机科学与技术学院", "cs"),
        ("college-ee", "电子工程学院", "ee"),
        ("college-is", "网络与信息安全学院", "is"),
        ("college-me", "机电工程学院", "me"),
        ("college-math", "数学与统计学院", "math"),
        ("college-phys", "物理学院", "phys"),
        ("college-human", "人文学院", "human"),
        ("college-econ", "经济与管理学院", "econ"),
    ]
    rows: list[dict[str, Any]] = [{
        "id": "section-general",
        "sectionType": "general",
        "sectionId": "general",
        "sectionName": "综合",
        "name": "综合",
        "description": "全校公共讨论分区。",
        "ruleText": "默认发布到综合分区；话题请使用 #标签。",
        "createdAt": created,
        "updatedAt": created,
        "enabled": True,
        "sortOrder": 0,
    }]
    rows.extend({
        "id": section_id,
        "sectionType": "college",
        "sectionId": key,
        "sectionName": name,
        "name": name,
        "description": "学院分区第一阶段展示规则，后续接入身份接口后做发帖权限校验。",
        "ruleText": "本学院可发帖，其他学院只读；当前阶段仅展示规则。",
        "createdAt": created,
        "updatedAt": created,
        "enabled": True,
        "sortOrder": index,
    } for index, (section_id, name, key) in enumerate(colleges, start=10))
    return rows



def _default_campus_services(created: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    ehall_url = "https://ehall.xidian.edu.cn/new/index.html"
    mobile_portal_url = "https://xxcapp.xidian.edu.cn/site/xidianPage/home"
    gis_url = "https://gis.xidian.edu.cn/#/home?campus=21047"
    payment_url = (
        "https://xxcapp.xidian.edu.cn/uc/api/oauth/index?"
        "redirect=https://ignypt.xidian.edu.cn/revenueH5/login?"
        "opcode=MPAY&appid=200260318155520600&state=1231231231"
    )
    remote_access_url = "https://xxzx.xidian.edu.cn/f_w/ssfw/xwycfwfw.htm"
    print_service_url = "https://xxzx.xidian.edu.cn/f_w/ssfw/zzdy.htm"
    email_service_url = "https://xxzx.xidian.edu.cn/f_w/ssfw/yx.htm"
    software_service_url = "https://gsoft.xidian.edu.cn"
    repair_url = (
        "https://ids.xidian.edu.cn/authserver/login?service="
        "https%3A%2F%2Fids.xidian.edu.cn%2Fauthserver%2Foauth2.0%2F"
        "callbackAuthorize%3Fclient_id%3D869608421533880320%26"
        "redirect_uri%3Dhttp%253A%252F%252Frepair.xidian.edu.cn%252F"
        "appsys%252FxidianCasLogin%252FoauthLogin%26response_type%3D"
        "code%26state%3Dhome%26client_name%3DCasOAuthClient"
    )
    service_specs = [
        {
            "name": "课表",
            "slug": "classtable",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "schedule",
            "iconKey": "calendar",
            "authType": "ids",
            "status": "日历视图",
            "summary": "以周历展示课程、考试与实验安排，按日期查看当天所有校园日程。",
            "requiredAccess": "一站式课表接口、统一身份认证回传用户唯一 ID。",
            "features": ["周历课表", "今日高亮", "课程/考试/实验合并日程", "地点与教师信息"],
            "dataFields": ["课程名称", "上课日期", "开始/结束时间", "地点", "教师", "节次"],
            "calendarSource": "academic",
            "emptyText": "当前没有课表数据。",
            "actions": [{"label": "查看周历", "type": "calendar"}],
        },
        {
            "name": "成绩单",
            "slug": "score",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "grade",
            "iconKey": "chart",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "查看学期成绩、课程性质、学分、等级成绩和均分/GPA 汇总。",
            "requiredAccess": "一站式成绩接口、统一身份认证、查询即返回的短期内存缓存。",
            "features": ["成绩列表", "按学期筛选", "均分/GPA 汇总", "未通过课程提示"],
            "dataFields": ["课程名称", "成绩", "学年学期", "学分", "课程性质", "等级", "是否通过"],
            "emptyText": "当前没有成绩数据。",
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
        {
            "name": "考试安排",
            "slug": "exam",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "schedule",
            "iconKey": "calendar",
            "authType": "ids",
            "status": "日历视图",
            "summary": "展示已安排考试与暂无考务安排的课程，自动进入课表日历。",
            "requiredAccess": "一站式考试安排接口。",
            "features": ["考试时间", "考场与座位", "未安排课程", "日历合并展示"],
            "dataFields": ["考试科目", "考试类型", "开始/结束时间", "地点", "座位号"],
            "calendarSource": "examSchedules",
            "emptyText": "当前没有考试安排数据。",
            "actions": [{"label": "查看考试日历", "type": "calendar"}],
        },
        {
            "name": "实验安排",
            "slug": "experiment",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "schedule",
            "iconKey": "flask",
            "authType": "physicsPassword",
            "status": "日历视图",
            "summary": "汇总物理实验与其他实验安排，包含时间、地点、教师、座位和成绩字段。",
            "requiredAccess": "物理实验系统账号密码；其他实验系统使用一站式认证入口。",
            "features": ["物理实验", "其他实验", "实验成绩", "课前提醒数据"],
            "dataFields": ["实验名称", "开始/结束时间", "地点", "教师", "座位号", "成绩"],
            "calendarSource": "experimentSchedules",
            "emptyText": "当前没有实验安排数据。",
            "actions": [
                {"label": "查看实验日历", "type": "calendar"},
                {"label": "物理实验系统", "type": "external", "url": "http://wlsy.xidian.edu.cn/PhyEws/default.aspx"},
                {"label": "其他实验系统", "type": "external", "url": "https://sysj.xidian.edu.cn/xidian/webapp/login"},
            ],
        },
        {
            "name": "空闲教室",
            "slug": "empty-classroom",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "location",
            "iconKey": "building",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "按校区、楼宇、节次筛选空闲教室，适合自习与临时讨论。",
            "requiredAccess": "教室占用数据或教务课表公共查询接口。",
            "features": ["校区筛选", "楼宇筛选", "节次占用", "关键词搜索"],
            "dataFields": ["教室名称", "1-2 节", "3-4 节", "5-6 节", "7-8 节", "9-10 节"],
            "emptyText": "当前没有空闲教室数据。",
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
        {
            "name": "考勤",
            "slug": "attendance",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "attendance",
            "iconKey": "check",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "展示课程考勤、签到详情、任务点、作业和考试进度。",
            "requiredAccess": "考勤系统接口、请销假系统状态接口。",
            "features": ["课程考勤记录", "签到详情", "学习进度", "请假关联"],
            "dataFields": ["课程名称", "签到次数", "异常次数", "任务点进度", "作业进度", "考试进度"],
            "emptyText": "当前没有考勤数据。",
            "actions": [{"label": "打开请销假系统", "type": "external", "url": "https://service.xidian.edu.cn/v2/matter/m_start?id=189"}],
        },
        {
            "name": "体育信息",
            "slug": "sport",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "sport",
            "iconKey": "activity",
            "authType": "unavailable",
            "status": "暂不可用",
            "summary": "体育系统当前仅提供 HTTP 登录地址，本站已停止收集和转发体育系统密码。",
            "requiredAccess": "等待学校提供 HTTPS 登录地址后重新评估。",
            "features": ["体育课程", "体测总分", "体测分项", "成绩等级"],
            "dataFields": ["学期", "课程名称", "教师", "上课时间", "课程成绩", "体测项目", "等级"],
            "emptyText": "当前没有体育信息。",
            "actions": [{"label": "等待 HTTPS 服务", "type": "notice", "url": ""}],
        },
        {
            "name": "宿舍电费",
            "slug": "electricity",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "energy",
            "iconKey": "bolt",
            "authType": "ids",
            "status": "已接入缴费入口",
            "summary": "查看宿舍电量、欠费金额和历史读表趋势，并进入学校缴费入口。",
            "requiredAccess": "宿舍电费查询接口、缴费系统跳转授权。",
            "features": ["剩余电量", "欠费金额", "历史读表", "缴费入口"],
            "dataFields": ["抓取日期", "剩余电量", "欠费金额", "电费账号"],
            "emptyText": "当前没有电费数据。",
            "actions": [{"label": "打开缴费系统", "type": "external", "url": payment_url}],
        },
        {
            "name": "宿舍水机",
            "slug": "dorm-water",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "water",
            "iconKey": "drop",
            "authType": "phoneSms",
            "status": "打开官方入口",
            "summary": "通过手机号和短信验证码登录水机服务，管理设备并开始/结束接水。",
            "requiredAccess": "宿舍水机服务 API、短信验证码、设备二维码。",
            "features": ["手机号登录", "设备列表", "扫码添加设备", "开始/结束接水"],
            "dataFields": ["手机号", "设备 ID", "设备名称", "接水状态", "Token"],
            "emptyText": "当前没有宿舍水机数据。",
            "actions": [{"label": "打开订水系统", "type": "external", "url": "https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1"}],
        },
        {
            "name": "图书馆",
            "slug": "library",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "library",
            "iconKey": "book",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "查看个人借阅、续借、馆藏搜索和南北校区在馆/空位情况。",
            "requiredAccess": "图书馆统一认证、借阅接口、馆藏检索与座位数据。",
            "features": ["借阅列表", "续借", "馆藏搜索", "图书馆容量"],
            "dataFields": ["书名", "作者", "ISBN", "借阅日期", "应还日期", "可否续借", "空位数"],
            "mapIds": ["map-main"],
            "emptyText": "当前没有图书馆数据。",
            "actions": [{"label": "打开图书馆", "type": "external", "url": "https://lib.xidian.edu.cn"}],
        },
        {
            "name": "校园卡",
            "slug": "school-card",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "card",
            "iconKey": "card",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "查看校园卡余额、消费流水，并预留付款码能力。",
            "requiredAccess": "校园卡接口、统一认证、二维码付款码授权。",
            "features": ["余额", "消费流水", "日期范围筛选", "付款码"],
            "dataFields": ["交易时间", "商户名称", "收入", "支出", "余额"],
            "emptyText": "当前没有校园卡数据。",
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
        {
            "name": "校园网",
            "slug": "schoolnet",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "network",
            "iconKey": "wifi",
            "authType": "schoolnetPassword",
            "status": "已接入入口",
            "summary": "查询校园网套餐、余额、已用流量、剩余流量和在线设备。",
            "requiredAccess": "校园网账号密码、验证码识别或手动验证码。",
            "features": ["当前账号", "在线设备", "已用流量", "余额", "当前网络信息"],
            "dataFields": ["账号", "套餐", "余额", "已用流量", "剩余流量", "在线 IP"],
            "emptyText": "当前没有校园网数据。",
            "actions": [{"label": "打开校园网自服务", "type": "external", "url": "https://zfw.xidian.edu.cn"}],
        },
        {
            "name": "校园地图",
            "slug": "map",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "map",
            "iconKey": "map",
            "authType": "public",
            "status": "已接入官方导航",
            "summary": "直接打开西电官方 GIS 导航系统，并保留南校区常用地点索引。",
            "requiredAccess": "官方 GIS 导航系统业务域名授权。",
            "features": ["官方 GIS 地图", "南校区导航", "常用地点索引"],
            "dataFields": ["地点名称", "分类", "校区", "位置说明"],
            "mapIds": ["map-main"],
            "actions": [{"label": "打开学校导航系统", "type": "external", "url": gis_url}],
        },
        {
            "name": "楼宇结构图",
            "slug": "building-map",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "map",
            "iconKey": "building",
            "authType": "public",
            "status": "可查看索引",
            "summary": "用于展示楼层、教室、办公室和功能空间分布。",
            "requiredAccess": "楼宇结构图、房间与部门定位数据。",
            "features": ["教学楼索引", "办公室定位", "功能空间查询"],
            "dataFields": ["楼宇", "楼层", "房间", "部门", "用途"],
            "mapIds": ["map-building"],
            "actions": [{"label": "查看楼宇索引", "type": "map"}],
        },
        {
            "name": "校园功能空间定位",
            "slug": "places",
            "groupId": "life",
            "groupName": "校园生活",
            "kind": "map",
            "iconKey": "pin",
            "authType": "public",
            "status": "可查看索引",
            "summary": "快速定位图书馆、食堂、办事大厅、打印点、体育场馆等校园空间。",
            "requiredAccess": "校园 POI 数据与服务分类。",
            "features": ["服务点分类", "位置索引", "地图跳转"],
            "dataFields": ["服务点", "分类", "校区", "位置"],
            "mapIds": ["map-main"],
            "actions": [{"label": "打开学校导航系统", "type": "external", "url": gis_url}],
        },
        {
            "name": "学期与住宿信息",
            "slug": "student-info",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "profile",
            "iconKey": "person",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "读取当前学期、学生基础信息和住宿地址，为课表、电费等服务提供基础资料。",
            "requiredAccess": "一站式个人信息接口、研究生/本科生学期接口。",
            "features": ["当前学期", "住宿地址", "学号绑定", "基础资料"],
            "dataFields": ["学号", "当前学期", "住宿地址", "学院", "专业"],
            "emptyText": "当前没有个人信息。",
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
        {
            "name": "缴费系统",
            "slug": "payment",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "payment",
            "iconKey": "pay",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校缴费系统，处理电费等校园缴费事项。",
            "requiredAccess": "缴费系统业务域名授权。",
            "features": ["电费缴费", "缴费记录", "欠费处理"],
            "dataFields": ["缴费项目", "金额", "状态", "时间"],
            "actions": [{"label": "打开缴费系统", "type": "external", "url": payment_url}],
        },
        {
            "name": "订水系统",
            "slug": "drinking-water",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "water",
            "iconKey": "drop",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校订水系统。",
            "requiredAccess": "订水系统业务域名授权。",
            "features": ["订水入口", "订单查看", "配送信息"],
            "dataFields": ["订单", "地址", "状态", "联系方式"],
            "actions": [{"label": "打开订水系统", "type": "external", "url": "https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1"}],
        },
        {
            "name": "后勤报修",
            "slug": "repair",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "repair",
            "iconKey": "tool",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校后勤报修系统，提交宿舍、楼宇、网络等维修事项。",
            "requiredAccess": "报修系统统一认证跳转授权。",
            "features": ["报修提交", "维修进度", "历史记录"],
            "dataFields": ["报修类型", "地点", "描述", "状态", "处理结果"],
            "actions": [{"label": "打开后勤报修", "type": "external", "url": repair_url}],
        },
        {
            "name": "空间预约",
            "slug": "space-reservation",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "reservation",
            "iconKey": "building",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入空间预约系统，预约图书馆或校内可用空间。",
            "requiredAccess": "空间预约业务域名授权。",
            "features": ["空间查询", "预约时段", "预约记录"],
            "dataFields": ["空间名称", "可预约时间", "预约人", "状态"],
            "actions": [{"label": "打开空间预约", "type": "external", "url": "http://libspace.xidian.edu.cn"}],
        },
        {
            "name": "请销假系统",
            "slug": "leave",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "leave",
            "iconKey": "check",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校请销假事项入口。",
            "requiredAccess": "学校服务大厅业务域名授权。",
            "features": ["请假申请", "销假", "审批进度"],
            "dataFields": ["申请类型", "时间", "审批状态", "处理人"],
            "actions": [{"label": "打开请销假系统", "type": "external", "url": "https://service.xidian.edu.cn/v2/matter/m_start?id=189"}],
        },
        {
            "name": "双创竞赛",
            "slug": "creative",
            "groupId": "affairs",
            "groupName": "校务办理",
            "kind": "competition",
            "iconKey": "star",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "查询创新创业竞赛项目、岗位或报名相关信息。",
            "requiredAccess": "双创平台统一认证和查询接口。",
            "features": ["项目查询", "竞赛岗位", "报名信息"],
            "dataFields": ["项目名称", "主办方", "报名时间", "状态"],
            "emptyText": "当前没有双创竞赛数据。",
            "actions": [{"label": "打开双创平台", "type": "external", "url": "https://scjspt.xidian.edu.cn"}],
        },
        {
            "name": "物理计算",
            "slug": "physics-helper",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "tool",
            "iconKey": "calculator",
            "authType": "public",
            "status": "已接入入口",
            "summary": "打开物理实验计算辅助工具。",
            "requiredAccess": "目标工具业务域名授权。",
            "features": ["物理实验计算", "数据处理辅助"],
            "dataFields": ["实验数据", "计算结果"],
            "actions": [{"label": "打开物理计算", "type": "external", "url": "https://experiment-helper.wizzstudio.com/#/"}],
        },
        {
            "name": "移动门户跳转",
            "slug": "mobile-portal",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "phone",
            "authType": "ids",
            "status": "可跳转",
            "summary": "打开西电移动门户，继续办理学校已有线上事项。",
            "requiredAccess": "学校移动门户开放跳转或小程序业务域名授权。",
            "features": ["移动门户", "校内事项入口"],
            "dataFields": ["事项名称", "跳转链接"],
            "actions": [{"label": "打开移动门户", "type": "external", "url": mobile_portal_url}],
        },
        {
            "name": "体育场馆预约",
            "slug": "venue-reservation",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "activity",
            "authType": "ids",
            "status": "打开官方入口",
            "summary": "预约体育场馆、查看可预约时段和预约记录。",
            "requiredAccess": "体育场馆预约系统跳转授权。",
            "features": ["场馆预约", "时段查询", "预约记录"],
            "dataFields": ["场馆", "时间", "状态"],
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
        {
            "name": "学校企业微信",
            "slug": "wecom",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "phone",
            "authType": "external",
            "status": "打开官方入口",
            "summary": "进入学校企业微信相关服务。",
            "requiredAccess": "企业微信应用跳转配置或官方链接。",
            "features": ["企业微信服务"],
            "dataFields": ["应用 appId", "跳转路径"],
            "actions": [{"label": "打开移动门户", "type": "external", "url": mobile_portal_url}],
        },
        {
            "name": "学校小程序",
            "slug": "official-miniprogram",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "phone",
            "authType": "external",
            "status": "打开官方入口",
            "summary": "跳转到学校官方小程序或对应服务页面。",
            "requiredAccess": "目标小程序 appId 与跳转路径配置。",
            "features": ["官方小程序跳转"],
            "dataFields": ["目标 appId", "目标页面路径"],
            "actions": [{"label": "打开移动门户", "type": "external", "url": mobile_portal_url}],
        },
        {
            "name": "其他校内服务入口",
            "slug": "service-hall",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "grid",
            "authType": "ids",
            "status": "可扩展",
            "summary": "进入校园服务大厅，办理更多校内事项。",
            "requiredAccess": "服务名称、官方链接、业务域名授权。",
            "features": ["校园服务大厅", "后台可配置入口"],
            "dataFields": ["服务名称", "官方链接", "跳转方式"],
            "actions": [{"label": "打开校园服务大厅", "type": "external", "url": "https://service.xidian.edu.cn"}],
        },
        {
            "name": "校外访问",
            "slug": "remote-access",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "network",
            "iconKey": "wifi",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校校外远程访问服务，用于在校外访问校园网资源。",
            "requiredAccess": "一网通办零信任/堡垒机账号申请或学校远程访问账号。",
            "features": ["校外访问", "零信任申请", "堡垒机账号", "校园网资源"],
            "dataFields": ["账号", "申请状态", "回执", "使用手册"],
            "actions": [{"label": "打开校外访问", "type": "external", "url": remote_access_url}],
        },
        {
            "name": "自助打印",
            "slug": "self-print",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "print",
            "iconKey": "print",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "查看自助打印和校务行服务，办理成绩单、证明材料等打印事项。",
            "requiredAccess": "一网通办自助打印及校务行接入申请。",
            "features": ["证明打印", "表单上线", "数据来源选择", "设备打印"],
            "dataFields": ["表单名称", "数据来源", "审批状态", "设备位置"],
            "actions": [{"label": "打开自助打印", "type": "external", "url": print_service_url}],
        },
        {
            "name": "校园邮箱",
            "slug": "campus-email",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "email",
            "iconKey": "mail",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校邮箱服务入口，处理学生邮件和邮件安全相关问题。",
            "requiredAccess": "学生邮箱账号或统一认证相关账号。",
            "features": ["学生邮件", "密码安全", "邮件异常处理", "邮箱入口"],
            "dataFields": ["邮箱账号", "绑定状态", "安全提醒"],
            "actions": [{"label": "打开邮箱服务", "type": "external", "url": email_service_url}],
        },
        {
            "name": "正版软件",
            "slug": "genuine-software",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "software",
            "iconKey": "download",
            "authType": "ids",
            "status": "已接入入口",
            "summary": "进入学校正版化软件服务，查看可用软件和申请流程。",
            "requiredAccess": "统一认证账号和软件使用资格。",
            "features": ["正版软件下载", "软件申请", "授权信息"],
            "dataFields": ["软件名称", "授权范围", "下载地址"],
            "actions": [{"label": "打开正版软件平台", "type": "external", "url": software_service_url}],
        },
        {
            "name": "社团推荐",
            "slug": "club-suggestion",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "club",
            "iconKey": "star",
            "authType": "public",
            "status": "已接入站内",
            "summary": "参考 PDA 的社团推荐入口，跳转到小程序已有社团功能，用于浏览社团、查看详情和提交申请。",
            "requiredAccess": "站内社团数据。",
            "features": ["社团浏览", "社团详情", "申请加入", "社团分区"],
            "dataFields": ["社团名称", "类别", "简介", "负责人", "申请状态"],
            "actions": [{"label": "打开社团", "type": "page", "path": "/pages/clubs/index"}],
        },
        {
            "name": "日程提醒",
            "slug": "schedule-reminder",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "schedule",
            "iconKey": "calendar",
            "authType": "ids",
            "status": "日历视图",
            "summary": "参考 PDA 的课表/考试/实验提醒与系统日历同步能力，先在小程序聚合展示今日与周历数据。",
            "requiredAccess": "一站式课表、考试和实验安排数据。",
            "features": ["今日提醒", "周历查看", "考试提醒", "实验提醒"],
            "dataFields": ["日程类型", "日期", "时间", "地点"],
            "calendarSource": "all",
            "emptyText": "当前没有可提醒的日程数据。",
            "actions": [{"label": "查看周历", "type": "calendar"}],
        },
    ]
    services: list[dict[str, Any]] = []
    for order, spec in enumerate(service_specs, start=1):
        services.append({
            "id": f"svc-{spec.get('slug') or order}",
            "name": spec["name"],
            "slug": spec.get("slug", ""),
            "groupId": spec["groupId"],
            "groupName": spec["groupName"],
            "kind": spec["kind"],
            "iconKey": spec.get("iconKey", "service"),
            "authType": spec.get("authType", ""),
            "status": spec["status"],
            "description": spec["summary"],
            "requiredAccess": spec["requiredAccess"],
            "features": spec.get("features", []),
            "dataFields": spec.get("dataFields", []),
            "calendarSource": spec.get("calendarSource", ""),
            "emptyText": spec.get("emptyText", ""),
            "mapIds": spec.get("mapIds", []),
            "actions": spec["actions"],
            "path": "/pages/campus/service-detail/index",
            "enabled": True,
            "sortOrder": order,
            "createdAt": created,
            "updatedAt": created,
        })
    maps = [
        {
            "id": "map-main",
            "name": "南校区常用地点",
            "type": "map",
            "status": "已接入官方导航",
            "description": "图书馆、教学楼、食堂、体育馆等南校区常用地点索引。",
            "officialUrl": gis_url,
            "items": [
                {"name": "图书馆", "category": "学习", "campus": "南校区", "location": "G6 北侧、Sq2 西侧", "x": 42, "y": 47},
                {"name": "A/B/C/D/E/F/G 教学楼", "category": "教学", "campus": "南校区", "location": "中部巨构教学区", "x": 55, "y": 39},
                {"name": "海棠餐厅", "category": "生活", "campus": "南校区", "location": "海棠学生公寓区", "x": 31, "y": 16},
                {"name": "竹园餐厅", "category": "生活", "campus": "南校区", "location": "竹园学生公寓区", "x": 67, "y": 17},
                {"name": "丁香餐厅", "category": "生活", "campus": "南校区", "location": "丁香学生公寓区", "x": 28, "y": 64},
                {"name": "北操场", "category": "运动", "campus": "南校区", "location": "西北角 S1", "x": 12, "y": 20},
                {"name": "南操场", "category": "运动", "campus": "南校区", "location": "西南侧 S2", "x": 12, "y": 55},
                {"name": "办公楼", "category": "行政", "campus": "南校区", "location": "东南侧 4/5 号楼", "x": 76, "y": 50},
                {"name": "校医院", "category": "医疗", "campus": "南校区", "location": "东北门附近", "x": 87, "y": 14},
                {"name": "礼仪广场", "category": "广场", "campus": "南校区", "location": "Sq1", "x": 51, "y": 28},
                {"name": "中心广场", "category": "广场", "campus": "南校区", "location": "Sq2", "x": 52, "y": 47},
            ],
            "createdAt": created,
        },
        {
            "id": "map-building",
            "name": "楼宇结构图",
            "type": "building",
            "status": "可查看索引",
            "description": "楼层、教室、办公室与功能空间的结构化索引。",
            "items": [
                {"name": "A 楼", "category": "巨构", "campus": "南校区", "location": "教学区西侧", "x": 27, "y": 37},
                {"name": "B 楼", "category": "巨构", "campus": "南校区", "location": "教学区西南侧", "x": 36, "y": 41},
                {"name": "C 楼", "category": "巨构", "campus": "南校区", "location": "教学区中部", "x": 43, "y": 37},
                {"name": "D 楼", "category": "巨构", "campus": "南校区", "location": "教学区中部偏东", "x": 52, "y": 36},
                {"name": "E 楼", "category": "巨构", "campus": "南校区", "location": "教学区东南侧", "x": 61, "y": 39},
                {"name": "F 楼", "category": "巨构", "campus": "南校区", "location": "教学区东侧", "x": 63, "y": 36},
                {"name": "G 楼", "category": "巨构", "campus": "南校区", "location": "教学区东端", "x": 77, "y": 36},
            ],
            "createdAt": created,
        },
    ]
    return services, maps


def _default_xidian_knowledge(created: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    sources = [
        {
            "id": "ks-campus",
            "name": "校园基础知识",
            "sourceType": "campus",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "createdAt": created,
        },
        {
            "id": "ks-announcements",
            "name": "公告聚合",
            "sourceType": "announcement",
            "sourceUrl": "",
            "createdAt": created,
        },
        {
            "id": "ks-posts",
            "name": "树洞公开帖子",
            "sourceType": "post",
            "sourceUrl": "",
            "createdAt": created,
        },
        {
            "id": "ks-xidian-services",
            "name": "西电官方学生服务指南",
            "sourceType": "official_xidian",
            "sourceUrl": "https://service.xidian.edu.cn/",
            "createdAt": created,
        },
        {
            "id": "ks-xidian-student-guide-2026",
            "name": "西电学生经验手册（2026）",
            "sourceType": "student_reference",
            "sourceUrl": "",
            "authority": "community",
            "createdAt": created,
        },
    ]
    guide_chunks = [
        {
            "id": "kc-xidian-ids",
            "title": "西电统一身份认证与一站式服务",
            "sourceUrl": "https://ids.xidian.edu.cn/authserver/login",
            "content": (
                "西电统一身份认证 IDS 是进入一站式大厅、教务、缴费、后勤报修、请销假等校内系统的主要入口。"
                "学生通常使用学号和统一认证密码登录。校园服务登录信息仅用于发起对应学校系统请求。"
                "常见入口包括一站式大厅 https://ehall.xidian.edu.cn/new/index.html 和服务大厅 https://service.xidian.edu.cn/。"
            ),
        },
        {
            "id": "kc-xidian-study",
            "title": "课表、成绩、考试、空闲教室与考勤",
            "sourceUrl": "https://ehall.xidian.edu.cn/new/index.html",
            "content": (
                "学习事务主要通过一站式/教务相关服务查询：课表按周和日期查看课程时间、地点、教师和节次；"
                "成绩单关注学年学期、课程名、学分、课程性质、成绩、等级和是否通过；考试安排关注考试类型、时间、地点和座位；"
                "空闲教室按校区、楼宇、日期和节次筛选；考勤可查看课程签到、异常次数、任务点和作业进度。"
            ),
        },
        {
            "id": "kc-xidian-experiment",
            "title": "物理实验与其他实验系统",
            "sourceUrl": "http://wlsy.xidian.edu.cn/PhyEws/default.aspx",
            "content": (
                "物理实验系统常用独立账号密码登录，关注实验名称、开始/结束时间、地点、负责老师、座位号和实验成绩。"
                "其他实验可从一站式或实验教学入口进入。做实验前应确认实验时间、地点、分组、座位以及是否需要预习报告或课前签到。"
            ),
        },
        {
            "id": "kc-xidian-sport",
            "title": "体育课程、体测与乐跑记录",
            "sourceUrl": "http://tybjxgl.xidian.edu.cn/app/",
            "content": (
                "体育系统用于查询体育课、体测成绩和运动记录。体测通常包含总分、等级和分项成绩；体育课程关注学期、课程、教师、上课时间和课程成绩。"
                "乐跑计数可作为体育系统关联信息展示，体育课程与体测结果以体育教学系统数据为准。"
            ),
        },
        {
            "id": "kc-xidian-energy",
            "title": "宿舍电费、水电缴费与宿舍水机",
            "sourceUrl": "https://xxcapp.xidian.edu.cn/uc/api/oauth/index?redirect=https://ignypt.xidian.edu.cn/revenueH5/login?opcode=MPAY&appid=200260318155520600&state=1231231231",
            "content": (
                "宿舍电费和水电缴费可通过学校缴费入口进入，查询时通常需要确认宿舍或缴费账号、剩余电量、欠费金额和缴费记录。"
                "宿舍水机服务使用手机号、图形验证码和短信验证码登录，关注设备列表、设备二维码、开始/结束接水和接水状态。"
                "订水入口为 https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1。学生经验中还提到，纸质水票可能已停用，"
                "桶装水、公共热水机和教学楼/图书馆供水的具体渠道与时间以西电后勤当年通知和现场标识为准。水电费也可能通过学校移动门户或南校区一站式服务中心办理。"
            ),
        },
        {
            "id": "kc-xidian-network",
            "title": "校园网自服务",
            "sourceUrl": "https://zfw.xidian.edu.cn",
            "content": (
                "校园网自服务用于查询账号套餐、余额、已用流量、剩余流量、在线 IP 和当前网络信息。"
                "登录一般需要学号/校园网账号、查询密码和图形验证码。信息网络技术中心学生服务目录还包括网络接入、一网通办、统一认证、一卡通、校外访问和邮件等服务。"
            ),
        },
        {
            "id": "kc-xidian-xxzx-services",
            "title": "信息网络技术中心学生服务目录",
            "sourceUrl": "https://xxzx.xidian.edu.cn/f_w/ssfw/xwycfwfw.htm",
            "content": (
                "西电信息网络技术中心面向学生提供网络接入、校园一卡通、一网通办、统一身份认证、邮箱、自助打印、正版软件、校外访问等服务。"
                "校外访问常见流程包括进入一网通办服务大厅、搜索零信任账号申请或堡垒机账号申请、填写申请表并等待回执。"
                "自助打印相关服务可用于材料打印、表单上线和校务行接入；正版软件平台用于查看学校授权软件。"
            ),
        },
        {
            "id": "kc-xidian-library",
            "title": "图书馆借阅、馆藏检索与空间预约",
            "sourceUrl": "https://lib.xidian.edu.cn",
            "content": (
                "图书馆服务包括馆藏检索、个人借阅、续借、到期提醒、馆藏位置和座位/空间预约。"
                "借阅信息通常包含书名、作者、ISBN、借阅日期、应还日期和是否可续借；空间预约入口可使用 http://libspace.xidian.edu.cn。"
            ),
        },
        {
            "id": "kc-xidian-card",
            "title": "校园卡与消费流水",
            "sourceUrl": "https://v8scan.xidian.edu.cn/home/openXDOAuth2Page",
            "content": (
                "校园卡服务关注余额、消费流水、充值记录和付款码能力。消费流水常用字段包括交易时间、商户、收入、支出和余额。"
                "涉及付款码或资金信息时应以学校官方页面为准，应用侧只展示必要信息并减少敏感数据留存。"
            ),
        },
        {
            "id": "kc-xidian-map",
            "title": "校园地图与南校区导航",
            "sourceUrl": "https://gis.xidian.edu.cn/#/home?campus=21047",
            "content": (
                "校园地图使用西电官方 GIS 导航系统。南校区常用地点包括图书馆、A/B/C/D/E/F/G 教学楼、海棠餐厅、竹园餐厅、丁香餐厅、"
                "北操场、南操场、办公楼、校医院、礼仪广场和中心广场。需要路线规划时优先打开官方 GIS。"
            ),
        },
        {
            "id": "kc-xidian-affairs",
            "title": "请销假、后勤报修、缴费、空间预约和双创竞赛",
            "sourceUrl": "https://service.xidian.edu.cn/",
            "content": (
                "常见校务办理包括请销假、后勤报修、缴费、空间预约和双创竞赛。请销假入口可从服务大厅事项进入；"
                "后勤报修用于宿舍、楼宇、网络等维修事项；缴费系统处理电费等缴费；空间预约用于图书馆或校内空间预约；"
                "双创竞赛平台用于查看项目、岗位、报名时间和状态。学校企业号、移动门户和学院/书院通知渠道可能提供消息、教务、客服、校园新闻、邮箱等服务；"
                "具体功能以当年官方通知为准。遇到缴费、招生、社团招新或账号异常要求，应通过官网、辅导员或官方客服核验，不要向陌生账号转账或提交敏感信息。"
            ),
        },
        {
            "id": "kc-xidian-ai-usage",
            "title": "AI 问答如何回答西电服务问题",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "回答西电服务问题时，应优先给出校内官方入口、需要准备的账号或材料、操作路径和注意事项；"
                "涉及成绩、考勤、缴费、校园卡、宿舍水机、校园网等个人数据时，提示用户只在官方系统或小程序真实登录页输入凭据，"
                "不要在普通聊天内容中发送密码、验证码、付款码或完整个人敏感信息。"
            ),
        },
        {
            "id": "kc-xidian-living-expenses",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电学生月度生活费参考",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "生活费是学生个人消费的经验性估算，不是西电统一收费标准，实际金额会因校区、消费习惯和住宿情况变化。"
                "按在校生账单整理，食堂正常荤素搭配约 8-12 元/餐，每日三餐约 25-35 元，纯食堂每月约 750-1050 元；"
                "奶茶、外卖、夜宵和聚餐等弹性餐饮每月可另预留约 300-500 元。洗漱用品、洗衣、水果、零食和宿舍小物件约 100-300 元/月；"
                "校内通常步行或骑车，公交地铁价格较低，话费、网费和偶尔打车可按约 100-200 元/月估算，校园网是否另行收费以学校当前通知为准；"
                "社交娱乐支出弹性较大，图书馆、体育馆和自习室等校内资源通常可免费使用，学生证可能享受景区、影院和场馆优惠。"
                "综合估算可分为：节省型约 1000-1300 元/月，标准型约 1500-2000 元/月，舒适型约 2500-3500 元/月及以上。"
                "其中 1500 元左右通常可以覆盖较正常的校园生活，具体预算应以个人实际账单为准；家庭经济困难可关注学校勤工助学和助学金渠道。"
            ),
        },
        {
            "id": "kc-xidian-major-change",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电本科生调整专业信息参考",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "西电实行大类招生培养，学生可能通过不同阶段进行专业方向调整。按提供的校内介绍，常见机会包括：入校后参加教改班、卓越工程师班、"
                "图灵人工智能等试点班选拔；第二学期末参加大类分流；大类分流后第二学年结束再申请一次转专业。"
                "大类分流的具体专业和时间由学院安排。转专业通常需要满足目标学院的接收条件；提供信息中列出的参考条件包括专业必修课程平均学分绩排位在本专业年级前 5%、"
                "无补考和违纪处分记录、完成规定学分，并满足目标专业对数学基础、编程能力等背景要求。申请一般需要转专业申请书、个人发展规划和成绩单，"
                "还可能因专业名额、生师比等因素进行比例调节。对专业特长、原专业学习困难或健康原因等特殊情形，可能需要学院推荐和证明材料；"
                "国防生、定向生以及国家规定不能改变专业的学生不能申请。特殊类型招生考生是否可以申请应以当年招生和教务文件为准。"
                "以上为信息整理，具体机会、比例、成绩条件、时间和流程必须以西电教务处及所在学院发布的最新实施办法为准。"
            ),
        },
        {
            "id": "kc-xidian-freshman-registration",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电 2026 级新生报到时间与校区地址",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "按提供的西电迎新网信息，2026 年本科新生报到时间为 8 月 30 日（星期日）8:00-24:00；第二学士学位新生为 9 月 6 日（星期日）8:00-24:00；"
                "预科新生为 9 月 15 日（星期二）8:00-20:00。具体报到安排、材料和流程以西电迎新网当年通知为准。"
                "长安校区地址：陕西省西安市西沣路兴隆段 266 号；雁塔校区地址：陕西省西安市太白南路 2 号。"
            ),
        },
        {
            "id": "kc-xidian-freshman-transport",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电长安校区与雁塔校区新生到校交通参考",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "前往长安校区时，从西安站或西安北站可乘地铁 2 号线或 4 号线换乘 6 号线，在‘西电科大南校区·未来之瞳’站下车；"
                "从西安东站可乘地铁 5 号线换乘 6 号线到达。西安咸阳国际机场可乘机场巴士长安大学城线，"
                "再在西部大道与西沣路十字换乘 333 路公交到西安电子科技大学长安校区站，或在西港商务中心换乘地铁 6 号线。"
                "前往雁塔校区时，从西安站或西安北站可乘地铁 2 号线或 4 号线换乘 3 号线，在太白南路站下车；"
                "从西安站也可乘 608 路公交到西安电子科技大学站；从西安东站可乘地铁 5 号线换乘 6 号线到科技路 D 口，再乘 604 路公交。"
                "机场到雁塔校区可乘西高新商务快线至志诚丽柏酒店后步行。线路、站点和运营时间可能调整，出行前应以西安地铁、公交和学校迎新通知为准。"
            ),
        },
        {
            "id": "kc-xidian-campuses-dormitory",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电南北校区与住宿费参考",
            "sourceUrl": "https://xdyx.xidian.edu.cn/index.htm",
            "content": (
                "西安电子科技大学有南校区和北校区。南校区位于陕西省西安市西沣路兴隆段 266 号，东门位于西沣路；"
                "南校区宿舍区主要包括竹园、海棠、丁香公寓，提供的住宿费参考为每人每年 1200 元。"
                "北校区位于陕西省西安市太白南路 2 号，北门位于南二环路段西段，南门位于光华路；北校区宿舍分东、西区，"
                "提供的住宿费参考为每人每年 600-800 元。住宿房型、收费标准和具体安排可能按年级、身份及学校当年安排变化，"
                "应以学校财务、迎新网和住宿管理通知为准。学生经验中常见的宿舍生活配置包括空调、开水房、洗浴热水和公共洗衣设施；"
                "空调供电时段、热水供应和使用费用可能调整，以宿舍管理和后勤通知为准。"
            ),
        },
        {
            "id": "kc-xidian-dining-guide",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电南北校区食堂与就餐价格参考",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "西安电子科技大学南、北两个校区共有 5 个食堂、12 个餐厅，档口总数约 278 个，总就餐面积约 26320 平方米。"
                "南校区主要有海棠、丁香、竹园三大餐厅：海棠餐厅靠近海棠公寓和北操场，提供基本伙食和南北风味小吃；"
                "丁香餐厅靠近丁香公寓，一、二层提供日常餐饮，三层主要承担教工餐饮、校内接待及零星点餐；"
                "竹园餐厅靠近竹园公寓和信远楼，包含南北风味档口，竹三餐厅也提供民族风味餐饮。"
                "北校区主要有西区学生餐厅、东区餐厅和位于东区学生餐厅二层的西军电餐厅。西区学生餐厅提供早、中、晚餐及民族和南北风味；"
                "东区餐厅提供早餐、小吃、主食和快餐；西军电餐厅提供多种风味餐饮及团餐服务。"
                "提供的参考价格包括：海棠餐厅麻辣香锅约 17 元/500 克、韩式烧肉饭约 9.9-15 元、金汤肥牛面约 12 元；"
                "丁香餐厅新派干锅约 9-15 元、无骨烤鱼捞饭约 16 元、精品川菜约 10-15 元；"
                "北校区西区学生餐厅葱油拌面约 7 元、腊汁肉夹馍约 5 元、新疆牛肉板面约 15 元；"
                "东区餐厅提供约 1 元基础餐和约 8 元套餐，鸡蛋炒饼丝约 5 元；西军电餐厅兰州拉面约 8 元、土豆牛肉盖饭约 15 元、卤肉饭约 13 元。"
                "食堂价格和低价餐可能包含学校保障性补助，部分时段可能提供一元餐或困难帮扶；具体供应、资格和金额以西电后勤及学生工作通知为准。"
                "遇到食品、服务或支付问题，应通过餐厅现场公示的后勤投诉渠道反馈。上述数量、营业时间、档口和价格仅作就餐参考，可能随经营安排调整，以校内公告和现场信息为准。"
            ),
        },
        {
            "id": "kc-xidian-scholarships-aid",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电本科生奖学金与国家助学资助参考",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "国家奖学金面向西电全日制本科（含第二学士学位）中特别优秀的学生，提供信息中的奖励标准为每生每年 10000 元。"
                "基本条件包括具有中国国籍、遵守法律和校规、诚实守信、上一学年成绩优异且综合表现突出；通常要求本科二年级及以上，"
                "学习成绩和综合考评排名在专业前 10%，排名前 30%但其他方面特别突出的学生可按要求提交证明材料。"
                "国家励志奖学金面向全日制本科二年级及以上、品学兼优且经认定为家庭经济困难的学生，提供信息中的奖励标准为每生每学年 5000 元，"
                "通常要求学习成绩和综合测评在专业前 30%。"
                "国家助学金面向家庭经济困难的全日制本科在校学生，包含预科和第二学士学位学生；退役士兵学生全部享受本科生国家助学金，"
                "提供信息中的标准为每生每年 3300 元。普通学生资助档次和金额按教育部及学校当年政策执行。"
                "本科毕业生奖学金面向毕业学年全日制计划内应届本科毕业生，提供信息中的标准为特等奖 3000 元、一等奖 1500 元、二等奖 1000 元、三等奖 600 元，"
                "具体比例和申请条件以当年评选通知为准。校级奖学金包括校长奖、综合发展奖学金、单项奖学金和毕业生奖学金，金额、比例和 M2 等具体条件以学校当年文件为准。"
            ),
        },
        {
            "id": "kc-xidian-dormitory-facilities",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电学生宿舍设施与网上选房参考",
            "sourceUrl": "https://xdyx.xidian.edu.cn/index.htm",
            "content": (
                "南校区学生公寓主要分布在竹园、海棠、丁香三个区域，常见配置包括上床下桌、开水房、自助洗衣设施和洗浴热水。"
                "提供的信息中，南校区宿舍床铺参考尺寸为 1.9 米×0.9 米，生活热水通常在中午和晚间供应；空调使用可能采取宿舍集体申请和租赁方式，"
                "相关费用按学校和服务商协议执行。"
                "北校区学生公寓分布在东区、西区，硕士宿舍参考为四人间、博士宿舍参考为两人间，宿舍基本配备空调；"
                "部分宿舍配置上床下桌、无线网络、洗澡房、洗衣机、烘干机、洗鞋机及公共吹风机、挂烫机等，具体以实际楼栋为准。"
                "学校每年可能通过迎新网安排网上选房，入口为 https://xdyx.xidian.edu.cn/index.htm；选房时间、房型、床位和收费以当年迎新通知为准。"
            ),
        },
        {
            "id": "kc-xidian-academic-calendar-2026-2027",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电 2026—2027 学年校历",
            "sourceUrl": "https://www.xidian.edu.cn/",
            "content": (
                "西安电子科技大学 2026—2027 学年校历显示：第一学期为 2026 年 9 月 7 日至 2027 年 1 月 17 日，共 19 周；"
                "第二学期为 2027 年 2 月 22 日至 2027 年 6 月 27 日，共 18 周；国际创新实践周为 2027 年 6 月 28 日至 2027 年 7 月 18 日，共 3 周。"
                "寒假为 2027 年 1 月 18 日至 2027 年 2 月 21 日，共 5 周；暑假为 2027 年 7 月 19 日至 2027 年 9 月 5 日，共 7 周。"
                "校历图中标注的法定节假日及调休安排包括：2026 年中秋节 9 月 25 日，国庆节 10 月 1—3 日；"
                "2027 年元旦 1 月 1 日，春节 2 月 5—8 日，元宵节 2 月 20 日，清明节 4 月 5 日，劳动节 5 月 1—2 日，端午节 6 月 9 日。"
                "节假日具体放假、调休和课程安排以学校当年校历、教务处通知及国务院节假日安排为准。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-services",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电学生常用官方平台与服务入口参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册整理的常用平台包括：西安电子科技大学官方渠道用于学校通知；西电后勤用于食堂、设备、宿舍、报修和生活缴费；"
                "西电信息中心用于校园网、VPN 等网络服务；西电学工用于学生工作通知；西电体育用于体育课程；西电青年用于团委和素质拓展；"
                "西安电子科技大学图书馆用于入馆教育、馆藏和空间预约；西安电子科技大学医院用于体检和疫苗等服务；学院、书院及学院学工渠道用于本单位通知。"
                "企业号和移动门户可能提供消息通知、校园新闻、客服、教务、缴费、邮箱等服务，具体入口和功能以学校当年通知为准。"
                "西电一站式入口为 http://ehall.xidian.edu.cn/new/index.html；图书馆网站为 https://lib.xidian.edu.cn/；"
                "学在西电平台入口为 https://xdspoc.xidian.edu.cn/；正版软件平台入口为 https://gsoft.xidian.edu.cn/。"
                "非官方平台或第三方工具即使提供课表、成绩、电费、选课评价等便利，也不应作为唯一数据来源，使用前应核实权限、隐私和下载安全。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-security",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电新生缴费、账号与防诈骗提醒",
            "sourceUrl": "https://xdyx.xidian.edu.cn/index.htm",
            "content": (
                "新生与辅导员、学校联系时应优先使用学校指定平台，不要因招生群、社团群或陌生账号的身份自称而转账或提供敏感信息。"
                "学费、住宿费等费用应通过迎新网或学校指定的官方缴费入口办理；不要点击陌生人发送的缴费链接。"
                "校园网账号、统一认证、邮箱、校园卡和银行卡信息属于个人敏感信息，不应在群聊、普通聊天或非官方平台发送密码、验证码、付款码和完整证件信息。"
                "学校通知、招生信息、社团招新和所谓优惠活动中可能存在冒充、收集个人信息或诈骗行为，遇到异常要求应通过学校官网、辅导员或官方客服核实。"
                "床上用品等生活物品可按迎新网说明自主购买或选择学校提供的正规渠道，注意产品质量和价格，不要轻信夸张宣传。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-daily-life",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电宿舍空调、饮水、洗衣与水电生活参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册称宿舍普遍安装空调，使用时主要承担电费；具体供电时段、空调覆盖和收费以宿舍管理及后勤当年通知为准。"
                "宿舍内禁止使用热水壶等违章电器，饮水可使用楼道公共热水机、教学楼或图书馆的供水设施；教学楼和图书馆供水时间、冷热水设备以现场为准。"
                "纸质水票是否停用、桶装水购买和配送渠道以西电后勤当前通知为准，不要把经验稿中的品牌或入口当成唯一渠道。"
                "水电费可通过学校移动门户或一站式服务中心查询、充值；每层宿舍通常设有公共洗衣机，手册记录标准洗约 3 元/次，但价格可能调整。"
                "公共吹风机等设施是否免费以实际楼栋为准。南校区宿舍床铺参考尺寸为 1.9 米×0.9 米，身高较高的学生可在学校信息采集时如实填写，是否提供加长床以宿舍安排为准。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-transport-delivery",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电校内出行、地铁与快递参考",
            "sourceUrl": "",
            "content": (
                "校内出行可步行、骑自行车或使用共享单车；部分区域可能有校园接驳车，票价、路线和运营时间以现场公告为准。"
                "南校区附近可通过地铁 6 号线及公交前往市区，站点、线路和开通状态可能变化，出行前应查询西安地铁、公交和学校通知。"
                "快递通常集中到校内菜鸟驿站或快递服务中心，具体收货地址、取件位置、取件码和大件存放点以物流短信和驿站通知为准。"
                "部分校内配送服务可能按包裹大小收费，价格和是否提供服务以当前快递点规则为准；长时间不取件可能按驿站规定处理。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-dining-support",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电食堂补助、低价餐与后勤服务参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册介绍，西电食堂承担基本伙食保障，部分窗口可能提供低价套餐或一元餐，具体供应时段、菜品和价格以西电后勤当期通知为准。"
                "南校区综合楼可提供餐饮、药店、理发、文具、手机和洗衣等生活服务；具体商户和营业时间会变化。"
                "食堂窗口和后勤渠道通常设有投诉或意见反馈方式，遇到食品、服务或支付问题应保留凭证并通过现场公示的官方渠道反馈。"
                "对家庭经济困难学生，学校可能通过困难认定、助学金、勤工助学或食堂补助等方式提供帮助，申请条件和发放方式以学生工作处、学院和后勤通知为准。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-undergraduate-study",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电本科课程、绩点、综测与学习参考",
            "sourceUrl": "",
            "content": (
                "西电学生经验手册将 GPA 称为绩点，将课程成绩按学分加权得到均分；综测用于学生综合排名，通常包含德智体美劳等模块，M2 与课程、竞赛等学习表现有关。"
                "具体 GPA、均分、综测和加分规则应以学校当年本科生手册及学院文件为准，经验稿中的示例不能替代正式制度。"
                "课程总评由平时成绩、考试或作业等部分构成，考勤、考试资格、补考、重修和学分要求由课程大纲及教务规定确定。"
                "学生可通过一站式、教务系统或图书馆查询课表、成绩、考试和空闲教室；在空闲教室自习时应遵守楼宇和教室管理要求。"
                "高等数学、线性代数、大学物理、C 语言、英语、编程和离散数学等课程可能是部分工科学院低年级的重要基础，具体课程安排因学院和专业而异。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-competitions",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电学生竞赛与常用学习技能参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册列举的常见竞赛包括 ACM、数学建模、大学生电子设计、软件精英挑战、硬件类竞赛及其他学校或学院竞赛。"
                "竞赛是否计入综测、计入哪个模块、报名资格和时间以学校、学院及竞赛组委会当年通知为准。"
                "新生可根据专业学习 Word、PPT、Excel、编程和论文排版等通用技能，也可在合规平台练习编程题；第三方课程和平台仅作为学习资源，不代表学校官方推荐。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-preparatory",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电预科生活、课程与考试参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册记录的预科安排仅适合作为往年经验参考：预科宿舍、课程、老师和选课通常由学院统一安排，课程可能分为必修和选修；"
                "专业分流可能综合两学期必修课成绩、学分加权结果和学校规定的平时加分，并按省份或其他规则排序。"
                "预科学生的奖助学金、困难认定、竞赛、考试、早晚自习和入团等事项，均可能因年份、学院和政策变化而调整。"
                "预科是否参加开学考、四六级、期中考试、具体课程、分流规则和比赛资格，应以当年学院通知、学生手册和教务文件为准。"
            ),
        },
        {
            "id": "kc-xidian-student-guide-graduation",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电本科毕业条件与发展事项参考",
            "sourceUrl": "",
            "content": (
                "学生经验手册提醒，本科毕业除修满培养方案要求的课程和学分外，部分专业或年级还可能有英语等级、社会实践、实验实践能力等培养要求。"
                "是否必须通过英语四级、社会实践次数、实验实践能力测试和其他毕业条件，应以本人培养方案、学院通知和学校当年毕业审核文件为准。"
                "考研是全国硕士研究生统一招生考试，保研是推荐优秀应届本科毕业生免试攻读研究生；报名条件、专业课、推免名额和考核方式以目标学校及西电当年通知为准。"
                "入党、入团、学生组织和社团活动应遵守学校管理规定，具体流程、名额和时间以团委、学院或书院通知为准。"
            ),
        },
    ]
    # Merge overlapping student-guide notes into the canonical topic chunks so
    # retrieval returns one concise result per topic instead of near-duplicates.
    chunks_by_id = {str(item.get("id", "")): item for item in guide_chunks}
    chunks_by_id["kc-xidian-ids"]["content"] += (
        "学生经验还提到，学校企业号、移动门户和邮箱可能承载通知、客服、教务和生活服务；"
        "具体入口以学校当年通知为准。"
    )
    chunks_by_id["kc-xidian-dormitory-facilities"]["content"] += (
        "宿舍空调、饮水、洗衣和水电使用的具体时段、价格与设备，以宿舍管理和后勤通知为准。"
    )
    chunks_by_id["kc-xidian-campuses-dormitory"]["content"] += (
        "学生经验还记录，南校区宿舍常见上床下桌、开水房、洗浴热水和自助洗衣设施，参考床铺尺寸为 1.9 米×0.9 米；"
        "北校区部分宿舍有上床下桌、无线网、洗澡房、洗衣机、烘干机、洗鞋机及公共吹风机、挂烫机等。"
        "学校可能通过迎新网安排网上选房，房型、床位和具体设施以当年通知及实际楼栋为准。"
    )
    chunks_by_id["kc-xidian-dining-guide"]["content"] += (
        "学生经验还提到，部分窗口可能提供低价套餐或一元餐，食堂现场通常设有投诉或意见反馈渠道；"
        "具体供应、资格、金额和处理时限以西电后勤当期通知为准。"
    )
    chunks_by_id["kc-xidian-study"]["content"] += (
        "学生经验中将 GPA 称为绩点，将课程成绩按学分加权得到均分；综测通常包含德智体美劳模块，"
        "M2 可能与课程、竞赛等学习表现有关。具体 GPA、均分、综测、考勤、考试资格、补考、重修和毕业学分规则，"
        "以学校本科生手册、课程大纲和学院教务文件为准。"
    )
    chunks_by_id["kc-xidian-affairs"]["content"] += (
        "学生经验列举的常见竞赛包括 ACM、数学建模、电子设计、软件或硬件类竞赛；"
        "是否计入综测、报名资格和时间以学校、学院及竞赛组委会当年通知为准。"
    )
    drop_ids = {
        "kc-xidian-student-guide-services",
        "kc-xidian-student-guide-daily-life",
        "kc-xidian-student-guide-dining-support",
        "kc-xidian-student-guide-undergraduate-study",
        "kc-xidian-student-guide-competitions",
        "kc-xidian-dormitory-facilities",
    }
    guide_chunks = [item for item in guide_chunks if str(item.get("id", "")) not in drop_ids]
    for item in guide_chunks:
        if (
            item.get("sourceId") == "ks-xidian-student-guide-2026"
            and item.get("sourceUrl") == "https://www.xidian.edu.cn/"
        ):
            item["sourceUrl"] = ""
    document_content = "\n\n".join(
        f"{item['title']}\n来源：{item['sourceUrl']}\n{item['content']}"
        for item in guide_chunks
        if item.get("sourceId", "ks-xidian-services") == "ks-xidian-services"
    )
    student_document_content = "\n\n".join(
        f"{item['title']}\n{item['content']}"
        for item in guide_chunks
        if item.get("sourceId") == "ks-xidian-student-guide-2026"
    )
    documents = [
        {
            "id": "kd-xidian-services",
            "sourceId": "ks-xidian-services",
            "title": "西电官方学生服务指南浓缩版",
            "content": document_content,
            "sourceUrl": "https://service.xidian.edu.cn/",
            "createdAt": created,
        },
        {
            "id": "kd-xidian-student-guide-2026",
            "sourceId": "ks-xidian-student-guide-2026",
            "title": "西电学生经验手册（2026）整理版",
            "content": student_document_content,
            "sourceUrl": "",
            "createdAt": created,
        },
    ]
    chunks = [
        {
            "id": item["id"],
            "sourceId": item.get("sourceId", "ks-xidian-services"),
            "documentId": (
                "kd-xidian-student-guide-2026"
                if item.get("sourceId") == "ks-xidian-student-guide-2026"
                else "kd-xidian-services"
            ),
            "title": item["title"],
            "content": f"{item['content']} 来源：{item['sourceUrl']}",
            "sourceUrl": item["sourceUrl"],
            "createdAt": created,
        }
        for item in guide_chunks
    ]
    return sources, documents, chunks


def ensure_radio_schema(db: dict[str, Any]) -> bool:
    changed = False
    created = now_iso()
    for key in RADIO_STATE_KEYS:
        if key not in db or not isinstance(db.get(key), list):
            db[key] = []
            changed = True
    for key in [
        "section", "club", "clubApplication", "clubMember", "campusService",
        "campusMap", "hotTopic", "hotTopicSummary", "knowledgeSource",
        "knowledgeDocument", "knowledgeChunk", "aiConversation", "aiMessage",
        "aiCitation", "dailySummary", "moderationTask",
        "ragCrawlRun", "ragRetrievalLog",
    ]:
        if key not in db.setdefault("seq", {}):
            db["seq"][key] = 0
            changed = True
    # The RAG index moved into a process-level cache (see rag_service).  Any
    # copy left over in the state is dead weight that every load_db would have
    # to JSON-decode out of the settings blob — 4.3 MB at 1500 posts.
    if db.get("ragIndex"):
        db["ragIndex"] = {}
        changed = True
    elif not isinstance(db.get("ragIndex"), dict):
        db["ragIndex"] = {}
        changed = True
    default_sections = _default_sections(created)
    if not db.get("sections"):
        db["sections"] = default_sections
        changed = True
    else:
        # Matched on sectionId, the section's identity: matching on the name
        # re-added a default an admin had renamed, with a duplicate sectionId.
        existing_section_ids = {str(row.get("sectionId") or row.get("id") or "").strip() for row in db["sections"]}
        for section in default_sections:
            if str(section.get("sectionId", "")).strip() not in existing_section_ids:
                db["sections"].append(section)
                existing_section_ids.add(str(section.get("sectionId", "")).strip())
                changed = True
    default_services, default_maps = _default_campus_services(created)
    if not db.get("campusServices"):
        db["campusServices"] = default_services
        if not db.get("campusMaps"):
            db["campusMaps"] = default_maps
        changed = True
    else:
        default_by_name = {str(item.get("name", "")).strip(): item for item in default_services}
        seen_service_names = {
            str(item.get("name", "")).strip()
            for item in db.get("campusServices", [])
            if str(item.get("name", "")).strip()
        }
        for service in db.get("campusServices", []):
            default_service = default_by_name.get(str(service.get("name", "")).strip())
            if not default_service:
                continue
            for key in (
                "slug",
                "groupId",
                "groupName",
                "kind",
                "iconKey",
                "authType",
                "status",
                "description",
                "requiredAccess",
                "features",
                "dataFields",
                "calendarSource",
                "emptyText",
                "mapIds",
                "actions",
                "path",
                "enabled",
                "sortOrder",
            ):
                if service.get(key) != default_service.get(key):
                    service[key] = default_service.get(key)
                    changed = True
        for default_service in default_services:
            service_name = str(default_service.get("name", "")).strip()
            if service_name and service_name not in seen_service_names:
                db["campusServices"].append(default_service)
                seen_service_names.add(service_name)
                changed = True
        if not db.get("campusMaps"):
            db["campusMaps"] = default_maps
            changed = True
    if db.get("campusMaps"):
        default_maps_by_id = {str(item.get("id", "")).strip(): item for item in default_maps}
        seen_map_ids = {
            str(item.get("id", "")).strip()
            for item in db.get("campusMaps", [])
            if str(item.get("id", "")).strip()
        }
        for campus_map in db.get("campusMaps", []):
            default_map = default_maps_by_id.get(str(campus_map.get("id", "")).strip())
            if not default_map:
                continue
            for key in ("name", "type", "status", "description", "items", "officialUrl"):
                if campus_map.get(key) != default_map.get(key):
                    campus_map[key] = default_map.get(key)
                    changed = True
        for default_map in default_maps:
            map_id = str(default_map.get("id", "")).strip()
            if map_id and map_id not in seen_map_ids:
                db["campusMaps"].append(default_map)
                seen_map_ids.add(map_id)
                changed = True
    for key in ("courseSchedules", "examSchedules", "experimentSchedules"):
        if key not in db:
            db[key] = []
            changed = True
    default_sources, default_documents, default_chunks = _default_xidian_knowledge(created)
    merged_chunk_ids = {
        "kc-xidian-student-guide-services",
        "kc-xidian-student-guide-daily-life",
        "kc-xidian-student-guide-dining-support",
        "kc-xidian-student-guide-undergraduate-study",
        "kc-xidian-student-guide-competitions",
    }
    existing_chunk_rows = db.get("knowledgeChunks", [])
    filtered_chunk_rows = [
        row for row in existing_chunk_rows
        if str(row.get("id", "")).strip() not in merged_chunk_ids
    ]
    if len(filtered_chunk_rows) != len(existing_chunk_rows):
        db["knowledgeChunks"] = filtered_chunk_rows
        changed = True
    existing_sources = {
        str(item.get("id", "")).strip(): item
        for item in db.get("knowledgeSources", [])
        if str(item.get("id", "")).strip()
    }
    for source in default_sources:
        source_id = str(source.get("id", "")).strip()
        existing = existing_sources.get(source_id)
        if existing is None:
            db.setdefault("knowledgeSources", []).append(source)
            existing_sources[source_id] = source
            changed = True
            continue
        for key in ("name", "sourceType", "sourceUrl", "authority"):
            if existing.get(key) != source.get(key):
                existing[key] = source.get(key)
                changed = True
        if not existing.get("createdAt"):
            existing["createdAt"] = source.get("createdAt")
            changed = True

    existing_documents = {
        str(item.get("id", "")).strip(): item
        for item in db.get("knowledgeDocuments", [])
        if str(item.get("id", "")).strip()
    }
    for document in default_documents:
        document_id = str(document.get("id", "")).strip()
        existing = existing_documents.get(document_id)
        if existing is None:
            db.setdefault("knowledgeDocuments", []).append(document)
            existing_documents[document_id] = document
            changed = True
            continue
        for key in ("sourceId", "title", "content", "sourceUrl"):
            if existing.get(key) != document.get(key):
                existing[key] = document.get(key)
                changed = True
        if not existing.get("createdAt"):
            existing["createdAt"] = document.get("createdAt")
            changed = True

    existing_chunks = {
        str(item.get("id", "")).strip(): item
        for item in db.get("knowledgeChunks", [])
        if str(item.get("id", "")).strip()
    }
    for chunk in default_chunks:
        chunk_id = str(chunk.get("id", "")).strip()
        existing = existing_chunks.get(chunk_id)
        if existing is None:
            db.setdefault("knowledgeChunks", []).append(chunk)
            existing_chunks[chunk_id] = chunk
            changed = True
            continue
        for key in ("sourceId", "documentId", "title", "content", "sourceUrl"):
            if existing.get(key) != chunk.get(key):
                existing[key] = chunk.get(key)
                changed = True
        if not existing.get("createdAt"):
            existing["createdAt"] = chunk.get("createdAt")
            changed = True
    return changed


def default_db() -> dict[str, Any]:
    created = now_iso()
    db: dict[str, Any] = {
        "seq": {
            "user": 1,
            "adminAccount": 1,
            "post": 0,
            "comment": 0,
            "report": 0,
            "cancellation": 0,
            "conversation": 0,
            "notification": 0,
            "announcement": 0,
            "appeal": 0,
            "pinRequest": 0,
            "levelRequest": 0,
            "audit": 0,
            "upload": 0,
        },
        "users": [
            {
                "id": _globals.DEMO_USER_ID,
                "email": _globals.DEMO_USER_EMAIL,
                "password": hash_password(_globals.DEMO_USER_PASSWORD),
                "alias": "洞主-雾蓝",
                "nickname": "洞主-雾蓝",
                "studentId": "2023000001",
                "avatarUrl": "",
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": True,
                "showContactable": True,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyRepost": True,
                "notifyMention": True,
                "notifyReportResult": True,
                "notifySystem": True,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
            {
                "id": "seed-user-1",
                "email": "seed1@stu.xidian.edu.cn",
                "password": "",
                "alias": "洞主-极光",
                "nickname": "洞主-极光",
                "studentId": "2023000002",
                "avatarUrl": "",
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyRepost": True,
                "notifyMention": True,
                "notifyReportResult": True,
                "notifySystem": True,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
            {
                "id": "seed-user-2",
                "email": "seed2@stu.xidian.edu.cn",
                "password": "",
                "alias": "洞主-银杏",
                "nickname": "洞主-银杏",
                "studentId": "2023000003",
                "avatarUrl": "",
                "userLevel": _globals.USER_LEVEL_TWO,
                "verified": True,
                "verifiedAt": created,
                "allowStrangerDm": False,
                "showContactable": False,
                "notifyComment": True,
                "notifyReply": True,
                "notifyLike": True,
                "notifyFavorite": True,
                "notifyRepost": True,
                "notifyMention": True,
                "notifyReportResult": True,
                "notifySystem": True,
                "createdAt": created,
                "deleted": False,
                "isAdmin": False,
                "banned": False,
                "muted": False,
            },
        ],
        "sessions": {},
        "emailCodes": {},
        "tags": list(_globals.DEFAULT_TAGS),
        "sensitiveWords": list(_globals.DEFAULT_SENSITIVE_WORDS),
        "settings": {
            **dict(_globals.DEFAULT_SETTINGS),
            _globals.ADMIN_USERNAME_SETTING_KEY: _globals.DEFAULT_ADMIN_USERNAME,
            _globals.ADMIN_PASSWORD_HASH_SETTING_KEY: hash_password(_globals.DEFAULT_ADMIN_PASSWORD),
        },
        "adminAccounts": [
            build_admin_account(
                admin_id="adm1",
                username=_globals.DEFAULT_ADMIN_USERNAME,
                password_hash=hash_password(_globals.DEFAULT_ADMIN_PASSWORD),
                role=_globals.ADMIN_ROLE_PRIMARY,
                active=True,
                created_at=created,
                updated_at=created,
                created_by="system",
            )
        ],
        "posts": [],
        "comments": [],
        "likes": [],
        "favorites": [],
        "reposts": [],
        "reports": [],
        "userBlocks": [],
        "userFollows": [],
        "conversations": [],
        "directMessages": [],
        "feedbacks": [],
        "notifications": [],
        "appeals": [],
        "postPinRequests": [],
        "userLevelRequests": [],
        "auditLogs": [],
        "accountCancellationRequests": [],
        "mediaUploads": [],
        "postViews": [],
    }
    ensure_radio_schema(db)

    if not _globals.SEED_DEMO_DATA:
        db["users"] = []
        db["seq"]["user"] = 0
        return db

    for row in _globals.SEED_POSTS:
        db["seq"]["post"] += 1
        post_id = f"p{db['seq']['post']}"
        db["posts"].append(
            {
                "id": post_id,
                "title": row["title"],
                "content": row["content"],
                "contentFormat": str(row.get("contentFormat", "plain") or "plain"),
                "markdownSource": str(row.get("markdownSource", "") or ""),
                "tags": row["tags"],
                "hasImage": row["hasImage"],
                "status": row["status"],
                "allowComment": row["allowComment"],
                "allowDm": row["allowDm"],
                "visibility": str(row.get("visibility", "public") or "public"),
                "authorAlias": row["authorAlias"],
                "authorId": row["authorId"],
                "pinStartedAt": "",
                "pinExpiresAt": "",
                "pinDurationMinutes": 0,
                "createdAt": created,
                "updatedAt": created,
                "deleted": False,
                "reviewStatus": "approved",
                "riskMarked": False,
                "seedData": True,
                "sectionType": "general",
                "sectionId": "general",
                "sectionName": "综合",
                "publisherType": "user",
                "publisherClubId": "",
                "shareCount": 0,
            }
        )

    db["favorites"].append({"userId": "u1", "postId": "p1"})
    db["favorites"].append({"userId": "u1", "postId": "p2"})


    db["conversations"].append(
        {
            "id": "c1", "userId": "u1", "peerUserId": "seed-user-1",
            "name": "洞主-极光", "avatarUrl": "",
            "lastMessage": "谢谢，已经找到位置了。",
            "unreadCount": 0, "lastReadAt": created, "updatedAt": created, "deleted": False,
        }
    )
    db["seq"]["conversation"] = 1
    db["directMessages"].append(
        {
            "id": "m1", "conversationKey": "seed-user-1::u1",
            "senderUserId": "seed-user-1", "receiverUserId": "u1",
            "content": "谢谢，已经找到位置了。",
            "createdAt": created, "readAt": created, "deleted": False,
        }
    )
    db["seq"]["message"] = 1

    db["comments"].append(
        {
            "id": "cm1", "postId": "p1", "userId": "seed-user-2",
            "authorAlias": "匿名同学-1", "content": "教研楼三层东边插座比较多。",
            "createdAt": created, "deleted": False, "likeCount": 0,
            "reviewStatus": "approved", "riskMarked": False,
        }
    )
    db["comments"].append(
        {
            "id": "cm2", "postId": "p1", "userId": "seed-user-1",
            "authorAlias": "匿名同学-2", "content": "新图二层靠窗位置不错，但中午人多。",
            "createdAt": created, "deleted": False, "likeCount": 0,
            "reviewStatus": "approved", "riskMarked": False,
        }
    )
    db["seq"]["comment"] = 2

    db["reports"].append(
        {
            "id": "r1", "userId": "u1", "reporterAlias": "洞主-雾蓝",
            "targetType": "post", "targetId": "p2",
            "reason": "广告引流", "description": "疑似卖课引流",
            "status": "pending", "result": "", "createdAt": created,
            "handledAt": "", "handledBy": "",
        }
    )
    db["seq"]["report"] = 1

    return db


def ensure_db() -> None:
    _globals.SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    first_boot = not _globals.SQL_DB_FILE.exists()
    _globals.REPOSITORY.initialize(default_db)

    default_sql_path = (_globals.DATA_DIR / "treehole.db").resolve()
    current_sql_path = _globals.SQL_DB_FILE.resolve()
    import_legacy_json = os.environ.get("BACKEND_IMPORT_LEGACY_JSON", "").strip() == "1"

    if (
        first_boot
        and _globals.LEGACY_DB_FILE.exists()
        and (current_sql_path == default_sql_path or import_legacy_json)
    ):
        try:
            with _globals.LEGACY_DB_FILE.open("r", encoding="utf-8") as f:
                legacy_db = json.load(f)
            if isinstance(legacy_db, dict):
                migrate_db(legacy_db)
                _globals.REPOSITORY.save_state(legacy_db)
        except Exception:
            logger.exception("[db] Legacy JSON import failed")
            raise
    else:
        # Not first boot, but let's migrate any missing schema items/sequences
        try:
            db = _globals.REPOSITORY.load_state()
            if migrate_db(db):
                logger.info("[db] Migrating existing database schema and sequences...")
                _globals.REPOSITORY.save_state(db)
        except Exception as e:
            logger.error(f"[db] Migration check failed: {e}", exc_info=True)
            raise


def save_db(db: dict[str, Any]) -> None:
    _globals.SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    _globals.REPOSITORY.save_state(db)


def _run_once(db: dict[str, Any], name: str, migration: Callable[[dict[str, Any]], None]) -> bool:
    """Apply a data migration once, recorded in settings.dataMigrations.

    Migrations are also written to be harmless if run again, in case the
    marker is ever lost (settings being reset).
    """
    settings = db.setdefault("settings", {})
    done = settings.get("dataMigrations")
    if not isinstance(done, list):
        done = settings["dataMigrations"] = []
    if name in done:
        return False
    migration(db)
    done.append(name)
    return True


def _migrate_sections_to_section_id(db: dict[str, Any]) -> None:
    """One pass that leaves sectionId as the only way to name a section.

    - the retired 学校总分区 (sectionType "school") goes; its posts move to 综合;
    - a section without a sectionId gets its row id as one, which is what
      posts filed under it already store;
    - posts and clubs that stored a section's row id get its sectionId.
    """
    def is_school(row: dict[str, Any]) -> bool:
        return (
            str(row.get("sectionType", "")).strip().lower() == "school"
            or str(row.get("sectionName", "")).strip() == "学校总分区"
        )

    sections = [row for row in db.get("sections", []) if not is_school(row)]
    for row in sections:
        if not str(row.get("sectionId", "")).strip():
            row["sectionId"] = str(row.get("id", "")).strip()
    db["sections"] = sections
    section_ids = {str(row.get("sectionId", "")).strip() for row in sections}
    by_row_id = {
        str(row.get("id", "")).strip(): str(row.get("sectionId", "")).strip()
        for row in sections
        if str(row.get("id", "")).strip() and str(row.get("id", "")).strip() not in section_ids
    }
    for post in db.get("posts", []):
        if is_school(post) or not str(post.get("sectionType", "")).strip():
            post["sectionType"] = "general"
            post["sectionId"] = "general"
            post["sectionName"] = "综合"
            continue
        stored = str(post.get("sectionId", "")).strip()
        if stored in by_row_id:
            post["sectionId"] = by_row_id[stored]
    for club in db.get("clubs", []):
        stored = str(club.get("sectionId", "")).strip()
        if stored in by_row_id:
            club["sectionId"] = by_row_id[stored]


def migrate_db(db: dict[str, Any]) -> bool:
    changed = False
    if ensure_radio_schema(db):
        changed = True
    if _run_once(db, "2026-09-28-section-id", _migrate_sections_to_section_id):
        changed = True

    # Channels are retired (folded into tags by the repository).
    if "channels" in db:
        del db["channels"]
        changed = True

    # Seed the defaults once. Re-adding any missing on every load undid an
    # admin deleting or renaming a default tag.
    if not db.get("tags"):
        db["tags"] = list(_globals.DEFAULT_TAGS)
        changed = True
    if "sensitiveWords" not in db:
        db["sensitiveWords"] = list(_globals.DEFAULT_SENSITIVE_WORDS)
        changed = True
    if "settings" not in db or not isinstance(db["settings"], dict):
        db["settings"] = dict(_globals.DEFAULT_SETTINGS)
        changed = True
    for key, value in _globals.DEFAULT_SETTINGS.items():
        if key not in db["settings"]:
            db["settings"][key] = value
            changed = True
    if ensure_admin_auth_settings(db):
        changed = True
    if ensure_admin_accounts(db):
        changed = True

    if "auditLogs" not in db:
        db["auditLogs"] = []
    if "feedbacks" not in db or not isinstance(db.get("feedbacks"), list):
        db["feedbacks"] = []
        changed = True
    if "userFollows" not in db or not isinstance(db.get("userFollows"), list):
        db["userFollows"] = []
        changed = True
    else:
        normalized_follows: list[dict[str, Any]] = []
        seen_follows: set[tuple[str, str]] = set()
        for follow in db.get("userFollows", []):
            if not isinstance(follow, dict):
                changed = True
                continue
            follower_user_id = str(
                follow.get("followerUserId")
                or follow.get("followerId")
                or ""
            ).strip()
            followee_user_id = str(
                follow.get("followeeUserId")
                or follow.get("followeeId")
                or follow.get("followedId")
                or ""
            ).strip()
            if not follower_user_id or not followee_user_id or follower_user_id == followee_user_id:
                changed = True
                continue
            follow_key = (follower_user_id, followee_user_id)
            if follow_key in seen_follows:
                changed = True
                continue
            seen_follows.add(follow_key)
            normalized_follows.append(
                {
                    "followerUserId": follower_user_id,
                    "followeeUserId": followee_user_id,
                    "createdAt": str(follow.get("createdAt", "")).strip() or _globals.now_iso(),
                }
            )
        if normalized_follows != db.get("userFollows", []):
            db["userFollows"] = normalized_follows
            changed = True
    if "appeals" not in db or not isinstance(db.get("appeals"), list):
        db["appeals"] = []
        changed = True
    if "postPinRequests" not in db or not isinstance(db.get("postPinRequests"), list):
        db["postPinRequests"] = []
        changed = True
    if "userLevelRequests" not in db or not isinstance(db.get("userLevelRequests"), list):
        db["userLevelRequests"] = []
        changed = True
    if "accountCancellationRequests" not in db or not isinstance(
        db.get("accountCancellationRequests"), list
    ):
        db["accountCancellationRequests"] = []
        changed = True
    users_by_id = {
        str(user.get("id", "")).strip(): user
        for user in db.get("users", [])
        if str(user.get("id", "")).strip()
    }
    for appeal in db.get("appeals", []):
        user = users_by_id.get(str(appeal.get("userId", "")).strip())
        defaults = {
            "userEmail": str(
                appeal.get("email")
                or (user or {}).get("email", "")
            ).strip().lower(),
            "studentId": str((user or {}).get("studentId", "")).strip(),
            "userNickname": str(
                (user or {}).get("nickname")
                or (user or {}).get("alias", "")
            ).strip(),
            "targetType": "account",
            "targetId": str(appeal.get("userId", "")).strip(),
            "title": str(appeal.get("appealType", "other")).strip(),
            "adminNote": str(
                appeal.get("adminNote", appeal.get("result", ""))
            ).strip(),
        }
        for key, value in defaults.items():
            if not str(appeal.get(key, "")).strip() and value:
                appeal[key] = value
                changed = True
    for request in db.get("accountCancellationRequests", []):
        user = users_by_id.get(str(request.get("userId", "")).strip())
        defaults = {
            "userEmail": str(
                request.get("email")
                or (user or {}).get("email", "")
            ).strip().lower(),
            "studentId": str((user or {}).get("studentId", "")).strip(),
            "userNickname": str(
                (user or {}).get("nickname")
                or (user or {}).get("alias", "")
            ).strip(),
            "avatarUrl": str((user or {}).get("avatarUrl", "")).strip(),
            "reviewNote": str(
                request.get("reviewNote", request.get("result", ""))
            ).strip(),
        }
        for key, value in defaults.items():
            if not str(request.get(key, "")).strip() and value:
                request[key] = value
                changed = True
    if "mediaUploads" not in db:
        db["mediaUploads"] = []
        changed = True
    if "emailCodes" not in db or not isinstance(db.get("emailCodes"), dict):
        db["emailCodes"] = {}
        changed = True
    else:
        normalized_email_codes: dict[str, dict[str, Any]] = {}
        for raw_key, raw_record in db["emailCodes"].items():
            if not isinstance(raw_record, dict):
                changed = True
                continue
            raw_key_text = str(raw_key).strip()
            if raw_key_text.lower().startswith(_globals.PASSWORD_RESET_CODE_PREFIX):
                reset_email = _globals.normalize_auth_email(
                    raw_key_text[len(_globals.PASSWORD_RESET_CODE_PREFIX):],
                )
                key = f"{_globals.PASSWORD_RESET_CODE_PREFIX}{reset_email}"
            else:
                key = _globals.normalize_auth_email(raw_key_text)
            if not key:
                changed = True
                continue
            inferred_purpose = (
                "password_reset"
                if key.startswith(_globals.PASSWORD_RESET_CODE_PREFIX)
                else "email_verification"
            )
            try:
                attempts = max(0, int(raw_record.get("attempts", 0) or 0))
            except (TypeError, ValueError):
                attempts = 0
            normalized_record = {
                "code": str(raw_record.get("code", "")).strip(),
                "expiresAt": str(raw_record.get("expiresAt", "")).strip(),
                "createdAt": str(raw_record.get("createdAt", "")).strip(),
                "recordId": str(raw_record.get("recordId", "")).strip(),
                "purpose": inferred_purpose,
                "attempts": attempts,
                "usedAt": str(raw_record.get("usedAt", "")).strip(),
            }
            normalized_email_codes[key] = normalized_record
            if key != raw_key or normalized_record != raw_record:
                changed = True
        if normalized_email_codes != db["emailCodes"]:
            db["emailCodes"] = normalized_email_codes

    for feedback in db.get("feedbacks", []):
        if "category" not in feedback:
            feedback["category"] = "其他反馈"
            changed = True
        if "schoolReply" not in feedback:
            feedback["schoolReply"] = ""
            changed = True

    if "seq" not in db:
        db["seq"] = {}
        changed = True
    for key in [
        "user", "adminAccount", "post", "comment", "report",
        "cancellation", "conversation", "message",
        "notification", "announcement", "appeal", "pinRequest",
        "levelRequest", "audit", "upload",
    ]:
        if key not in db["seq"]:
            db["seq"][key] = 0
            changed = True

    for user in db.get("users", []):
        if "nickname" not in user or not str(user.get("nickname", "")).strip():
            user["nickname"] = sanitize_alias(str(user.get("alias", "")), fallback="匿名同学")
            changed = True
        if "alias" not in user or not str(user.get("alias", "")).strip():
            user["alias"] = sanitize_alias(str(user.get("nickname", "")), fallback="匿名同学")
            changed = True
        if "studentId" not in user or not str(user.get("studentId", "")).strip():
            user["studentId"] = student_id_from_email(str(user.get("email", "")))
            changed = True
        if "avatarUrl" not in user:
            user["avatarUrl"] = ""
            changed = True
        else:
            normalized_avatar = normalize_avatar_url(str(user.get("avatarUrl", "")))
            if normalized_avatar != str(user.get("avatarUrl", "")):
                user["avatarUrl"] = normalized_avatar
                changed = True
        if "major" not in user:
            user["major"] = ""
            changed = True
        # 学院 is derived from the identity mapping (verified_college); a
        # typed-in value from before is dropped.
        if "college" in user:
            del user["college"]
            changed = True
        for key in (
            "notifyComment",
            "notifyReply",
            "notifyLike",
            "notifyFavorite",
            "notifyRepost",
            "notifyMention",
            "notifyReportResult",
            "notifySystem",
        ):
            if key not in user:
                user[key] = True
                changed = True

    for post in db.get("posts", []):
        for k, v in {
            "pinStartedAt": "", "pinExpiresAt": "", "pinDurationMinutes": 0,
            "updatedAt": str(post.get("createdAt", now_iso())),
            "reviewStatus": "approved", "riskMarked": False,
            "deleted": False, "allowComment": True, "allowDm": True, "visibility": "public",
            "contentFormat": "plain", "markdownSource": "", "viewCount": 0,
        }.items():
            if k not in post:
                post[k] = v
                changed = True
        normalized_content_format = "markdown" if str(post.get("contentFormat", "plain")).strip().lower() == "markdown" else "plain"
        if normalized_content_format != str(post.get("contentFormat", "plain")):
            post["contentFormat"] = normalized_content_format
            changed = True
        if normalized_content_format != "markdown" and str(post.get("markdownSource", "")).strip():
            post["markdownSource"] = ""
            changed = True
        if normalized_content_format == "markdown" and not str(post.get("markdownSource", "")).strip():
            post["markdownSource"] = str(post.get("content", ""))
            changed = True
        normalized_visibility = "private" if str(post.get("visibility", "public")).strip().lower() == "private" else "public"
        if normalized_visibility != str(post.get("visibility", "public")):
            post["visibility"] = normalized_visibility
            changed = True
        if "isAnonymous" not in post:
            author_alias = str(post.get("authorAlias", "")).strip()
            author_id = str(post.get("authorId", "")).strip()
            if author_alias and author_id:
                post["isAnonymous"] = author_alias not in [
                    str(u.get("nickname", "")).strip()
                    for u in db.get("users", [])
                    if str(u.get("id", "")) == author_id
                ]
            else:
                post["isAnonymous"] = True
            changed = True
        for k, v in {
            "sectionType": "general",
            "sectionId": "general",
            "sectionName": "综合",
            "publisherType": "user",
            "publisherClubId": "",
            "shareCount": 0,
        }.items():
            if k not in post:
                post[k] = v
                changed = True
        if "channel" in post:
            del post["channel"]
            changed = True

    if _globals.SEED_DEMO_DATA:
        existing_seed_titles = {
            str(post.get("title", "")).strip()
            for post in db.get("posts", [])
            if str(post.get("title", "")).strip()
        }
        for row in _globals.SEED_POSTS[4:]:
            title = str(row.get("title", "")).strip()
            if not title or title in existing_seed_titles:
                continue
            db["seq"]["post"] = int(db["seq"].get("post", 0)) + 1
            created = now_iso()
            tags = list(dict.fromkeys(row.get("tags", [])))
            db.setdefault("posts", []).append({
                "id": f"p{db['seq']['post']}",
                "title": title,
                "content": str(row.get("content", "")),
                "contentFormat": "plain",
                "markdownSource": "",
                "tags": [tag for tag in tags if tag and tag != "综合"],
                "hasImage": bool(row.get("hasImage")),
                "status": str(row.get("status", "ongoing")),
                "allowComment": bool(row.get("allowComment", True)),
                "allowDm": bool(row.get("allowDm", False)),
                "visibility": "public",
                "authorAlias": str(row.get("authorAlias", "洞主-测试")),
                "authorId": str(row.get("authorId", "seed-user-1")),
                "pinStartedAt": "",
                "pinExpiresAt": "",
                "pinDurationMinutes": 0,
                "createdAt": created,
                "updatedAt": created,
                "deleted": False,
                "reviewStatus": "approved",
                "riskMarked": False,
                "seedData": True,
                "sectionType": "general",
                "sectionId": "general",
                "sectionName": "综合",
                "publisherType": "user",
                "publisherClubId": "",
                "shareCount": 0,
                "viewCount": 0,
            })
            existing_seed_titles.add(title)
            changed = True

    for comment in db.get("comments", []):
        for k, v in {
            "likeCount": 0, "authorAlias": "匿名同学",
            "deleted": False, "reviewStatus": "approved",
            "riskMarked": False, "isAnonymous": True,
        }.items():
            if k not in comment:
                comment[k] = v
                changed = True

    comments_by_id = {
        str(comment.get("id", "")).strip(): comment
        for comment in db.get("comments", [])
        if str(comment.get("id", "")).strip()
    }
    for comment in db.get("comments", []):
        parent_id = str(comment.get("parentId", "")).strip()
        if not parent_id:
            continue
        parent = comments_by_id.get(parent_id)
        if (
            parent is None
            or parent.get("deleted")
            or str(parent.get("postId", "")).strip()
            != str(comment.get("postId", "")).strip()
        ):
            comment["parentId"] = ""
            changed = True

    for notification in db.get("notifications", []):
        for k, v in {
            "relatedType": "", "relatedId": "", "actorId": "",
            "actorAlias": "", "deleted": False, "readAt": "",
        }.items():
            if k not in notification:
                notification[k] = v
                changed = True
    retained_notification_ids: set[str] = set()
    notification_users = {
        str(row.get("userId", "")).strip()
        for row in db.get("notifications", [])
        if str(row.get("userId", "")).strip()
    }
    for user_id in notification_users:
        rows = [
            row for row in db.get("notifications", [])
            if str(row.get("userId", "")).strip() == user_id
        ]
        rows.sort(
            key=lambda row: (
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
        retained_notification_ids.update(
            str(row.get("id", "")).strip()
            for row in rows[:_globals.NOTIFICATION_MAX_PER_USER]
        )
    bounded_notifications = [
        row for row in db.get("notifications", [])
        if not str(row.get("userId", "")).strip()
        or str(row.get("id", "")).strip() in retained_notification_ids
    ]
    if bounded_notifications != db.get("notifications", []):
        db["notifications"] = bounded_notifications
        changed = True

    for upload in db.get("mediaUploads", []):
        for k, v in {
            "objectKey": "", "moderationReason": "", "reviewNote": "",
            "reviewedBy": "", "reviewedAt": "", "sha256": "",
            "deleted": False, "uploaderId": "",
        }.items():
            if k not in upload:
                upload[k] = v
                changed = True

    return changed


def load_db() -> dict[str, Any]:
    db = _globals.REPOSITORY.load_state()
    if migrate_db(db):
        logger.info("[db] Database schema auto-migration performed during load_db.")
        _globals.REPOSITORY.save_state(db)
    return db
