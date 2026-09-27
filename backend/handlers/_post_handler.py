"""
handlers/_post_handler.py

Post, comment, report, favorite, like, and appeal endpoints:
  GET  /api/posts                                      — list posts
  GET  /api/posts/mine                                 — list own posts
  GET  /api/posts/favorites                            — list favorited posts
  GET  /api/uploads/mine                               — list own uploads
  GET  /api/comments/mine                              — list own comments
  GET  /api/reports/mine                               — list own reports
  GET  /api/reports/<id>                              — get report detail
  GET  re("/api/posts/([^/]+)")                        — get single post
  GET  re("/api/posts/([^/]+)/comments")              — list post comments
  POST /api/posts                                      — create a post
  POST /api/reports                                    — submit a report
  POST /api/appeals                                    — submit an appeal
  POST re("/api/posts/([^/]+)/comments")             — create a comment
  POST re("/api/posts/([^/]+)/like")                 — toggle like
  POST re("/api/posts/([^/]+)/favorite")              — toggle favorite
  POST re("/api/posts/([^/]+)/pin-request")          — request pin-top
  POST re("/api/posts/([^/]+)/view")                  — increment view count
  DELETE re("/api/posts/([^/]+)")                     — delete own post
  DELETE re("/api/comments/([^/]+)")                  — delete own comment
  DELETE re("/api/posts/([^/]+)/favorite")            — remove favorite
"""
from __future__ import annotations

import copy
import logging
import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from object_storage import delete_objects_with_backups, restore_object_backups
from helpers import (
    assess_text_risk,
    check_ip_rate_limit,
    clear_rate_limit_breaches,
    consume_rate_limit,
    get_client_ip,
    record_rate_limit_breach,
    is_campus_email,
    json_error,
    now_iso,
    parse_bool,
    read_json_body,
    sanitize_alias,
    send_rate_limit_error,
    send_json,
    verify_password,
)
from handlers._social_handler import notify_mentions, resolve_mentions
from services import (
    add_audit_log,
    apply_post_pin,
    auth_user as auth_user_helper,
    create_notification,
    find_user_by_email,
    find_user_by_id,
    iso_to_time_text,
    is_level_one_user,
    is_post_anonymous,
    is_user_blocked,
    is_post_private,
    is_user_following,
    latest_pending_appeal_for_user,
    ban_appeal_used,
    BAN_APPEAL_TYPES,
    latest_pending_post_pin_request_for_post,
    latest_user_level_request_for_user,
    list_comments,
    list_following_users,
    list_posts,
    next_id,
    parse_pin_duration_minutes,
    normalize_optional_bool,
    normalize_post_visibility,
    post_counts,
    recalc_post_has_image,
    save_db,
    serialize_admin_post_pin_request,
    serialize_comment,
    serialize_notification,
    serialize_post,
    serialize_public_user_profile,
    is_post_pin_active,
    user_avatar_url,
    user_nickname,
    visible_mentions,
)

_MAX_POST_TITLE_CHARS = 200
_MAX_POST_CONTENT_CHARS = 10_000
logger = logging.getLogger("treehole.posts")

_MAX_MARKDOWN_SOURCE_CHARS = 20_000
_MAX_COMMENT_CHARS = 2_000
_MAX_TAGS = 10
_MAX_POST_IMAGES = 9
_MAX_TAG_CHARS = 40
_MARKDOWN_IMAGE_RE = re.compile(
    r"!\[[^\]]*\]\(([^)\s]+)(?:\s+['\"][^'\"]*['\"])?\)",
)


# Anonymous nicknames offered by 随机: "<where/when>的<creature/thing>", in the
# campus register of the ones users pick themselves (北门的风, 晨跑的鹿).
_ALIAS_PREFIXES = (
    "北门的", "南门的", "图书馆的", "操场边的", "食堂里的", "海棠路的", "银杏道的",
    "实验楼的", "晨跑的", "早八的", "熬夜的", "午后的", "雨后的", "路过的",
    "安静的", "考研的", "自习室的", "宿舍楼下的", "湖边的", "晚自习的",
)
_ALIAS_NOUNS = (
    "鹿", "风", "猫", "云", "树", "星", "灯", "鲸", "松鼠", "白鸽", "银杏",
    "蒲公英", "月亮", "纸飞机", "橘子", "萤火虫", "小熊", "海盐", "薄荷", "向日葵",
)


def random_anonymous_alias(db: dict[str, Any]) -> str:
    """A random alias that avoids the admin's sensitive words."""
    import secrets

    blocked = [
        str(word).strip().lower()
        for word in db.get("sensitiveWords", [])
        if str(word).strip()
    ]
    alias = ""
    for _ in range(20):
        alias = secrets.choice(_ALIAS_PREFIXES) + secrets.choice(_ALIAS_NOUNS)
        if not any(word in alias.lower() for word in blocked):
            return sanitize_alias(alias)
    return "匿名同学"


