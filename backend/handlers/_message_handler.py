"""
handlers/_message_handler.py

Direct-message & conversation endpoints:
  GET  /api/messages/requests                          — list received DM requests
  POST /api/messages/requests                          — send a DM request
  POST re("/api/messages/requests/([^/]+)/(accept|reject)") — accept/reject DM request
  GET  /api/messages/conversations                     — list DM conversations
  POST /api/messages/conversations/direct             — find or create conversation directly
  GET  re("/api/messages/conversations/([^/]+)/messages") — list messages in conversation
  POST re("/api/messages/conversations/([^/]+)/messages") — send a message
  DELETE re("/api/messages/conversations/([^/]+)")     — delete own conversation
  POST re("/api/messages/conversations/([^/]+)/(block|unblock)") — block/unblock peer
"""
from __future__ import annotations

from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    assess_text_risk,
    check_ip_rate_limit,
    consume_rate_limit,
    is_campus_email,
    json_error,
    now_iso,
    read_json_body,
    sanitize_alias,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    can_request_dm_to_user,
    conversation_block_state,
    deliver_message_to_conversation_pair,
    find_user_by_id,
    get_setting_int,
    is_user_blocked,
    list_comments,
    mark_conversation_read,
    next_id,
    post_counts,
    reject_pending_dm_requests_between,
    save_db,
    serialize_direct_message,
    serialize_notification,
    serialize_post,
    sync_conversation_pair,
    user_avatar_url,
    user_nickname,
)


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]):
    """Short-hand for requiring an authorized user."""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _conversations_for_user(
    db: dict[str, Any],
    user_id: str,
) -> list[dict[str, Any]]:
    rows = [x for x in db["conversations"] if x.get("userId") == user_id and not x.get("deleted")]
    rows.sort(key=lambda x: x.get("updatedAt", ""), reverse=True)
    return rows


