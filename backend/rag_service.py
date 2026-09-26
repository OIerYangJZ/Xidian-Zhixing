"""Private campus RAG indexing and retrieval.

Retrieval uses a small BM25-style inverted index with Chinese character
n-grams.  The index is derived data, so it lives in a process-level cache
rather than in the application state dict:

  * keeping it in the state meant every request paid to JSON-decode it out of
    the settings blob (4.3 MB at 1500 posts, ~60 ms per request), and
  * the read paths never saved the state they rebuilt it into, so the index was
    reconstructed from scratch on *every* AI request and then thrown away
    (11 s at 1500 posts, holding the GIL the whole time).

The cache is maintained incrementally: a new post re-tokenises that one
document instead of the entire corpus.
"""
from __future__ import annotations

import hashlib
import math
import re
import threading
from datetime import datetime, timezone
from typing import Any

from services._user_service import is_post_private


INDEX_KEY = "ragIndex"
INDEX_VERSION = 3

# Queries stay short on purpose — beyond a point extra terms only add noise.
MAX_QUERY_TERMS = 80
# Documents keep their whole vocabulary.  Truncating them to MAX_QUERY_TERMS
# (as every earlier version did) meant a Chinese post was indexed by roughly
# its first 80 single characters: no 2/3/4-grams survived, "图书馆" never made
# it into the index, and every document reported the same length so BM25's
# length normalisation did nothing.  The ceiling here only guards against a
# pathological single document.
MAX_DOCUMENT_TERMS = 20_000

_WORD_RE = re.compile("[A-Za-z0-9_]+|[\\u4e00-\\u9fff]")
_CJK_RUN_RE = re.compile("[\\u4e00-\\u9fff]{2,}")
_ALIAS_EXPANSIONS = {
    "教学楼": ["教学楼", "教室", "楼"],
    "教室": ["教室", "教学楼", "上课"],
    "图书馆": ["图书馆", "借阅", "馆藏", "座位"],
    "吃饭": ["食堂", "餐厅", "就餐"],
    "打印": ["打印", "自助打印", "复印"],
    "网": ["校园网", "网络", "上网"],
    "宿舍": ["宿舍", "公寓", "寝室"],
    "电费": ["电费", "缴费", "宿舍"],
    "成绩": ["成绩", "教务", "考试"],
}

# Guards the cache and every read of the structures inside it: retrieve_lexical()
# scores against the same dicts that an incremental update mutates.  Reentrant
# so ensure_rag_index() can be called from inside a held section.
_INDEX_LOCK = threading.RLock()
_INDEX_CACHE: dict[bool, dict[str, Any]] = {}


def _clean(value: Any, limit: int = 6000) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()[:limit]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _tokenize(text: str, *, limit: int) -> list[str]:
    """Distinct terms of `text`, in a stable order, capped at `limit`.

    Dedup goes through a set: the old list membership test made this O(n²) and
    a single 2400-character post cost ~88 ms to tokenise.
    """
    lowered = str(text or "").lower()
    seen: set[str] = set()
    tokens: list[str] = []

    for match in _WORD_RE.finditer(lowered):
        token = match.group(0)
        if token not in seen:
            seen.add(token)
            tokens.append(token)
            if len(tokens) >= limit:
                return tokens

    for run in _CJK_RUN_RE.findall(lowered):
        for size in (2, 3, 4):
            if len(run) < size:
                continue
            for start in range(0, len(run) - size + 1):
                token = run[start : start + size]
                if token not in seen:
                    seen.add(token)
                    tokens.append(token)
                    if len(tokens) >= limit:
                        return tokens
    return tokens


def _query_tokens(query: str) -> list[str]:
    base = _tokenize(query, limit=MAX_QUERY_TERMS)
    expanded = list(base)
    seen = set(base)
    for token in base:
        for replacement in _ALIAS_EXPANSIONS.get(token, []):
            for extra in _tokenize(replacement, limit=MAX_QUERY_TERMS):
                if extra not in seen:
                    seen.add(extra)
                    expanded.append(extra)
    return expanded[:MAX_QUERY_TERMS]