def handle_get_random_anonymous_alias(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/posts/anonymous-alias -> {"alias": "..."}"""
    if _require_auth(handler, db) is None:
        return
    send_json(handler, HTTPStatus.OK, {"data": {"alias": random_anonymous_alias(db)}})


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _enforce_interaction_rate_limit(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user: dict[str, Any],
) -> bool:
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "interaction")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="互动操作",
            retry_after_seconds=ip_retry_after,
        )
        return False
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=str(user.get("id", "")).strip(),
        action="interaction",
        setting_key="interactionRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["interactionRateLimit"]),
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="互动操作",
            retry_after_seconds=retry_after,
        )
        return False
    return True


def _requested_state(handler: BaseHTTPRequestHandler, key: str) -> bool | None:
    """The target state a like / favorite request asks for, or None to toggle.

    Toggling from the client's idea of the current state goes wrong whenever
    that idea is stale (a list not refreshed after the detail page changed it),
    so current clients send the state they want. Older released clients send
    an empty body and keep the toggle.
    """
    value = read_json_body(handler).get(key)
    return value if isinstance(value, bool) else None


def _can_view_post(post: dict[str, Any], viewer_user_id: str) -> bool:
    author_id = str(post.get("authorId", "")).strip()
    is_owner = bool(viewer_user_id and viewer_user_id == author_id)
    review_status = (
        str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
    )
    if review_status not in {"approved", "resolved"}:
        return is_owner
    return not is_post_private(post) or is_owner


def _can_interact_with_post(post: dict[str, Any], viewer_user_id: str) -> bool:
    review_status = (
        str(post.get("reviewStatus", "approved")).strip().lower() or "approved"
    )
    return review_status in {"approved", "resolved"} and _can_view_post(
        post,
        viewer_user_id,
    )


def _normalize_post_content_format(value: Any) -> str:
    return "markdown" if str(value or "").strip().lower() == "markdown" else "plain"


def _markdown_to_plain_text(source: str) -> str:
    text = source.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(
        r"```([\s\S]*?)```",
        lambda match: f"\n{(match.group(1) or '').strip()}\n",
        text,
    )
    text = re.sub(r"`([^`]*)`", lambda match: match.group(1) or "", text)
    text = re.sub(
        r"!\[([^\]]*)\]\([^)]+\)",
        lambda match: (match.group(1) or "").strip() or "图片",
        text,
    )
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", lambda match: match.group(1) or "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"^\s{0,3}#{1,6}\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s{0,3}>\s?", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*([-*_]\s*){3,}$", "", text, flags=re.MULTILINE)
    text = re.sub(r"[*_~]", "", text)
    text = text.replace("|", " ")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n[ \t]+", "\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _extract_inline_tags(*values: Any) -> list[str]:
    tags: list[str] = []
    for value in values:
        text = str(value or "")
        for match in re.findall(r"#([\w\u4e00-\u9fff-]{1,30})", text):
            tag = match.strip()
            if tag and tag not in tags:
                tags.append(tag)
    return tags


def _comments_as_anonymous_author(db: dict[str, Any], post: dict[str, Any], user_id: str) -> bool:
    """The author of an anonymous post comments under the post's alias.

    Otherwise their comment (and its 洞主 mark) would name them as the author.
    """
    return bool(
        user_id
        and str(post.get("authorId", "")).strip() == user_id
        and is_post_anonymous(db, post)
    )


def _serialize_comment(
    db: dict[str, Any],
    comment: dict[str, Any],
    viewer_user_id: str,
    post: dict[str, Any] | None = None,
) -> dict[str, Any]:
    author_id = str(comment.get("userId", "")).strip()
    author_user = find_user_by_id(db, author_id)
    if post is None:
        post_id = str(comment.get("postId", "")).strip()
        post = next((p for p in db["posts"] if str(p.get("id", "")).strip() == post_id), None)
    is_post_author = bool(
        post is not None and author_id and str(post.get("authorId", "")).strip() == author_id
    )
    # Comments stored before comment anonymity existed are covered here too.
    as_anonymous_author = post is not None and _comments_as_anonymous_author(db, post, author_id)
    is_anonymous = bool(comment.get("isAnonymous", False)) or as_anonymous_author
    author_alias = (
        str(post.get("authorAlias", "")) if as_anonymous_author and post is not None
        else str(comment.get("authorAlias", ""))
    )
    liked = bool(
        viewer_user_id
        and any(
            x for x in db["likes"]
            if x.get("userId") == viewer_user_id and x.get("commentId") == comment.get("id")
        )
    )
    like_count_raw = comment.get("likeCount", 0)
    try:
        like_count = max(0, int(like_count_raw or 0))
    except (TypeError, ValueError):
        like_count = 0
    public_author_id = "" if is_anonymous else author_id
    author_avatar_url = "" if is_anonymous else user_avatar_url(author_user)
    return {
        "id": comment.get("id", ""),
        "postId": comment.get("postId", ""),
        "content": comment.get("content", ""),
        "authorAlias": _globals.sanitize_alias(author_alias, fallback="匿名同学"),
        "authorId": public_author_id,
        "authorAvatarUrl": author_avatar_url,
        "authorAvatar": author_avatar_url,
        "authorUserId": public_author_id,
        "isOwnComment": bool(viewer_user_id and viewer_user_id == author_id),
        "mentions": visible_mentions(db, comment.get("mentions")),
        "editedAt": str(comment.get("editedAt", "") or ""),
        # 洞主. Only the flag is exposed; on an anonymous post the comment is
        # anonymous too, so it names no one.
        "isPostAuthor": is_post_author,
        "likeCount": like_count,
        "liked": liked,
        "createdAt": comment.get("createdAt", ""),
        "isAnonymous": is_anonymous,
        "reviewStatus": str(comment.get("reviewStatus", "approved") or "approved"),
        "parentId": str(comment.get("parentId", "")).strip(),
    }


def _serialize_upload(db: dict[str, Any], upload: dict[str, Any]) -> dict[str, Any]:
    uploader = find_user_by_id(db, str(upload.get("uploaderId", "")))
    return {
        "id": upload.get("id", ""),
        "url": upload.get("url", ""),
        "fileName": upload.get("fileName", ""),
        "contentType": upload.get("contentType", ""),
        "sizeBytes": int(upload.get("sizeBytes", 0)),
        "status": upload.get("status", "pending"),
        "createdAt": upload.get("createdAt", ""),
        "postId": upload.get("postId", ""),
        "uploaderId": upload.get("uploaderId", ""),
        "uploaderAlias": user_nickname(uploader),
    }


def _normalize_comment_sort(value: Any) -> str:
    text = str(value or "").strip().lower()
    if text in {"hot", "top"}:
        return "hot"
    return "latest"


def _positive_int(value: Any, default: int, maximum: int | None = None) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError):
        number = default
    number = max(1, number)
    if maximum is not None:
        number = min(number, maximum)
    return number


# ===========================================================================
# GET handlers
# ===========================================================================


def handle_get_posts(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/posts"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""

    keyword = (query.get("keyword", [""])[0] or "").strip().lower()
    has_image = parse_bool(query.get("hasImage", [None])[0])
    allow_dm = parse_bool(query.get("allowDm", [None])[0])
    status = (query.get("status", [""])[0] or "").strip().lower()
    sort_by = (query.get("sort", ["latest"])[0] or "latest").strip().lower()
    author_id = (query.get("authorId", [""])[0] or "").strip()
    section_id = (query.get("sectionId", [""])[0] or "").strip()
    section_type = (query.get("sectionType", [""])[0] or "").strip()
    channel = (query.get("channel", [""])[0] or "").strip()

    filtered_posts = []
    for post in list_posts(
        db,
        sort_by=sort_by,
        viewer_user_id=viewer_user_id,
    ):
        if status and str(post.get("status", "")).lower() != status:
            continue
        if has_image is not None and bool(post.get("hasImage", False)) != has_image:
            continue
        if allow_dm is not None and _globals.effective_post_allow_dm(db, post) != allow_dm:
            continue
        if author_id:
            if str(post.get("authorId", "")).strip() != author_id:
                continue
            # The query itself is the disclosure: emptying authorUserId in the
            # response is not enough, because a caller who asked for authorId=X
            # and got a post back has just learned that X wrote it.  Anonymous
            # posts must therefore never be reachable through this filter for
            # anyone but their own author.
            if is_post_anonymous(db, post) and author_id != viewer_user_id:
                continue
        # Seed / legacy posts predate sections and belong to 综合 (general).
        post_section_type = str(post.get("sectionType", "")).strip() or "general"
        post_section_id = str(post.get("sectionId", "")).strip() or (
            "general" if post_section_type == "general" else ""
        )
        if section_id and post_section_id != section_id:
            continue
        if section_type and post_section_type != section_type:
            continue
        if channel and channel != "全部":
            post_channel = str(post.get("channel", "")).strip()
            post_tags = post.get("tags", [])
            if post_channel != channel and channel not in post_tags:
                continue

        if keyword:
            text = " ".join(
                [
                    str(post.get("title", "")).lower(),
                    str(post.get("content", "")).lower(),
                    " ".join(str(tag).lower() for tag in post.get("tags", [])),
                ]
            )
            if keyword not in text:
                continue

        filtered_posts.append(post)

    filtered_posts = _globals.sort_posts_for_view(db, filtered_posts, sort_by=sort_by)
    has_pagination = "page" in query or "limit" in query
    if has_pagination:
        page = _positive_int((query.get("page") or [1])[0], 1)
        limit = _positive_int((query.get("limit") or [20])[0], 20, 100)
        start = (page - 1) * limit
        # serialize_post scans whole tables per post: only the page is built.
        page_rows = [
            serialize_post(db, post, viewer_user_id=viewer_user_id)
            for post in filtered_posts[start:start + limit]
        ]
        send_json(
            handler,
            HTTPStatus.OK,
            {
                "data": {
                    "items": page_rows,
                    "page": page,
                    "limit": limit,
                    "total": len(filtered_posts),
                    "hasMore": start + limit < len(filtered_posts),
                }
            },
        )
        return

    rows = [serialize_post(db, post, viewer_user_id=viewer_user_id) for post in filtered_posts]
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_posts_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/posts/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = [
        p
        for p in list_posts(
            db,
            include_rejected=True,
            viewer_user_id=user["id"],
        )
        if p.get("authorId") == user["id"]
    ]
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": [
                serialize_post(db, p, include_unapproved_images=True, viewer_user_id=user["id"])
                for p in rows
            ]
        },
    )


def handle_get_posts_favorites(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/posts/favorites"""
    user = _require_auth(handler, db)
    if user is None:
        return

    fav_post_ids = {f["postId"] for f in db["favorites"] if f.get("userId") == user["id"]}
    rows = [
        p
        for p in list_posts(db, viewer_user_id=user["id"])
        if p.get("id") in fav_post_ids
    ]
    send_json(
        handler,
        HTTPStatus.OK,
        {"data": [serialize_post(db, p, viewer_user_id=user["id"]) for p in rows]},
    )


def handle_get_uploads_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/uploads/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = [
        _serialize_upload(db, u)
        for u in db.get("mediaUploads", [])
        if not u.get("deleted") and u.get("uploaderId") == user["id"]
    ]
    rows.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_get_comments_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/comments/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    result = []
    for comment in db["comments"]:
        if comment.get("userId") != user["id"] or comment.get("deleted"):
            continue
        post = next(
            (p for p in db["posts"] if p.get("id") == comment.get("postId") and not p.get("deleted")),
            None,
        )
        result.append(
            {
                "id": comment.get("id"),
                "commentId": comment.get("id"),
                "postId": comment.get("postId", ""),
                "postTitle": post.get("title") if post else "原帖",
                "content": comment.get("content", ""),
                "timeText": iso_to_time_text(comment.get("createdAt")),
            }
        )
    result.sort(key=lambda x: x.get("timeText", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_get_reports_mine(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/reports/mine"""
    user = _require_auth(handler, db)
    if user is None:
        return

    result = []
    for report in db["reports"]:
        if report.get("userId") != user["id"]:
            continue
        target_type = str(report.get("targetType", "other"))
        target_id = str(report.get("targetId", "unknown"))
        target_title = ""
        if target_type == "post":
            post = next(
                (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
                None,
            )
            if post is not None:
                target_title = str(post.get("title", "")).strip()
        elif target_type == "comment":
            comment = next(
                (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
                None,
            )
            if comment is not None:
                target_title = str(comment.get("content", "")).strip()[:50]
        elif target_type == "user":
            reported = find_user_by_id(db, target_id)
            if reported is not None:
                target_title = user_nickname(reported)
        result.append({
            "id": report.get("id"),
            "target": f"{target_type}: {target_id}",
            "targetType": target_type,
            "targetId": target_id,
            "targetTitle": target_title,
            "reason": report.get("reason", "-"),
            "status": report.get("status", "pending"),
            "description": report.get("description", ""),
            "result": report.get("result", ""),
            "createdAt": report.get("createdAt", ""),
            "handledAt": report.get("handledAt", ""),
        })
    result.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_get_report_detail(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    report_id: str,
) -> None:
    """GET /api/reports/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    report = next((r for r in db["reports"] if r.get("id") == report_id), None)
    if report is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "举报记录不存在")
        return
    if report.get("userId") != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "无权限查看此举报记录")
        return

    target_type = str(report.get("targetType", "other"))
    target_id = str(report.get("targetId", "unknown"))
    target_title = ""
    if target_type == "post":
        post = next(
            (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
            None,
        )
        if post is not None:
            target_title = str(post.get("title", "")).strip()
    elif target_type == "comment":
        comment = next(
            (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
            None,
        )
        if comment is not None:
            target_title = str(comment.get("content", "")).strip()[:50]

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": report.get("id"),
                "targetType": target_type,
                "targetId": target_id,
                "targetTitle": target_title,
                "reason": report.get("reason", "-"),
                "description": report.get("description", ""),
                "status": report.get("status", "pending"),
                "result": report.get("result", ""),
                "createdAt": report.get("createdAt", ""),
                "handledAt": report.get("handledAt", ""),
            }
        },
    )


def handle_get_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """GET /api/posts/<id>"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    send_json(handler, HTTPStatus.OK, {"data": serialize_post(db, post, viewer_user_id=viewer_user_id)})


def handle_get_post_comments(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
    query: dict[str, list[str]] | None = None,
) -> None:
    """GET /api/posts/<id>/comments"""
    viewer, _ = auth_user_helper(handler, db)
    viewer_user_id = str(viewer.get("id", "")) if viewer else ""
    sort_by = _normalize_comment_sort(
        ((query or {}).get("sort", ["latest"])[0] if query is not None else "latest")
    )

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    rows = [
        _serialize_comment(db, comment, viewer_user_id, post)
        for comment in list_comments(
            db,
            post_id=post_id,
            viewer_user_id=viewer_user_id,
        )
    ]

    like_count_by_comment: dict[str, int] = {}
    for like in db.get("likes", []):
        comment_id = str(like.get("commentId", "")).strip()
        if not comment_id:
            continue
        like_count_by_comment[comment_id] = like_count_by_comment.get(comment_id, 0) + 1

    def _to_int(value: Any) -> int:
        try:
            return int(value or 0)
        except (TypeError, ValueError):
            return 0

    for row in rows:
        row_comment_id = str(row.get("id", "")).strip()
        computed = like_count_by_comment.get(row_comment_id)
        if computed is None:
            computed = max(0, _to_int(row.get("likeCount", 0)))
        row["likeCount"] = computed

    if sort_by == "hot":
        rows.sort(
            key=lambda row: (
                max(0, _to_int(row.get("likeCount", 0))),
                str(row.get("createdAt", "") or ""),
                str(row.get("id", "") or ""),
            ),
            reverse=True,
        )
    else:
        rows.sort(
            key=lambda row: (
                str(row.get("createdAt", "") or ""),
                str(row.get("id", "") or ""),
            ),
            reverse=True,
        )
    send_json(handler, HTTPStatus.OK, {"data": rows})


# ===========================================================================
# POST handlers
# ===========================================================================


def handle_create_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/posts"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法发帖")
        return

    body = read_json_body(handler)
    title = str(body.get("title", "")).strip()
    raw_content = str(body.get("content", "")).strip()
    content_format = _normalize_post_content_format(body.get("contentFormat"))
    markdown_source = ""
    content = raw_content
    if content_format == "markdown":
        markdown_source = str(body.get("markdownSource", raw_content)).strip() or raw_content
        content = _markdown_to_plain_text(markdown_source) or markdown_source
    legacy_channel = str(body.get("channel", "")).strip()
    section_type = str(body.get("sectionType", "")).strip().lower()
    section_id = str(body.get("sectionId", "")).strip()
    section_name = str(body.get("sectionName", "")).strip()
    publisher_type = str(body.get("publisherType", "user")).strip().lower() or "user"
    publisher_club_id = str(body.get("publisherClubId", body.get("clubId", ""))).strip()
    raw_tags = body.get("tags", [])
    tags = [str(tag).strip() for tag in raw_tags if str(tag).strip()] if isinstance(raw_tags, list) else []
    for tag in _extract_inline_tags(title, raw_content):
        if tag not in tags:
            tags.append(tag)
    if legacy_channel and legacy_channel != "综合" and legacy_channel not in tags:
        tags.append(legacy_channel)
    raw_image_ids = body.get("imageUploadIds") or body.get("imageIds") or []
    image_ids = [str(image_id).strip() for image_id in raw_image_ids if str(image_id).strip()] if isinstance(raw_image_ids, list) else []
    use_anonymous_alias = bool(body.get("useAnonymousAlias"))
    anonymous_alias = sanitize_alias(str(body.get("anonymousAlias", "")).strip(), fallback="")
    status = str(body.get("status", "ongoing")).strip().lower()
    visibility = normalize_post_visibility(body.get("visibility"))
    pin_duration_minutes = parse_pin_duration_minutes(body.get("pinDurationMinutes"))
    allow_comment = parse_bool(body.get("allowComment"))
    allow_dm = parse_bool(body.get("allowDm"))

    if not raw_content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "帖子内容不能为空")
        return
    if len(title) > _MAX_POST_TITLE_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"帖子标题不能超过 {_MAX_POST_TITLE_CHARS} 个字符")
        return
    if len(content) > _MAX_POST_CONTENT_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"帖子正文不能超过 {_MAX_POST_CONTENT_CHARS} 个字符")
        return
    if len(markdown_source) > _MAX_MARKDOWN_SOURCE_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"Markdown 不能超过 {_MAX_MARKDOWN_SOURCE_CHARS} 个字符")
        return
    if len(tags) > _MAX_TAGS or any(len(tag) > _MAX_TAG_CHARS for tag in tags):
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签数量或长度超出限制")
        return
    if len(image_ids) > _MAX_POST_IMAGES:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"每条帖子最多 {_MAX_POST_IMAGES} 张图片")
        return
    if content_format == "markdown":
        unsafe_images = [
            url for url in _MARKDOWN_IMAGE_RE.findall(markdown_source)
            if not url.lower().startswith("/api/storage/")
        ]
        if unsafe_images:
            json_error(handler, HTTPStatus.BAD_REQUEST, "Markdown 图片必须使用本站上传地址")
            return
    if section_type and section_type not in {"general", "college", "club"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的分区类型")
        return
    if section_type == "college":
        student_id = str(user.get("studentId", "")).strip().lower()
        trusted_section_id = _globals.AUTH_STUDENT_COLLEGE_SECTIONS.get(
            student_id,
            "",
        )
        if not trusted_section_id:
            json_error(handler, HTTPStatus.FORBIDDEN, "学院归属尚未由学校身份源确认")
            return
        section = next(
            (
                row for row in db.get("sections", [])
                if section_id in {
                    str(row.get("id", "")).strip(),
                    str(row.get("sectionId", "")).strip(),
                }
                and str(row.get("sectionType", "")).strip().lower() == "college"
                and bool(row.get("enabled", True))
            ),
            None,
        )
        if section is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "学院分区不存在或已停用")
            return
        canonical_section_name = str(
            section.get("sectionName") or section.get("name") or "",
        ).strip()
        canonical_section_id = str(
            section.get("sectionId") or section.get("id") or "",
        ).strip()
        if trusted_section_id not in {
            canonical_section_id,
            str(section.get("id", "")).strip(),
        }:
            json_error(handler, HTTPStatus.FORBIDDEN, "只能在本学院分区发帖")
            return
        section_id = canonical_section_id
        section_name = canonical_section_name
    if publisher_type not in {"user", "club"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的发布身份")
        return
    if publisher_type == "club":
        club = next(
            (
                row for row in db.get("clubs", [])
                if str(row.get("id", "")).strip() == publisher_club_id
                and str(row.get("status", "active")).strip().lower() == "active"
            ),
            None,
        )
        member = next(
            (
                row for row in db.get("clubMembers", [])
                if str(row.get("clubId", "")) == publisher_club_id
                and str(row.get("userId", "")) == str(user.get("id", ""))
                and str(row.get("role", "")) in {"owner", "manager"}
            ),
            None,
        )
        if club is None or member is None:
            json_error(handler, HTTPStatus.FORBIDDEN, "仅社团负责人可使用社团名义发布")
            return
        if section_type == "club":
            club_section_id = str(club.get("sectionId", "")).strip()
            section = next(
                (
                    row for row in db.get("sections", [])
                    if str(row.get("sectionType", "")).strip().lower() == "club"
                    and bool(row.get("enabled", True))
                    and club_section_id in {
                        str(row.get("id", "")).strip(),
                        str(row.get("sectionId", "")).strip(),
                    }
                ),
                None,
            )
            submitted_section_ids = {section_id}
            if section is not None:
                submitted_section_ids = {
                    str(section.get("id", "")).strip(),
                    str(section.get("sectionId", "")).strip(),
                }
            if section is None or section_id not in submitted_section_ids:
                json_error(handler, HTTPStatus.FORBIDDEN, "只能在本社团分区发布社团帖子")
                return
            section_id = str(
                section.get("sectionId") or section.get("id") or "",
            ).strip()
            section_name = str(
                section.get("sectionName") or section.get("name") or club.get("name") or "",
            ).strip()
    elif section_type == "club":
        json_error(handler, HTTPStatus.FORBIDDEN, "社团分区仅允许负责人使用社团身份发布")
        return
    if pin_duration_minutes is not None and not is_level_one_user(user):
        json_error(handler, HTTPStatus.FORBIDDEN, "仅一级用户可在发帖时直接置顶")
        return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="post",
        setting_key="postRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["postRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="发帖",
            retry_after_seconds=retry_after,
        )
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "post")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="发帖",
            retry_after_seconds=ip_retry_after,
        )
        return

    risk_marked, high_risk, risk_reasons = assess_text_risk(
        db,
        "\n字段分隔\n".join([title, raw_content, " ".join(tags)]),
        block_on_match=True,
    )
    if high_risk:
        prohibited_categories = [
            reason.removeprefix("禁止内容类别: ").strip()
            for reason in risk_reasons
            if reason.startswith("禁止内容类别: ")
        ]
        category_text = "、".join(prohibited_categories)
        message = (
            f"内容包含平台禁止发布的{category_text}内容，请修改后重试"
            if category_text
            else "内容命中敏感词，禁止发布，请修改后重试"
        )
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            message,
            data={
                "code": "POST_CONTENT_REJECTED",
                "categories": prohibited_categories,
            },
        )
        add_audit_log(db, user["id"], "risk_block_post", ";".join(risk_reasons))
        save_db(db)
        return

    author_alias = user_nickname(user)
    if use_anonymous_alias:
        author_alias = anonymous_alias or "匿名同学"
    has_image = False
    picked_uploads: list[dict[str, Any]] = []
    for img_id in image_ids:
        upload = next((u for u in db.get("mediaUploads", []) if u.get("id") == img_id), None)
        if upload is None or upload.get("deleted"):
            json_error(handler, HTTPStatus.BAD_REQUEST, f"图片不存在: {img_id}")
            return
        if upload.get("uploaderId") != user["id"]:
            json_error(handler, HTTPStatus.FORBIDDEN, f"图片无权限绑定: {img_id}")
            return
        if upload.get("postId"):
            json_error(handler, HTTPStatus.BAD_REQUEST, f"图片已绑定帖子: {img_id}")
            return
        picked_uploads.append(upload)
        if str(upload.get("status", "approved")).strip().lower() != "rejected":
            has_image = True

    mentions = resolve_mentions(db, user["id"], f"{title}\n{raw_content}", body.get("mentionUserIds"))
    post = {
        "id": next_id(db, "post", "p"),
        "title": title,
        "content": content,
        "contentFormat": content_format,
        "markdownSource": markdown_source,
        "channel": "",
        "tags": tags,
        "hasImage": has_image or bool(picked_uploads),
        "imageIds": image_ids,
        "status": status if status in {"ongoing", "resolved", "closed"} else "ongoing",
        "allowComment": True if allow_comment is None else allow_comment,
        "allowDm": (not use_anonymous_alias) if allow_dm is None else allow_dm,
        "visibility": visibility,
        "authorAlias": _globals.sanitize_alias(author_alias, fallback="匿名同学"),
        "authorId": user["id"],
        "pinStartedAt": "",
        "pinExpiresAt": "",
        "pinDurationMinutes": 0,
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
        "deleted": False,
        "reviewStatus": "pending" if risk_marked else "approved",
        "riskMarked": risk_marked,
        "isAnonymous": use_anonymous_alias,
        "sectionType": section_type,
        "sectionId": section_id,
        "sectionName": section_name,
        "publisherType": publisher_type,
        "publisherClubId": publisher_club_id if publisher_type == "club" else "",
        "shareCount": 0,
        "mentions": mentions,
        "editedAt": "",
    }
    if risk_marked:
        from handlers._radio_handler import add_moderation_task

        add_moderation_task(
            db,
            target_type="post",
            target_id=post["id"],
            title=title or content[:40],
            content=content,
            risk_reasons=risk_reasons,
        )
    if pin_duration_minutes is not None:
        apply_post_pin(
            post,
            duration_minutes=pin_duration_minutes,
            started_at=post["createdAt"],
        )
    db["posts"].append(post)
    for upload in picked_uploads:
        upload["postId"] = post["id"]
    recalc_post_has_image(db, post["id"])
    # Only once others can read it: a pending or private post would notify
    # people about something they cannot open.
    if not risk_marked and visibility != "private":
        notify_mentions(
            db,
            mentions,
            author=user,
            anonymous=use_anonymous_alias,
            actor_alias=post["authorAlias"],
            snippet=title or content,
            post_id=post["id"],
        )
    add_audit_log(db, user["id"], "create_post", f"发布帖子 {post['id']}")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": serialize_post(
                db,
                post,
                include_unapproved_images=True,
                viewer_user_id=user["id"],
            )
        },
    )


def handle_create_comment(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/comments"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if user.get("muted"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被禁言，暂时无法评论")
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_interact_with_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not post.get("allowComment", True):
        json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子已关闭评论")
        return

    body = read_json_body(handler)
    comment_content = str(body.get("content", "")).strip()
    if not comment_content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "评论内容不能为空")
        return
    if len(comment_content) > _MAX_COMMENT_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"评论内容不能超过 {_MAX_COMMENT_CHARS} 个字符")
        return
    parent_id = str(body.get("parentId", body.get("replyToId", ""))).strip()
    if parent_id:
        parent_comment = next(
            (
                comment
                for comment in db.get("comments", [])
                if str(comment.get("id", "")).strip() == parent_id
                and not comment.get("deleted")
            ),
            None,
        )
        if parent_comment is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "回复的评论不存在或已被删除")
            return
        if str(parent_comment.get("postId", "")).strip() != post_id:
            json_error(handler, HTTPStatus.BAD_REQUEST, "不能回复其他帖子的评论")
            return
        parent_status = (
            str(parent_comment.get("reviewStatus", "approved")).strip().lower()
            or "approved"
        )
        if parent_status not in {"approved", "resolved"}:
            json_error(handler, HTTPStatus.BAD_REQUEST, "回复的评论尚未通过审核")
            return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="comment",
        setting_key="commentRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["commentRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="评论",
            retry_after_seconds=retry_after,
        )
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "comment")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="评论",
            retry_after_seconds=ip_retry_after,
        )
        return

    risk_marked, high_risk, risk_reasons = assess_text_risk(db, comment_content)
    if high_risk:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"评论触发高风险风控：{'; '.join(risk_reasons)}",
        )
        add_audit_log(db, user["id"], "risk_block_comment", ";".join(risk_reasons))
        save_db(db)
        return

    comment_anonymous = _comments_as_anonymous_author(db, post, user["id"])
    author_alias = _globals.sanitize_alias(
        str(post.get("authorAlias", "")) if comment_anonymous else user_nickname(user),
        fallback="匿名同学",
    )
    comment = {
        "id": next_id(db, "comment", "cm"),
        "postId": post_id,
        "userId": user["id"],
        "authorAlias": author_alias,
        "content": comment_content,
        "likeCount": 0,
        "createdAt": now_iso(),
        "deleted": False,
        "reviewStatus": "pending" if risk_marked else "approved",
        "riskMarked": risk_marked,
        "isAnonymous": comment_anonymous,
        "parentId": parent_id,
        "mentions": resolve_mentions(db, user["id"], comment_content, body.get("mentionUserIds")),
        "editedAt": "",
    }
    if risk_marked:
        from handlers._radio_handler import add_moderation_task

        add_moderation_task(
            db,
            target_type="comment",
            target_id=comment["id"],
            title="疑似敏感评论",
            content=comment_content,
            risk_reasons=risk_reasons,
        )
    db["comments"].append(comment)

    post_author_id = str(post.get("authorId", "")).strip()
    parent_author_id = (
        str(parent_comment.get("userId", "")).strip() if parent_id else ""
    )
    # An anonymous comment carries no actor id (it would name the author), so
    # create_notification cannot see a block; check it with the real sender.
    if (
        not risk_marked
        and parent_author_id
        and parent_author_id != user["id"]
        and not is_user_blocked(db, parent_author_id, user["id"])
    ):
        create_notification(
            db,
            user_id=parent_author_id,
            notification_type="reply",
            title="收到新回复",
            content=comment_content[:100],
            related_type="comment",
            related_id=comment["id"],
            post_id=post_id,
            actor_id="" if comment_anonymous else user["id"],
            actor_alias=author_alias,
        )
    # A post author replied to in their own thread already has the reply
    # notification, which is the more specific of the two.
    if (
        not risk_marked
        and post_author_id
        and post_author_id != user["id"]
        and post_author_id != parent_author_id
        and not is_user_blocked(db, post_author_id, user["id"])
    ):
        create_notification(
            db,
            user_id=post_author_id,
            notification_type="comment",
            title="收到新评论",
            content=comment_content[:100],
            related_type="post",
            related_id=post_id,
            post_id=post_id,
            actor_id="" if comment_anonymous else user["id"],
            actor_alias=author_alias,
        )

    if not risk_marked:
        already_told = {parent_author_id, post_author_id}
        notify_mentions(
            db,
            [m for m in comment["mentions"] if m["userId"] not in already_told],
            author=user,
            anonymous=comment_anonymous,
            actor_alias=author_alias,
            snippet=comment_content,
            post_id=post_id,
            comment_id=comment["id"],
        )
    add_audit_log(db, user["id"], "create_comment", f"在帖子 {post_id} 下发表评论 {comment['id']}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_comment(db, comment, viewer_user_id=user["id"], post=post)})


def handle_toggle_like(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/like  body: {"liked": bool} (omitted: toggle)"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if not _enforce_interaction_rate_limit(handler, db, user):
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_interact_with_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    existing = next(
        (x for x in db["likes"] if x.get("userId") == user["id"] and x.get("postId") == post_id and not x.get("commentId")),
        None,
    )
    requested = _requested_state(handler, "liked")
    liked = existing is None if requested is None else requested
    if liked and existing is None:
        db["likes"].append({"userId": user["id"], "postId": post_id, "createdAt": now_iso()})
        post_author_id = str(post.get("authorId", "")).strip()
        if post_author_id and post_author_id != user["id"]:
            create_notification(
                db,
                user_id=post_author_id,
                notification_type="like",
                title="收到点赞",
                content=str(post.get("title", "")).strip()[:50],
                related_type="post",
                related_id=post_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "like_post", f"点赞帖子 {post_id}")
    elif not liked and existing is not None:
        db["likes"] = [x for x in db["likes"] if not (
            x.get("userId") == user["id"]
            and x.get("postId") == post_id
            and not x.get("commentId")
        )]
        add_audit_log(db, user["id"], "unlike_post", f"取消点赞帖子 {post_id}")

    like_count = sum(
        1
        for like in db["likes"]
        if like.get("postId") == post_id and not like.get("commentId")
    )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"liked": liked, "likeCount": like_count}})


def handle_toggle_comment_like(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    comment_id: str,
    requested: bool | None = None,
) -> None:
    """POST /api/comments/<id>/like  body: {"liked": bool} (omitted: toggle)

    DELETE /api/comments/<id>/like passes requested=False.
    """
    user = _require_auth(handler, db)
    if user is None:
        return
    if not _enforce_interaction_rate_limit(handler, db, user):
        return

    comment = next(
        (c for c in db["comments"] if c.get("id") == comment_id and not c.get("deleted")),
        None,
    )
    if comment is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return
    post = next(
        (
            row
            for row in db.get("posts", [])
            if str(row.get("id", "")).strip()
            == str(comment.get("postId", "")).strip()
            and not row.get("deleted")
        ),
        None,
    )
    if post is None or not _can_interact_with_post(
        post,
        str(user.get("id", "")),
    ):
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return
    comment_status = (
        str(comment.get("reviewStatus", "approved")).strip().lower()
        or "approved"
    )
    if comment_status not in {"approved", "resolved"}:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return

    existing = next(
        (x for x in db["likes"]
         if x.get("userId") == user["id"]
         and x.get("commentId") == comment_id),
        None,
    )
    if requested is None:
        requested = _requested_state(handler, "liked")
    liked = existing is None if requested is None else requested
    if liked and existing is None:
        db["likes"].append({"userId": user["id"], "commentId": comment_id, "createdAt": now_iso()})
        comment_author_id = str(comment.get("userId", "")).strip()
        if comment_author_id and comment_author_id != user["id"]:
            post_id = str(comment.get("postId", "")).strip()
            create_notification(
                db,
                user_id=comment_author_id,
                notification_type="like",
                title="收到点赞",
                content=str(comment.get("content", "")).strip()[:50],
                related_type="comment",
                related_id=comment_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "like_comment", f"点赞评论 {comment_id}")
    elif not liked and existing is not None:
        db["likes"] = [x for x in db["likes"] if x is not existing]
        add_audit_log(db, user["id"], "unlike_comment", f"取消点赞评论 {comment_id}")

    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"liked": liked}})


def handle_toggle_favorite(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/favorite  body: {"favorited": bool} (omitted: toggle)"""
    user = _require_auth(handler, db)
    if user is None:
        return
    if not _enforce_interaction_rate_limit(handler, db, user):
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_interact_with_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    existing = next(
        (f for f in db["favorites"] if f.get("userId") == user["id"] and f.get("postId") == post_id),
        None,
    )
    requested = _requested_state(handler, "favorited")
    favorited = existing is None if requested is None else requested
    if favorited and existing is None:
        db["favorites"].append({"userId": user["id"], "postId": post_id, "createdAt": now_iso()})
        post_author_id = str(post.get("authorId", "")).strip()
        if post_author_id and post_author_id != user["id"]:
            create_notification(
                db,
                user_id=post_author_id,
                notification_type="favorite",
                title="收到收藏",
                content=str(post.get("title", "")).strip()[:50],
                related_type="post",
                related_id=post_id,
                post_id=post_id,
                actor_id=user["id"],
                actor_alias=_globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
            )
        add_audit_log(db, user["id"], "favorite_post", f"收藏帖子 {post_id}")
    elif not favorited and existing is not None:
        db["favorites"] = [f for f in db["favorites"] if not (f.get("userId") == user["id"] and f.get("postId") == post_id)]
        add_audit_log(db, user["id"], "unfavorite_post", f"取消收藏帖子 {post_id}")

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
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"favorited": favorited, "likeCount": like_count, "favoriteCount": favorite_count}})


