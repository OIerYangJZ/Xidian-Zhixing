"""
handlers/_web_session_handler.py

Page-gate cookie for the static web frontend:
  POST   /api/auth/web-session   — mirror the caller's bearer token into an HttpOnly cookie
  DELETE /api/auth/web-session   — clear that cookie
  GET    /api/auth/check         — 204 if the cookie names a live session, else 401

The static site cannot redirect on the server the way a Next.js middleware
would, so Nginx does it instead: `auth_request /api/auth/check` in front of the
signed-in pages.  The cookie only ever answers "may this page load?".  API
calls still authenticate with the Authorization header alone, and auth_user
never reads cookies, so the cookie grants nothing a cross-site request could
use.
"""
from __future__ import annotations

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any

import _globals
from handlers._auth_handler import _read_cookie
from helpers import json_error
from services import auth_user as auth_user_helper
from sql_repository import SESSION_MAX_AGE_DAYS

WEB_SESSION_COOKIE_NAME = "zx_session"
_WEB_SESSION_MAX_AGE_SECONDS = SESSION_MAX_AGE_DAYS * 24 * 60 * 60


def _build_session_cookie(token: str, *, max_age: int) -> str:
    parts = [
        f"{WEB_SESSION_COOKIE_NAME}={token}",
        f"Max-Age={max(0, max_age)}",
        "Path=/",
        "HttpOnly",
        "SameSite=Lax",
    ]
    if _public_origin_is_https():
        parts.append("Secure")
    return "; ".join(parts)


def _public_origin_is_https() -> bool:
    # Read the setting directly: the auth handler's _client_origin raises when
    # unified auth is not configured, and the page gate must still work there
    # (local development, or a deployment with IDS switched off).
    origin = str(getattr(_globals, "BACKEND_XIDIAN_PUBLIC_ORIGIN", "") or "").strip()
    return origin.lower().startswith("https://")


def _send_empty(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus,
    *,
    cookie: str = "",
) -> None:
    handler.send_response(int(status))
    if cookie:
        handler.send_header("Set-Cookie", cookie)
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", "0")
    handler.end_headers()


def handle_web_session_create(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user, token = auth_user_helper(handler, db)
    if user is None or not token or user.get("deleted"):
        json_error(handler, HTTPStatus.UNAUTHORIZED, "请先登录")
        return
    _send_empty(
        handler,
        HTTPStatus.NO_CONTENT,
        cookie=_build_session_cookie(token, max_age=_WEB_SESSION_MAX_AGE_SECONDS),
    )


def handle_web_session_delete(handler: BaseHTTPRequestHandler) -> None:
    _send_empty(
        handler,
        HTTPStatus.NO_CONTENT,
        cookie=_build_session_cookie("", max_age=0),
    )


def handle_auth_check(handler: BaseHTTPRequestHandler) -> None:
    """Answer Nginx's auth_request subrequest.

    Runs on every navigation to a signed-in page, so it looks up the one
    session row instead of going through load_db.  Banned accounts pass: their
    pages have to load to show the ban notice and the appeal form, and the API
    session floor already limits what they can do.
    """
    token = _read_cookie(handler, WEB_SESSION_COOKIE_NAME)
    user = _globals.REPOSITORY.lookup_session_user(token) if token else None
    if (
        user is None
        or user.get("deleted")
        or not _globals.is_auth_student_id_allowed(str(user.get("studentId", "")))
    ):
        _send_empty(handler, HTTPStatus.UNAUTHORIZED)
        return
    _send_empty(handler, HTTPStatus.NO_CONTENT)
