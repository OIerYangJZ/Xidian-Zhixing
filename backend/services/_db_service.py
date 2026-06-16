from __future__ import annotations

import json
import logging
import os
from typing import Any

import _globals
from helpers._auth_helpers import (
    hash_password,
    is_password_hashed,
    normalize_avatar_url,
    normalize_media_url,
    sanitize_alias,
    student_id_from_email,
)
from helpers._datetime_helpers import now_iso, now_utc, parse_iso

logger = logging.getLogger(__name__)


def next_id(db: dict[str, Any], key: str, prefix: str) -> str:
    db.setdefault("seq", {})
    if key not in db["seq"]:
        db["seq"][key] = 0
    db["seq"][key] += 1
    return f"{prefix}{db['seq'][key]}"


def add_audit_log(db: dict[str, Any], actor_id: str, action: str, detail: str) -> None:
    db["auditLogs"].append(
        {
            "id": next_id(db, "audit", "a"),
            "actorId": actor_id,
            "action": action,
            "detail": detail,
            "createdAt": now_iso(),
        }
    )


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
    """Extract Bearer token, validate admin session, return (admin, token) or (None, None)."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[7:].strip()
    if not token:
        return None, None
    with _globals.ADMIN_SESSION_LOCK:
        admin_id = _globals.ADMIN_SESSIONS.get(token)
    if not admin_id:
        return None, token
    account = find_admin_account_by_id(db, str(admin_id), include_inactive=True)
    if account is None or not bool(account.get("active", True)):
        with _globals.ADMIN_SESSION_LOCK:
            _globals.ADMIN_SESSIONS.pop(token, None)
        return None, token
    return build_authenticated_admin(account), token


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
    return {
        "totalUsers": len(users),
        "totalPosts": len(posts),
        "totalReports": len(db.get("reports", [])),
        "pendingReports": len(reports_pending),
        "pendingReportCount": len(reports_pending),
        "pendingReviews": len(pending_reviews),
        "pendingReviewCount": len(pending_reviews),
        "pendingImages": len(pending_images),
        "pendingImageCount": len(pending_images),
        "totalComments": len([c for c in db.get("comments", []) if not c.get("deleted")]),
        "channels": list(db.get("channels", [])),
        "tags": list(db.get("tags", [])),
    }


def post_counts(db: dict[str, Any]) -> dict[str, int]:
    """Return per-channel post counts."""
    counts: dict[str, int] = {}
    for post in db.get("posts", []):
        if post.get("deleted"):
            continue
        channel = str(post.get("channel", ""))
        counts[channel] = counts.get(channel, 0) + 1
    return counts


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


# ---------------------------------------------------------------------------
# List helpers used by post / comment handlers
# ---------------------------------------------------------------------------

def list_posts(
    db: dict[str, Any],
    *,
    keyword: str = "",
    channel: str = "",
    has_image: bool | None = None,
    author_id: str = "",
    viewer_user_id: str = "",
    sort_by: str = "latest",
    include_rejected: bool = False,
) -> list[dict[str, Any]]:
    """Return filtered post rows."""
    posts = []
    for post in db.get("posts", []):
        if post.get("deleted"):
            continue
        if not include_rejected and post.get("reviewStatus") not in ("approved", "resolved"):
            continue
        if channel and post.get("channel") != channel:
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
        post["likeCount"] = sum(
            1
            for like in db.get("likes", [])
            if str(like.get("postId", "")).strip() == post_id
        )
        post["commentCount"] = sum(
            1
            for comment in db.get("comments", [])
            if not comment.get("deleted")
            and str(comment.get("postId", "")).strip() == post_id
        )
        post["favoriteCount"] = sum(
            1
            for favorite_row in db.get("favorites", [])
            if str(favorite_row.get("postId", "")).strip() == post_id
        )
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
    comments = []
    for comment in db.get("comments", []):
        if comment.get("postId") != post_id:
            continue
        if comment.get("deleted"):
            continue
        status = str(comment.get("reviewStatus", "")).strip().lower()
        if status == "rejected":
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
        headers = ["id", "title", "channel", "authorId", "authorAlias", "createdAt", "reviewStatus", "deleted"]
        for post in db.get("posts", []):
            status = str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
            if review_status != "all" and status != review_status:
                continue
            rows.append([
                str(post.get("id", "")),
                str(post.get("title", "")),
                str(post.get("channel", "")),
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
        writer.writerow(headers)
        writer.writerows(rows)
        output = si.getvalue()
    else:
        output = json.dumps({"headers": headers, "rows": rows}, ensure_ascii=False)

    return {"format": export_format, "data": output}


# ---------------------------------------------------------------------------
# Legacy stubs / aliases (handlers expect these at module level)
# ---------------------------------------------------------------------------

# Backward-compat constant
IS_SQL_DB = False


# Public system settings for unauthenticated endpoints
def public_system_settings(db: dict[str, Any]) -> dict[str, Any]:
    """Return public system settings (channels, tags, rate limits)."""
    return {
        "channels": list(db.get("channels", [])),
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

    comment_count = sum(
        1
        for comment in db.get("comments", [])
        if not comment.get("deleted") and str(comment.get("postId", "")).strip() == post_id
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

    image_urls: list[str] = []
    uploaded_image_ids: list[str] = []
    for upload in db.get("mediaUploads", []):
        if str(upload.get("postId", "")).strip() != post_id:
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
        "channel": post.get("channel", ""),
        "tags": post.get("tags", []),
        "authorAlias": post.get("authorAlias", "匿名同学"),
        "isAnonymous": is_anonymous,
        "authorAvatarUrl": "" if is_anonymous else user_avatar_url(author_user),
        "authorUserId": author_id if can_view_author_profile else "",
        "createdAt": post.get("createdAt", ""),
        "updatedAt": post.get("updatedAt", ""),
        "hasImage": bool(post.get("hasImage", False)) or bool(image_urls),
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
        "status": post.get("status", "ongoing"),
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
    return {
        "id": comment.get("id", ""),
        "postId": comment.get("postId", ""),
        "content": comment.get("content", ""),
        "authorAlias": comment.get("authorAlias", "匿名同学"),
        "authorId": author_id,
        "authorAvatarUrl": user_avatar_url(author_user) if author_user else "",
        "authorUserId": "" if is_anonymous else author_id,
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
    "announcements",
    "announcementSources",
    "announcementPreferences",
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
    "aiConversations",
    "aiMessages",
    "aiCitations",
    "dailySummaries",
    "moderationTasks",
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


def _default_announcements(created: str) -> list[dict[str, Any]]:
    seeds = [
        ("ann-school-1", "学校官方通知", "关于夏季作息与服务窗口调整的通知", "5 月 27 日起部分服务窗口开放时间调整，请同学们提前规划。", "党政办公室", "school", "", "", ["校级", "重要"], True),
        ("ann-college-1", "学院通知", "计算机学院本科生科研训练报名提醒", "报名截止至 5 月 30 日，学院将按年级和方向组织导师匹配。", "计算机科学与技术学院", "college", "计算机科学与技术学院", "", ["科研", "学院"], True),
        ("ann-major-1", "专业通知", "软件工程专业课程设计分组安排", "请相关同学在本周内完成小组确认并提交题目偏好。", "软件工程系", "major", "计算机科学与技术学院", "软件工程", ["课程", "专业"], False),
        ("ann-competition-1", "比赛通知", "校赛创新创业训练营开放报名", "训练营包含选题、路演、商业计划书三场工作坊。", "创新创业学院", "competition", "", "", ["比赛", "训练营"], False),
        ("ann-club-1", "社团活动", "无线电协会开放日活动预告", "欢迎对硬件、通信和校园技术服务感兴趣的同学参加。", "无线电协会", "club", "", "", ["社团", "活动"], False),
        ("ann-service-1", "一站式平台消息", "学生事务服务大厅端午值班安排", "端午期间保留应急事项窗口，普通事项节后办理。", "一站式学生社区", "service", "", "", ["一站式", "服务"], False),
        ("ann-other-1", "其他校内通知", "图书馆研讨间预约系统维护", "维护期间暂不支持新增预约，已预约记录不受影响。", "图书馆", "other", "", "", ["图书馆"], False),
    ]
    rows = []
    for offset, (ann_id, type_name, title, content, publisher, source_type, college, major, tags, important) in enumerate(seeds):
        rows.append({
            "id": ann_id,
            "title": title,
            "content": content,
            "summary": content[:80],
            "aiSummary": "",
            "publishedAt": created,
            "createdAt": created,
            "publisher": publisher,
            "sourceType": source_type,
            "sourceName": type_name,
            "type": type_name,
            "college": college,
            "major": major,
            "tags": tags,
            "isImportant": important,
            "originalUrl": "",
            "jumpUrl": f"/pages/announcements/detail/index?id={ann_id}",
            "sortOrder": offset,
            "reviewStatus": "approved",
        })
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
            "name": "统一认证",
            "slug": "ids-login",
            "groupId": "account",
            "groupName": "账户认证",
            "kind": "account",
            "iconKey": "person",
            "authType": "ids",
            "status": "可测试",
            "summary": "用于验证西电统一身份认证账号，临时接入 PDA 同类登录方式，验证通过后可继续测试各类校园服务。",
            "requiredAccess": "西电统一身份认证账号密码；密码仅用于本次请求，不写入数据库。",
            "features": ["统一认证验证", "学生身份校验", "一站式入口", "短时测试"],
            "dataFields": ["学号", "统一认证状态", "校内邮箱"],
            "emptyText": "",
            "actions": [{"label": "打开一站式", "type": "external", "url": ehall_url}],
        },
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
            "calendarSource": "courseSchedules",
            "emptyText": "当前没有课表数据。完成统一认证并接入学校课表接口后会显示周历。",
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
            "status": "待接口接入",
            "summary": "查看学期成绩、课程性质、学分、等级成绩，并支持后续均分/GPA 汇总。",
            "requiredAccess": "一站式成绩接口、统一身份认证、查询即返回的短期内存缓存。",
            "features": ["成绩列表", "按学期筛选", "均分/GPA 汇总", "未通过课程提示"],
            "dataFields": ["课程名称", "成绩", "学年学期", "学分", "课程性质", "等级", "是否通过"],
            "emptyText": "成绩接口尚未接入。可先打开一站式查看原始成绩。",
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
            "emptyText": "当前没有考试安排数据。接入考试接口后会按日期显示。",
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
            "emptyText": "当前没有实验安排数据。物理实验和其他实验接口接入后会显示。",
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
            "status": "待接口接入",
            "summary": "按校区、楼宇、节次筛选空闲教室，适合自习与临时讨论。",
            "requiredAccess": "教室占用数据或教务课表公共查询接口。",
            "features": ["校区筛选", "楼宇筛选", "节次占用", "关键词搜索"],
            "dataFields": ["教室名称", "1-2 节", "3-4 节", "5-6 节", "7-8 节", "9-10 节"],
            "emptyText": "空闲教室查询接口尚未接入。可先打开一站式教务入口。",
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
            "status": "待接口接入",
            "summary": "展示课程考勤、签到详情、任务点、作业和考试进度。",
            "requiredAccess": "考勤系统接口、请销假系统状态接口。",
            "features": ["课程考勤记录", "签到详情", "学习进度", "请假关联"],
            "dataFields": ["课程名称", "签到次数", "异常次数", "任务点进度", "作业进度", "考试进度"],
            "emptyText": "考勤接口尚未接入。请销假入口已可跳转。",
            "actions": [{"label": "打开请销假系统", "type": "external", "url": "https://service.xidian.edu.cn/v2/matter/m_start?id=189"}],
        },
        {
            "name": "体育信息",
            "slug": "sport",
            "groupId": "study",
            "groupName": "学习事务",
            "kind": "sport",
            "iconKey": "activity",
            "authType": "sportPassword",
            "status": "待接口接入",
            "summary": "查看体育课程、体测成绩、分项成绩和等级。",
            "requiredAccess": "体育系统账号密码。",
            "features": ["体育课程", "体测总分", "体测分项", "成绩等级"],
            "dataFields": ["学期", "课程名称", "教师", "上课时间", "课程成绩", "体测项目", "等级"],
            "emptyText": "体育信息接口尚未接入。可先打开体育教学系统。",
            "actions": [{"label": "打开体育系统", "type": "external", "url": "http://tybjxgl.xidian.edu.cn/app/"}],
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
            "summary": "查看宿舍电量、欠费金额和历史读表趋势，当前先接入学校缴费入口。",
            "requiredAccess": "宿舍电费查询接口、缴费系统跳转授权。",
            "features": ["剩余电量", "欠费金额", "历史读表", "缴费入口"],
            "dataFields": ["抓取日期", "剩余电量", "欠费金额", "电费账号"],
            "emptyText": "电量查询接口尚未接入。缴费系统可以直接打开。",
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
            "status": "待接口接入",
            "summary": "通过手机号和短信验证码登录水机服务，管理设备并开始/结束接水。",
            "requiredAccess": "宿舍水机服务 API、短信验证码、设备二维码。",
            "features": ["手机号登录", "设备列表", "扫码添加设备", "开始/结束接水"],
            "dataFields": ["手机号", "设备 ID", "设备名称", "接水状态", "Token"],
            "emptyText": "宿舍水机 API 尚未接入小程序。可先打开订水系统。",
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
            "status": "待接口接入",
            "summary": "查看个人借阅、续借、馆藏搜索和南北校区在馆/空位情况。",
            "requiredAccess": "图书馆统一认证、借阅接口、馆藏检索与座位数据。",
            "features": ["借阅列表", "续借", "馆藏搜索", "图书馆容量"],
            "dataFields": ["书名", "作者", "ISBN", "借阅日期", "应还日期", "可否续借", "空位数"],
            "mapIds": ["map-main"],
            "emptyText": "图书馆接口尚未接入。可先打开图书馆主页。",
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
            "status": "待接口接入",
            "summary": "查看校园卡余额、消费流水，并预留付款码能力。",
            "requiredAccess": "校园卡接口、统一认证、二维码付款码授权。",
            "features": ["余额", "消费流水", "日期范围筛选", "付款码"],
            "dataFields": ["交易时间", "商户名称", "收入", "支出", "余额"],
            "emptyText": "校园卡接口尚未接入。可先打开一站式。",
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
            "emptyText": "校园网查询接口尚未接入小程序。可先打开校园网自服务。",
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
            "status": "待接口接入",
            "summary": "读取当前学期、学生基础信息和住宿地址，为课表、电费等服务提供基础资料。",
            "requiredAccess": "一站式个人信息接口、研究生/本科生学期接口。",
            "features": ["当前学期", "住宿地址", "学号绑定", "基础资料"],
            "dataFields": ["学号", "当前学期", "住宿地址", "学院", "专业"],
            "emptyText": "个人信息接口尚未接入。",
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
            "status": "待接口接入",
            "summary": "查询创新创业竞赛项目、岗位或报名相关信息。",
            "requiredAccess": "双创平台统一认证和查询接口。",
            "features": ["项目查询", "竞赛岗位", "报名信息"],
            "dataFields": ["项目名称", "主办方", "报名时间", "状态"],
            "emptyText": "双创竞赛接口尚未接入。",
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
            "status": "待配置入口",
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
            "status": "待配置",
            "summary": "进入学校企业微信相关服务。",
            "requiredAccess": "企业微信应用跳转配置或官方链接。",
            "features": ["企业微信服务"],
            "dataFields": ["应用 appId", "跳转路径"],
            "actions": [{"label": "查看接入说明", "type": "notice"}],
        },
        {
            "name": "学校小程序",
            "slug": "official-miniprogram",
            "groupId": "tools",
            "groupName": "工具入口",
            "kind": "external",
            "iconKey": "phone",
            "authType": "external",
            "status": "待配置",
            "summary": "跳转到学校官方小程序或对应服务页面。",
            "requiredAccess": "目标小程序 appId 与跳转路径配置。",
            "features": ["官方小程序跳转"],
            "dataFields": ["目标 appId", "目标页面路径"],
            "actions": [{"label": "查看接入说明", "type": "notice"}],
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
            "summary": "预留更多校内服务链接，后续由后台配置增补。",
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
            "summary": "进入学校校外远程访问服务说明，用于在校外访问校园网资源。",
            "requiredAccess": "一网通办零信任/堡垒机账号申请或学校远程访问账号。",
            "features": ["校外访问", "零信任申请", "堡垒机账号", "校园网资源"],
            "dataFields": ["账号", "申请状态", "回执", "使用手册"],
            "actions": [{"label": "打开校外访问说明", "type": "external", "url": remote_access_url}],
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
            "summary": "查看自助打印和校务行接入说明，后续可对接成绩单、证明材料等自助打印场景。",
            "requiredAccess": "一网通办自助打印及校务行接入申请。",
            "features": ["证明打印", "表单上线", "数据来源选择", "设备打印"],
            "dataFields": ["表单名称", "数据来源", "审批状态", "设备位置"],
            "actions": [{"label": "打开自助打印说明", "type": "external", "url": print_service_url}],
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
            "summary": "进入学校正版化软件服务，查看可用软件和申请说明。",
            "requiredAccess": "统一认证账号和软件使用资格。",
            "features": ["正版软件下载", "软件申请", "授权说明"],
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
            "dataFields": ["日程类型", "日期", "时间", "地点", "备注"],
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
    ]
    guide_chunks = [
        {
            "id": "kc-xidian-ids",
            "title": "西电统一身份认证与一站式服务",
            "sourceUrl": "https://ids.xidian.edu.cn/authserver/login",
            "content": (
                "西电统一身份认证 IDS 是进入一站式大厅、教务、缴费、后勤报修、请销假等校内系统的主要入口。"
                "学生通常使用学号和统一认证密码登录。小程序内的校园服务测试只在发起请求时使用密码，不写入数据库。"
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
                "PDA 中乐跑计数作为体育系统关联信息展示，小程序当前先接入体育系统登录验证和入口跳转。"
            ),
        },
        {
            "id": "kc-xidian-energy",
            "title": "宿舍电费、水电缴费与宿舍水机",
            "sourceUrl": "https://xxcapp.xidian.edu.cn/uc/api/oauth/index?redirect=https://ignypt.xidian.edu.cn/revenueH5/login?opcode=MPAY&appid=200260318155520600&state=1231231231",
            "content": (
                "宿舍电费和水电缴费可通过学校缴费入口进入，查询时通常需要确认宿舍或缴费账号、剩余电量、欠费金额和缴费记录。"
                "宿舍水机服务使用手机号、图形验证码和短信验证码登录，关注设备列表、设备二维码、开始/结束接水和接水状态。"
                "订水入口为 https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1。"
            ),
        },
        {
            "id": "kc-xidian-network",
            "title": "校园网自服务",
            "sourceUrl": "https://zfw.xidian.edu.cn",
            "content": (
                "校园网自服务用于查询账号套餐、余额、已用流量、剩余流量、在线 IP 和当前网络信息。"
                "登录一般需要学号/校园网账号、查询密码和图形验证码。信息网络技术中心学生服务目录还包括网络接入、一网通办、统一认证、一卡通、校外访问和邮件等服务。"
                "真机调试时若本地接口不可访问，应确认手机与电脑在同一 Wi-Fi 且后端地址不是 localhost。"
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
                "双创竞赛平台用于查看项目、岗位、报名时间和状态。"
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
    ]
    document_content = "\n\n".join(
        f"{item['title']}\n来源：{item['sourceUrl']}\n{item['content']}"
        for item in guide_chunks
    )
    documents = [
        {
            "id": "kd-xidian-services",
            "sourceId": "ks-xidian-services",
            "title": "西电官方学生服务指南浓缩版",
            "content": document_content,
            "sourceUrl": "https://service.xidian.edu.cn/",
            "createdAt": created,
        }
    ]
    chunks = [
        {
            "id": item["id"],
            "sourceId": "ks-xidian-services",
            "documentId": "kd-xidian-services",
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
        "section", "club", "clubApplication", "clubMember", "announcement",
        "announcementSource", "announcementPreference", "campusService",
        "campusMap", "hotTopic", "hotTopicSummary", "knowledgeSource",
        "knowledgeDocument", "knowledgeChunk", "aiConversation", "aiMessage",
        "aiCitation", "dailySummary", "moderationTask",
    ]:
        if key not in db.setdefault("seq", {}):
            db["seq"][key] = 0
            changed = True
    default_sections = _default_sections(created)
    if not db.get("sections"):
        db["sections"] = default_sections
        changed = True
    else:
        before_count = len(db.get("sections", []))
        db["sections"] = [
            row for row in db.get("sections", [])
            if str(row.get("sectionType", "")).strip().lower() != "school"
            and str(row.get("sectionName", "")).strip() != "学校总分区"
        ]
        if len(db["sections"]) != before_count:
            changed = True
        existing_section_names = {
            str(row.get("sectionName") or row.get("name") or "").strip()
            for row in db.get("sections", [])
        }
        for section in default_sections:
            if str(section.get("sectionName", "")).strip() not in existing_section_names:
                db["sections"].append(section)
                existing_section_names.add(str(section.get("sectionName", "")).strip())
                changed = True
    if not db.get("announcementSources"):
        db["announcementSources"] = [
            {"id": "src-school", "name": "学校官方通知", "sourceType": "school", "createdAt": created},
            {"id": "src-college", "name": "学院通知", "sourceType": "college", "createdAt": created},
            {"id": "src-major", "name": "专业通知", "sourceType": "major", "createdAt": created},
            {"id": "src-competition", "name": "比赛通知", "sourceType": "competition", "createdAt": created},
            {"id": "src-club", "name": "社团活动", "sourceType": "club", "createdAt": created},
            {"id": "src-service", "name": "一站式平台消息", "sourceType": "service", "createdAt": created},
            {"id": "src-other", "name": "其他校内通知", "sourceType": "other", "createdAt": created},
        ]
        changed = True
    if not db.get("announcements"):
        db["announcements"] = _default_announcements(created)
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
        for key in ("name", "sourceType", "sourceUrl"):
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
            "request": 0,
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
        "channels": list(_globals.DEFAULT_CHANNELS),
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
        "reports": [],
        "dmRequests": [],
        "userBlocks": [],
        "userFollows": [],
        "conversations": [],
        "directMessages": [],
        "systemAnnouncements": [],
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
                "channel": row["channel"],
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

    db["dmRequests"].append(
        {
            "id": "req1", "toUserId": "u1", "fromAlias": "同学-海盐",
            "fromUserId": "seed-user-1", "fromAvatarUrl": "",
            "reason": "想咨询图书馆座位信息", "createdAt": created, "status": "pending",
        }
    )
    db["dmRequests"].append(
        {
            "id": "req2", "toUserId": "u1", "fromAlias": "同学-留白",
            "fromUserId": "seed-user-2", "fromAvatarUrl": "",
            "reason": "想问二手显示器细节", "createdAt": created, "status": "pending",
        }
    )
    db["seq"]["request"] = 2

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
            pass
    else:
        # Not first boot, but let's migrate any missing schema items/sequences
        try:
            db = _globals.REPOSITORY.load_state()
            if migrate_db(db):
                logger.info("[db] Migrating existing database schema and sequences...")
                _globals.REPOSITORY.save_state(db)
        except Exception as e:
            logger.error(f"[db] Migration check failed: {e}", exc_info=True)


def save_db(db: dict[str, Any]) -> None:
    _globals.SQL_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    _globals.REPOSITORY.save_state(db)


def migrate_db(db: dict[str, Any]) -> bool:
    changed = False
    if ensure_radio_schema(db):
        changed = True

    if "channels" not in db:
        db["channels"] = []
        changed = True
    elif not isinstance(db.get("channels"), list):
        db["channels"] = []
        changed = True
    else:
        legacy_channels = [str(channel).strip() for channel in db.get("channels", []) if str(channel).strip()]
        if legacy_channels:
            tags = db.setdefault("tags", [])
            for channel in legacy_channels:
                if channel != "综合" and channel not in tags:
                    tags.append(channel)
            db["channels"] = []
            changed = True

    if "tags" not in db:
        db["tags"] = list(_globals.DEFAULT_TAGS)
        changed = True
    else:
        for default_tag in _globals.DEFAULT_TAGS:
            if default_tag not in db["tags"]:
                db["tags"].append(default_tag)
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
    if "mediaUploads" not in db:
        db["mediaUploads"] = []
        changed = True
    if "emailCodes" not in db or not isinstance(db.get("emailCodes"), dict):
        db["emailCodes"] = {}
        changed = True

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
        "cancellation", "request", "conversation", "message",
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
        for key in ("college", "major"):
            if key not in user:
                user[key] = ""
                changed = True
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
        if str(post.get("sectionType", "")).strip().lower() == "school" or str(post.get("sectionName", "")).strip() == "学校总分区":
            post["sectionType"] = "general"
            post["sectionId"] = "general"
            post["sectionName"] = "综合"
            changed = True
        legacy_channel = str(post.get("channel", "")).strip()
        if legacy_channel:
            post_tags = post.setdefault("tags", [])
            if legacy_channel != "综合" and legacy_channel not in post_tags:
                post_tags.append(legacy_channel)
            post["channel"] = ""
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

    for notification in db.get("notifications", []):
        for k, v in {
            "relatedType": "", "relatedId": "", "actorId": "",
            "actorAlias": "", "deleted": False, "readAt": "",
        }.items():
            if k not in notification:
                notification[k] = v
                changed = True

    for announcement in db.get("systemAnnouncements", []):
        if "createdBy" not in announcement:
            announcement["createdBy"] = ""
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
