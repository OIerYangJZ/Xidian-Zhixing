"""Focused contract checks for the actual provider payload and RAG evidence."""
import json

from handlers import _ai_handler
from rag_service import retrieve_lexical as retrieve
from services._ai_prompt import PROMPT_VERSION


def test_provider_receives_identity_core_knowledge_history_and_evidence(monkeypatch):
    captured = []

    def provider(request, timeout):
        captured.append(json.loads(request.data))
        return {"choices": [{"message": {"content": json.dumps({"answer":"材料：\n1. 申请表\n2. 成绩单", "sourceIds":["test-source"]})}}]}

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
