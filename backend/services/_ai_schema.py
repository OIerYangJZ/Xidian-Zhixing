"""Provider-enforced output contracts shared by query planning and generation."""


def structured_output(name, properties):
    return {"type": "json_schema", "json_schema": {
        "name": name, "strict": True, "schema": {
            "type": "object", "properties": properties,
            "required": list(properties), "additionalProperties": False,
        },
    }}


QUERY_FORMAT = structured_output("xiaodian_query", {
    "intent": {"type": "string", "enum": ["core", "campus_qa", "text", "general", "personal_data"]},
    "standaloneQuery": {"type": "string", "description": "供精排使用的独立完整问题。必须补回历史用户消息中的具体事项、学校和适用条件，脱离历史也能理解；不能只改写 queries 而遗漏此字段的主题。"},
    "queries": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 3},
    "campus": {"type": ["string", "null"], "enum": ["changan", "yanta", None]},
    "educationLevel": {"type": ["string", "null"], "enum": ["undergraduate", "graduate", None]},
    "requestedFields": {"type": "array", "items": {"type": "string"}},
    "includeCommunity": {"type": "boolean"},
    "needsClarification": {"type": "boolean"},
})


def answer_format(source_ids):
    sources = {"type": "array", "items": {"type": "string"},
        "description": "回答采用了本轮资料中的任何具体事实时，必须列出支持它的证据ID。混合身份介绍不免除其他事实的引用；只有完全未用资料时才为空。"}
    if source_ids:
        sources["items"]["enum"] = list(dict.fromkeys(source_ids))
    else:
        sources["maxItems"] = 0
    return structured_output("xiaodian_answer", {
        "answer": {"type": "string"}, "sourceIds": sources,
    })
