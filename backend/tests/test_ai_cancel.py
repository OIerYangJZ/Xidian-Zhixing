"""Stopping an AI request must stop the upstream generation, not just the UI."""
import json
import threading
import time

import pytest

from handlers import _ai_handler
from services import _ai_cancel
from services._ai_cancel import AiRequestCancelled, CancelToken


class _Headers(dict):
    def get(self, key, default=None):
        return super().get(key, default)


class _StreamResponse:
    """An SSE response that serves [events] and then blocks like a provider
    still generating, until it is closed."""

    def __init__(self, events, *, block=True, content_type="text/event-stream"):
        self.headers = _Headers({"Content-Type": content_type})
        self._lines = [f"data: {e}\n".encode() for e in events]
        self._block = block
        self.closed = threading.Event()
        self.read_limits = []

    def readline(self, limit=-1):
        self.read_limits.append(limit)
        if self._lines:
            return self._lines.pop(0)
        if not self._block:
            return b""
        # Stand-in for a socket read waiting on the next token.
        if self.closed.wait(timeout=5):
            raise ValueError("I/O operation on closed file")
        raise AssertionError("upstream was never closed")

    def read(self, size=-1):
        return b""

    def close(self):
        self.closed.set()


def _delta(text):
    return json.dumps({"choices": [{"delta": {"content": text}}]})


def test_stream_is_reassembled_into_a_completion(monkeypatch):
    response = _StreamResponse([_delta("你"), _delta("好"), "[DONE]"], block=False)
    monkeypatch.setattr(_ai_handler, "urlopen", lambda *_a, **_k: response)

    data = _ai_handler._read_provider_stream(object(), timeout=5)

    assert data == {"choices": [{"message": {"content": "你好"}}]}
    assert response.closed.is_set()
    assert all(limit > 0 for limit in response.read_limits), "reads must be bounded"


def test_provider_that_ignores_stream_is_read_as_json(monkeypatch):
    body = json.dumps({"choices": [{"message": {"content": "ok"}}]}).encode()
    response = _StreamResponse([], block=False, content_type="application/json")
    response.read = lambda size=-1: body
    monkeypatch.setattr(_ai_handler, "urlopen", lambda *_a, **_k: response)

    assert _ai_handler._read_provider_stream(object(), timeout=5)["choices"][0][
        "message"]["content"] == "ok"


def test_cancel_closes_the_upstream_connection_mid_answer(monkeypatch):
    response = _StreamResponse([_delta("正在")])
    monkeypatch.setattr(_ai_handler, "urlopen", lambda *_a, **_k: response)
    token = CancelToken()
    outcome = {}

    def read():
        try:
            _ai_handler._read_provider_stream(object(), timeout=5, cancel=token)
        except Exception as error:  # noqa: BLE001 - recorded for the assertion
            outcome["error"] = error

    reader = threading.Thread(target=read)
    reader.start()
    time.sleep(0.05)  # the reader is now blocked waiting for the next token
    token.cancel()
    reader.join(timeout=2)

    assert not reader.is_alive(), "cancel must unblock the reader"
    assert response.closed.is_set(), "cancel must drop the provider connection"
    assert isinstance(outcome.get("error"), AiRequestCancelled)


def test_cancelled_token_starts_no_upstream_call(monkeypatch):
    def urlopen(*_a, **_k):
        raise AssertionError("no provider call after cancel")

    monkeypatch.setattr(_ai_handler, "urlopen", urlopen)
    token = CancelToken()
    token.cancel()
    with pytest.raises(AiRequestCancelled):
        _ai_handler._read_provider_stream(object(), timeout=5, cancel=token)


def test_generation_asks_for_a_stream_and_stops_retrying_once_cancelled(monkeypatch):
    calls = []
    token = CancelToken()

    def provider(request, timeout, cancel=None):
        calls.append(json.loads(request.data))
        token.cancel()  # user presses 停止 during the first attempt
        raise AiRequestCancelled("已停止生成")

    monkeypatch.setattr(_ai_handler, "_read_provider_stream", provider)
    with pytest.raises(AiRequestCancelled):
        _ai_handler._call_chat_completion(
            base_url="https://example.test/v1", api_key="k", model="m",
            question="图书馆几点关门", messages=[], context_items=[], cancel=token,
        )
    assert len(calls) == 1, "a cancelled request must not be retried"
    assert calls[0]["stream"] is True


def test_cancel_reaches_only_the_callers_own_request():
    token = _ai_cancel.begin("u1", "req-12345678")
    try:
        assert _ai_cancel.cancel("u2", "req-12345678") is False
        assert not token.cancelled
        assert _ai_cancel.cancel("u1", "req-12345678") is True
        assert token.cancelled
    finally:
        _ai_cancel.end("u1", "req-12345678", token)


def test_cancel_that_overtakes_its_request_still_applies():
    assert _ai_cancel.cancel("u1", "early-12345678") is False
    token = _ai_cancel.begin("u1", "early-12345678")
    try:
        assert token.cancelled
    finally:
        _ai_cancel.end("u1", "early-12345678", token)


def test_request_ids_are_validated():
    assert _ai_cancel.valid_request_id("abc") is None
    assert _ai_cancel.valid_request_id("../../etc/passwd") is None
    assert _ai_cancel.valid_request_id("a" * 65) is None
    assert _ai_cancel.valid_request_id("req_0123-abcd") == "req_0123-abcd"
