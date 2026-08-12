"""Private campus RAG indexing and retrieval.

The service deliberately keeps the index in the existing application state so
the JSON/SQLite repository remains the source of truth.  Retrieval uses a
small BM25-style inverted index with Chinese character n-grams.  This keeps
the first deployment self-contained while leaving the document metadata ready
for a remote embedding/reranking service later.
"""
from __future__ import annotations

import hashlib
import math
import re
from datetime import datetime, timezone
from typing import Any

from services._user_service import is_post_private


INDEX_KEY = "ragIndex"
INDEX_VERSION = 2
MAX_QUERY_TERMS = 80

_WORD_RE = re.compile(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]")
_CJK_RUN_RE = re.compile(r"[\u4e00-\u9fff]{2,}")
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


def _clean(value: Any, limit: int = 6000) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()[:limit]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _tokenize(text: str) -> list[str]:
    text = str(text or "").lower()
    tokens: list[str] = []
    for match in _WORD_RE.finditer(text):
        token = match.group(0)
        if token not in tokens:
            tokens.append(token)
    for run in _CJK_RUN_RE.findall(text):
        for size in (2, 3, 4):
            if len(run) < size:
                continue
            for start in range(0, len(run) - size + 1):
                token = run[start : start + size]
                if token not in tokens:
                    tokens.append(token)
    return tokens[:MAX_QUERY_TERMS]


def _query_tokens(query: str) -> list[str]:
    base = _tokenize(query)
    expanded = list(base)
    for token in base:
        for replacement in _ALIAS_EXPANSIONS.get(token, []):
            if replacement not in expanded:
                expanded.extend(_tokenize(replacement))
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


def _signature(rows: list[dict[str, Any]]) -> str:
    payload = "\n".join(
        f"{row['key']}|{row.get('updatedAt', '')}|{row.get('content', '')}"
        for row in rows
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def rebuild_rag_index(db: dict[str, Any], *, include_posts: bool = True) -> dict[str, Any]:
    rows = _corpus(db, include_posts=include_posts)
    inverted: dict[str, dict[str, int]] = {}
    documents: dict[str, dict[str, Any]] = {}
    total_length = 0
    for row in rows:
        tokens = _tokenize(row.get("searchText", ""))
        counts: dict[str, int] = {}
        for token in tokens:
            counts[token] = counts.get(token, 0) + 1
        for token, count in counts.items():
            inverted.setdefault(token, {})[row["key"]] = count
        total_length += len(tokens)
        documents[row["key"]] = {
            **row,
            "length": len(tokens),
        }
    index = {
        "version": INDEX_VERSION,
        "signature": _signature(rows),
        "updatedAt": _now(),
        "includePosts": include_posts,
        "documents": documents,
        "inverted": inverted,
        "documentCount": len(documents),
        "knowledgeCount": sum(1 for row in rows if row["type"] == "knowledge"),
        "postCount": sum(1 for row in rows if row["type"] == "post"),
        "averageLength": (total_length / len(rows)) if rows else 1.0,
    }
    db[INDEX_KEY] = index
    return index


def ensure_rag_index(db: dict[str, Any], *, include_posts: bool = True) -> dict[str, Any]:
    rows = _corpus(db, include_posts=include_posts)
    current = db.get(INDEX_KEY)
    signature = _signature(rows)
    if not isinstance(current, dict) or current.get("version") != INDEX_VERSION or current.get("signature") != signature or current.get("includePosts") != include_posts:
        return rebuild_rag_index(db, include_posts=include_posts)
    return current


def _authority_boost(row: dict[str, Any]) -> float:
    if row.get("type") == "knowledge":
        return {"official": 1.35, "verified": 1.2, "curated": 1.12}.get(str(row.get("authority", "")), 1.0)
    return 1.0


def retrieve(db: dict[str, Any], query: str, *, include_posts: bool = True, limit: int = 8) -> list[dict[str, Any]]:
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
    seen_titles: set[str] = set()
    for score, row in ranked:
        title = str(row.get("title", ""))
        if title in seen_titles and row.get("type") == "knowledge":
            continue
        seen_titles.add(title)
        results.append({
            **row,
            "score": round(score, 6),
            "summary": _clean(row.get("content"), 260),
        })
        if len(results) >= limit:
            break
    return results


def citations(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "sourceType": "帖子" if row.get("type") == "post" else "校园知识",
            "targetType": row.get("type", ""),
            "targetId": row.get("id", ""),
            "title": row.get("title", ""),
            "summary": row.get("summary", ""),
            "publishedAt": row.get("createdAt", ""),
            "updatedAt": row.get("updatedAt", ""),
            "publisher": row.get("channel") or row.get("sourceName", ""),
            "sourceUrl": row.get("sourceUrl", ""),
            "jumpUrl": row.get("jumpUrl", ""),
            "authority": row.get("authority", ""),
            "score": row.get("score", 0),
        }
        for row in results
    ]


def forum_citations(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Build navigable references only for public forum posts.

    Knowledge-base chunks are context for the answer, not user-facing
    citations.  Forum posts retain their in-app jump URL so users can inspect
    the original discussion.
    """
    return citations([row for row in results if row.get("type") == "post"])