def _force_logout_for_view_abuse(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    viewer: dict[str, Any],
    breaches: int,
) -> None:
    """Drop every session for a viewer that keeps exhausting the hourly ceiling.

    All of the account's tokens go, not just the calling one, so the account is
    signed out on every client rather than moving to whichever one still holds
    a token. Answered 401 because that is what the clients already treat as a
    dead session, and after this call it is literally true.
    """
    viewer_user_id = str(viewer.get("id", ""))
    revoked = 0
    for token, session_user_id in list(db.get("sessions", {}).items()):
        if session_user_id == viewer_user_id:
            db["sessions"].pop(token, None)
            revoked += 1
    # The breaches have been acted on. Leaving them would sign the account out
    # again on its next request, before it could accumulate anything new.
    clear_rate_limit_breaches(viewer_user_id, "view_hourly_breach")
    detail = (
        f"{_globals.VIEW_BREACH_WINDOW_SECONDS // 3600} 小时内第 {breaches} 次触达每小时浏览上限，"
        f"已撤销 {revoked} 个会话"
    )
    add_audit_log(db, viewer_user_id, "force_logout_view_abuse", detail)
    save_db(db)
    logger.warning(
        "forced logout after repeated view rate limit breaches",
        extra={"structured": {
            "event": "view_abuse_force_logout",
            "userId": viewer_user_id,
            "breaches": breaches,
            "windowSeconds": _globals.VIEW_BREACH_WINDOW_SECONDS,
            "revokedSessions": revoked,
            "clientIp": get_client_ip(handler),
        }},
    )
    json_error(
        handler,
        HTTPStatus.UNAUTHORIZED,
        "浏览行为异常，账号已被强制登出，请重新登录",
    )


