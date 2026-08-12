#!/usr/bin/env python3
"""Crawl public Xidian University pages into the private RAG knowledge base."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qsl, quote, urlencode, urljoin, urlsplit, urlunsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))

SEEDS = [
    "https://www.xidian.edu.cn/",
    "https://news.xidian.edu.cn/",
    "https://lib.xidian.edu.cn/",
    "https://xxzx.xidian.edu.cn/",
    "https://gr.xidian.edu.cn/",
    "https://jwc.xidian.edu.cn/",
    "https://xsc.xidian.edu.cn/",
    "https://job.xidian.edu.cn/",
    "https://zsb.xidian.edu.cn/",
    "https://international.xidian.edu.cn/",
    "https://hqjt.xidian.edu.cn/",
    "https://tyb.xidian.edu.cn/",
    "https://cwc.xidian.edu.cn/",
    "https://service.xidian.edu.cn/",
    # Focused official entry points that were not explicit in the previous run.
    "https://faculty.xidian.edu.cn/",
    "https://yjspt.xidian.edu.cn/",
    "https://yjsxk.xidian.edu.cn/",
    "https://xdyx.xidian.edu.cn/",
    "https://xgc.xidian.edu.cn/",
    "https://xsw.xidian.edu.cn/",
    # Public, non-official discussion/index pages.  They are imported as
    # community references and are filtered by relevance below.
    "https://yz.kaoyan.com/xidian/daoshi/",
    "https://muchong.com/bbs/viewthread.php?tid=15967764&pid=9",
    "https://www.houbaoyan.cn/articles/xidian-dept35-tuimian-2026",
]

EXTERNAL_HOSTS = {
    "yz.kaoyan.com",
    "muchong.com",
    "www.houbaoyan.cn",
}
COMMUNITY_KEYWORDS = (
    "西电", "西安电子科技大学", "考研", "保研", "推免", "导师", "复试", "招生",
    "宿舍", "食堂", "生活费", "选课", "转专业", "奖学金", "助学金", "答疑",
)
ADVERTISEMENT_MARKERS = (
    "加微信", "扫码", "领取资料", "免费资料", "课程咨询", "报班", "招生代理",
    "一对一辅导", "广告", "推广", "返现", "优惠券",
)

SKIP_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".ico",
    ".zip", ".rar", ".7z", ".gz", ".tar", ".mp3", ".mp4", ".avi",
    ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
}
TRACKING_QUERY_KEYS = {"from", "spm", "utm_source", "utm_medium", "utm_campaign", "timestamp"}


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[str] = []
        self.text_parts: list[str] = []
        self.title_parts: list[str] = []
        self._ignored_depth = 0
        self._in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        lowered = tag.lower()
        if lowered in {"script", "style", "noscript", "svg", "canvas"}:
            self._ignored_depth += 1
        if lowered == "title":
            self._in_title = True
        if lowered == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)

    def handle_endtag(self, tag: str) -> None:
        lowered = tag.lower()
        if lowered in {"script", "style", "noscript", "svg", "canvas"} and self._ignored_depth:
            self._ignored_depth -= 1
        if lowered == "title":
            self._in_title = False
        if lowered in {"p", "div", "li", "tr", "h1", "h2", "h3", "h4", "br", "section", "article"}:
            self.text_parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._ignored_depth:
            return
        clean = re.sub(r"\s+", " ", data).strip()
        if not clean:
            return
        self.text_parts.append(clean)
        if self._in_title:
            self.title_parts.append(clean)


@dataclass
class CrawlResult:
    url: str
    ok: bool
    title: str = ""
    text: str = ""
    links: tuple[str, ...] = ()
    error: str = ""
    content_type: str = ""


def canonical_url(url: str) -> str:
    parts = urlsplit(url)
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()
    try:
        parsed_port = parts.port
    except ValueError:
        parsed_port = None
    port = f":{parsed_port}" if parsed_port and parsed_port not in {80, 443} else ""
    path = quote(re.sub(r"/{2,}", "/", parts.path or "/"), safe="/%:@")
    query = urlencode([
        (key, value) for key, value in parse_qsl(parts.query, keep_blank_values=True)
        if key.lower() not in TRACKING_QUERY_KEYS
    ])
    return urlunsplit((scheme, f"{host}{port}", path, query, ""))


def allowed_url(url: str) -> bool:
    parts = urlsplit(url)
    host = (parts.hostname or "").lower()
    if parts.scheme not in {"http", "https"} or not (
        host == "xidian.edu.cn"
        or host.endswith(".xidian.edu.cn")
        or host in EXTERNAL_HOSTS
    ):
        return False
    suffix = Path(parts.path.lower()).suffix
    return suffix not in SKIP_EXTENSIONS


def decode_html(raw: bytes, content_type: str) -> str:
    charset_match = re.search(r"charset=([\w-]+)", content_type, re.I)
    charsets = [charset_match.group(1)] if charset_match else []
    charsets.extend(["utf-8", "gb18030"])
    for charset in dict.fromkeys(charsets):
        try:
            return raw.decode(charset)
        except (LookupError, UnicodeDecodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def normalize_page_text(text: str) -> str:
    lines: list[str] = []
    seen: set[str] = set()
    for line in text.replace("\r", "\n").split("\n"):
        clean = re.sub(r"\s+", " ", line).strip()
        if len(clean) < 2 or clean in seen:
            continue
        seen.add(clean)
        lines.append(clean)
    return "\n".join(lines)


def is_community_page_relevant(url: str, text: str) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    if host not in EXTERNAL_HOSTS:
        return True
    lowered = text.lower()
    if not any(keyword.lower() in lowered for keyword in COMMUNITY_KEYWORDS):
        return False
    marker_hits = sum(marker.lower() in lowered for marker in ADVERTISEMENT_MARKERS)
    return marker_hits < 3


def fetch_page(url: str, timeout: int) -> CrawlResult:
    request = Request(url, headers={
        "User-Agent": "XduRadioKnowledgeCrawler/1.0 (+https://www.xidian.edu.cn/)",
        "Accept": "text/html,application/xhtml+xml,application/pdf;q=0.8,*/*;q=0.1",
    })
    try:
        with urlopen(request, timeout=timeout) as response:
            final_url = canonical_url(response.geturl())
            content_type = str(response.headers.get("Content-Type", "")).lower()
            raw = response.read(15_000_000)
    except (HTTPError, URLError, TimeoutError, OSError, UnicodeError, ValueError) as error:
        return CrawlResult(url=url, ok=False, error=str(error)[:300])
    if "application/pdf" in content_type or raw.startswith(b"%PDF"):
        try:
            from pypdf import PdfReader

            reader = PdfReader(io.BytesIO(raw))
            text = normalize_page_text("\n".join((page.extract_text() or "") for page in reader.pages))
            metadata_title = str((reader.metadata or {}).get("/Title") or "").strip()
        except Exception as error:
            return CrawlResult(url=final_url, ok=False, error=f"pdf parse error: {error}"[:300], content_type=content_type)
        if len(text) < 80:
            return CrawlResult(url=final_url, ok=False, error="pdf text too short", content_type=content_type)
        return CrawlResult(
            url=final_url,
            ok=True,
            title=metadata_title or Path(urlsplit(final_url).path).name or final_url,
            text=text[:240_000],
            content_type="application/pdf",
        )
    if "text/html" not in content_type and "application/xhtml" not in content_type:
        return CrawlResult(url=final_url, ok=False, error=f"unsupported content type: {content_type}", content_type=content_type)
    parser = PageParser()
    try:
        parser.feed(decode_html(raw, content_type))
    except Exception as error:
        return CrawlResult(url=final_url, ok=False, error=f"html parse error: {error}", content_type=content_type)
    text = normalize_page_text(" ".join(parser.text_parts).replace(" \n ", "\n"))
    title = re.sub(r"\s+", " ", " ".join(parser.title_parts)).strip()
    if len(text) < 80:
        return CrawlResult(url=final_url, ok=False, error="page text too short", content_type=content_type)
    if not is_community_page_relevant(final_url, text):
        return CrawlResult(url=final_url, ok=False, error="community page not relevant", content_type=content_type)
    links = []
    for href in parser.links:
        absolute = canonical_url(urljoin(final_url, href))
        if allowed_url(absolute) and absolute not in links:
            links.append(absolute)
    return CrawlResult(url=final_url, ok=True, title=title, text=text[:120_000], links=tuple(links), content_type=content_type)


def chunk_text(text: str, target: int = 850, overlap: int = 100) -> list[str]:
    paragraphs = [re.sub(r"\s+", " ", row).strip() for row in text.split("\n") if row.strip()]
    chunks: list[str] = []
    current = ""
    for paragraph in paragraphs:
        if current and len(current) + len(paragraph) + 1 > target:
            chunks.append(current)
            tail = current[-overlap:] if overlap else ""
            current = f"{tail} {paragraph}".strip()
        else:
            current = f"{current} {paragraph}".strip()
    if current:
        chunks.append(current)
    return [chunk for chunk in chunks if len(chunk) >= 50]


def stable_id(prefix: str, value: str, extra: str = "") -> str:
    digest = hashlib.sha256(f"{value}|{extra}".encode("utf-8")).hexdigest()[:20]
    return f"{prefix}-{digest}"


def upsert_pages(db: dict, pages: Iterable[CrawlResult], run_id: str) -> dict[str, int]:
    source_rows = db.setdefault("knowledgeSources", [])
    document_rows = db.setdefault("knowledgeDocuments", [])
    chunk_rows = db.setdefault("knowledgeChunks", [])
    source_by_id = {str(row.get("id")): row for row in source_rows}
    document_by_url = {str(row.get("sourceUrl")): row for row in document_rows if row.get("sourceUrl")}
    existing_hashes = {
        str(row.get("contentHash", ""))
        for row in document_rows
        if str(row.get("contentHash", "")).strip()
    }
    existing_chunk_hashes = {
        hashlib.sha256(normalize_page_text(str(row.get("content", ""))).encode("utf-8")).hexdigest()
        for row in chunk_rows
        if str(row.get("content", "")).strip()
    }
    added_documents = updated_documents = skipped_documents = added_chunks = skipped_chunks = 0
    fetched_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for page in pages:
        host = (urlsplit(page.url).hostname or "xidian.edu.cn").lower()
        source_id = stable_id("ks-web", host)
        source = source_by_id.get(source_id)
        if source is None:
            source = {
                "id": source_id,
                "name": f"西安电子科技大学官方站点：{host}",
                "sourceType": "official_xidian_web",
                "sourceUrl": f"https://{host}/",
                "authority": "official",
                "status": "published",
                "createdAt": fetched_at,
                "updatedAt": fetched_at,
            }
            source_rows.append(source)
            source_by_id[source_id] = source
        else:
            source["updatedAt"] = fetched_at
        document = document_by_url.get(page.url)
        content_hash = hashlib.sha256(page.text.encode("utf-8")).hexdigest()
        document_id = stable_id("kd-web", page.url)
        if document is None:
            if content_hash in existing_hashes:
                skipped_documents += 1
                continue
            community = host in EXTERNAL_HOSTS
            document = {
                "id": document_id,
                "sourceId": source_id,
                "title": page.title or page.url,
                "content": page.text,
                "sourceUrl": page.url,
                "authority": "community" if community else "official",
                "sourceType": "community_web" if community else "official_xidian_web",
                "status": "published",
                "contentHash": content_hash,
                "crawlRunId": run_id,
                "createdAt": fetched_at,
                "updatedAt": fetched_at,
            }
            document_rows.append(document)
            document_by_url[page.url] = document
            existing_hashes.add(content_hash)
            added_documents += 1
        elif document.get("contentHash") != content_hash:
            old_document_chunks = [
                row for row in chunk_rows
                if str(row.get("documentId")) == str(document.get("id"))
            ]
            for old_chunk in old_document_chunks:
                old_hash = hashlib.sha256(
                    normalize_page_text(str(old_chunk.get("content", ""))).encode("utf-8")
                ).hexdigest()
                existing_chunk_hashes.discard(old_hash)
            document.update({
                "title": page.title or page.url,
                "content": page.text,
                "contentHash": content_hash,
                "crawlRunId": run_id,
                "updatedAt": fetched_at,
            })
            updated_documents += 1
        else:
            document["crawlRunId"] = run_id
            continue
        chunk_rows[:] = [row for row in chunk_rows if str(row.get("documentId")) != str(document.get("id"))]
        chunks = chunk_text(page.text)
        community = host in EXTERNAL_HOSTS
        for index, content in enumerate(chunks, start=1):
            chunk_hash = hashlib.sha256(normalize_page_text(content).encode("utf-8")).hexdigest()
            if chunk_hash in existing_chunk_hashes:
                skipped_chunks += 1
                continue
            chunk_rows.append({
                "id": stable_id("kc-web", page.url, str(index)),
                "sourceId": source_id,
                "documentId": document["id"],
                "title": f"{document['title']} · {index}",
                "content": content,
                "sourceUrl": page.url,
                "authority": "community" if community else "official",
                "status": "published",
                "crawlRunId": run_id,
                "createdAt": fetched_at,
                "updatedAt": fetched_at,
            })
            existing_chunk_hashes.add(chunk_hash)
            added_chunks += 1
    return {
        "addedDocuments": added_documents,
        "updatedDocuments": updated_documents,
        "skippedDocuments": skipped_documents,
        "addedChunks": added_chunks,
        "skippedChunks": skipped_chunks,
    }


def crawl(max_pages: int, workers: int, timeout: int) -> tuple[list[CrawlResult], list[CrawlResult], int]:
    frontier = [canonical_url(url) for url in SEEDS]
    queued = set(frontier)
    visited: set[str] = set()
    successes: list[CrawlResult] = []
    failures: list[CrawlResult] = []
    discovered = len(frontier)
    with ThreadPoolExecutor(max_workers=workers) as executor:
        while frontier and len(visited) < max_pages:
            batch = []
            while frontier and len(batch) < workers * 3 and len(visited) + len(batch) < max_pages:
                url = frontier.pop(0)
                if url in visited:
                    continue
                visited.add(url)
                batch.append(url)
            futures = {executor.submit(fetch_page, url, timeout): url for url in batch}
            for future in as_completed(futures):
                try:
                    result = future.result()
                except Exception as error:
                    result = CrawlResult(url=futures[future], ok=False, error=f"unexpected fetch error: {error}"[:300])
                if result.ok:
                    successes.append(result)
                    for link in result.links:
                        if link not in queued and len(queued) < max_pages * 8:
                            queued.add(link)
                            frontier.append(link)
                            discovered += 1
                else:
                    failures.append(result)
    return successes, failures, discovered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-pages", type=int, default=1200)
    parser.add_argument("--workers", type=int, default=10)
    parser.add_argument("--timeout", type=int, default=12)
    parser.add_argument("--db-file", default=str(BACKEND / "data" / "treehole.db"))
    parser.add_argument("--report", default=str(BACKEND / "data" / "xidian_crawl_report.json"))
    args = parser.parse_args()
    os.environ["BACKEND_DB_FILE"] = str(Path(args.db_file).resolve())

    import server
    from rag_service import rebuild_rag_index

    started_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    run_id = stable_id("crawl", started_at, str(args.max_pages))
    successes, failures, discovered = crawl(args.max_pages, args.workers, args.timeout)
    db = server.load_db()
    imported = upsert_pages(db, successes, run_id)
    index = rebuild_rag_index(db)
    completed_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    report = {
        "runId": run_id,
        "startedAt": started_at,
        "completedAt": completed_at,
        "maxPages": args.max_pages,
        "discoveredUrls": discovered,
        "requestedPages": len(successes) + len(failures),
        "successfulPages": len(successes),
        "failedPages": len(failures),
        **imported,
        "knowledgeSources": len(db.get("knowledgeSources", [])),
        "knowledgeDocuments": len(db.get("knowledgeDocuments", [])),
        "knowledgeChunks": len(db.get("knowledgeChunks", [])),
        "indexDocumentCount": index.get("documentCount", 0),
        "indexKnowledgeCount": index.get("knowledgeCount", 0),
        "indexPostCount": index.get("postCount", 0),
        "successfulUrls": [row.url for row in successes],
        "failures": [{"url": row.url, "error": row.error} for row in failures],
    }
    db.setdefault("ragCrawlRuns", []).append({key: value for key, value in report.items() if key not in {"successfulUrls", "failures"}})
    server.save_db(db)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in {"successfulUrls", "failures"}}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