def _post_allowed(post: dict[str, Any]) -> bool:
    return (
        not bool(post.get("deleted"))
        and str(post.get("reviewStatus", "approved")).lower() in {"approved", "resolved"}
        and not is_post_private(post)
    )


def _source_map(db: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row.get("id")): row
        for row in db.get("knowledgeSources", [])
        if isinstance(row, dict) and str(row.get("id", "")).strip()
    }


def _corpus(db: dict[str, Any], include_posts: bool = True) -> list[dict[str, Any]]:
    sources = _source_map(db)
    rows: list[dict[str, Any]] = []
    for chunk in db.get("knowledgeChunks", []):
        if not isinstance(chunk, dict) or not str(chunk.get("content", "")).strip():
            continue
        source = sources.get(str(chunk.get("sourceId", "")), {})
        if str(chunk.get("status", source.get("status", "published"))).lower() in {"archived", "disabled"}:
            continue
        content = _clean(chunk.get("content"), 6000)
        rows.append({
            "key": f"knowledge:{chunk.get('id', '')}",
            "type": "knowledge",
            "id": str(chunk.get("id", "")),
            "title": _clean(chunk.get("title") or source.get("name") or "校园资料", 160),
            "content": content,
            "sourceUrl": str(chunk.get("sourceUrl") or source.get("sourceUrl") or ""),
            "sourceName": _clean(source.get("name") or "校园知识库", 160),
            "authority": str(chunk.get("authority") or source.get("authority") or "verified"),
            "createdAt": str(chunk.get("createdAt") or source.get("createdAt") or ""),
            "publishedAt": str(chunk.get("publishedAt") or ""),
            "updatedAt": str(chunk.get("updatedAt") or chunk.get("createdAt") or ""),
            "jumpUrl": str(chunk.get("jumpUrl") or ""),
        })
    if include_posts:
        for post in db.get("posts", []):
            if not isinstance(post, dict) or not _post_allowed(post):
                continue
            content = _clean(post.get("content"), 2400)
            title = _clean(post.get("title") or "无标题帖子", 160)
            tags = " ".join(str(item) for item in post.get("tags", []) if item)
            rows.append({
                "key": f"post:{post.get('id', '')}",
                "type": "post",
                "id": str(post.get("id", "")),
                "title": title,
                "content": content,
                "searchText": f"{title} {content} {tags} {post.get('channel', '')}",
                "sourceUrl": str(post.get("sourceUrl") or ""),
                "sourceName": _clean(post.get("channel") or "论坛公开帖子", 160),
                "authority": "community",
                "createdAt": str(post.get("createdAt", "")),
                "updatedAt": str(post.get("updatedAt") or post.get("createdAt") or ""),
                "channel": str(post.get("channel", "")),
                "jumpUrl": f"/pages/campus/post-detail/index?id={post.get('id', '')}",
            })
    for row in rows:
        row["searchText"] = row.get("searchText") or f"{row.get('title', '')} {row.get('content', '')}"
    return rows


_FINGERPRINT_FIELDS = (
    "type", "id", "title", "content", "searchText", "sourceUrl",
    "sourceName", "authority", "createdAt", "publishedAt", "updatedAt", "jumpUrl", "channel",
)


