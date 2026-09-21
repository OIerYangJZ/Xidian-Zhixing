"""
handlers/_upload_handler.py

Image upload and avatar endpoints:
  POST /api/uploads/images                         — upload an image (with moderation)
  POST /api/users/avatar                           — upload/change avatar
"""
from __future__ import annotations

import copy
import base64
import json
import re
from typing import Any
from urllib import request as url_request

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    calc_sha256_hex,
    check_duplicate_image_hash,
    check_ip_rate_limit,
    consume_rate_limit,
    decode_base64_payload,
    detect_image_type,
    extract_local_object_key_from_url,
    json_error,
    normalize_avatar_url,
    now_iso,
    read_json_body,
    send_rate_limit_error,
    send_json,
)
from services import (
    add_audit_log,
    auth_user as auth_user_helper,
    find_user_by_id,
    next_id,
    save_db,
)


def _call_image_service(url: str, image_bytes: bytes, content_type: str) -> dict[str, Any]:
    """Call an optional local moderation worker without adding a model dependency."""
    payload = json.dumps(
        {
            "imageBase64": base64.b64encode(image_bytes).decode("ascii"),
            "contentType": content_type,
            "input": {
                "type": "base64",
                "data": base64.b64encode(image_bytes).decode("ascii"),
            },
        }
    ).encode("utf-8")
    request = url_request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with url_request.urlopen(request, timeout=_globals.IMAGE_MODERATION_TIMEOUT_SECONDS) as response:
        result = json.loads(response.read().decode("utf-8"))
    return result if isinstance(result, dict) else {}


def _extract_service_text(result: dict[str, Any]) -> str:
    values = result.get("text", result.get("texts", ""))
    if isinstance(values, list):
        return " ".join(str(value) for value in values)
    return str(values or "")


# Re-export moderate_image_upload and get_upload_by_id from server.py helpers
# (these are currently defined in server.py; they will be moved in TODO-05)
def moderate_image_upload(
    *,
    file_name: str,
    content_type: str,
    size_bytes: int,
    db: dict[str, Any],
    image_bytes: bytes | None = None,
) -> tuple[str, str]:
    if content_type not in _globals.ALLOWED_IMAGE_TYPES:
        return "rejected", f"不支持的图片格式：{content_type}"
    max_bytes = _globals.get_image_max_bytes(db)
    if size_bytes > max_bytes:
        return "rejected", f"图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）"
    lowered_name = file_name.lower()
    hit_words = [
        str(word).strip()
        for word in db.get("sensitiveWords", [])
        if str(word).strip() and str(word).strip().lower() in lowered_name
    ]
    if hit_words:
        return "risk", f"文件名命中敏感词：{','.join(hit_words[:3])}"

    if image_bytes is not None and _globals.IMAGE_MODERATION_URL:
        try:
            result = _call_image_service(
                _globals.IMAGE_MODERATION_URL,
                image_bytes,
                content_type,
            )
        except Exception:
            return "risk", "图片内容审核服务不可用，需人工审核"
        try:
            prediction = result.get("result", result)
            if not isinstance(prediction, dict):
                prediction = result
            probability = float(
                prediction.get("nsfw_probability", prediction.get("nsfwProbability", 0.0))
            )
        except (TypeError, ValueError):
            return "risk", "图片内容审核服务返回了无效结果，需人工审核"
        if probability >= _globals.IMAGE_NSFW_BLOCK_THRESHOLD:
            return "rejected", f"图片疑似不适宜内容（{probability:.2f}）"
        if probability >= _globals.IMAGE_NSFW_REVIEW_THRESHOLD:
            return "risk", f"图片疑似不适宜内容，需人工审核（{probability:.2f}）"

    if image_bytes is not None and _globals.IMAGE_OCR_URL:
        try:
            ocr_result = _call_image_service(
                _globals.IMAGE_OCR_URL,
                image_bytes,
                content_type,
            )
        except Exception:
            return "risk", "图片文字审核服务不可用，需人工审核"
        ocr_text = _extract_service_text(ocr_result)
        if ocr_text:
            from helpers._rate_limit import assess_text_risk

            risk_marked, high_risk, reasons = assess_text_risk(
                db,
                ocr_text,
                block_on_match=True,
            )
            if risk_marked:
                prefix = "图片文字命中禁止规则" if high_risk else "图片文字需人工审核"
                return ("rejected" if high_risk else "risk"), \
                    f"{prefix}：{'；'.join(reasons[:3])}"
    return "approved", ""


def get_upload_by_id(db: dict[str, Any], upload_id: str) -> dict[str, Any] | None:
    for row in db.get("mediaUploads", []):
        if row.get("id") == upload_id:
            return row
    return None


