from __future__ import annotations

import re
import time
import unicodedata
from collections import deque
from http.server import BaseHTTPRequestHandler
from typing import Any

import _globals


PROHIBITED_CONTENT_TERMS: dict[str, tuple[str, ...]] = {
    "血腥": (
        "血腥",
        "血肉模糊",
        "肢解",
        "碎尸",
        "斩首",
        "开膛",
        "割喉",
        "断肢",
        "虐杀",
        "gore",
        "dismemberment",
        "beheading",
    ),
    "暴力": (
        "暴力",
        "殴打",
        "群殴",
        "砍人",
        "捅人",
        "枪杀",
        "虐待",
        "家暴",
        "恐怖袭击",
        "校园霸凌",
        "violent assault",
    ),
    "色情": (
        "色情",
        "淫秽",
        "成人影片",
        "成人视频",
        "黄色内容",
        "黄色图片",
        "黄色视频",
        "黄色网站",
        "裸聊",
        "约炮",
        "卖淫",
        "嫖娼",
        "强奸",
        "乱伦",
        "porn",
        "pornography",
        "sexual content",
    ),
    "违法犯罪": (
        "违法犯罪",
        "诈骗",
        "毒品",
        "贩毒",
        "制毒",
        "赌博网站",
        "赌博平台",
        "洗钱",
        "枪支交易",
        "炸弹制作",
        "买卖身份证",
        "伪造证件",
        "入室盗窃",
        "抢劫",
        "绑架",
        "勒索",
        "黑客攻击",
        "盗号",
        "criminal activity",
        "drug trafficking",
        "money laundering",
    ),
}


def _normalize_moderation_text(value: Any) -> str:
    return unicodedata.normalize("NFKC", str(value or "")).casefold()


def _moderation_term_matches(normalized_text: str, term: str) -> bool:
    normalized_term = _normalize_moderation_text(term).strip()
    if not normalized_term:
        return False

    if re.fullmatch(r"[a-z0-9 ]+", normalized_term):
        pattern = (
            r"(?<![a-z0-9])"
            + re.escape(normalized_term).replace(r"\ ", r"\s+")
            + r"(?![a-z0-9])"
        )
        return re.search(pattern, normalized_text) is not None

    compact_text = re.sub(r"[\W_]+", "", normalized_text, flags=re.UNICODE)
    compact_term = re.sub(r"[\W_]+", "", normalized_term, flags=re.UNICODE)
    return bool(compact_term and compact_term in compact_text)


def get_setting_int(db: dict[str, Any], key: str, default: int, *, minimum: int = 1) -> int:
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        try:
            return max(minimum, int(settings.get(key, default)))
        except (TypeError, ValueError):
            return max(minimum, default)
    return max(minimum, default)


def consume_rate_limit(
    db: dict[str, Any],
    *,
    user_id: str,
    action: str,
    setting_key: str,
    default_limit: int,
) -> tuple[bool, int]:
    limit = get_setting_int(db, setting_key, default_limit, minimum=1)
    window_seconds = _globals.RATE_LIMIT_WINDOWS_SECONDS.get(action, 3600)
    now = time.time()
    key = (user_id, action)

    with _globals.RATE_LIMIT_LOCK:
        queue = _globals.RATE_LIMIT_EVENTS.setdefault(key, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        while len(queue) > 300:
            queue.popleft()
        return True, 0


def get_client_ip(handler: BaseHTTPRequestHandler) -> str:
    x_forwarded_for = handler.headers.get("X-Forwarded-For", "")
    if x_forwarded_for:
        return x_forwarded_for.split(",")[0].strip()
    x_real_ip = handler.headers.get("X-Real-IP", "")
    if x_real_ip:
        return x_real_ip.strip()
    return handler.client_address[0] or "unknown"


def check_ip_rate_limit(
    handler: BaseHTTPRequestHandler,
    action: str,
) -> tuple[bool, int]:
    ip = get_client_ip(handler)
    limits = _globals.IP_RATE_LIMITS.get(action)
    if not limits:
        return True, 0
    limit = limits["limit"]
    window_seconds = limits["window"]
    now = time.time()

    with _globals.IP_RATE_LIMIT_LOCK:
        ip_events = _globals.IP_RATE_LIMIT_EVENTS.setdefault(ip, {})
        queue = ip_events.setdefault(action, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        return True, 0


def check_duplicate_image_hash(db: dict[str, Any], image_hash: str) -> bool:
    if not image_hash:
        return False
    return any(
        (upload.get("sha256") == image_hash or upload.get("hash") == image_hash)
        for upload in db.get("mediaUploads", [])
        if upload.get("sha256") or upload.get("hash")
    )


def assess_text_risk(
    db: dict[str, Any],
    text: str,
    *,
    block_on_match: bool = False,
) -> tuple[bool, bool, list[str]]:
    normalized = _normalize_moderation_text(text).strip()
    if not normalized:
        return False, False, []

    reasons: list[str] = []
    spam_re = re.compile(r"(.)\1{8,}", re.DOTALL)

    prohibited_categories = (
        [
            category
            for category, terms in PROHIBITED_CONTENT_TERMS.items()
            if any(_moderation_term_matches(normalized, term) for term in terms)
        ]
        if block_on_match
        else []
    )
    reasons.extend(f"禁止内容类别: {category}" for category in prohibited_categories)

    hit_words = [
        str(word).strip()
        for word in db.get("sensitiveWords", [])
        if str(word).strip() and _moderation_term_matches(normalized, str(word))
    ]
    if hit_words:
        reasons.append(f"命中敏感词: {','.join(hit_words[:3])}")

    if spam_re.search(normalized):
        reasons.append("疑似重复刷屏文本")
    if len(normalized) > 5000:
        reasons.append("文本长度异常")

    risk_marked = bool(reasons)
    high_risk = block_on_match and bool(prohibited_categories or hit_words)
    return risk_marked, high_risk, reasons


def send_rate_limit_error(
    handler: BaseHTTPRequestHandler,
    *,
    action_text: str,
    retry_after_seconds: int,
) -> None:
    from helpers._http_helpers import send_json
    from http import HTTPStatus
    send_json(
        handler,
        HTTPStatus.TOO_MANY_REQUESTS,
        {
            "message": f"{action_text}过于频繁，请在 {retry_after_seconds} 秒后重试",
            "data": {"retryAfterSeconds": retry_after_seconds},
        },
    )
