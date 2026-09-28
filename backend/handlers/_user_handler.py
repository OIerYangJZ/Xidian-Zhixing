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
    normalize_media_url,
    read_json_body,
    sanitize_alias,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    count_followers,
    count_following,
    current_user_level,
    find_user_by_id,
    is_user_following,
    is_level_one_user,
    latest_account_cancellation_request_for_user,
    latest_user_level_request_for_user,
    list_posts,
    list_follower_users,
    list_following_users,
    list_friend_users,
    normalize_optional_bool,
    save_db,
    search_public_users,
    serialize_account_cancellation_request,
    serialize_public_user_profile,
    serialize_user_level_request_summary,
    user_avatar_url,
    user_level_label,
    user_nickname,
    is_user_blocked,
    iso_to_time_text,
    verified_college,
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
    favorite_post_ids = {
        str(x.get("postId", ""))
        for x in db.get("favorites", [])
        if x.get("userId") == user["id"]
    }
    favorite_count = sum(
        1
        for post in list_posts(db, viewer_user_id=uid)
        if str(post.get("id", "")) in favorite_post_ids
    )
    # Same rows as GET /api/posts/mine, so the count matches 我的帖子.
    post_count = sum(
        1
        for post in list_posts(db, include_rejected=True, viewer_user_id=uid)
        if post.get("authorId") == uid
    )

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": uid,
                "alias": user_nickname(user),
                "nickname": user_nickname(user),
                "studentId": str(user.get("studentId", "")).strip(),
                "avatarUrl": user_avatar_url(user),
                "bio": str(user.get("bio", "")).strip(),
                "gender": str(user.get("gender", "")).strip(),
                "college": verified_college(db, user),
                "major": str(user.get("major", "")).strip(),
                "backgroundImageUrl": normalize_media_url(str(user.get("backgroundImageUrl", "")).strip()),
                "verified": bool(user.get("verified")),
                "verifiedAt": str(user.get("verifiedAt", "")).strip(),
                # A banned session is allowed to read this endpoint so the
                # client can route to the appeal screen after a reload.
                "banned": bool(user.get("banned")),
                "muted": bool(user.get("muted")),
                "allowStrangerDm": bool(user.get("allowStrangerDm", True)),
                "showContactable": bool(user.get("showContactable", True)),
                "notifyComment": bool(user.get("notifyComment", True)),
                "notifyReply": bool(user.get("notifyReply", True)),
                "notifyLike": bool(user.get("notifyLike", True)),
                "notifyFavorite": bool(user.get("notifyFavorite", True)),
                "notifyRepost": bool(user.get("notifyRepost", True)),
                "notifyMention": bool(user.get("notifyMention", True)),
                "notifyReportResult": bool(user.get("notifyReportResult", True)),
                "notifySystem": bool(user.get("notifySystem", True)),
                "favoriteCount": favorite_count,
                "postCount": post_count,
                "followingCount": count_following(db, uid),
                "followerCount": count_followers(db, uid),
                "userLevel": current_user_level(user),
                "userLevelLabel": user_level_label(current_user_level(user)),
                "isLevelOneUser": is_level_one_user(user),
                "email": str(user.get("email", "")).strip(),
                "levelUpgradeRequest": serialize_user_level_request_summary(level_req) if level_req else None,
                "accountCancellationRequest": serialize_account_cancellation_request(cancellation_req) if cancellation_req else None,
                "createdAt": str(user.get("createdAt", "")).strip(),
                "deleted": bool(user.get("deleted", False)),
                "banned": bool(user.get("banned", False)),
                "muted": bool(user.get("muted", False)),
            }
        },
    )


def handle_get_user(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    user_id: str,
) -> None:
    """GET /api/users/<id>"""
    viewer, _ = auth_user_helper(handler, db)
    if viewer is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return
    target = find_user_by_id(db, user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "用户不存在")
        return

    viewer_id = str(viewer.get("id", "")) if viewer else ""
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": serialize_public_user_profile(
                db,
                target_user=target,
                viewer_user_id=viewer_id,
            )
        },
    )


