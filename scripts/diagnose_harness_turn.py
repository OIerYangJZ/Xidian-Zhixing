"""Measure one real turn: the current provider latency and what the tools actually return.

Run through the parent's .env.local loader so no credential is printed.
"""
from __future__ import annotations

import asyncio
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent_harness import app as h  # noqa: E402

QUESTION = sys.argv[1] if len(sys.argv) > 1 else "物理学院有哪些科研团队"

# Time the provider itself by wrapping the model's request, so turn time can be split into
# model latency and tool latency instead of guessed at.
from pydantic_ai.models import Model  # noqa: E402

original_request = Model.request
provider_seconds = 0.0
provider_calls = 0


async def timed_request(self, *args, **kwargs):  # noqa: ANN001, ANN002, ANN003
    global provider_seconds, provider_calls
    started = time.perf_counter()
    try:
        return await original_request(self, *args, **kwargs)
    finally:
        provider_seconds += time.perf_counter() - started
        provider_calls += 1


Model.request = timed_request

tool_seconds: dict[str, float] = {}
for name in ("search_all_sources", "read_files", "read_web_pages", "find_files", "search_docs", "present_ui"):
    original = getattr(h, name, None)
    if original is None:
        continue

    def wrapper(*args, __name=name, __original=original, **kwargs):  # noqa: ANN002, ANN003
        started = time.perf_counter()
        outcome = __original(*args, **kwargs)

        async def finish():
            try:
                return await outcome
            finally:
                tool_seconds[__name] = tool_seconds.get(__name, 0.0) + (time.perf_counter() - started)

        return finish() if hasattr(outcome, "__await__") else outcome

    setattr(h, name, wrapper)


async def main() -> None:
    print("model:", h.model_name, "| backends:", h.DDGS_BACKENDS)
    started = time.perf_counter()
    result = await h.chat(h.ChatRequest(question=QUESTION, trace_id="measure-trace"))
    total = time.perf_counter() - started
    usage = result["usage"]
    print(json.dumps({
        "question": QUESTION,
        "durationMs": result["durationMs"],
        "wallSeconds": round(total, 2),
        "providerSeconds": round(provider_seconds, 2),
        "providerCalls": provider_calls,
        "toolSeconds": {k: round(v, 2) for k, v in tool_seconds.items()},
        "usage": usage,
        "sources": len(result["sources"]),
        "cards": len((result.get("ui") or {}).get("cards", []) or []),
    }, ensure_ascii=False, indent=2))
    print("answer chars:", len(result["answer"]))


asyncio.run(main())