def handle_increment_view(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/view"""
    viewer = _require_auth(handler, db)
    if viewer is None:
        return
    viewer_user_id = str(viewer.get("id", ""))
    # Every client reaches this one route, so both ceilings and the escalation
    # apply identically to the miniprogram, the app and the web build.
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=viewer_user_id,
        action="view",
        setting_key="viewRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["viewRateLimit"]),
    )
    if not allowed:
        # A request refused by the burst ceiling was never served, so it must
        # not also spend the hourly budget or count toward the escalation.
        send_rate_limit_error(
            handler,
            action_text="浏览帖子",
            retry_after_seconds=retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=viewer_user_id,
        action="view_hourly",
        setting_key="viewHourlyRateLimit",
        default_limit=int(_globals.DEFAULT_SETTINGS["viewHourlyRateLimit"]),
    )
    if not allowed:
        breaches = record_rate_limit_breach(viewer_user_id, "view_hourly_breach")
        if breaches >= _globals.VIEW_BREACH_FORCE_LOGOUT_THRESHOLD:
            _force_logout_for_view_abuse(handler, db, viewer, breaches)
            return
        send_rate_limit_error(
            handler,
            action_text="浏览帖子",
            retry_after_seconds=retry_after,
        )
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if not _can_view_post(post, viewer_user_id):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    # The author may open their own pending / rejected post; that is not a view.
    if _can_interact_with_post(post, viewer_user_id):
        post["viewCount"] = max(0, int(post.get("viewCount", 0) or 0)) + 1
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "viewCount": max(0, int(post.get("viewCount", 0) or 0))}})


def handle_pin_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """POST /api/posts/<id>/pin-request"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能为自己的帖子申请置顶")
        return

    body = read_json_body(handler)
    duration_minutes = parse_pin_duration_minutes(body.get("durationMinutes", 1440))
    if duration_minutes is None:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请选择有效的置顶时长")
        return
    reason = str(body.get("reason", "")).strip()

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "pin_request")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="置顶申请",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="pin_request",
        setting_key="pinRequestRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["pinRequestRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="置顶申请",
            retry_after_seconds=retry_after,
        )
        return

    if is_level_one_user(user):
        if is_post_pin_active(post):
            json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子当前已在置顶中")
            return
        apply_post_pin(post, duration_minutes=duration_minutes)
        add_audit_log(
            db,
            user["id"],
            "direct_pin_post",
            f"{post_id}:{duration_minutes}",
        )
        save_db(db)
        send_json(
            handler,
            HTTPStatus.OK,
            {
                "message": "帖子已置顶",
                "data": {
                    "mode": "direct",
                    "post": serialize_post(
                        db,
                        post,
                        viewer_user_id=user["id"],
                    ),
                },
            },
        )
        return

    if is_post_pin_active(post):
        json_error(handler, HTTPStatus.BAD_REQUEST, "该帖子当前已在置顶中")
        return

    existing = latest_pending_post_pin_request_for_post(db, post_id)
    if existing is not None:
        json_error(handler, HTTPStatus.CONFLICT, "该帖子已有待处理的置顶申请")
        return

    request = {
        "id": next_id(db, "pinRequest", "pin"),
        "postId": post_id,
        "userId": str(user.get("id", "")).strip(),
        "durationMinutes": duration_minutes,
        "reason": reason,
        "status": "pending",
        "adminNote": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db.setdefault("postPinRequests", []).append(request)
    add_audit_log(
        db,
        user["id"],
        "submit_post_pin_request",
        f"{request['id']}:{post_id}:{duration_minutes}",
    )
    save_db(db)
    send_json(
        handler,
        HTTPStatus.CREATED,
        {
            "message": "置顶申请已提交，请等待管理员审核",
            "data": {
                "mode": "pending",
                "request": serialize_admin_post_pin_request(db, request),
            },
        },
    )


# The mini program sends the first five; web and Android send the second
# list. Both are accepted so neither client's reports bounce.
_REPORT_REASONS = frozenset({
    "广告引流", "人身攻击", "违规内容", "垃圾信息", "其他",
    "垃圾广告", "违法违规", "色情低俗", "虚假信息", "侵犯隐私",
})


def handle_submit_report(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/reports"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_type = str(body.get("targetType", "")).strip().lower()
    target_id = str(body.get("targetId", "")).strip()
    reason = str(body.get("reason", "")).strip()
    description = str(body.get("description", "")).strip()

    if target_type not in {"post", "comment", "user"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "targetType 必须是 post、comment 或 user")
        return
    if not target_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标 ID")
        return
    if reason not in _REPORT_REASONS:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的举报原因")
        return

    if target_type == "user":
        # A person, reported from their profile.
        if target_id == str(user.get("id", "")):
            json_error(handler, HTTPStatus.BAD_REQUEST, "不能举报自己")
            return
        target_user = find_user_by_id(db, target_id)
        if target_user is None or target_user.get("deleted"):
            json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
            return
    elif target_type == "post":
        post = next(
            (p for p in db["posts"] if p.get("id") == target_id and not p.get("deleted")),
            None,
        )
        if post is None or not _can_view_post(post, user["id"]):
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return
    else:
        comment = next(
            (c for c in db["comments"] if c.get("id") == target_id and not c.get("deleted")),
            None,
        )
        if comment is None:
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return
        comment_post = next(
            (
                p for p in db["posts"]
                if p.get("id") == comment.get("postId") and not p.get("deleted")
            ),
            None,
        )
        if comment_post is None or not _can_view_post(comment_post, user["id"]):
            json_error(handler, HTTPStatus.NOT_FOUND, "目标内容不存在")
            return

    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="report",
        setting_key="reportRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["reportRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="举报",
            retry_after_seconds=retry_after,
        )
        return

    report = {
        "id": next_id(db, "report", "r"),
        "userId": user["id"],
        "reporterAlias": _globals.sanitize_alias(user_nickname(user), fallback="匿名同学"),
        "targetType": target_type,
        "targetId": target_id,
        "reason": reason,
        "description": description,
        "status": "pending",
        "result": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["reports"].append(report)
    add_audit_log(db, user["id"], "submit_report", f"举报 {target_type} {target_id}: {reason}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": report["id"]}})


