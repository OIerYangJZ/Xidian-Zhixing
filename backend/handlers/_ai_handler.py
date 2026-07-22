"""Server-owned AI chat and retrieval endpoints."""
from __future__ import annotations

import json
import re
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import _globals
from helpers import json_error, read_json_body, send_json
from rag_service import citations, retrieve
from services import auth_user as auth_user_helper, save_db


MAX_CONTEXT_ITEMS = 8


def _require_auth(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> dict[str, Any] | None:
    user, _ = auth_user_helper(handler, db)
    if user is None:
        json_error(handler, HTTPStatus.UNAUTHORIZED, "Unauthorized")
        return None
    return user


def _clean_text(value: Any, max_len: int = 4000) -> str:
    text = str(value or "").replace("\r\n", "\n").replace("\r", "\n")
    return re.sub(r"\s+", " ", text).strip()[:max_len]


def _normalize_base_url(value: Any) -> str:
    url = str(value or "").strip().rstrip("/")
    if not url:
        return ""
    if not re.match(r"^https?://[^/]+", url):
        return ""
    return url if url.endswith("/v1") else f"{url}/v1"


def _configured_provider() -> tuple[str, str, str]:
    return (
        _normalize_base_url(_globals.AI_BASE_URL),
        str(_globals.AI_API_KEY or "").strip(),
        str(_globals.AI_MODEL or "").strip(),
    )


def _auth_headers(api_key: str) -> dict[str, str]:
    return {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}


def _read_provider_json(request: Request, timeout: int = 25) -> dict[str, Any]:
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as error:
        detail = ""
        try:
            detail = error.read().decode("utf-8")
        except Exception:
            detail = str(error)
        raise RuntimeError(f"模型接口返回 {error.code}: {detail[:240]}") from error
    except URLError as error:
        raise RuntimeError(f"无法连接模型接口: {error.reason}") from error
    except TimeoutError as error:
        raise RuntimeError("模型接口响应超时") from error
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RuntimeError("模型接口返回了无法解析的 JSON") from error
    if not isinstance(payload, dict):
        raise RuntimeError("模型接口返回格式异常")
    return payload


def _context_text(items: list[dict[str, Any]]) -> str:
    if not items:
        return "暂无可用检索资料。"
    lines: list[str] = []
    for index, item in enumerate(items, start=1):
        kind = "论坛帖子" if item.get("type") == "post" else "校园知识库"
        lines.append(
            f"[{index}] {kind}《{item.get('title', '')}》"
            f" 来源:{item.get('sourceUrl') or item.get('sourceName', '')}"
            f" 时间:{item.get('createdAt', '')}\n{item.get('content', '')}"
        )
    return "\n\n".join(lines)


def _call_chat_completion(
    *,
    base_url: str,
    api_key: str,
    model: str,
    question: str,
    messages: list[dict[str, str]],
    context_items: list[dict[str, Any]],
) -> str:
    system_prompt = (
        "你是「电台」的校园 AI 助手。只能把检索资料作为事实依据，不能编造地点、时间、政策、联系人或帖子内容。"
        "校园知识库是管理员维护资料，论坛内容是公开社区经验；引用论坛时必须明确说是同学讨论或经验。"
        "资料不足时明确说明不确定，并给出官方入口或下一步查询建议。回答使用简洁中文。"
        "如果资料之间存在时间或内容冲突，分别说明来源和日期。每条具体事实后使用对应的 [编号] 标注引用；没有证据的内容不要加编号。"
    )
    payload_messages: list[dict[str, str]] = [
        {"role": "system", "content": system_prompt},
        {"role": "system", "content": f"检索资料（引用编号必须与资料编号对应）:\n{_context_text(context_items)}"},
    ]
    for message in messages[-8:]:
        role = "assistant" if message.get("role") == "assistant" else "user"
        content = _clean_text(message.get("content", ""), 1600)
        if content:
            payload_messages.append({"role": role, "content": content})
    payload_messages.append({"role": "user", "content": question})
    request = Request(
        f"{base_url}/chat/completions",
        data=json.dumps({
            "model": model,
            "messages": payload_messages,
            "temperature": 0.2,
            "stream": False,
        }, ensure_ascii=False).encode("utf-8"),
        headers=_auth_headers(api_key),
        method="POST",
    )
    data = _read_provider_json(request, timeout=45)
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise RuntimeError("模型接口没有返回回答")
    message = choices[0].get("message") if isinstance(choices[0], dict) else {}
    reply = _clean_text(message.get("content") if isinstance(message, dict) else "", 6000)
    if not reply:
        raise RuntimeError("模型接口返回了空回答")
    return reply


def handle_ai_models(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    """GET /api/ai/models; provider credentials never come from clients."""
    if _require_auth(handler, db) is None:
        return
    base_url, api_key, model = _configured_provider()
    if not base_url or not api_key:
        json_error(handler, HTTPStatus.SERVICE_UNAVAILABLE, "服务器尚未配置 AI 服务")
        return
    request = Request(f"{base_url}/models", headers=_auth_headers(api_key), method="GET")
    try:
        data = _read_provider_json(request, timeout=20)
    except RuntimeError as error:
        json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
        return
    models: list[str] = []
    for row in data.get("data", []):
        value = row.get("id") if isinstance(row, dict) else row
        if str(value or "").strip():
            models.append(str(value).strip())
    if model and model not in models:
        models.insert(0, model)
    send_json(handler, HTTPStatus.OK, {"data": {"models": sorted(dict.fromkeys(models)), "currentModel": model}})


def handle_ai_chat(handler: BaseHTTPRequestHandler, db: dict[str, Any]) -> None:
    user = _require_auth(handler, db)
    if user is None:
        return
    body = read_json_body(handler)
    if not body:
        json_error(handler, HTTPStatus.BAD_REQUEST, "Invalid JSON body")
        return
    question = _clean_text(body.get("content") or body.get("question"), 2000)
    if not question:
        json_error(handler, HTTPStatus.BAD_REQUEST, "Content is required")
        return
    base_url, api_key, configured_model = _configured_provider()
    if not base_url or not api_key:
        json_error(handler, HTTPStatus.SERVICE_UNAVAILABLE, "服务器尚未配置 AI 服务")
        return
    model = configured_model
    raw_messages = body.get("messages", [])
    messages = raw_messages if isinstance(raw_messages, list) else []
    include_posts = body.get("includePosts") is not False
    context_items = retrieve(db, question, include_posts=include_posts, limit=MAX_CONTEXT_ITEMS)
    try:
        reply = _call_chat_completion(
            base_url=base_url,
            api_key=api_key,
            model=model,
            question=question,
            messages=messages,
            context_items=context_items,
        )
    except RuntimeError as error:
        json_error(handler, HTTPStatus.BAD_GATEWAY, str(error))
        return
    db.setdefault("ragRetrievalLogs", []).append({
        "queryLength": len(question),
        "includePosts": include_posts,
        "sourceKeys": [str(item.get("key", "")) for item in context_items],
        "createdAt": _globals.now_iso(),
    })
    db["ragRetrievalLogs"] = db["ragRetrievalLogs"][-500:]
    save_db(db)
    reference_rows = citations(context_items)
    send_json(handler, HTTPStatus.OK, {
        "data": {
            "answer": reply,
            "reply": reply,
            "role": "assistant",
            "model": model,
            "citations": reference_rows,
            "references": reference_rows,
            "relatedActions": [],
            "usage": {
                "sourceCount": len(context_items),
                "knowledgeCount": sum(1 for item in context_items if item.get("type") == "knowledge"),
                "postCount": sum(1 for item in context_items if item.get("type") == "post"),
            },
            "reviewStatus": "approved",
        }
    })
