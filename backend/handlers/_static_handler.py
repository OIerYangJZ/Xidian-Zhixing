"""
handlers/_static_handler.py

Static file / asset serving:
  GET /api/storage/<object_key>   — object storage (avatars, post images);
                                   ?w=<width> returns a resized WebP
  GET /<fallback>                — SPA index.html for unmatched GET paths
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler

import _globals
from helpers import (
    json_error,
    resolve_web_asset_path,
    send_binary,
    send_static_file,
    should_fallback_to_spa,
)
from helpers._image_variants import cached_variant, snap_width
from services import auth_user as auth_user_helper, is_post_private


def handle_storage_get(
    handler: BaseHTTPRequestHandler,
    path: str,
    db: dict[str, Any],
    query: dict[str, list[str]] | None = None,
) -> bool:
    """
    Handle GET /api/storage/<object_key>.
    Returns True if this path was handled, False otherwise.

    With ?w=<width> an image is served as a WebP no wider than the nearest
    step in VARIANT_WIDTHS.  The visibility checks below run first either way.
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
                # Not attached to a post: avatars, profile backgrounds and
                # images staged before their post exists all live here, and
                # every other user legitimately needs to load them.  These are
                # capability URLs — object_storage mints keys as
                # token_hex(2)/token_hex(16), i.e. 128 bits of entropy, so the
                # key itself is the secret and cannot be enumerated.  Moderation
                # is still enforced: the status check above already rejects
                # anything not approved.
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
    requested_width = ((query or {}).get("w") or [""])[0]
    width = snap_width(requested_width) if requested_width else None
    if width is not None:
        storage = _globals.OBJECT_STORAGE
        root_dir = (
            Path(getattr(storage, "root_dir"))
            if getattr(storage, "backend_name", "") == "local"
            else None
        )
        variant = cached_variant(root_dir, object_key, data, content_type, width)
        if variant is not None:
            data, content_type = variant, "image/webp"
    # Images are meant to render in-page; anything else is forced to download so
    # it can never be interpreted as a document on our origin.
    is_image = str(content_type or "").lower().startswith("image/")
    send_binary(
        handler,
        HTTPStatus.OK,
        data,
        content_type,
        inline=is_image,
    )
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
    if asset_path is None:
        # Path escaped the web root (or could not be resolved) — never fall back
        # to index.html for it.
        json_error(handler, HTTPStatus.NOT_FOUND, "Not Found")
        return True
    if not asset_path.is_file():
        index_path = resolve_web_asset_path("/index.html")
        if index_path is None or not index_path.is_file():
            json_error(handler, HTTPStatus.NOT_FOUND, "Not Found")
            return True
        asset_path = index_path
    send_static_file(handler, asset_path)
    return True
