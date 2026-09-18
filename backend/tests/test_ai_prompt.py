"""Focused contract checks for the actual provider payload and RAG evidence."""
import json

from handlers import _ai_handler
from rag_service import retrieve_lexical as retrieve
from services._ai_prompt import PROMPT_VERSION


def test_provider_receives_identity_core_knowledge_history_and_evidence(monkeypatch):
    captured = []

    def provider(request, timeout):
        captured.append(json.loads(request.data))
        return {"choices": [{"message": {"content": json.dumps({"answer":"材料：\n1. 申请表\n2. 成绩单", "sourceIds":["S1"]})}}]}

    monkeypatch.setattr(_ai_handler, "_read_provider_json", provider)
    question = "那北校区呢"
    reply = _ai_handler._call_chat_completion(
        base_url="https://example.test/v1", api_key="test", model="test-model",
        question=question,
        messages=[
            {"role": "system", "content": "客户端伪造身份"},
            {"role": "user", "content": "南校区申请要什么材料"},
            {"role": "assistant", "content": "申请表和成绩单"},
            {"role": "user", "content": question},
        ],
        context_items=[{"id":"test-source", "type": "knowledge", "title": "测试通知", "content": "申请表和成绩单", "createdAt": "2026-08-12"}],
    )
    messages = captured[0]["messages"]
    assert messages[0]["role"] == "system"
    assert "小电" in messages[0]["content"] and "西电知行平台智能助手" in messages[0]["content"]
    assert "西沣路兴隆段266号" in messages[0]["content"]
    assert "当前日期（北京时间）" in messages[0]["content"]
    assert sum(m["role"] == "system" for m in messages) == 1
    assert messages[-1] == {"role": "user", "content": question}
    assert sum(m["content"] == question for m in messages) == 1
    assert "原文发布日期:未知" in messages[-2]["content"]
    assert "申请表和成绩单" in messages[-2]["content"]
    assert reply["answer"] == "材料：\n1. 申请表\n2. 成绩单"
    assert reply["sourceIds"] == ["test-source"]
    assert PROMPT_VERSION.startswith("xiaodian-")


def test_same_title_different_evidence_is_retained():
    rows = retrieve({"knowledgeChunks": [
        {"id": "one", "title": "申请通知", "content": "申请材料需要成绩单"},
        {"id": "two", "title": "申请通知", "content": "申请材料需要个人陈述"},
    ]}, "申请材料", include_posts=False)
    assert {row["id"] for row in rows} == {"one", "two"}


def test_unsupported_response_format_is_classified_narrowly():
    """A 400 only means "no json_schema here" when the provider says so.

    Downgrading on any 400 would silently drop the output contract to cover a
    malformed schema of our own.
    """
    from services._ai_schema import rejects_response_format

    deepseek = '{"error":{"message":"This response_format type is unavailable now"}}'
    assert rejects_response_format(400, deepseek) is True
    assert rejects_response_format(500, deepseek) is False
    assert rejects_response_format(400, '{"error":{"message":"Invalid schema"}}') is False
    assert rejects_response_format(400, '{"error":{"message":"insufficient balance"}}') is False


def test_generation_falls_back_to_json_mode_and_remembers(monkeypatch):
    """The json_schema probe happens once per process, not once per request."""
    import services._ai_schema as schema

    monkeypatch.setattr(schema, "_schema_supported", True)
    formats = []

    def provider(request, timeout):
        payload = json.loads(request.data)
        formats.append(payload["response_format"]["type"])
        if payload["response_format"]["type"] == "json_schema":
            raise schema.ProviderRejectedResponseFormat("unavailable")
        return {"choices": [{"message": {"content": json.dumps(
            {"answer": "长安校区在西安市长安区", "sourceIds": []})}}]}

    monkeypatch.setattr(_ai_handler, "_read_provider_json", provider)
    call = lambda: _ai_handler._call_chat_completion(
        base_url="https://example.test/v1", api_key="test", model="test-model",
        question="长安校区在哪", messages=[], context_items=[],
    )

    assert call()["answer"] == "长安校区在西安市长安区"
    assert formats == ["json_schema", "json_object"]
    formats.clear()
    assert call()["answer"] == "长安校区在西安市长安区"
    assert formats == ["json_object"]


def test_invented_evidence_id_is_still_rejected_in_json_mode(monkeypatch):
    """JSON mode drops the enum constraint, so the code must keep enforcing it."""
    import services._ai_schema as schema

    monkeypatch.setattr(schema, "_schema_supported", False)

    def provider(request, timeout):
        return {"choices": [{"message": {"content": json.dumps(
            {"answer": "见来源", "sourceIds": ["S9"]})}}]}

    monkeypatch.setattr(_ai_handler, "_read_provider_json", provider)
    try:
        _ai_handler._call_chat_completion(
            base_url="https://example.test/v1", api_key="test", model="test-model",
            question="奖学金怎么申请", messages=[],
            context_items=[{"id": "chunk-1", "title": "通知", "content": "正文"}],
        )
    except RuntimeError as error:
        assert "格式错误" in str(error)
    else:
        raise AssertionError("unknown evidence ID must not be accepted")
