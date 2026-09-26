"""Admin knowledge routes now edit the independent canonical knowledge store."""
from http import HTTPStatus

from helpers import json_error,read_json_body,send_json
from handlers._radio_handler import _require_admin
from services._rag_client import knowledge_request


def _source(doc):
    return {**doc,"name":doc["title"],"sourceType":"knowledge_document","documentCount":1,
        "contentLength":len(doc.get("content",""))}


def list_sources(handler,db):
    if _require_admin(handler,db) is None:
        return
    try:
        # Deleting archives a document; it no longer belongs in the list.
        docs=[d for d in knowledge_request("/documents")["items"] if d.get("status")!="archived"]
        status=knowledge_request("/status")
        send_json(handler,HTTPStatus.OK,{"data":{"items":[_source(d) for d in docs],"index":status}})
    except RuntimeError as error:
        json_error(handler,HTTPStatus.BAD_GATEWAY,str(error))


def read_trace(handler,db,trace_id):
    if _require_admin(handler,db) is None:
        return
    try:
        send_json(handler,HTTPStatus.OK,{"data":knowledge_request("/traces/"+trace_id)})
    except RuntimeError as error:
        json_error(handler,HTTPStatus.BAD_GATEWAY,str(error))


def write_source(handler,db,source_id=None):
    if _require_admin(handler,db) is None:
        return
    body=read_json_body(handler)
    try:
        if source_id and set(body).issubset({"status"}):
            result=knowledge_request("/documents/status",{"id":source_id,"status":body["status"]})
        else:
            previous=knowledge_request("/documents/"+source_id) if source_id else {}
            # An upsert publishes, so editing a deleted document would bring it
            # back into retrieval without anyone asking for that.
            if previous.get("status")=="archived":
                json_error(handler,HTTPStatus.CONFLICT,"该知识条目已删除，不能编辑")
                return
            payload={"title":body.get("name",previous.get("title","")),
                "content":body.get("content",previous.get("content","")),
                "sourceUrl":body.get("sourceUrl",previous.get("sourceUrl","")),
                "authority":body.get("authority",previous.get("authority","curated")),
                "publishedAt":body.get("publishedAt",previous.get("publishedAt"))}
            if source_id:
                payload["id"]=source_id
            for field in ("effectiveFrom","effectiveTo","supersedesId","campuses","educationLevels"):
                if field in body or field in previous:
                    payload[field]=body.get(field,previous.get(field))
            result=knowledge_request("/documents",payload,timeout=300)
            result=_source(result["document"])
        send_json(handler,HTTPStatus.OK if source_id else HTTPStatus.CREATED,{"data":result})
    except RuntimeError as error:
        json_error(handler,HTTPStatus.BAD_GATEWAY,str(error))


def delete_source(handler,db,source_id):
    if _require_admin(handler,db) is None:
        return
    try:
        result=knowledge_request("/documents/status",{"id":source_id,"status":"archived"})
        send_json(handler,HTTPStatus.OK,{"data":result})
    except RuntimeError as error:
        json_error(handler,HTTPStatus.BAD_GATEWAY,str(error))


def reindex(handler,db):
    if _require_admin(handler,db) is None:
        return
    try:
        result=knowledge_request("/reindex",{},timeout=600)
        send_json(handler,HTTPStatus.OK,{"data":{**result,"ok":True}})
    except RuntimeError as error:
        json_error(handler,HTTPStatus.BAD_GATEWAY,str(error))