def handle_get_requests(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/messages/requests"""
    user = _require_auth(handler, db)
    if user is None:
        return

    requests = []
    for row in db["dmRequests"]:
        if row.get("toUserId") != user["id"]:
            continue
        status = str(row.get("status", "pending")).strip().lower() or "pending"
        from_user = find_user_by_id(db, str(row.get("fromUserId", "")))
        from_alias = svc_user_nickname(from_user) if from_user else sanitize_alias(
            str(row.get("fromAlias", "")),
            fallback="匿名同学",
        )
        from_avatar = user_avatar_url(from_user)
        if not from_avatar:
            from_avatar = _globals.normalize_avatar_url(str(row.get("fromAvatarUrl", "")))
        status_label = {
            "pending": "待处理",
            "accepted": "已同意",
            "rejected": "已拒绝",
        }.get(status, status)
        requests.append({
            "id": row.get("id"),
            "fromAlias": from_alias,
            "fromAvatarUrl": from_avatar,
            "reason": row.get("reason", "请求联系"),
            "timeText": _globals.iso_to_time_text(row.get("createdAt")),
            "status": status,
            "statusLabel": status_label,
            "createdAt": row.get("createdAt", ""),
            "updatedAt": row.get("updatedAt", ""),
        })

    requests.sort(key=lambda x: x.get("updatedAt", "") or x.get("createdAt", ""), reverse=True)
    requests.sort(key=lambda x: 0 if x.get("status") == "pending" else 1)
    send_json(handler, HTTPStatus.OK, {"data": requests})


def handle_send_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/messages/requests"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_user_id = str(body.get("targetUserId", "")).strip()
    from_post_id = str(body.get("fromPostId", "")).strip()
    reason = str(body.get("reason", "想认识你")).strip()

    if not target_user_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标用户")
        return
    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能给自己发私信")
        return

    target = find_user_by_id(db, target_user_id)
    if target is None or target.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    if is_user_blocked(db, user["id"], target_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发私信")
        return
    if is_user_blocked(db, target_user_id, user["id"]):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发私信")
        return

    if not can_request_dm_to_user(db, target):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方不允许陌生人私信")
        return

    rate_key = f"dm_request::{target_user_id}"
    if not consume_rate_limit(db, rate_key, max_requests=3, window_seconds=3600):
        json_error(handler, HTTPStatus.TOO_MANY_REQUESTS, "发送私信过于频繁，请稍后再试")
        return

    post = None
    if from_post_id:
        post = next((p for p in db["posts"] if p.get("id") == from_post_id and not p.get("deleted")), None)
        if post is None:
            json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在")
            return
        if str(post.get("authorId", "")).strip() != target_user_id:
            json_error(handler, HTTPStatus.BAD_REQUEST, "帖子作者与目标用户不匹配")
            return
        if not post.get("allowDm", True):
            json_error(handler, HTTPStatus.FORBIDDEN, "该帖子作者关闭了私信功能")
            return

    existing = next(
        (r for r in db["dmRequests"]
         if r.get("fromUserId") == user["id"] and r.get("toUserId") == target_user_id
         and r.get("status") == "pending"),
        None,
    )
    if existing:
        send_json(handler, HTTPStatus.OK, {"data": {"alreadyPending": True, "id": existing.get("id")}})
        return

    req = {
        "id": next_id(db, "request", "req"),
        "toUserId": target_user_id,
        "fromUserId": user["id"],
        "fromAlias": svc_user_nickname(user),
        "fromAvatarUrl": user_avatar_url(user),
        "postId": from_post_id,
        "reason": reason,
        "status": "pending",
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }
    db["dmRequests"].append(req)
    add_audit_log(db, user["id"], "send_dm_request", f"向用户 {target_user_id} 发送私信请求")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True, "id": req["id"]}})


def handle_accept_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/messages/requests/<id>/accept"""
    user = _require_auth(handler, db)
    if user is None:
        return

    req = next(
        (r for r in db["dmRequests"] if r.get("id") == request_id and r.get("toUserId") == user["id"]),
        None,
    )
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "请求不存在")
        return
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "请求已被处理")
        return

    req["status"] = "accepted"
    req["updatedAt"] = now_iso()
    sync_conversation_pair(db, user["id"], str(req.get("fromUserId", "")))
    add_audit_log(db, user["id"], "accept_dm_request", f"接受来自 {req.get('fromUserId')} 的私信请求")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_reject_request(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    request_id: str,
) -> None:
    """POST /api/messages/requests/<id>/reject"""
    user = _require_auth(handler, db)
    if user is None:
        return

    req = next(
        (r for r in db["dmRequests"] if r.get("id") == request_id and r.get("toUserId") == user["id"]),
        None,
    )
    if req is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "请求不存在")
        return
    if req.get("status") != "pending":
        json_error(handler, HTTPStatus.BAD_REQUEST, "请求已被处理")
        return

    req["status"] = "rejected"
    req["updatedAt"] = now_iso()
    add_audit_log(db, user["id"], "reject_dm_request", f"拒绝来自 {req.get('fromUserId')} 的私信请求")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_get_conversations(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """GET /api/messages/conversations"""
    user = _require_auth(handler, db)
    if user is None:
        return

    rows = _conversations_for_user(db, user["id"])
    result = []
    for row in rows:
        peer_user_id = str(row.get("peerUserId", "")).strip()
        peer_user = find_user_by_id(db, peer_user_id)
        name = svc_user_nickname(peer_user) if peer_user else sanitize_alias(
            str(row.get("name", "")), fallback="匿名同学",
        )
        avatar_url = user_avatar_url(peer_user)
        if not avatar_url:
            avatar_url = _globals.normalize_avatar_url(str(row.get("avatarUrl", "")))
        blocked_by_me, blocked_by_peer = conversation_block_state(
            db,
            viewer_user_id=str(user.get("id", "")),
            peer_user_id=peer_user_id,
        )
        unread_count = max(0, int(row.get("unreadCount", 0) or 0))
        result.append({
            "id": row.get("id"),
            "peerUserId": peer_user_id,
            "name": name,
            "avatarUrl": avatar_url,
            "lastMessage": row.get("lastMessage", "") or "开始聊天吧",
            "timeText": _globals.iso_to_time_text(row.get("updatedAt")),
            "unreadCount": unread_count,
            "hasUnread": unread_count > 0,
            "blockedByMe": blocked_by_me,
            "blockedByPeer": blocked_by_peer,
        })

    send_json(handler, HTTPStatus.OK, {"data": result})


def handle_direct_conversation(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/messages/conversations/direct — find or create conversation directly (WeChat-style)"""
    user = _require_auth(handler, db)
    if user is None:
        return

    body = read_json_body(handler)
    target_user_id = str(body.get("targetUserId", "")).strip()

    if not target_user_id:
        json_error(handler, HTTPStatus.BAD_REQUEST, "缺少目标用户")
        return
    if target_user_id == user["id"]:
        json_error(handler, HTTPStatus.BAD_REQUEST, "不能给自己发私信")
        return

    target_user = find_user_by_id(db, target_user_id)
    if target_user is None or target_user.get("deleted"):
        json_error(handler, HTTPStatus.NOT_FOUND, "目标用户不存在")
        return

    if is_user_blocked(db, user["id"], target_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，解除屏蔽后才能发私信")
        return
    if is_user_blocked(db, target_user_id, user["id"]):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已屏蔽你，暂时无法发私信")
        return

    now = now_iso()
    existing = next(
        (
            row
            for row in db.get("conversations", [])
            if row.get("userId") == user["id"] and row.get("peerUserId") == target_user_id
        ),
        None,
    )
    if existing is not None:
        existing["deleted"] = False
        existing["updatedAt"] = now
        save_db(db)
        blocked_by_me, blocked_by_peer = conversation_block_state(
            db,
            viewer_user_id=str(user.get("id", "")),
            peer_user_id=target_user_id,
        )
        send_json(
            handler,
            HTTPStatus.OK,
            {
                "data": {
                    "id": existing.get("id"),
                    "peerUserId": target_user_id,
                    "peerAlias": svc_user_nickname(target_user),
                    "blockedByMe": blocked_by_me,
                    "blockedByPeer": blocked_by_peer,
                    "alreadyExisted": True,
                }
            },
        )
        return

    peer_user = find_user_by_id(db, target_user_id)
    conversation = {
        "id": next_id(db, "conversation", "conv"),
        "userId": user["id"],
        "peerUserId": target_user_id,
        "name": svc_user_nickname(peer_user),
        "avatarUrl": user_avatar_url(peer_user) or "",
        "lastMessage": "",
        "unreadCount": 0,
        "lastReadAt": "",
        "updatedAt": now,
        "deleted": False,
    }
    db["conversations"].append(conversation)
    sync_conversation_pair(db, user["id"], target_user_id)
    add_audit_log(db, user["id"], "create_direct_conversation", f"与用户 {target_user_id} 创建私信会话")
    save_db(db)
    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": conversation["id"],
                "peerUserId": target_user_id,
                "peerAlias": svc_user_nickname(peer_user),
                "alreadyExisted": False,
            }
        },
    )


def handle_get_messages(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """GET /api/messages/conversations/<id>/messages"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if is_user_blocked(db, user["id"], peer_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已将你屏蔽，无法查看消息")
        return

    conv_key = _globals.conversation_key_for_users(str(user.get("id", "")), peer_user_id)
    messages = [
        serialize_direct_message(msg)
        for msg in db.get("directMessages", [])
        if msg.get("conversationKey") == conv_key and not msg.get("deleted")
    ]
    messages.sort(key=lambda m: m.get("createdAt", ""))

    mark_conversation_read(db, str(user.get("id", "")), peer_user_id)
    save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"items": messages}})


