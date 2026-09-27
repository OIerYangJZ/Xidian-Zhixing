"""
handlers/_social_handler.py

Reposts, @-mentions and the signed-in user's own activity:
  POST /api/posts/<id>/repost        — {reposted: bool} (omit to toggle)
  GET  /api/users/<id>/timeline      — a user's posts and reposts, newest first
  GET  /api/users/me/activity        — what the signed-in user did, newest first

Mentions are resolved when a post or comment is written (resolve_mentions)
and notified once it is visible (notify_mentions); both are called from
_post_handler.
"""
from __future__ import annotations

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any

import _globals
from helpers import consume_rate_limit, json_error, now_iso, read_json_body, send_json, send_rate_limit_error
from services import (
    auth_user as auth_user_helper,
    create_notification,
    find_user_by_id,
    is_post_anonymous,
    is_user_blocked,
    list_posts,
    save_db,
    serialize_post,
    user_nickname,
)

MENTION_LIMIT = 10
_PAGE_LIMIT_MAX = 50


def _page_args(query: dict[str, list[str]], default_limit: int = 20) -> tuple[int, int]:
    def _int(name: str, default: int) -> int:
        try:
            return int((query.get(name) or [default])[0])
        except (TypeError, ValueError):
            return default

    page = max(1, _int("page", 1))
    limit = min(_PAGE_LIMIT_MAX, max(1, _int("limit", default_limit)))
    return page, limit


def _paged(items: list[Any], page: int, limit: int) -> dict[str, Any]:
    start = (page - 1) * limit
    return {
        "items": items[start:start + limit],
        "page": page,
        "limit": limit,
        "total": len(items),
        "hasMore": start + limit < len(items),
    }


# ---------------------------------------------------------------- mentions


def resolve_mentions(db: dict[str, Any], author_id: str, text: str, requested: Any) -> list[dict[str, str]]:
    """Validate the client's mentionUserIds against the text being written.

    A mention counts only if the account exists, is not the author, neither
    side blocks the other, and "@<nickname>" actually appears in the text —
    the client cannot notify people the text does not name.
    """
    if not isinstance(requested, list):
        return []
    mentions: list[dict[str, str]] = []
    seen: set[str] = set()
    for raw_id in requested:
        user_id = str(raw_id or "").strip()
        if not user_id or user_id in seen or user_id == author_id:
            continue
        seen.add(user_id)
        user = find_user_by_id(db, user_id)
        if user is None or user.get("deleted"):
            continue
        if is_user_blocked(db, user_id, author_id) or is_user_blocked(db, author_id, user_id):
            continue
        nickname = user_nickname(user)
        if not nickname or f"@{nickname}" not in text:
            continue
        mentions.append({"userId": user_id, "nickname": nickname})
        if len(mentions) >= MENTION_LIMIT:
            break
    return mentions


def notify_mentions(
    db: dict[str, Any],
    mentions: list[dict[str, str]],
    *,
    author: dict[str, Any],
    anonymous: bool,
    actor_alias: str,
    snippet: str,
    post_id: str,
    comment_id: str = "",
) -> None:
    """One "mention" notification per mentioned account.

    Anonymous writing carries no actor id, exactly like anonymous comments,
    so the notification cannot be traced back to the author; the block check
    is therefore done here with the real sender.
    """
    author_id = str(author.get("id", "")).strip()
    for mention in mentions:
        target_id = mention["userId"]
        if is_user_blocked(db, target_id, author_id):
            continue
        create_notification(
            db,
            user_id=target_id,
            notification_type="mention",
            title="有人提到了你",
            content=snippet[:100],
            related_type="comment" if comment_id else "post",
            related_id=comment_id or post_id,
            post_id=post_id,
            actor_id="" if anonymous else author_id,
            actor_alias=actor_alias,
        )


# ---------------------------------------------------------------- reposts


