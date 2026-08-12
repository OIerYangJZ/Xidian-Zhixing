#!/usr/bin/env python3
"""Remove exact duplicate Xidian RAG documents and chunks.

The operation is deliberately conservative: only normalized-identical
content is deduplicated.  Titles, URLs, or host names alone never trigger a
delete.  Built-in seed records are retained as canonical records when a web
copy contains the same text.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))


def normalized_text(value: Any) -> str:
    text = unicodedata.normalize("NFKC", str(value or ""))
    return re.sub(r"\s+", " ", text).strip()


def authority_rank(row: dict[str, Any]) -> int:
    return {
        "official": 4,
        "verified": 3,
        "curated": 2,
        "community": 1,
    }.get(str(row.get("authority", "")).strip().lower(), 0)


def choose_survivor(rows: list[dict[str, Any]], *, seed_ids: set[str]) -> dict[str, Any]:
    return sorted(
        rows,
        key=lambda row: (
            str(row.get("id", "")) in seed_ids,
            authority_rank(row),
            bool(str(row.get("sourceUrl", "")).strip()),
            len(normalized_text(row.get("content", ""))),
            str(row.get("createdAt", "")),
            str(row.get("id", "")),
        ),
        reverse=True,
    )[0]


def dedupe(db: dict[str, Any]) -> dict[str, int]:
    from services._db_service import _default_xidian_knowledge
    from rag_service import rebuild_rag_index

    _, seed_documents, seed_chunks = _default_xidian_knowledge("seed")
    seed_document_ids = {str(row.get("id", "")) for row in seed_documents}
    seed_chunk_ids = {str(row.get("id", "")) for row in seed_chunks}

    documents = [row for row in db.get("knowledgeDocuments", []) if isinstance(row, dict)]
    chunks = [row for row in db.get("knowledgeChunks", []) if isinstance(row, dict)]
    chunks_by_document: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in chunks:
        chunks_by_document[str(row.get("documentId", ""))].append(row)

    document_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in documents:
        key = hashlib.sha256(normalized_text(row.get("content")).encode("utf-8")).hexdigest()
        document_groups[key].append(row)
    document_survivor: dict[str, str] = {}
    kept_documents: list[dict[str, Any]] = []
    removed_documents = 0
    for rows in document_groups.values():
        survivor = choose_survivor(rows, seed_ids=seed_document_ids)
        survivor_id = str(survivor.get("id", ""))
        kept_documents.append(survivor)
        for row in rows:
            document_survivor[str(row.get("id", ""))] = survivor_id
        removed_documents += len(rows) - 1
    db["knowledgeDocuments"] = kept_documents

    for row in chunks:
        old_document_id = str(row.get("documentId", ""))
        if old_document_id in document_survivor:
            row["documentId"] = document_survivor[old_document_id]

    chunk_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in chunks:
        key = hashlib.sha256(normalized_text(row.get("content")).encode("utf-8")).hexdigest()
        chunk_groups[key].append(row)
    kept_chunks: list[dict[str, Any]] = []
    removed_chunks = 0
    for rows in chunk_groups.values():
        kept_chunks.append(choose_survivor(rows, seed_ids=seed_chunk_ids))
        removed_chunks += len(rows) - 1
    valid_document_ids = {str(row.get("id", "")) for row in kept_documents}
    orphan_chunks = [row for row in kept_chunks if str(row.get("documentId", "")) not in valid_document_ids]
    kept_chunks = [row for row in kept_chunks if str(row.get("documentId", "")) in valid_document_ids]
    db["knowledgeChunks"] = kept_chunks
    db["ragIndex"] = rebuild_rag_index(db, include_posts=True)
    return {
        "documentsBefore": len(documents),
        "documentsAfter": len(kept_documents),
        "removedDocuments": removed_documents,
        "chunksBefore": len(chunks),
        "chunksAfter": len(kept_chunks),
        "removedChunks": removed_chunks,
        "orphanChunks": len(orphan_chunks),
        "indexDocumentCount": int(db["ragIndex"].get("documentCount", 0)),
        "indexKnowledgeCount": int(db["ragIndex"].get("knowledgeCount", 0)),
        "indexPostCount": int(db["ragIndex"].get("postCount", 0)),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db-file", default=str(BACKEND / "data" / "treehole.db"))
    args = parser.parse_args()
    import os

    os.environ["BACKEND_DB_FILE"] = str(Path(args.db_file).resolve())
    os.environ.setdefault("BACKEND_ADMIN_USERNAME", "admin")
    os.environ.setdefault("BACKEND_ADMIN_PASSWORD", "local-dedupe-placeholder")
    os.environ.setdefault("BACKEND_ENV", "development")
    import server

    db = server.load_db()
    report = dedupe(db)
    server.save_db(db)
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