def _row_fingerprint(row: dict[str, Any]) -> str:
    payload = "\x1f".join(str(row.get(field, "")) for field in _FINGERPRINT_FIELDS)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _signature(rows: list[dict[str, Any]]) -> str:
    payload = "\n".join(
        f"{row['key']}|{row.get('updatedAt', '')}|{row.get('content', '')}"
        for row in rows
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _add_document(index: dict[str, Any], row: dict[str, Any]) -> None:
    tokens = _tokenize(row.get("searchText", ""), limit=MAX_DOCUMENT_TERMS)
    counts: dict[str, int] = {}
    for token in tokens:
        counts[token] = counts.get(token, 0) + 1
    inverted = index["inverted"]
    key = row["key"]
    for token, count in counts.items():
        inverted.setdefault(token, {})[key] = count
    index["documents"][key] = {
        **row,
        "length": len(tokens),
        "fingerprint": _row_fingerprint(row),
    }


def _remove_document(index: dict[str, Any], key: str) -> None:
    document = index["documents"].pop(key, None)
    if document is None:
        return
    inverted = index["inverted"]
    for token in _tokenize(document.get("searchText", ""), limit=MAX_DOCUMENT_TERMS):
        posting = inverted.get(token)
        if posting is None:
            continue
        posting.pop(key, None)
        if not posting:
            inverted.pop(token, None)


def _refresh_stats(index: dict[str, Any], *, include_posts: bool) -> None:
    documents = index["documents"]
    total_length = sum(int(row.get("length", 0) or 0) for row in documents.values())
    index["includePosts"] = include_posts
    index["documentCount"] = len(documents)
    index["knowledgeCount"] = sum(
        1 for row in documents.values() if row.get("type") == "knowledge"
    )
    index["postCount"] = sum(
        1 for row in documents.values() if row.get("type") == "post"
    )
    index["averageLength"] = (total_length / len(documents)) if documents else 1.0
    index["updatedAt"] = _now()


def _empty_index(include_posts: bool) -> dict[str, Any]:
    return {
        "version": INDEX_VERSION,
        "signature": "",
        "updatedAt": _now(),
        "includePosts": include_posts,
        "documents": {},
        "inverted": {},
        "documentCount": 0,
        "knowledgeCount": 0,
        "postCount": 0,
        "averageLength": 1.0,
    }


def _sync_locked(
    index: dict[str, Any],
    rows: list[dict[str, Any]],
    *,
    include_posts: bool,
) -> dict[str, Any]:
    """Bring `index` in line with `rows`, touching only what moved."""
    documents = index["documents"]
    incoming = {row["key"]: row for row in rows}

    stale = [key for key in documents if key not in incoming]
    changed = [
        key
        for key, row in incoming.items()
        if key in documents and documents[key].get("fingerprint") != _row_fingerprint(row)
    ]
    fresh = [key for key in incoming if key not in documents]

    if not stale and not changed and not fresh:
        return index

    for key in stale:
        _remove_document(index, key)
    for key in changed:
        _remove_document(index, key)
        _add_document(index, incoming[key])
    for key in fresh:
        _add_document(index, incoming[key])

    index["signature"] = _signature(rows)
    _refresh_stats(index, include_posts=include_posts)
    return index


def rebuild_rag_index(db: dict[str, Any], *, include_posts: bool = True) -> dict[str, Any]:
    """Discard the cached index and build it again from scratch."""
    rows = _corpus(db, include_posts=include_posts)
    with _INDEX_LOCK:
        index = _empty_index(include_posts)
        for row in rows:
            _add_document(index, row)
        index["signature"] = _signature(rows)
        _refresh_stats(index, include_posts=include_posts)
        _INDEX_CACHE[include_posts] = index
        return index


def ensure_rag_index(db: dict[str, Any], *, include_posts: bool = True) -> dict[str, Any]:
    rows = _corpus(db, include_posts=include_posts)
    with _INDEX_LOCK:
        cached = _INDEX_CACHE.get(include_posts)
        if not isinstance(cached, dict) or cached.get("version") != INDEX_VERSION:
            cached = _empty_index(include_posts)
            _INDEX_CACHE[include_posts] = cached
        return _sync_locked(cached, rows, include_posts=include_posts)


def index_summary() -> dict[str, Any]:
    """Stats for the admin knowledge-source page."""
    with _INDEX_LOCK:
        index = _INDEX_CACHE.get(True) or _INDEX_CACHE.get(False)
        if not isinstance(index, dict):
            return {
                "version": 0,
                "updatedAt": "",
                "documentCount": 0,
                "knowledgeCount": 0,
                "postCount": 0,
            }
        return {
            "version": index.get("version", 0),
            "updatedAt": index.get("updatedAt", ""),
            "documentCount": index.get("documentCount", 0),
            "knowledgeCount": index.get("knowledgeCount", 0),
            "postCount": index.get("postCount", 0),
        }


def reset_index_cache() -> None:
    """Drop the cache; used by tests that need a cold start."""
    with _INDEX_LOCK:
        _INDEX_CACHE.clear()


def _authority_boost(row: dict[str, Any]) -> float:
    if row.get("type") == "knowledge":
        return {"official": 1.35, "verified": 1.2, "curated": 1.12}.get(str(row.get("authority", "")), 1.0)
    return 1.0


def retrieve_lexical(db: dict[str, Any], query: str, *, include_posts: bool = True, limit: int = 8) -> list[dict[str, Any]]:
    # The whole scoring pass stays under the index lock: it reads the same
    # dictionaries an incremental update mutates.
    with _INDEX_LOCK:
        index = ensure_rag_index(db, include_posts=include_posts)
        tokens = _query_tokens(query)
        if not tokens:
            return []
        documents = index.get("documents", {})
        inverted = index.get("inverted", {})
        total_docs = max(1, int(index.get("documentCount", len(documents))))
        average_length = max(1.0, float(index.get("averageLength", 1.0)))
        scores: dict[str, float] = {}
        k1, b = 1.35, 0.72
        for token in tokens:
            posting = inverted.get(token, {})
            if not isinstance(posting, dict) or not posting:
                continue
            idf = math.log(1.0 + (total_docs - len(posting) + 0.5) / (len(posting) + 0.5))
            for key, raw_tf in posting.items():
                row = documents.get(key, {})
                length = max(1, int(row.get("length", 1)))
                tf = float(raw_tf)
                score = idf * ((tf * (k1 + 1)) / (tf + k1 * (1 - b + b * length / average_length)))
                scores[key] = scores.get(key, 0.0) + score
        ranked: list[tuple[float, dict[str, Any]]] = []
        for key, score in scores.items():
            row = documents.get(key)
            if not isinstance(row, dict):
                continue
            ranked.append((score * _authority_boost(row), row))
        ranked.sort(key=lambda item: (item[0], str(item[1].get("updatedAt", ""))), reverse=True)
        results: list[dict[str, Any]] = []
        seen_content: set[str] = set()
        for score, row in ranked:
            content = str(row.get("content", ""))
            if content in seen_content and row.get("type") == "knowledge":
                continue
            seen_content.add(content)
            payload = {key: value for key, value in row.items() if key != "fingerprint"}
            results.append({
                **payload,
                "score": round(score, 6),
                "summary": _clean(row.get("content"), 260),
            })
            if len(results) >= limit:
                break
        return results


def visible_context(db, items):
    posts={str(p["id"]):p for p in db.get("posts",[])}
    result=[]
    for item in items:
        if item.get("type")!="post":
            result.append(item)
            continue
        post=posts.get(item.get("postId"))
        if post and _post_allowed(post) and (
            hashlib.sha256(str(post.get("content","")).encode("utf8")).hexdigest()==item.get("postContentHash")
            and str(post.get("title",""))==item.get("postTitle")
        ):
            result.append(item)
    return result


def citations(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "sourceType": "帖子" if row.get("type") == "post" else "校园知识",
            "targetType": row.get("type", ""),
            "targetId": row.get("postId") or row.get("id", ""),
            "title": row.get("title", ""),
            "summary": row.get("summary", ""),
            "publishedAt": row.get("publishedAt") if row.get("type") == "knowledge" else row.get("createdAt", ""),
            "updatedAt": row.get("updatedAt", ""),
            "publisher": row.get("channel") or row.get("sourceName", ""),
            "sourceUrl": row.get("sourceUrl", ""),
            "jumpUrl": row.get("jumpUrl", ""),
            "authority": row.get("authority", ""),
            "score": row.get("score", 0),
        }
        for row in results
    ]
