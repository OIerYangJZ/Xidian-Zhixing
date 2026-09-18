"""Provider-enforced output contracts shared by query planning and generation."""

JSON_OBJECT_FORMAT = {"type": "json_object"}

# Flipped the first time a provider refuses json_schema, so later requests skip
# a round trip that is known to fail. A racing thread at worst probes once more;
# the value only ever moves from True to False.
_schema_supported = True


class ProviderRejectedResponseFormat(RuntimeError):
    """The provider does not implement json_schema response formatting.

    Distinct from other provider errors because it is the one failure worth
    retrying differently: the request was well formed and the account is fine.
    """


def rejects_response_format(status, detail):
    """Classify a provider error as "json_schema is not implemented here".

    Deliberately narrow. A malformed schema is also a 400, and treating that as
    "unsupported" would silently drop the output contract to hide our own bug,
    so only an explicit unavailable/unsupported verdict counts.
    """
    if int(status) != 400:
        return False
    low = str(detail).lower()
    if "response_format" not in low:
        return False
    return any(word in low for word in ("unavailable", "unsupported", "not supported", "not support"))


def structured_call(attempt, schema_format):
    """Run `attempt(response_format)`, degrading to JSON mode when required.

    `attempt` must send the request and fully parse and validate the result, so
    a provider that answers with valid JSON in the wrong shape is caught here
    rather than downstream. Both prompts already state their required fields in
    text, which is what makes JSON mode viable: only the provider-side shape
    guarantee is lost, and every field is validated in code regardless.
    """
    global _schema_supported
    if _schema_supported:
        try:
            return attempt(schema_format)
        except ProviderRejectedResponseFormat:
            _schema_supported = False
    try:
        return attempt(JSON_OBJECT_FORMAT)
    except (ValueError, KeyError, TypeError, IndexError):
        # JSON mode guarantees syntax, not shape. One retry absorbs a single
        # malformed generation instead of surfacing it as a failed request.
        return attempt(JSON_OBJECT_FORMAT)


def structured_output(name, properties):
    return {"type": "json_schema", "json_schema": {
        "name": name, "strict": True, "schema": {
            "type": "object", "properties": properties,
            "required": list(properties), "additionalProperties": False,
        },
    }}


# Decide the route after writing the complete request, so an opening identity
# question cannot prematurely suppress retrieval for later campus subquestions.
QUERY_FORMAT = structured_output("xiaodian_query", {
    "standaloneQuery": {"type": "string", "description": "供精排使用的独立完整问题。必须补回历史用户消息中的具体事项、学校和适用条件，脱离历史也能理解；不能只改写 queries 而遗漏此字段的主题。"},
    "queries": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 3},
    "campus": {"type": ["string", "null"], "enum": ["changan", "yanta", None]},
    "educationLevel": {"type": ["string", "null"], "enum": ["undergraduate", "graduate", None]},
    "requestedFields": {"type": "array", "items": {"type": "string"}},
    "includeCommunity": {"type": "boolean"},
    "needsClarification": {"type": "boolean"},
    "intent": {"type": "string", "enum": ["core", "campus_qa", "text", "general", "personal_data"]},
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
