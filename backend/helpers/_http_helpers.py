from __future__ import annotations

import io
import json
import mimetypes
import re
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import quote

from helpers._datetime_helpers import now_iso


def _sanitize_header_filename(filename: str) -> str:
    """Strip path separators and anything that could break out of the header."""
    cleaned = re.sub(r"[\r\n\x00-\x1f\x7f]", "", str(filename or ""))
    cleaned = cleaned.replace("\\", "/").rsplit("/", 1)[-1]
    cleaned = cleaned.replace('"', "").strip()
    return cleaned[:180] or "download"


class RequestBodyTooLarge(ValueError):
    pass


class InvalidJsonBody(ValueError):
    pass


def _allowed_cors_origin(handler: BaseHTTPRequestHandler) -> str:
    import _globals

    origin = (handler.headers.get("Origin", "") or "").strip().rstrip("/")
    if origin and origin in _globals.CORS_ALLOWED_ORIGINS:
        return origin
    return ""


def request_origin_allowed(handler: BaseHTTPRequestHandler) -> bool:
    origin = (handler.headers.get("Origin", "") or "").strip()
    return not origin or bool(_allowed_cors_origin(handler))


def _send_cors_headers(handler: BaseHTTPRequestHandler) -> None:
    origin = _allowed_cors_origin(handler)
    if origin:
        handler.send_header("Access-Control-Allow-Origin", origin)
        handler.send_header("Vary", "Origin")
    handler.send_header(
        "Access-Control-Allow-Methods",
        "GET, POST, PATCH, DELETE, OPTIONS",
    )
    handler.send_header(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization, X-Client-Type, X-Request-ID",
    )
    handler.send_header("Access-Control-Expose-Headers", "X-Request-ID")


def read_json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    import _globals

    length_str = handler.headers.get("Content-Length", "0")
    try:
        length = max(0, int(length_str))
    except ValueError:
        length = 0
    if length > _globals.MAX_REQUEST_BODY_BYTES:
        raise RequestBodyTooLarge(
            f"request body exceeds {_globals.MAX_REQUEST_BODY_BYTES // (1024 * 1024)} MB",
        )
    body = handler.rfile.read(length) if length > 0 else b""
    if not body:
        return {}
    try:
        parsed = json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise InvalidJsonBody("请求体不是有效的 JSON") from error
    if not isinstance(parsed, dict):
        raise InvalidJsonBody("JSON 请求体必须是对象")
    return parsed


def send_json(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    data: Any,
    *,
    no_cache: bool = False,
) -> None:
    code = int(status)
    body = json.dumps(data, ensure_ascii=False)
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    request_id = str(getattr(handler, "request_id", "") or "").strip()
    if request_id:
        handler.send_header("X-Request-ID", request_id)
    _send_cors_headers(handler)
    if no_cache:
        handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(body.encode("utf-8"))))
    handler.end_headers()
    handler.wfile.write(body.encode("utf-8"))


def json_error(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    message: str,
    *,
    data: Any = None,
) -> None:
    payload: dict[str, Any] = {"message": message}
    if data is not None:
        payload["data"] = data
    send_json(handler, status, payload)


def _send_content_security_headers(
    handler: BaseHTTPRequestHandler,
    *,
    sandbox: bool,
) -> None:
    """Headers that stop user-supplied bytes from being treated as active
    content on our own origin."""
    handler.send_header("X-Content-Type-Options", "nosniff")
    if sandbox:
        # User uploads: no scripts, no plugins, no framing, no navigation.
        handler.send_header(
            "Content-Security-Policy",
            "default-src 'none'; img-src 'self' data:; media-src 'self'; "
            "style-src 'unsafe-inline'; sandbox; frame-ancestors 'none'",
        )
        handler.send_header("X-Frame-Options", "DENY")
        # Deliberately "cross-origin", not "same-origin": the web build is often
        # served from a different origin than the API (see API_BASE_URL), and
        # same-origin here would block every avatar and post image in that
        # topology.  nosniff + the sandbox CSP are what actually prevent these
        # bytes from executing.
        handler.send_header("Cross-Origin-Resource-Policy", "cross-origin")


def send_binary(
    handler: BaseHTTPRequestHandler,
    status: HTTPStatus | int,
    data: bytes,
    content_type: str,
    *,
    filename: str = "",
    inline: bool = False,
) -> None:
    code = int(status)
    handler.send_response(code)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    _send_cors_headers(handler)
    _send_content_security_headers(handler, sandbox=True)
    disposition = "inline" if inline else "attachment"
    if filename:
        safe_filename = _sanitize_header_filename(filename)
        encoded_filename = quote(safe_filename, safe="")
        ascii_fallback = (
            re.sub(r'[^A-Za-z0-9._-]', "_", safe_filename) or "download"
        )
        handler.send_header(
            "Content-Disposition",
            f'{disposition}; filename="{ascii_fallback}"; '
            f"filename*=UTF-8''{encoded_filename}",
        )
    else:
        handler.send_header("Content-Disposition", disposition)
    handler.end_headers()
    handler.wfile.write(data)


def send_static_file(
    handler: BaseHTTPRequestHandler,
    file_path: Path,
) -> None:
    try:
        data = file_path.read_bytes()
    except OSError:
        json_error(handler, HTTPStatus.NOT_FOUND, "Not Found")
        return

    content_type, _ = mimetypes.guess_type(str(file_path))
    if file_path.suffix == ".wasm":
        content_type = "application/wasm"
    if not content_type:
        content_type = "application/octet-stream"

    handler.send_response(HTTPStatus.OK)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    _send_cors_headers(handler)
    # Trusted first-party bundle: nosniff only, no sandbox (it must run).
    _send_content_security_headers(handler, sandbox=False)
    # Beta deployment prefers freshness over caching to avoid stale Flutter bundles.
    handler.send_header("Cache-Control", "no-cache")
    handler.end_headers()
    handler.wfile.write(data)


def resolve_web_asset_path(path: str) -> Path | None:
    from _globals import WEB_ROOT_DIR

    raw = path or "/"
    # Remove URL-encoded characters (unquote equivalent via urllib)
    try:
        from urllib.parse import unquote
        raw = unquote(raw)
    except ImportError:
        pass
    normalized = raw.lstrip("/")
    if not normalized:
        target = WEB_ROOT_DIR / "index.html"
    else:
        target = (WEB_ROOT_DIR / normalized).resolve()
    try:
        target.relative_to(WEB_ROOT_DIR)
    except ValueError:
        return None
    if target.is_dir():
        target = target / "index.html"
    return target


def should_fallback_to_spa(path: str) -> bool:
    if not path.startswith("/"):
        return False
    if "?" in path:
        path = path.split("?")[0]
    if "." in path:
        filename = path.rsplit(".", 1)[-1].lower()
        if filename not in {"html", "htm"}:
            return True
        return False
    return True
