"""
handlers/_static_handler.py

Static file / asset serving:
  GET /api/storage/<object_key>   — object storage (avatars, post images)
  GET /<fallback>                — SPA index.html for unmatched GET paths
"""
from __future__ import annotations

import re
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    resolve_web_asset_path,
    send_binary,
    send_static_file,
    should_fallback_to_spa,
)
from services import auth_user as auth_user_helper, is_post_private


def handle_storage_get(
    handler: BaseHTTPRequestHandler,
    path: str,
    db: dict[str, Any],
) -> bool:
    """
    Handle GET /api/storage/<object_key>.
    Returns True if this path was handled, False otherwise.
    """
    prefix = "/api/storage/"
    if not path.startswith(prefix):
        return False

    object_key = path[len(prefix):].strip("/")
    if not object_key:
        return False

    matching_uploads = [
        upload
        for upload in db.get("mediaUploads", [])
        if str(upload.get("objectKey", "")).strip() == object_key
    ]
    if matching_uploads:
        viewer, _ = auth_user_helper(handler, db)
        viewer_user_id = str(viewer.get("id", "")).strip() if viewer else ""
        allowed = False
        for upload in matching_uploads:
            if upload.get("deleted"):
                continue
            upload_status = (
                str(upload.get("status", "approved")).strip().lower() or "approved"
            )
            if upload_status != "approved":
                continue
            post_id = str(upload.get("postId", "")).strip()
            if not post_id:
                allowed = True
                break
            post = next(
                (
                    row
                    for row in db.get("posts", [])
                    if str(row.get("id", "")).strip() == post_id
                    and not row.get("deleted")
                ),
                None,
            )
            if post is None:
                continue
            review_status = (
                str(post.get("reviewStatus", "approved")).strip().lower()
                or "approved"
            )
            if review_status not in {"approved", "resolved"}:
                continue
            author_id = str(post.get("authorId", "")).strip()
            if (
                not is_post_private(post)
                or (viewer_user_id and viewer_user_id == author_id)
            ):
                allowed = True
                break
        if not allowed:
            return False
    if not matching_uploads:
        storage_path = f"/api/storage/{object_key}"
        referenced_by_user = any(
            not user.get("deleted")
            and storage_path
            in {
                str(user.get("avatarUrl", "")).strip(),
                str(user.get("backgroundImageUrl", "")).strip(),
            }
            for user in db.get("users", [])
        )
        release = (
            db.get("settings", {}).get("androidRelease", {})
            if isinstance(db.get("settings"), dict)
            else {}
        )
        referenced_by_release = (
            isinstance(release, dict)
            and str(release.get("objectKey", "")).strip() == object_key
        )
        if not referenced_by_user and not referenced_by_release:
            return False

    try:
        result = _globals.OBJECT_STORAGE.get_bytes(object_key)
    except ValueError:
        return False
    if result is None:
        return False

    data, content_type = result
    send_binary(handler, HTTPStatus.OK, data, content_type)
    return True


def handle_web_fallback_get(
    handler: BaseHTTPRequestHandler,
    path: str,
) -> bool:
    """
    Serve index.html for any unmatched GET path that should fall back to SPA.
    Returns True if this path was handled, False otherwise.
    """
    if not should_fallback_to_spa(path):
        return False

    asset_path = resolve_web_asset_path(path)
    send_static_file(handler, asset_path, fallback_to_index=True)
    return True
