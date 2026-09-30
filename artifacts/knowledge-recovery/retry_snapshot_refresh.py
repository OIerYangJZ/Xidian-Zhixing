"""Retry failed official snapshot refreshes into the offline candidate database."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from knowledge_service.ingest import fetch_document
from knowledge_service.store import KnowledgeStore, utcnow


def main():
    database = ARTIFACTS / "knowledge.db"
    source_report = ARTIFACTS / "snapshot-refresh-report.json"
    output_report = ARTIFACTS / "snapshot-refresh-retry-report.json"
    raw_dir = ARTIFACTS / "raw"
    targets = json.loads(source_report.read_text(encoding="utf-8"))["failed"]
    store = KnowledgeStore(str(database))
    by_id = {doc["id"]: doc for doc in store.documents()}
    eligible = []
    skipped = []
    for target in targets:
        old = by_id.get(target["id"])
        if (old is None or old.get("status") != "published"
                or old.get("sourceUrl") != target["url"]):
            skipped.append({"id": target["id"], "url": target["url"],
                            "error": "候选库记录不存在、未发布或来源网址不匹配"})
        else:
            eligible.append((target, old))

    report = {"requested": len(eligible), "skipped": skipped,
              "published": [], "failed": []}
    with ThreadPoolExecutor(max_workers=4) as pool:
        pending = {pool.submit(fetch_document, target["url"], raw_dir): (target, old)
                   for target, old in eligible}
        for future in as_completed(pending):
            target, old = pending[future]
            try:
                doc, chunks = future.result()
                doc["id"] = old["id"]
                doc["sourceId"] = old["sourceId"]
                doc["authority"] = old["authority"]
                doc["status"] = old["status"]
                doc["publishedAt"] = doc.get("publishedAt") or old.get("publishedAt")
                doc["createdAt"] = old.get("createdAt", doc["createdAt"])
                doc["fetchedAt"] = utcnow()
                for field in ("effectiveFrom", "effectiveTo", "supersedesId",
                              "campuses", "educationLevels", "sourceSnapshotAt",
                              "sourceSnapshotRecordId", "sourceSnapshotCreatedAt",
                              "sourceSnapshotUpdatedAt"):
                    if field in old:
                        doc[field] = old[field]
                for ordinal, chunk in enumerate(chunks):
                    chunk_id = f'{old["id"]}:{doc["contentHash"][:12]}:{ordinal}'
                    chunk.update({"id": chunk_id, "key": "knowledge:" + chunk_id,
                                  "documentId": old["id"], "sourceId": old["sourceId"],
                                  "authority": old["authority"], "status": old["status"]})
                    for field in ("effectiveFrom", "effectiveTo", "supersedesId",
                                  "campuses", "educationLevels"):
                        if field in old:
                            chunk[field] = old[field]
                doc["chunkCount"] = len(chunks)
                store.put_document(doc, chunks)
                report["published"].append({"id": doc["id"], "url": target["url"],
                                            "title": doc["title"], "chunks": len(chunks)})
            except Exception as error:
                report["failed"].append({"id": target["id"], "url": target["url"],
                                         "title": target.get("title"), "error": str(error)})
    output_report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"requested": report["requested"],
                      "published": len(report["published"]),
                      "failed": len(report["failed"]),
                      "skipped": len(report["skipped"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