def handle_send_message(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/messages"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if is_user_blocked(db, user["id"], peer_user_id):
        json_error(handler, HTTPStatus.FORBIDDEN, "你已屏蔽对方，无法发送消息")
        return
    if is_user_blocked(db, peer_user_id, user["id"]):
        json_error(handler, HTTPStatus.FORBIDDEN, "对方已将你屏蔽，暂时无法发送消息")
        return

    body = read_json_body(handler)
    content = str(body.get("content", "")).strip()
    if not content:
        json_error(handler, HTTPStatus.BAD_REQUEST, "消息内容不能为空")
        return

    ip = _globals.get_client_ip(handler)
    if not check_ip_rate_limit(handler, db, ip):
        return
    if not consume_rate_limit(db, f"dm::{peer_user_id}", max_requests=20, window_seconds=60):
        json_error(handler, HTTPStatus.TOO_MANY_REQUESTS, "发送消息过于频繁，请稍后再试")
        return

    risk_score = assess_text_risk(content, db=db, min_length=1)
    if risk_score >= 3:
        json_error(handler, HTTPStatus.BAD_REQUEST, "消息内容可能包含敏感词或违规信息，请修改后重试")
        return

    deliver_message_to_conversation_pair(db, str(user.get("id", "")), peer_user_id, content)
    add_audit_log(db, user["id"], "send_message", f"向用户 {peer_user_id} 发送私信: {content[:20]}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_delete_conversation(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """DELETE /api/messages/conversations/<id>"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"] and not c.get("deleted")),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    conv["deleted"] = True
    add_audit_log(db, user["id"], "delete_conversation", f"删除与用户 {conv.get('peerUserId')} 的私信会话")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"ok": True}})


def handle_block_peer(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/block"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"]),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    if not is_user_blocked(db, user["id"], peer_user_id):
        db["userBlocks"].append({
            "blockerId": user["id"],
            "blockedId": peer_user_id,
            "createdAt": now_iso(),
        })
        reject_pending_dm_requests_between(db, user["id"], peer_user_id)
        add_audit_log(db, user["id"], "block_user", f"屏蔽用户 {peer_user_id}")
        save_db(db)

    send_json(handler, HTTPStatus.OK, {"data": {"blocked": True}})


def handle_unblock_peer(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
    conversation_id: str,
) -> None:
    """POST /api/messages/conversations/<id>/unblock"""
    user = _require_auth(handler, db)
    if user is None:
        return

    conv = next(
        (c for c in db["conversations"]
         if c.get("id") == conversation_id and c.get("userId") == user["id"]),
        None,
    )
    if conv is None:
        json_error(handler, HTTPStatus.NOT_FOUND, "会话不存在")
        return

    peer_user_id = str(conv.get("peerUserId", "")).strip()
    db["userBlocks"][:] = [
        b for b in db["userBlocks"]
        if not (b.get("blockerId") == user["id"] and b.get("blockedId") == peer_user_id)
    ]
    add_audit_log(db, user["id"], "unblock_user", f"解除屏蔽用户 {peer_user_id}")
    save_db(db)
    send_json(handler, HTTPStatus.OK, {"data": {"blocked": False}})