def handle_upload_image(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/uploads/images"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return
    if user.get("banned"):
        json_error(handler, HTTPStatus.FORBIDDEN, "账号已被封禁")
        return

    body = read_json_body(handler)
    image_data_base64 = str(
        body.get("imageDataBase64", body.get("dataBase64", "")),
    ).strip()
    file_name = str(body.get("fileName", "image.png")).strip() or "image.png"
    content_type = str(body.get("contentType", "")).strip().lower()
    post_id = str(body.get("postId", "")).strip()

    target_post: dict[str, Any] | None = None
    if post_id:
        target_post = next(
            (
                post
                for post in db.get("posts", [])
                if str(post.get("id", "")).strip() == post_id
                and not post.get("deleted")
            ),
            None,
        )
        if target_post is None:
            json_error(handler, HTTPStatus.NOT_FOUND, "帖子不存在或已被删除")
            return
        if str(target_post.get("authorId", "")).strip() != str(user.get("id", "")).strip():
            json_error(handler, HTTPStatus.FORBIDDEN, "只能向自己的帖子上传图片")
            return

    if not image_data_base64:
        json_error(handler, HTTPStatus.BAD_REQUEST, "图片数据不能为空")
        return

    try:
        image_bytes = decode_base64_payload(image_data_base64)
    except Exception:
        json_error(handler, HTTPStatus.BAD_REQUEST, "图片数据格式错误")
        return

    if not image_bytes:
        json_error(handler, HTTPStatus.BAD_REQUEST, "图片数据不能为空")
        return

    detected_content_type = detect_image_type(image_bytes)
    if detected_content_type is None:
        json_error(handler, HTTPStatus.BAD_REQUEST, "仅支持 jpg/png/webp/gif 图片")
        return

    if content_type and content_type != detected_content_type:
        json_error(handler, HTTPStatus.BAD_REQUEST, "声明的图片格式与实际内容不一致")
        return
    ct = detected_content_type

    max_bytes = _globals.get_image_max_bytes(db)
    if len(image_bytes) > max_bytes:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
        )
        return

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "upload")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="图片上传",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="upload",
        setting_key="uploadRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["uploadRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="图片上传",
            retry_after_seconds=retry_after,
        )
        return

    sha = calc_sha256_hex(image_bytes)
    if check_duplicate_image_hash(db, sha):
        add_audit_log(db, user["id"], "reupload_duplicate", f"重复上传图片 {sha[:12]}")

    moderation_status, moderation_reason = moderate_image_upload(
        file_name=file_name,
        content_type=ct,
        size_bytes=len(image_bytes),
        db=db,
        image_bytes=image_bytes,
    )
    if post_id and moderation_status != "approved":
        json_error(handler, HTTPStatus.BAD_REQUEST, "图片尚未通过审核，不能绑定到帖子")
        return

    try:
        stored = _globals.OBJECT_STORAGE.put_bytes(
            data=image_bytes,
            file_name=file_name,
            content_type=ct,
        )
    except Exception:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "图片上传失败，请稍后重试")
        return

    upload = {
        "id": next_id(db, "upload", "up"),
        "url": stored.url,
        "objectKey": stored.key,
        "fileName": file_name,
        "contentType": ct,
        "sizeBytes": len(image_bytes),
        "sha256": sha,
        "status": moderation_status,
        "moderationReason": moderation_reason,
        "createdAt": now_iso(),
        "postId": post_id,
        "uploaderId": user["id"],
        "deleted": False,
    }
    db_snapshot = copy.deepcopy(db)
    db["mediaUploads"].append(upload)

    if post_id:
        if target_post is not None:
            target_post.setdefault("imageIds", [])
            target_post["imageIds"].append(upload["id"])
            if moderation_status == "approved":
                target_post["hasImage"] = True

    add_audit_log(db, user["id"], "upload_image", f"上传图片 {upload['id']}")
    try:
        save_db(db)
    except Exception:
        db.clear()
        db.update(db_snapshot)
        try:
            _globals.OBJECT_STORAGE.delete(stored.key)
        except Exception as cleanup_error:
            raise RuntimeError(
                "图片记录保存失败，且新上传对象清理失败"
            ) from cleanup_error
        raise

    send_json(
        handler,
        HTTPStatus.OK,
        {
            "data": {
                "id": upload["id"],
                "url": upload["url"],
                "status": upload["status"],
                "moderationReason": upload["moderationReason"],
            }
        },
    )