def handle_search_users(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    query: dict[str, list[str]],
) -> None:
    """GET /api/users/search?keyword=..."""
    viewer, _ = auth_user_helper(handler, db)
    if viewer is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    keyword = str((query.get("keyword") or [""])[0]).strip()
    if not keyword:
        send_json(handler, HTTPStatus.OK, {"data": []})
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": search_public_users(
                db,
                viewer_user_id=str(viewer.get("id", "")).strip(),
                keyword=keyword,
            )
        },
    )


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
    profile_keys = {
        "nickname",
        "avatarUrl",
        "backgroundImageUrl",
        "bio",
        "gender",
        "major",
    }
    # 学院 comes from the school identity mapping only.  Clients that still
    # send the whole form may echo the verified value back; anything else is
    # an attempt to set it.
    if "college" in body and re.sub(r"\s+", "", str(body.get("college", "")).strip()) != verified_college(db, user):
        json_error(handler, HTTPStatus.BAD_REQUEST, "学院由学校统一身份认证确定，不能自行修改")
        return
    if not any(key in body for key in profile_keys):
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少可更新的个人资料字段")
        return
    new_nickname = (
        sanitize_alias(str(body.get("nickname", "")), fallback="")
        if "nickname" in body
        else None
    )
    current_avatar = normalize_avatar_url(str(user.get("avatarUrl", "")))
    requested_avatar = str(body.get("avatarUrl", "")).strip()
    new_avatar = normalize_avatar_url(requested_avatar) if "avatarUrl" in body else None
    if new_avatar is not None and new_avatar != current_avatar:
        json_error(handler, HTTPStatus.BAD_REQUEST, "请通过头像上传接口更换头像")
        return
    new_background_image = (
        normalize_media_url(str(body.get("backgroundImageUrl", "")))
        if "backgroundImageUrl" in body
        else None
    )
    new_bio = str(body.get("bio", "")).strip() if "bio" in body else None
    new_gender = str(body.get("gender", "")).strip() if "gender" in body else None
    new_major = (
        re.sub(r"\s+", "", str(body.get("major", "")).strip())[:80]
        if "major" in body
        else None
    )

    if new_bio is not None and len(new_bio) > 100:
        json_error(handler, HTTPStatus.BAD_REQUEST, "个性签名不能超过 100 个字符")
        return
    if new_gender is not None and new_gender not in {"", "男", "女"}:
        json_error(handler, HTTPStatus.BAD_REQUEST, "性别仅支持：男、女")
        return
    if (
        new_background_image is not None
        and new_background_image
        and new_background_image
        != normalize_media_url(str(user.get("backgroundImageUrl", "")).strip())
    ):
        matching_upload = next(
            (
                upload
                for upload in db.get("mediaUploads", [])
                if normalize_media_url(str(upload.get("url", "")).strip())
                == new_background_image
                and not upload.get("deleted")
            ),
            None,
        )
        if matching_upload is None:
            json_error(handler, HTTPStatus.BAD_REQUEST, "背景图片不是有效的已上传图片")
            return
        if (
            str(matching_upload.get("uploaderId", "")).strip()
            != str(user.get("id", "")).strip()
        ):
            json_error(handler, HTTPStatus.FORBIDDEN, "不能使用其他用户上传的背景图片")
            return
        if str(matching_upload.get("postId", "")).strip():
            json_error(handler, HTTPStatus.BAD_REQUEST, "帖子图片不能用作个人背景")
            return
        upload_status = (
            str(matching_upload.get("status", "")).strip().lower()
        )
        if upload_status != "approved":
            json_error(handler, HTTPStatus.BAD_REQUEST, "背景图片尚未通过审核")
            return

    if new_nickname is not None and new_nickname and new_nickname != user_nickname(user):
        user["nickname"] = new_nickname
        user["alias"] = new_nickname
        add_audit_log(db, user["id"], "update_nickname", f"更新昵称为 {new_nickname}")

    if new_avatar is not None:
        user["avatarUrl"] = new_avatar

    if new_bio is not None:
        user["bio"] = new_bio
    if new_gender is not None:
        user["gender"] = new_gender
    if new_major is not None:
        user["major"] = new_major
    if new_background_image is not None:
        user["backgroundImageUrl"] = new_background_image

    add_audit_log(db, user["id"], "update_profile", "更新个人资料")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "ok": True,
                "nickname": user_nickname(user),
                "bio": str(user.get("bio", "")).strip(),
                "gender": str(user.get("gender", "")).strip(),
                "college": verified_college(db, user),
                "major": str(user.get("major", "")).strip(),
                "backgroundImageUrl": normalize_media_url(str(user.get("backgroundImageUrl", "")).strip()),
            }
        },
    )


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
    if not any(key in body for key in ("allowStrangerDm", "showContactable")):
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少隐私设置字段")
        return
    if "allowStrangerDm" in body:
        user["allowStrangerDm"] = normalize_optional_bool(
            body.get("allowStrangerDm"),
            default=bool(user.get("allowStrangerDm", True)),
        )
    if "showContactable" in body:
        user["showContactable"] = normalize_optional_bool(
            body.get("showContactable"),
            default=bool(user.get("showContactable", True)),
        )
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_my_feedbacks(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/feedback/mine"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    rows = [
        {
            "id": str(item.get("id", "")),
            "category": str(item.get("category", "其他反馈")),
            "content": str(item.get("content", "")),
            "contact": str(item.get("contact", "")),
            "status": str(item.get("status", "pending")),
            "schoolReply": str(item.get("schoolReply", "")),
            "createdAt": str(item.get("createdAt", "")),
            "handledAt": str(item.get("handledAt", "")),
        }
        for item in db.get("feedbacks", [])
        if str(item.get("userId", "")) == str(user.get("id", ""))
    ]
    rows.sort(key=lambda item: item["createdAt"], reverse=True)
    send_json(handler, HTTPStatus.OK, {"data": rows})


