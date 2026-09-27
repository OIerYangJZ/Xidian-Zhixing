"""Fetch official documents, extract body text, preserve provenance and chunk structure."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
import sqlite3
import uuid
import hashlib
from urllib.parse import urlsplit, unquote

from .store import KnowledgeStore, content_hash, utcnow


SERVICE_TITLE_TERMS = (
    "指南", "办事", "流程", "常见问题", "faq", "借阅", "续借", "开放时间",
    "上网申请", "远程访问", "网接入", "校园网", "无线网络", "无线网",
    "使用手册", "使用说明", "就诊时间", "门诊", "校医院", "就医", "医保", "预约",
    "报修", "维修", "一卡通", "校园卡", "学籍", "学位", "成绩", "选课", "考务", "考试须知",
    "课表", "班车", "资助", "奖学金", "宿舍", "住宿", "迎新", "离校",
    "缴费", "证明", "补办", "请假", "心理咨询", "通办", "图书服务",
    "图书馆", "馆藏", "自习室", "座位预约", "食堂", "餐饮", "饮食", "水电", "热水", "浴室",
    "统一身份认证", "学生邮件认证", "正版软件", "自助打印", "服务器申请",
    "高算资源", "教室运维", "会议中心", "固话业务", "出访指南",
)

SERVICE_PATH_PREFIXES = ("/f_w/", "/fwzn", "/bszn", "/bslc", "/ssfw/", "/bmfw/", "/cyfw/")


def official_url(url: str) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    return host == "xidian.edu.cn" or host.endswith(".xidian.edu.cn") or host == "moe.gov.cn" or host.endswith(".moe.gov.cn")


def knowledge_source_url(url: str, title: str = "") -> bool:
    """Keep official articles, attachments, and clearly named service pages."""
    url=str(url or "")
    title=str(title or "")
    if not official_url(url):
        return False
    path=urlsplit(url).path.lower()
    if "/info/" in path or path.endswith((".pdf", ".doc", ".docx", ".xls", ".xlsx")):
        return True
    lowered=title.casefold()
    if any(token in path for token in ("/login", "slogin", "showpublic")):
        return False
    if path in ("", "/") and not any(token in lowered for token in ("服务指南", "学生服务指南")):
        return False
    return (bool(title.strip()) and path.startswith(SERVICE_PATH_PREFIXES)) or any(
        term.casefold() in lowered for term in SERVICE_TITLE_TERMS)


def split_text(text: str, size=240, overlap=48) -> list[str]:
    """Keep paragraphs intact when possible; even a single long paragraph is bounded."""
    paragraphs = [p.strip() for p in re.split(r"\n+", text) if p.strip()]
    output, current = [], ""
    for para in paragraphs:
        while len(para) > size:
            if current:
                output.append(current)
                current = ""
            cut = max(para.rfind(mark, size//2, size) for mark in "。；！？\n")
            cut = cut+1 if cut >= 0 else size
            output.append(para[:cut])
            para = para[max(1,cut-overlap):]
        if current and len(current)+len(para)+1 > size:
            output.append(current)
            current = para
        else:
            current = (current+"\n"+para).strip()
    if current:
        output.append(current)
    return list(dict.fromkeys(output))


def make_document(title: str, text: str, url: str, *, published_at=None,
                  authority="official", source_id=None, doc_id=None, pages=None) -> tuple[dict,list[dict]]:
    document_id = doc_id or ("doc-"+content_hash(url)[:24] if url else "doc-"+uuid.uuid4().hex)
    revision = content_hash(text)
    fetched = utcnow()
    doc = {
        "id":document_id, "sourceId":source_id or "source-"+content_hash(urlsplit(url).netloc)[:16],
        "title":title, "content":text, "sourceUrl":url, "authority":authority,
        "publishedAt":published_at, "fetchedAt":fetched, "createdAt":fetched,
        "updatedAt":fetched, "contentHash":revision, "status":"published",
        "parserVersion":"xiaodian-body-3", "effectiveFrom":None, "effectiveTo":None,
        "supersedesId":None, "campuses":[], "educationLevels":[],
    }
    chunks=[]
    for name, aliases in {"changan":("长安校区","南校区"),"yanta":("雁塔校区","北校区")}.items():
        if any(alias in title for alias in aliases):
            doc["campuses"].append(name)
    for level, alias in {"undergraduate":"本科", "graduate":"研究生"}.items():
        if alias in title:
            doc["educationLevels"].append(level)
    source_pages = pages if pages is not None else [(None,text)]
    for page_number, body in source_pages:
        for content in split_text(body):
            ordinal=len(chunks)
            chunk_id=f"{document_id}:{revision[:12]}:{ordinal}"
            chunks.append({
                "id":chunk_id, "key":"knowledge:"+chunk_id, "type":"knowledge",
                "documentId":document_id, "sourceId":doc["sourceId"],
                "ordinal":ordinal, "title":title, "content":content,
                "sourceUrl":url, "sourceName":urlsplit(url).netloc,
                "authority":authority, "publishedAt":published_at, "createdAt":fetched,
                "updatedAt":fetched, "revision":revision, "pageNumber":page_number,
                "contentHash":content_hash(content), "status":"published",
                "campuses":doc["campuses"], "educationLevels":doc["educationLevels"],
                "searchText":f"{title}\n原文日期：{published_at or '未标明'}\n{content}",
            })
    return doc,chunks


def fetch_document(url: str, raw_dir: Path) -> tuple[dict,list[dict]]:
    from email.message import Message
    from io import BytesIO
    import requests

    if not official_url(url):
        raise ValueError("只摄取配置范围内的官方来源")
    response=requests.get(url,timeout=(10,30),headers={"User-Agent":"ZhixingKnowledge/2.0 (+https://zhixing.xidian.edu.cn)"})
    response.raise_for_status()
    if not official_url(response.url):
        raise ValueError("原文重定向到来源范围以外")
    raw_dir.mkdir(parents=True,exist_ok=True)
    raw_path=raw_dir/(hashlib.sha256(response.content).hexdigest()+".source")
    raw_path.write_bytes(response.content)
    content_type=response.headers.get("Content-Type","")
    disposition=Message()
    disposition['Content-Disposition']=response.headers.get('Content-Disposition','')
    filename=unquote(disposition.get_filename() or Path(urlsplit(response.url).path).name)
    suffix=Path(filename).suffix.lower()
    pages=None
    if "pdf" in content_type or suffix==".pdf":
        from pypdf import PdfReader
        from .attachments import ocr_pdf

        reader=PdfReader(BytesIO(response.content))
        pages=[(i+1,(page.extract_text(extraction_mode="layout") or "").strip()) for i,page in enumerate(reader.pages)]
        scanned=[number-1 for number,body in pages if len(body)<80]
        if scanned:
            recognized=ocr_pdf(response.content,scanned)
            pages=[(number,recognized.get(number-1,body)) for number,body in pages]
        text="\n\n".join(body for _,body in pages)
        if len(text.strip()) < 80:
            raise ValueError("PDF 正文与 OCR 均无可用文字，未发布空白资料")
        title=filename if suffix=='.pdf' else str((reader.metadata or {}).get("/Title") or 'PDF 文档')
        published_at=None
    elif suffix in {".docx",".xlsx",".doc",".xls"}:
        from .attachments import office_text

        text=office_text(response.content,suffix)
        title=filename
        published_at=None
    else:
        from .html_body import parse_html
        title,text,published_at,pages=parse_html(response.content,response.url)
    doc,chunks=make_document(title,text,response.url,published_at=published_at,pages=pages)
    doc["rawObjectKey"]=str(raw_path.resolve())
    doc["chunkCount"]=len(chunks)
    return doc,chunks


def existing_urls(app_db: str) -> list[str]:
    uri=Path(app_db).resolve().as_uri()+"?mode=ro"
    with sqlite3.connect(uri,uri=True) as con:
        row=con.execute("SELECT value_text FROM settings WHERE setting_key='radioState'").fetchone()
    if row is None:
        raise ValueError("应用数据库中没有 radioState")
    data=json.loads(row[0])
    urls=[]
    for doc in data.get("knowledgeDocuments",[]):
        url=doc.get("sourceUrl","")
        if not knowledge_source_url(url,doc.get("title", "")):
            continue
        urls.append(url)
    return list(dict.fromkeys(urls))


def import_app_snapshot(db_path: str, app_db: str, report_path: str, limit: int | None = None) -> dict:
    """Restore already-captured official bodies without depending on live websites.

    The app snapshot is read only. Existing URLs are left untouched so disabled,
    curated, or newer canonical records keep their current state. The resulting
    corpus must be reindexed before search resumes.
    """
    uri=Path(app_db).resolve().as_uri()+"?mode=ro"
    with sqlite3.connect(uri,uri=True) as con:
        row=con.execute("SELECT value_text,updated_at FROM settings WHERE setting_key='radioState'").fetchone()
    if row is None:
        raise ValueError("应用数据库中没有 radioState")
    state=json.loads(row[0])
    snapshot_at=row[1]
    store=KnowledgeStore(db_path)
    before_docs=store.documents()
    existing={doc.get("sourceUrl") for doc in before_docs if doc.get("sourceUrl")}
    before_chunks=store.chunks(published_only=False)
    candidates=[doc for doc in state.get("knowledgeDocuments",[])
        if knowledge_source_url(doc.get("sourceUrl", ""),doc.get("title", ""))]
    if limit is not None:
        candidates=candidates[:limit]
    report={"snapshotAt":snapshot_at,"requested":len(candidates),
        "documentsBefore":len(before_docs),"chunksBefore":len(before_chunks),"imported":[],
        "skippedExisting":0,"skippedInvalid":0}
    for old in candidates:
        url=old.get("sourceUrl", "")
        if url in existing:
            report["skippedExisting"]+=1
            continue
        title=str(old.get("title") or "").strip()
        body=str(old.get("content") or "").strip()
        if old.get("status", "published")!="published" or not title or len(body)<80:
            report["skippedInvalid"]+=1
            continue
        doc,chunks=make_document(title,body,url,authority="official",source_id=old.get("sourceId"))
        doc.update({"parserVersion":"radio-state-snapshot-1","sourceSnapshotAt":snapshot_at,
            "sourceSnapshotRecordId":old.get("id"),"chunkCount":len(chunks)})
        for chunk in chunks:
            chunk["parserVersion"]="radio-state-snapshot-1"
        store.put_document(doc,chunks)
        existing.add(url)
        report["imported"].append({"id":doc["id"],"url":url,"title":title,"chunks":len(chunks)})
    active_index=store.setting("activeIndex")
    if report["imported"]:
        store.set_setting("activeIndex",None)
    report["reindexRequired"]=bool(report["imported"]) or active_index is None
    after_docs=store.documents()
    after_chunks=store.chunks(published_only=False)
    report.update({"documentsAfter":len(after_docs),
        "publishedDocumentsAfter":sum(doc.get("status")=="published" for doc in after_docs),
        "chunksAfter":len(after_chunks),
        "chunksImported":len(after_chunks)-len(before_chunks)})
    Path(report_path).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    return report


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",required=True)
    parser.add_argument("--app-db")
    parser.add_argument("--urls")
    parser.add_argument("--raw-dir")
    parser.add_argument("--from-app-snapshot",action="store_true",
        help="从 KNOWLEDGE_APP_DB 已保存的正文补充官方页面，不访问学校网站")
    parser.add_argument("--workers",type=int,default=8)
    parser.add_argument("--limit",type=int)
    parser.add_argument("--report",required=True)
    args=parser.parse_args()
    if args.from_app_snapshot:
        if not args.app_db:
            parser.error("--from-app-snapshot 需要 --app-db")
        if args.urls:
            parser.error("--from-app-snapshot 不能与 --urls 同时使用")
        report=import_app_snapshot(args.db,args.app_db,args.report,args.limit)
        print(json.dumps({"imported":len(report["imported"]),"skippedExisting":report["skippedExisting"],
            "skippedInvalid":report["skippedInvalid"],"reindexRequired":report["reindexRequired"]},ensure_ascii=False))
        return
    if not args.raw_dir:
        parser.error("在线采集需要 --raw-dir")
    urls=existing_urls(args.app_db) if args.app_db else []
    if args.urls:
        urls += json.loads(Path(args.urls).read_text(encoding="utf-8"))
    urls=list(dict.fromkeys(urls))
    if args.limit:
        urls=urls[:args.limit]
    store=KnowledgeStore(args.db)
    report={"startedAt":utcnow(),"requested":len(urls),"published":[],"failed":[]}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending={pool.submit(fetch_document,url,Path(args.raw_dir)):url for url in urls}
        for future in as_completed(pending):
            url=pending[future]
            try:
                doc,chunks=future.result()
                store.put_document(doc,chunks)
                store.job(url,"published")
                report["published"].append({"id":doc["id"],"url":url,"title":doc["title"],"chunks":len(chunks),"publishedAt":doc["publishedAt"]})
            except Exception as error:
                detail=str(error)
                store.job(url,"failed",detail)
                report["failed"].append({"url":url,"error":detail})
            done=len(report["published"])+len(report["failed"])
            if done%25==0:
                print(json.dumps({"done":done,"published":len(report["published"]),"failed":len(report["failed"])}),flush=True)
    report["completedAt"]=utcnow()
    Path(args.report).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"published":len(report["published"]),"failed":len(report["failed"])},ensure_ascii=False))


if __name__=="__main__":
    main()