def handle_upload_avatar(
    handler: BaseHTTPRequestHandler,
    db: dict[str, Any],
) -> None:
    """POST /api/users/avatar"""
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return

    body = read_json_body(handler)
    avatar_data_base64 = str(
        body.get("avatarDataBase64", body.get("dataBase64", "")),
    ).strip()
    file_name = str(body.get("fileName", "avatar.png")).strip() or "avatar.png"
    content_type = str(
        body.get("avatarContentType", body.get("contentType", "")),
    ).strip().lower()

    if not avatar_data_base64:
        json_error(handler, HTTPStatus.BAD_REQUEST, "头像图片不能为空")
        return

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

    if content_type and content_type != detected_content_type:
        json_error(handler, HTTPStatus.BAD_REQUEST, "声明的头像格式与实际内容不一致")
        return
    ct = detected_content_type

    max_bytes = _globals.get_image_max_bytes(db)
    if len(avatar_bytes) > max_bytes:
        json_error(
            handler,
            HTTPStatus.BAD_REQUEST,
            f"头像图片超出大小限制（最大 {max_bytes // (1024 * 1024)}MB）",
        )
        return

    ip_allowed, ip_retry_after = check_ip_rate_limit(handler, "upload")
    if not ip_allowed:
        send_rate_limit_error(
            handler,
            action_text="头像上传",
            retry_after_seconds=ip_retry_after,
        )
        return
    allowed, retry_after = consume_rate_limit(
        db,
        user_id=user["id"],
        action="upload",
        setting_key="uploadRateLimit",
        default_limit=_globals.DEFAULT_SETTINGS["uploadRateLimit"],
    )
    if not allowed:
        send_rate_limit_error(
            handler,
            action_text="头像上传",
            retry_after_seconds=retry_after,
        )
        return

    moderation_status, moderation_reason = moderate_image_upload(
        file_name=file_name,
        content_type=ct,
        size_bytes=len(avatar_bytes),
        db=db,
        image_bytes=avatar_bytes,
    )
    if moderation_status != "approved":
        json_error(handler, HTTPStatus.BAD_REQUEST, moderation_reason or "头像未通过审核")
        return

    try:
        stored = _globals.OBJECT_STORAGE.put_bytes(
            data=avatar_bytes,
            file_name=file_name,
            content_type=ct,
        )
    except Exception:
        json_error(handler, HTTPStatus.INTERNAL_SERVER_ERROR, "头像上传失败，请稍后重试")
        return

    db_snapshot = copy.deepcopy(db)
    old_avatar_url = normalize_avatar_url(str(user.get("avatarUrl", "")))
    old_key = extract_local_object_key_from_url(old_avatar_url) if old_avatar_url else ""
    owned_old_upload = None
    if old_key:
        owned_old_upload = next(
            (
                row for row in db.get("mediaUploads", [])
                if str(row.get("objectKey", "")).strip() == old_key
                and str(row.get("uploaderId", "")).strip() == str(user.get("id", "")).strip()
                and not row.get("deleted")
            ),
            None,
        )

    upload = {
        "id": next_id(db, "upload", "up"),
        "url": stored.url,
        "objectKey": stored.key,
        "fileName": file_name,
        "contentType": ct,
        "sizeBytes": len(avatar_bytes),
        "sha256": calc_sha256_hex(avatar_bytes),
        "status": "approved",
        "moderationReason": "",
        "createdAt": now_iso(),
        "postId": "",
        "uploaderId": user["id"],
        "usageType": "avatar",
        "deleted": False,
    }
    db.setdefault("mediaUploads", []).append(upload)
    if owned_old_upload is not None:
        owned_old_upload["deleted"] = True
    user["avatarUrl"] = stored.url
    add_audit_log(
        db, user["id"], "upload_avatar", f"更换头像 {stored.key}"
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
                "头像数据库保存失败，且新头像存储回滚删除失败",
            ) from cleanup_error
        raise

    if old_key and old_key != stored.key:
        try:
            _globals.OBJECT_STORAGE.delete(old_key)
        except Exception:
            db.clear()
            db.update(db_snapshot)
            try:
                save_db(db)
            except Exception:
                json_error(
                    handler,
                    HTTPStatus.BAD_GATEWAY,
                    "旧头像删除失败且数据库回滚失败，头像状态需要人工核查",
                )
                return
            try:
                _globals.OBJECT_STORAGE.delete(stored.key)
            except Exception:
                json_error(
                    handler,
                    HTTPStatus.BAD_GATEWAY,
                    "旧头像删除失败且新头像回滚删除失败，头像未更新",
                )
                return
            json_error(handler, HTTPStatus.BAD_GATEWAY, "旧头像存储删除失败，头像未更新")
            return

    send_json(
        handler,
        HTTPStatus.OK,
        {"data": {"avatarUrl": stored.url}},
    )