def handle_toggle_repost(handler: BaseHTTPRequestHandler, db: dict[str, Any], post_id: str) -> None:
    """POST /api/posts/<id>/repost"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "请先登录")
        return
    user_id = str(user["id"])
    visible = {str(post.get("id")): post for post in list_posts(db, viewer_user_id=user_id)}
    post = visible.get(post_id)
    if post is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
        return
    author_id = str(post.get("authorId", "")).strip()
    # A repost is shown under the reposter's name: reposting one's own
    # anonymous post would say who wrote it.
    if author_id == user_id and is_post_anonymous(db, post):
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能转发自己的匿名帖子")
        return
    if str(post.get("visibility", "public")).strip().lower() == "private":
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅自己可见的帖子不能转发")
        return

    body = read_json_body(handler)
    reposts = db.setdefault("reposts", [])
    existing = next((row for row in reposts if row.get("userId") == user_id and row.get("postId") == post_id), None)
    wanted = body.get("reposted")
    target = (existing is None) if wanted is None else bool(wanted)

    if target and existing is None:
        allowed, retry_after = consume_rate_limit(
            db,
            user_id=user_id,
            action="interaction",
            setting_key="interactionRateLimit",
            default_limit=_globals.DEFAULT_SETTINGS["interactionRateLimit"],
        )
        if not allowed:
            send_rate_limit_error(handler, action_text="转发", retry_after_seconds=retry_after)
            return
        reposts.append({"userId": user_id, "postId": post_id, "createdAt": now_iso()})
        if author_id and author_id != user_id:
            create_notification(
                db,
                user_id=author_id,
                notification_type="repost",
                title="你的帖子被转发了",
                content=str(post.get("title") or post.get("content") or "")[:100],
                related_type="post",
                related_id=post_id,
                post_id=post_id,
                actor_id=user_id,
                actor_alias=user_nickname(user),
            )
        save_db(db)
    elif not target and existing is not None:
        reposts.remove(existing)
        save_db(db)

    count = sum(1 for row in reposts if row.get("postId") == post_id)
    send_json(handler, HTTPStatus.OK, {"data": {"reposted": target, "repostCount": count}})


def handle_get_timeline(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
    query: dict[str, list[str]],
) -> None:
    """GET /api/users/<id>/timeline — posts written and reposted, newest first.

    Each item is a serialized post plus `repostedBy` (null for the user's own
    post) and `eventKey`, since one post can appear as both.
    """
    viewer, _ = auth_user_helper(handler, db)
    if viewer is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "请先登录")
        return
    viewer_id = str(viewer["id"])
    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return
    page, limit = _page_args(query)
    visible = {str(post.get("id")): post for post in list_posts(db, viewer_user_id=viewer_id)}

    events: list[tuple[str, str, dict[str, Any], bool]] = []
    for post in visible.values():
        if str(post.get("authorId", "")).strip() != target_user_id:
            continue
        # Same rule as /api/posts?authorId: an anonymous post never shows
        # up under its author, except to the author.
        if is_post_anonymous(db, post) and target_user_id != viewer_id:
            continue
        events.append((str(post.get("createdAt", "")), f"post:{post['id']}", post, False))
    for row in db.get("reposts", []):
        if row.get("userId") != target_user_id:
            continue
        post = visible.get(str(row.get("postId")))
        if post is None:
            continue
        if str(post.get("authorId", "")).strip() == target_user_id and is_post_anonymous(db, post):
            continue
        events.append((str(row.get("createdAt", "")), f"repost:{target_user_id}:{post['id']}", post, True))
    events.sort(key=lambda event: (event[0], event[1]), reverse=True)

    page_data = _paged(events, page, limit)
    reposter = {"userId": target_user_id, "nickname": user_nickname(target)}
    page_data["items"] = [
        {
            **serialize_post(db, post, viewer_user_id=viewer_id),
            "repostedBy": reposter if is_repost else None,
            "eventKey": key,
            "eventAt": at,
        }
        for at, key, post, is_repost in page_data["items"]
    ]
    send_json(handler, HTTPStatus.OK, {"data": page_data})


# ---------------------------------------------------------------- activity


def handle_get_my_activity(handler: BaseHTTPRequestHandler, db: dict[str, Any], query: dict[str, list[str]]) -> None:
    """GET /api/users/me/activity — the signed-in user's own actions, newest first.

    Types: post, comment, like_post, like_comment, favorite, repost, follow.
    Items whose target is gone or no longer visible are left out.
    """
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "请先登录")
        return
    user_id = str(user["id"])
    page, limit = _page_args(query)
    # Other people's posts only while they are publicly visible; one's own
    # stay listed through review, since they are one's own history.
    visible = {str(post.get("id")): post for post in list_posts(db, viewer_user_id=user_id)}
    for post in list_posts(db, viewer_user_id=user_id, include_rejected=True):
        if str(post.get("authorId", "")).strip() == user_id:
            visible[str(post.get("id"))] = post
    comments = {str(c.get("id")): c for c in db.get("comments", []) if not c.get("deleted")}

    def post_ref(post_id: str) -> dict[str, Any] | None:
        post = visible.get(post_id)
        if post is None:
            return None
        title = str(post.get("title") or "").strip() or str(post.get("content") or "").strip()[:60]
        return {"id": post_id, "title": title}

    items: list[dict[str, Any]] = []

    def add(kind: str, at: Any, key: str, post_id: str, **extra: Any) -> None:
        ref = post_ref(post_id)
        if ref is None:
            return
        items.append({"id": key, "type": kind, "createdAt": str(at or ""), "post": ref, **extra})

    for post in visible.values():
        if str(post.get("authorId", "")).strip() == user_id:
            add("post", post.get("createdAt"), f"post:{post['id']}", str(post["id"]),
                isAnonymous=is_post_anonymous(db, post))
    for comment in comments.values():
        if str(comment.get("userId", "")).strip() == user_id:
            add("comment", comment.get("createdAt"), f"comment:{comment['id']}", str(comment.get("postId")),
                commentId=str(comment["id"]), content=str(comment.get("content", ""))[:100])
    for like in db.get("likes", []):
        if like.get("userId") != user_id:
            continue
        if like.get("postId"):
            add("like_post", like.get("createdAt"), f"like:{like['postId']}", str(like["postId"]))
        elif like.get("commentId"):
            comment = comments.get(str(like["commentId"]))
            if comment is not None:
                add("like_comment", like.get("createdAt"), f"like-comment:{comment['id']}", str(comment.get("postId")),
                    commentId=str(comment["id"]), content=str(comment.get("content", ""))[:100])
    for favorite in db.get("favorites", []):
        if favorite.get("userId") == user_id:
            add("favorite", favorite.get("createdAt"), f"favorite:{favorite['postId']}", str(favorite["postId"]))
    for repost in db.get("reposts", []):
        if repost.get("userId") == user_id:
            add("repost", repost.get("createdAt"), f"repost:{repost['postId']}", str(repost["postId"]))
    for follow in db.get("userFollows", []):
        if str(follow.get("followerUserId", "")).strip() != user_id:
            continue
        followee = find_user_by_id(db, str(follow.get("followeeUserId", "")))
        if followee is None or followee.get("deleted"):
            continue
        items.append({
            "id": f"follow:{followee['id']}",
            "type": "follow",
            "createdAt": str(follow.get("createdAt") or ""),
            "user": {"userId": str(followee["id"]), "nickname": user_nickname(followee)},
        })

    items.sort(key=lambda item: (item["createdAt"], item["id"]), reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": _paged(items, page, limit)})