def handle_my_latest_appeal(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/appeals/mine

    A banned caller needs to know whether a request is still waiting, was
    approved, or was turned down -- the last case is what sends them to the
    mailbox instead of resubmitting.
    """
    user = _require_auth(handler, db)
    if user is None:
        return
    user_id = str(user.get("id", "")).strip()
    rows = [
        row
        for row in db.get("appeals", [])
        if str(row.get("userId", "")).strip() == user_id
    ]
    rows.sort(
        key=lambda item: (str(item.get("createdAt", "")), str(item.get("id", ""))),
        reverse=True,
    )
    latest = rows[0] if rows else None
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                # The admin note is written by a human about this account, so it
                # is shown back to its owner rather than kept internal.
                "appeal": None if latest is None else {
                    "id": str(latest.get("id", "")),
                    "appealType": str(latest.get("appealType", "")),
                    "title": str(latest.get("title", "")),
                    "content": str(latest.get("content", "")),
                    "status": str(latest.get("status", "pending")),
                    "adminNote": str(latest.get("adminNote", "")),
                    "createdAt": str(latest.get("createdAt", "")),
                    "handledAt": str(latest.get("handledAt", "")),
                },
                "banned": bool(user.get("banned")),
                # One in-app appeal per ban; clients show the form only when
                # this is true (handle_submit_appeal enforces the same rule).
                "canSubmit": bool(user.get("banned"))
                and latest_pending_appeal_for_user(db, user_id) is None
                and not ban_appeal_used(db, user),
                "supportEmail": _globals.SUPPORT_CONTACT_EMAIL,
            }
        },
    )


def handle_submit_appeal(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/appeals"""
    body = read_json_body(handler)
    email = str(body.get("email", "")).strip().lower()
    appeal_type = str(body.get("appealType", "")).strip().lower()
    content = str(body.get("content", "")).strip()
    password = str(body.get("password", "")).strip()

    if not is_campus_email(email):
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持西电学生邮箱（@stu.xidian.edu.cn）")
        return
    if appeal_type not in {"account_restore", "ban_revoke", "wrong_punishment", "account_cancel_reject"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的申诉类型")
        return
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "申诉内容不能为空")
        return
    if len(content) > 4000:
        json_error(handler, HTTPStatus.BAD_REQUEST, "申诉内容不能超过 4000 字")
        return
    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "appeal")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="提交申诉",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=f"appeal::{email}",
        action="appeal",
        setting_key="appealRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["appealRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="提交申诉",
            retry_after_seconds=retry_after,
        )
        return

    user = find_user_by_email(db, email, include_deleted=True)
    session_user, _ = auth_user_helper(handler, db)
    session_matches = bool(
        user
        and session_user
        and str(session_user.get("id", "")).strip()
        == str(user.get("id", "")).strip()
    )
    password_matches = bool(
        user
        and password
        and verify_password(str(user.get("password", "")), password)
    )
    if user is None or not (session_matches or password_matches):
        # Signed in as someone else: a 401 would tell the client its own
        # (valid) session is dead and sign it out.
        if session_user is not None:
            json_error(handler, HTTPStatus.FORBIDDEN, "只能为当前登录的账号申诉")
        else:
            json_error(handler, HTTPStatus.UNAUTHORIZED, "账号凭证无效")
        return
    if appeal_type == "account_restore" and not user.get("deleted"):
        json_error(handler, HTTPStatus.CONFLICT, "账号当前未注销，无需恢复")
        return
    if appeal_type != "account_restore" and user.get("deleted"):
        json_error(handler, HTTPStatus.BAD_REQUEST, "已注销账号只能提交账号恢复申诉")
        return
    if latest_pending_appeal_for_user(db, str(user.get("id", ""))) is not None:
        json_error(handler, HTTPStatus.CONFLICT, "该账号已有待处理的申诉")
        return
    if appeal_type in BAN_APPEAL_TYPES and user.get("banned") and ban_appeal_used(db, user):
        json_error(
            handler,
            HTTPStatus.CONFLICT,
            f"本次封禁的站内申诉已用完，请用本人校园邮箱发送至 {_globals.SUPPORT_CONTACT_EMAIL}",
        )
        return

    appeal_titles = {
        "account_restore": "账号恢复申诉",
        "ban_revoke": "解除封禁申诉",
        "wrong_punishment": "处罚异议申诉",
        "account_cancel_reject": "注销处理异议",
    }

    appeal = {
        "id": next_id(db, "appeal", "ap"),
        "userId": str(user.get("id", "")),
        "userEmail": email,
        "studentId": str(user.get("studentId", "")).strip(),
        "userNickname": user_nickname(user),
        "appealType": appeal_type,
        "targetType": "account",
        "targetId": str(user.get("id", "")),
        "title": appeal_titles[appeal_type],
        "content": content,
        "status": "pending",
        "adminNote": "",
        "createdAt": now_iso(),
        "handledAt": "",
        "handledBy": "",
    }
    db["appeals"].append(appeal)
    add_audit_log(db, user["id"], "submit_appeal", f"提交申诉 {appeal_type}: {content[:30]}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": appeal["id"]}})


