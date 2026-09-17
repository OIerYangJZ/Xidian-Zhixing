"""Internal knowledge API transport; retrieval errors are never lexical fallbacks."""
import json
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
from urllib.error import HTTPError,URLError
from urllib.request import Request,urlopen

import _globals

_ORIGINAL_CACHE_TTL = 300
_ORIGINAL_CACHE_LIMIT = 128
_original_cache: dict[str, tuple[float, dict]] = {}
_original_cache_lock = threading.RLock()
_ORIGINAL_FETCH_POOL = ThreadPoolExecutor(
    max_workers=8,
    thread_name_prefix="rag-original",
)


def knowledge_request(path:str,body:dict|None=None,*,timeout=30):
    if not _globals.RAG_URL or not _globals.RAG_API_KEY:
        raise RuntimeError("服务器尚未配置知识检索服务")
    request=Request(_globals.RAG_URL+path,
        data=json.dumps(body,ensure_ascii=False).encode("utf-8") if body is not None else None,
        headers={"Content-Type":"application/json","Authorization":"Bearer "+_globals.RAG_API_KEY})
    try:
        with urlopen(request,timeout=timeout) as response:
            return json.loads(response.read())
    except HTTPError as error:
        raise RuntimeError(f"知识检索服务返回错误（HTTP {error.code}）") from error
    except (URLError,TimeoutError) as error:
        raise RuntimeError("知识检索服务连接失败或超时") from error


def search_knowledge(query:str,*,queries=None,filters=None,include_community=False,limit=8,trace_id=None):
    result = knowledge_request("/search",{
        "query":query,"queries":queries or [query],"filters":filters or {},
        "includeCommunity":include_community,"limit":limit,"traceId":trace_id,
    })
    items = result.get("items", []) if isinstance(result, dict) else []
    document_ids = list(dict.fromkeys(
        str(item.get("documentId", "")).strip()
        for item in items if isinstance(item, dict) and str(item.get("documentId", "")).strip()
    ))[:4]

    def load_original(document_id: str):
        now = time.monotonic()
        with _original_cache_lock:
            cached = _original_cache.get(document_id)
            if cached and now - cached[0] < _ORIGINAL_CACHE_TTL:
                return document_id, cached[1]
        try:
            document = knowledge_request(f"/documents/{document_id}/content", timeout=12)
        except RuntimeError:
            return document_id, None
        with _original_cache_lock:
            _original_cache[document_id] = (now, document)
            if len(_original_cache) > _ORIGINAL_CACHE_LIMIT:
                oldest = min(_original_cache, key=lambda key: _original_cache[key][0])
                _original_cache.pop(oldest, None)
        return document_id, document

    originals: dict[str, dict] = {}
    futures = [
        _ORIGINAL_FETCH_POOL.submit(load_original, document_id)
        for document_id in document_ids
    ]
    for future in as_completed(futures):
        document_id, document = future.result()
        if isinstance(document, dict) and document.get("content"):
            originals[document_id] = document
    for item in items:
        if not isinstance(item, dict):
            continue
        original = originals.get(str(item.get("documentId", "")).strip())
        if original:
            item["originalContent"] = original.get("content", "")
            item["originalTitle"] = original.get("title", item.get("title", ""))
            item["originalSourceUrl"] = original.get("sourceUrl", item.get("sourceUrl", ""))
            item["rawObjectKey"] = original.get("rawObjectKey", "")
    return result
