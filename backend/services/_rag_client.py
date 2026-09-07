"""Internal knowledge API transport; retrieval errors are never lexical fallbacks."""
import json
from urllib.error import HTTPError,URLError
from urllib.request import Request,urlopen

import _globals


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
    return knowledge_request("/search",{
        "query":query,"queries":queries or [query],"filters":filters or {},
        "includeCommunity":include_community,"limit":limit,"traceId":trace_id,
    })