# ===========================================================================
# PATCH handlers
# ===========================================================================


def handle_update_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """PATCH /api/posts/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能编辑自己的帖子")
        return

    body = read_json_body(handler)
    edits_text = any(key in body for key in ("title", "content", "imageUploadIds"))
    if "status" in body:
        new_status = str(body.get("status", "")).strip().lower()
        if new_status not in {"ongoing", "open", "resolved", "closed"}:
            json_error(handler, HTTPStatus.BAD_REQUEST, "无效的帖子状态")
            return
        post["status"] = "ongoing" if new_status == "open" else new_status
    elif not edits_text:
        json_error(handler, HTTPStatus.BAD_REQUEST, "无效的帖子状态")
        return

    removed_object_keys: list[str] = []
    if edits_text:
        result = _apply_post_edit(handler, db, user, post, body)
        if result is None:
            return
        removed_object_keys = result
    post["updatedAt"] = now_iso()
    add_audit_log(
        db,
        user["id"],
        "edit_post" if edits_text else "update_post_status",
        f"编辑帖子 {post_id}" if edits_text else f"更新帖子状态为 {post['status']}",
    )
    save_db(db)
    # After the save: a failure here only leaves unreachable files behind
    # (their uploads are already marked deleted), never a post pointing at
    # images that are gone.
    if removed_object_keys:
        try:
            delete_objects_with_backups(_globals.OBJECT_STORAGE, removed_object_keys)
        except Exception:
            logger.warning("could not delete images removed from post %s", post_id, exc_info=True)

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": serialize_post(db, post, viewer_user_id=user["id"], include_unapproved_images=True)},
    )


def _apply_post_edit(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user: dict[str, Any],
    post: dict[str, Any],
    body: dict[str, Any],
) -> list[str] | None:
    """Title, text and images of an existing post, with the same checks as
    creating one.  Returns the storage keys of images taken off the post
    (to delete once saved), or None after sending the error response.

    The edited text goes through moderation again: a risky edit sends the
    post back to review, where only its author can see it.
    """
    title = str(body.get("title", post.get("title", ""))).strip()
    raw_content = str(body.get("content", post.get("content", ""))).strip()
    if not raw_content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "帖子内容不能为空")
        return None
    if len(title) > _MAX_POST_TITLE_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"帖子标题不能超过 {_MAX_POST_TITLE_CHARS} 个字符")
        return None
    if len(raw_content) > _MAX_POST_CONTENT_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"帖子正文不能超过 {_MAX_POST_CONTENT_CHARS} 个字符")
        return None

    current_uploads = [
        u for u in db.get("mediaUploads", [])
        if str(u.get("postId", "")).strip() == post["id"] and not u.get("deleted")
    ]
    image_ids: list[str] | None = None
    if "imageUploadIds" in body:
        raw_ids = body.get("imageUploadIds")
        if not isinstance(raw_ids, list):
            json_error(handler, HTTPStatus.BAD_REQUEST, "imageUploadIds 必须是数组")
            return None
        image_ids = [str(i).strip() for i in raw_ids if str(i).strip()]
        if len(image_ids) > _MAX_POST_IMAGES:
            json_error(handler, HTTPStatus.BAD_REQUEST, f"每条帖子最多 {_MAX_POST_IMAGES} 张图片")
            return None
        for img_id in image_ids:
            upload = next((u for u in db.get("mediaUploads", []) if u.get("id") == img_id), None)
            if upload is None or upload.get("deleted"):
                json_error(handler, HTTPStatus.BAD_REQUEST, f"图片不存在: {img_id}")
                return None
            if upload.get("uploaderId") != user["id"]:
                json_error(handler, HTTPStatus.FORBIDDEN, f"图片无权限绑定: {img_id}")
                return None
            if upload.get("postId") and upload.get("postId") != post["id"]:
                json_error(handler, HTTPStatus.BAD_REQUEST, f"图片已绑定帖子: {img_id}")
                return None

    tags = [tag for tag in post.get("tags", []) if tag not in _extract_inline_tags(post.get("title"), post.get("content"))]
    for tag in _extract_inline_tags(title, raw_content):
        if tag not in tags:
            tags.append(tag)
    if len(tags) > _MAX_TAGS or any(len(tag) > _MAX_TAG_CHARS for tag in tags):
        json_error(handler, HTTPStatus.BAD_REQUEST, "标签数量或长度超出限制")
        return None

    risk_marked, high_risk, risk_reasons = assess_text_risk(
        db,
        "\n字段分隔\n".join([title, raw_content, " ".join(tags)]),
        block_on_match=True,
    )
    if high_risk:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            "内容命中敏感词，禁止发布，请修改后重试",
            data={"code": "POST_CONTENT_REJECTED", "categories": []},
        )
        add_audit_log(db, user["id"], "risk_block_post_edit", ";".join(risk_reasons))
        save_db(db)
        return None

    old_mentioned = {m.get("userId") for m in post.get("mentions", []) if isinstance(m, dict)}
    mentions = resolve_mentions(db, user["id"], f"{title}\n{raw_content}", body.get("mentionUserIds", [
        m.get("userId") for m in post.get("mentions", []) if isinstance(m, dict)
    ]))
    post["title"] = title
    post["content"] = raw_content
    post["contentFormat"] = "plain"
    post["markdownSource"] = ""
    post["tags"] = tags
    post["mentions"] = mentions
    post["editedAt"] = now_iso()
    if risk_marked:
        post["reviewStatus"] = "pending"
        post["riskMarked"] = True
        from handlers._radio_handler import add_moderation_task

        add_moderation_task(
            db,
            target_type="post",
            target_id=post["id"],
            title=title or raw_content[:40],
            content=raw_content,
            risk_reasons=risk_reasons,
        )

    removed_object_keys: list[str] = []
    if image_ids is not None:
        kept = set(image_ids)
        for upload in db.get("mediaUploads", []):
            if upload.get("id") in kept:
                upload["postId"] = post["id"]
        # Same treatment as deleting a post's images: the objects go too.
        for upload in current_uploads:
            if upload.get("id") in kept:
                continue
            upload["deleted"] = True
            key = str(upload.get("objectKey", "")).strip()
            if key:
                removed_object_keys.append(key)
        post["imageIds"] = image_ids
        recalc_post_has_image(db, post["id"])

    if not risk_marked and str(post.get("visibility", "public")) != "private":
        notify_mentions(
            db,
            [m for m in mentions if m["userId"] not in old_mentioned],
            author=user,
            anonymous=is_post_anonymous(db, post),
            actor_alias=str(post.get("authorAlias", "")),
            snippet=title or raw_content,
            post_id=post["id"],
        )
    return removed_object_keys


def handle_update_comment(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    comment_id: str,
) -> None:
    """PATCH /api/comments/<id> — the author edits the text."""
    user = _require_auth(handler, db)
    if user is None:
        return
    comment = next(
        (c for c in db.get("comments", []) if c.get("id") == comment_id and not c.get("deleted")),
        None,
    )
    if comment is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return
    if str(comment.get("userId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能编辑自己的评论")
        return
    post = next(
        (p for p in db.get("posts", []) if p.get("id") == comment.get("postId") and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    body = read_json_body(handler)
    content = str(body.get("content", "")).strip()
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "评论内容不能为空")
        return
    if len(content) > _MAX_COMMENT_CHARS:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"评论内容不能超过 {_MAX_COMMENT_CHARS} 个字符")
        return
    risk_marked, high_risk, risk_reasons = assess_text_risk(db, content)
    if high_risk:
        json_error(handler, HTTPStatus.BAD_REQUEST, f"评论触发高风险风控：{'; '.join(risk_reasons)}")
        add_audit_log(db, user["id"], "risk_block_comment_edit", ";".join(risk_reasons))
        save_db(db)
        return

    old_mentioned = {m.get("userId") for m in comment.get("mentions", []) if isinstance(m, dict)}
    mentions = resolve_mentions(db, user["id"], content, body.get("mentionUserIds", list(old_mentioned)))
    comment["content"] = content
    comment["mentions"] = mentions
    comment["editedAt"] = now_iso()
    if risk_marked:
        comment["reviewStatus"] = "pending"
        comment["riskMarked"] = True
        from handlers._radio_handler import add_moderation_task

        add_moderation_task(
            db,
            target_type="comment",
            target_id=comment["id"],
            title="疑似敏感评论",
            content=content,
            risk_reasons=risk_reasons,
        )
    else:
        notify_mentions(
            db,
            [m for m in mentions if m["userId"] not in old_mentioned],
            author=user,
            anonymous=bool(comment.get("isAnonymous")),
            actor_alias=str(comment.get("authorAlias", "")),
            snippet=content,
            post_id=str(post["id"]),
            comment_id=comment["id"],
        )
    add_audit_log(db, user["id"], "edit_comment", f"编辑评论 {comment_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": _serialize_comment(db, comment, viewer_user_id=user["id"], post=post)})


# ===========================================================================
# DELETE handlers
# ===========================================================================


def handle_delete_post(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """DELETE /api/posts/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    if str(post.get("authorId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能删除自己的帖子")
        return

    uploads = [
        upload
        for upload in db.get("mediaUploads", [])
        if upload.get("postId") == post_id and not upload.get("deleted")
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
    except Exception:
        json_error(handler, HTTPStatus.BAD_GATEWAY, "帖子图片存储删除失败，帖子未删除")
        return

    db_snapshot = copy.deepcopy(db)
    post["deleted"] = True
    for upload in uploads:
        upload["deleted"] = True
    add_audit_log(db, user["id"], "delete_post", f"删除帖子 {post_id}")
    try:
        save_db(db)
    except Exception:
        db.clear()
        db.update(db_snapshot)
        restore_object_backups(_globals.OBJECT_STORAGE, storage_backups)
        raise
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_delete_comment(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    comment_id: str,
) -> None:
    """DELETE /api/comments/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    comment = next(
        (c for c in db["comments"] if c.get("id") == comment_id and not c.get("deleted")),
        None,
    )
    if comment is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "评论不存在或已被删除")
        return
    if str(comment.get("userId", "")).strip() != user["id"]:
        json_error(handler, HTTPStatus.FORBIDDEN, "只能删除自己的评论")
        return

    comment["deleted"] = True
    add_audit_log(db, user["id"], "delete_comment", f"删除评论 {comment_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_remove_favorite(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    post_id: str,
) -> None:
    """DELETE /api/posts/<id>/favorite"""
    user = _require_auth(handler, db)
    if user is None:
        return

    post = next(
        (p for p in db["posts"] if p.get("id") == post_id and not p.get("deleted")),
        None,
    )
    if post is None or not _can_view_post(post, user["id"]):
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return

    db["favorites"] = [
        f for f in db["favorites"]
        if not (f.get("userId") == user["id"] and f.get("postId") == post_id)
    ]
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
    add_audit_log(db, user["id"], "unfavorite_post", f"取消收藏帖子 {post_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "favorited": False, "likeCount": like_count, "favoriteCount": favorite_count}})