def handle_update_notification_preferences(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """PATCH /api/users/notification-preferences"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    preference_keys = (
        "notifyComment",
        "notifyReply",
        "notifyLike",
        "notifyFavorite",
        "notifyRepost",
        "notifyMention",
        "notifyReportResult",
        "notifySystem",
    )
    if not any(key in body for key in preference_keys):
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少通知设置字段")
        return
    for key in preference_keys:
        if key in body:
            user[key] = normalize_optional_bool(
                body.get(key),
                default=bool(user.get(key, True)),
            )
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
        "followerUserId": user["id"],
        "followeeUserId": target_user_id,
        "createdAt": _globals.now_iso(),
    })
    add_audit_log(db, user["id"], "follow_user", target_user_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"userId": target_user_id, "following": True}})


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
        if not (
            str(f.get("followerUserId", "")).strip() == str(user.get("id", "")).strip()
            and str(f.get("followeeUserId", "")).strip() == target_user_id
        )
    ]
    add_audit_log(db, user["id"], "unfollow_user", target_user_id)
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"userId": target_user_id, "following": False}})


def handle_get_following(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/following"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": list_following_users(
                db,
                user_id=user["id"],
                viewer_user_id=user["id"],
            )
        },
    )


def handle_get_followers(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/followers"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": list_follower_users(
                db,
                user_id=user["id"],
                viewer_user_id=user["id"],
            )
        },
    )


def handle_get_friends(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/friends"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": list_friend_users(db, user_id=user["id"])},
    )


def serialize_blocked_user(db: dict[str, Any], block_record: dict[str, Any]) -> dict[str, Any]:
    blocked_id = str(block_record.get("blockedUserId", "")).strip()
    target_user = find_user_by_id(db, blocked_id)
    nickname = user_nickname(target_user) if target_user else "已注销用户"
    avatar_url = user_avatar_url(target_user)
    bio = str(target_user.get("bio", "")).strip() if target_user else ""
    return {
        "id": blocked_id,
        "nickname": nickname,
        "avatarUrl": avatar_url,
        "bio": bio,
        "blockedAt": block_record.get("createdAt", ""),
        "timeText": iso_to_time_text(block_record.get("createdAt")),
    }


def handle_get_blocks(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/users/me/blocks"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    records = [
        r for r in db.get("userBlocks", [])
        if str(r.get("blockerUserId", "")).strip() == user["id"]
    ]
    records.sort(key=lambda x: x.get("createdAt", ""), reverse=True)

    data = [serialize_blocked_user(db, r) for r in records]
    send_json(handler, HTTPStatus.OK, {"data": data})


def handle_block_user_globally(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/users/me/blocks"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    target_user_id = str(body.get("targetUserId") or body.get("userId") or "").strip()
    if not target_user_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标用户ID")
        return

    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能屏蔽自己")
        return

    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    if not is_user_blocked(db, user["id"], target_user_id):
        blocked_at = _globals.now_iso()
        db.setdefault("userBlocks", []).append({
            "blockerUserId": user["id"],
            "blockedUserId": target_user_id,
            "createdAt": blocked_at,
        })
        add_audit_log(db, user["id"], "block_user", f"屏蔽用户 {target_user_id}")
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"blocked": True}})


def handle_unblock_user_globally(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    target_user_id: str,
) -> None:
    """DELETE /api/users/me/blocks/<target_user_id>"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    target_user_id = target_user_id.strip()
    db["userBlocks"][:] = [
        b for b in db.get("userBlocks", [])
        if not (
            str(b.get("blockerUserId", "")).strip() == user["id"]
            and str(b.get("blockedUserId", "")).strip() == target_user_id
        )
    ]
    add_audit_log(db, user["id"], "unblock_user", f"解除屏蔽用户 {target_user_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"blocked": False}})
