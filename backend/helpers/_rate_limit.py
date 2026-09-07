from __future__ import annotations

import ipaddress
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
        stale_keys: list[tuple[str, str]] = []
        for existing_key, existing_queue in _globals.RATE_LIMIT_EVENTS.items():
            existing_window = _globals.RATE_LIMIT_WINDOWS_SECONDS.get(
                existing_key[1],
                3600,
            )
            while existing_queue and now - existing_queue[0] >= existing_window:
                existing_queue.popleft()
            if not existing_queue:
                stale_keys.append(existing_key)
        for stale_key in stale_keys:
            _globals.RATE_LIMIT_EVENTS.pop(stale_key, None)
        if (
            len(_globals.RATE_LIMIT_EVENTS) >= _globals.RATE_LIMIT_SUBJECT_MAX
            and key not in _globals.RATE_LIMIT_EVENTS
        ):
            oldest_key = min(
                _globals.RATE_LIMIT_EVENTS,
                key=lambda item: _globals.RATE_LIMIT_EVENTS[item][-1],
            )
            _globals.RATE_LIMIT_EVENTS.pop(oldest_key, None)
        queue = _globals.RATE_LIMIT_EVENTS.setdefault(key, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        # Cap memory per bucket, but never below the limit we are enforcing:
        # truncating to fewer entries than `limit` would make len(queue) >= limit
        # unreachable and silently disable the limit altogether (admins can set
        # these above RATE_LIMIT_EVENT_MAX from the config page).
        cap = max(_globals.RATE_LIMIT_EVENT_MAX, limit + 1)
        while len(queue) > cap:
            queue.popleft()
        return True, 0


def _parse_ip(value: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address | None:
    candidate = (value or "").strip()
    if not candidate:
        return None
    # Tolerate "[::1]:443" / "1.2.3.4:443" forms emitted by some proxies.
    if candidate.startswith("["):
        candidate = candidate[1:].split("]", 1)[0]
    elif candidate.count(":") == 1:
        candidate = candidate.split(":", 1)[0]
    try:
        address = ipaddress.ip_address(candidate)
    except ValueError:
        return None
    # A dual-stack listener reports IPv4 peers as "::ffff:127.0.0.1".  Such an
    # address is NOT a member of any IPv4Network (ipaddress compares versions
    # first), so without this the local nginx would not match 127.0.0.1/32 and
    # every request would collapse into a single shared rate-limit bucket.
    mapped = getattr(address, "ipv4_mapped", None)
    if mapped is not None:
        return mapped
    return address


def _is_trusted_proxy(address: ipaddress.IPv4Address | ipaddress.IPv6Address | None) -> bool:
    if address is None:
        return False
    return any(address in network for network in _globals.TRUSTED_PROXY_NETWORKS)


def get_client_ip(handler: BaseHTTPRequestHandler) -> str:
    """Resolve the real client IP, honouring proxy headers only from trusted peers.

    Behind our own nginx, X-Real-IP is authoritative: every deploy config sets
    `proxy_set_header X-Real-IP $remote_addr`, which *overwrites* whatever the
    client sent, so from a trusted peer it is the true socket address of the
    caller.  It is preferred over X-Forwarded-For, whose leftmost entries stay
    attacker-controlled (nginx appends with $proxy_add_x_forwarded_for, so a
    forged prefix survives) and which therefore has to be walked right-to-left.

    A client address in RFC1918 space is a normal client — campus NAT, VPN,
    the docker bridge — and must not be mistaken for a proxy hop.  Treating it
    as one used to make every such caller fall through to the peer address, so
    they all shared a single rate-limit bucket and could exhaust each other's
    login / upload / AI quota.  Only *intermediate* hops are skipped.
    """
    peer_raw = ""
    try:
        peer_raw = handler.client_address[0] or ""
    except (AttributeError, IndexError, TypeError):
        peer_raw = ""
    peer = _parse_ip(peer_raw)

    if not _is_trusted_proxy(peer):
        # Direct connection (or an unknown peer): never trust forwarding headers.
        return str(peer) if peer is not None else (peer_raw.strip() or "unknown")

    real_ip = _parse_ip(handler.headers.get("X-Real-IP", "") or "")
    if real_ip is not None:
        return str(real_ip)

    # Fallback for a proxy that did not set X-Real-IP.  Take the *rightmost*
    # X-Forwarded-For entry and nothing else: with $proxy_add_x_forwarded_for
    # that is the address the trusted proxy itself observed, so it is the one
    # entry a client cannot forge.  Anything further left is client-supplied.
    # This assumes a single trusted hop, which is what every deploy config in
    # this repo sets up; add X-Real-IP at the outermost proxy before adding a
    # second layer.
    for entry in reversed((handler.headers.get("X-Forwarded-For", "") or "").split(",")):
        candidate = _parse_ip(entry)
        if candidate is not None:
            return str(candidate)

    return str(peer) if peer is not None else "unknown"


_IP_RATE_LIMIT_LAST_PRUNE: float = 0.0
_IP_RATE_LIMIT_PRUNE_INTERVAL_SECONDS = 300
_IP_RATE_LIMIT_MAX_TRACKED_IPS = 20000


def _prune_ip_rate_limit_events(now: float) -> None:
    """Drop per-IP buckets whose events have all aged out.

    Callers must already hold IP_RATE_LIMIT_LOCK.  Without this the table grows
    without bound, one entry per distinct source address.
    """
    global _IP_RATE_LIMIT_LAST_PRUNE

    events = _globals.IP_RATE_LIMIT_EVENTS
    over_capacity = len(events) > _IP_RATE_LIMIT_MAX_TRACKED_IPS
    if (
        not over_capacity
        and now - _IP_RATE_LIMIT_LAST_PRUNE < _IP_RATE_LIMIT_PRUNE_INTERVAL_SECONDS
    ):
        return
    _IP_RATE_LIMIT_LAST_PRUNE = now

    for tracked_ip in list(events.keys()):
        buckets = events.get(tracked_ip) or {}
        for bucket_action in list(buckets.keys()):
            queue = buckets[bucket_action]
            bucket_window = (
                _globals.IP_RATE_LIMITS.get(bucket_action, {}) or {}
            ).get("window", 3600)
            while queue and now - queue[0] >= bucket_window:
                queue.popleft()
            if not queue:
                buckets.pop(bucket_action, None)
        if not buckets:
            events.pop(tracked_ip, None)

    # Hard ceiling: if a flood from many distinct sources still leaves us over
    # capacity, evict the least-recently-active buckets.  Clearing the whole
    # table would let an attacker reset everyone's quota on demand simply by
    # touching enough distinct addresses.
    overflow = len(events) - _IP_RATE_LIMIT_MAX_TRACKED_IPS
    if overflow > 0:
        def _last_seen(item: tuple[str, dict]) -> float:
            return max(
                (queue[-1] for queue in item[1].values() if queue),
                default=0.0,
            )

        for tracked_ip, _buckets in sorted(events.items(), key=_last_seen)[:overflow]:
            events.pop(tracked_ip, None)


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
        _prune_ip_rate_limit_events(now)

        ip_events = _globals.IP_RATE_LIMIT_EVENTS.setdefault(ip, {})
        queue = ip_events.setdefault(action, deque())
        while queue and now - queue[0] >= window_seconds:
            queue.popleft()

        if len(queue) >= limit:
            retry_after = max(1, int(window_seconds - (now - queue[0])))
            return False, retry_after

        queue.append(now)
        while len(queue) > _globals.RATE_LIMIT_EVENT_MAX:
            queue.popleft()
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
