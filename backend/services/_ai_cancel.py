"""Stop an in-flight AI request, including its upstream model calls.

Each chat turn can spend thousands of generated tokens upstream. When the user
presses 停止 the client drops its own request, but the server would otherwise
keep the provider generating (and billing) until the answer completes. The
client therefore tags each request with a requestId and calls the cancel
endpoint; this module lets that second request reach the first one's thread.

Cancelling sets a flag the pipeline checks before each stage, and closes the
upstream response the pipeline is blocked reading, which drops the provider
connection so generation stops there too.
"""

from __future__ import annotations

import re
import threading
import time
from typing import Any

_REQUEST_ID = re.compile(r"[A-Za-z0-9_-]{8,64}")

# A cancel can arrive before its chat request is registered (the client may
# press 停止 while the chat request is still queued). Remember such cancels
# briefly so the chat request starts already cancelled.
_EARLY_CANCEL_TTL_SECONDS = 300
_MAX_EARLY_CANCELS = 1000


class AiRequestCancelled(RuntimeError):
    """The user stopped this request; not a provider failure."""


class CancelToken:
    def __init__(self) -> None:
        self._event = threading.Event()
        self._lock = threading.Lock()
        self._open: list[Any] = []

    @property
    def cancelled(self) -> bool:
        return self._event.is_set()

    def raise_if_cancelled(self) -> None:
        if self._event.is_set():
            raise AiRequestCancelled("已停止生成")

    def attach(self, response: Any) -> None:
        """Track an open upstream response so cancel() can close it."""
        with self._lock:
            if self._event.is_set():
                _close_quietly(response)
                raise AiRequestCancelled("已停止生成")
            self._open.append(response)

    def detach(self, response: Any) -> None:
        with self._lock:
            if response in self._open:
                self._open.remove(response)

    def cancel(self) -> None:
        with self._lock:
            self._event.set()
            responses, self._open = self._open, []
        for response in responses:
            _close_quietly(response)


def _close_quietly(response: Any) -> None:
    try:
        response.close()
    except Exception:
        pass


_lock = threading.Lock()
_active: dict[tuple[str, str], CancelToken] = {}
_early: dict[tuple[str, str], float] = {}


def valid_request_id(value: Any) -> str | None:
    text = str(value or "").strip()
    return text if _REQUEST_ID.fullmatch(text) else None


def _prune_early(now: float) -> None:
    for key, at in list(_early.items()):
        if now - at > _EARLY_CANCEL_TTL_SECONDS:
            del _early[key]
    while len(_early) > _MAX_EARLY_CANCELS:
        del _early[next(iter(_early))]


def begin(user_id: str, request_id: str | None) -> CancelToken:
    """Register a request. Without a requestId it simply cannot be cancelled."""
    token = CancelToken()
    if request_id is None:
        return token
    key = (user_id, request_id)
    with _lock:
        _prune_early(time.monotonic())
        if _early.pop(key, None) is not None:
            token.cancel()
        _active[key] = token
    return token


def end(user_id: str, request_id: str | None, token: CancelToken) -> None:
    if request_id is None:
        return
    with _lock:
        if _active.get((user_id, request_id)) is token:
            del _active[(user_id, request_id)]


def cancel(user_id: str, request_id: str) -> bool:
    """Cancel the caller's own request. True when it was running."""
    key = (user_id, request_id)
    with _lock:
        token = _active.get(key)
        if token is None:
            now = time.monotonic()
            _prune_early(now)
            _early[key] = now
    if token is None:
        return False
    token.cancel()
    return True
