"""Versioned Qdrant dense retrieval + Chinese BM25 + neural reranking."""
from __future__ import annotations

from collections import Counter
from datetime import date, datetime, timezone, timedelta
import os
import threading
import time
import uuid

from qdrant_client import QdrantClient, models as qm

from .lexical import BM25, reciprocal_rank_fusion
from .store import KnowledgeStore, content_hash, utcnow


def date_day(value):
    if not value:
        return None
    try:
        return int(date.fromisoformat(str(value)[:10]).strftime("%Y%m%d"))
    except ValueError:
        return None


def matches_scope(row,*,today,campus=None,level=None):
    if campus and row.get("campuses") and campus not in row["campuses"]:
        return False
    if level and row.get("educationLevels") and level not in row["educationLevels"]:
        return False
    starts=date_day(row.get("effectiveFrom"))
    ends=date_day(row.get("effectiveTo"))
    today_number=date_day(today)
    return (starts is None or starts<=today_number) and (ends is None or ends>=today_number)


def narrow_candidates(rows,*,today,campus=None,level=None,limit=12):
    """Dedup, drop out-of-scope rows, then keep a document-diverse top slice.

    `rows` arrives in RRF order and the slice has to stay last.  Reranking a pair
    costs about a hundred times what recalling it does, so only `limit` pairs can
    be afforded -- but cutting before the filters would let a withdrawn, superseded
    or out-of-scope chunk occupy one of those slots and silently starve recall.
    A long document can contribute many highly ranked chunks, so cap it at the
    same three passages the response stage can return from one document.
    Returns the filtered list and the slice, so callers can trace both counts.
    """
    distinct={}
    for row in rows:
        distinct.setdefault(row["contentHash"],row)
    kept=[row for row in distinct.values()
        if matches_scope(row,today=today,campus=campus,level=level)]
    candidates=[]
    per_document=Counter()
    for row in kept:
        if len(candidates)>=limit:
            break
        document_id=row.get("documentId",row["id"])
        if per_document[document_id]>=3:
            continue
        candidates.append(row)
        per_document[document_id]+=1
    return kept,candidates


def dedupe_ranking(rows,lexical,limit=30):
    """Keep one representative of each exact chunk before fusion."""
    distinct=[]
    seen=set()
    for key,score in rows:
        row=lexical.rows.get(key)
        identity=(row.get("contentHash") if row else None) or key
        if identity in seen:
            continue
        seen.add(identity)
        distinct.append((key,score))
        if len(distinct)>=limit:
            break
    return distinct


def scope_qdrant_filter(authorities,*,campus=None,level=None,today=None):
    """Filter Qdrant before top-k so out-of-scope vectors cannot starve recall.

    Empty metadata remains eligible as a corpus-wide source. Existing collections
    without the scope payload are therefore compatible until their next reindex.
    """
    must=[qm.FieldCondition(key="authority",match=qm.MatchAny(any=authorities))]
    scopes=[]
    if campus:
        scopes.append(("campuses",qm.FieldCondition(
            key="campuses",match=qm.MatchValue(value=campus))))
    if level:
        scopes.append(("educationLevels",qm.FieldCondition(
            key="educationLevels",match=qm.MatchValue(value=level))))
    today_number=date_day(today)
    if today_number is not None:
        scopes.extend([
            ("effectiveFromDay",qm.FieldCondition(
                key="effectiveFromDay",range=qm.Range(lte=today_number))),
            ("effectiveToDay",qm.FieldCondition(
                key="effectiveToDay",range=qm.Range(gte=today_number))),
        ])
    for field,condition in scopes:
        must.append(qm.Filter(should=[condition,
            qm.IsEmptyCondition(is_empty=qm.PayloadField(key=field))]))
    return qm.Filter(must=must)


def point_payload(row):
    return {"chunkId":row["id"],"documentId":row["documentId"],
        "authority":row["authority"],"campuses":row.get("campuses",[]),
        "educationLevels":row.get("educationLevels",[]),
        "effectiveFromDay":date_day(row.get("effectiveFrom")),
        "effectiveToDay":date_day(row.get("effectiveTo"))}


class HybridEngine:
    def __init__(self,store:KnowledgeStore,models):
        self.store,self.models=store,models
        self.qdrant=QdrantClient(url=os.environ["KNOWLEDGE_QDRANT_URL"],
            api_key=os.environ.get("KNOWLEDGE_QDRANT_API_KEY") or None,timeout=30)
        self.lock=threading.RLock()
        self.index_write_lock=threading.Lock()
        # Required, not defaulted: a rerank threshold is only meaningful for the
        # model, input length, and corpus it was calibrated against. Fail at
        # startup instead of silently inheriting an unrelated cutoff.
        if "KNOWLEDGE_RERANK_THRESHOLD" not in os.environ:
            raise RuntimeError("必须设置 KNOWLEDGE_RERANK_THRESHOLD，且需针对当前重排配置和语料校准")
        self.rerank_threshold=float(os.environ["KNOWLEDGE_RERANK_THRESHOLD"])
        self._load_lexical()

    def _load_lexical(self):
        self.lexical=BM25(self.store.chunks())

    def build_index(self):
        with self.index_write_lock:
            return self._build_index()

    def _build_index(self):
        rows=self.store.chunks()
        if not rows:
            raise ValueError("知识库没有已发布片段，不能建立空索引")
        version="zhixing_v2_"+uuid.uuid4().hex[:16]
        self.qdrant.create_collection(version,
            vectors_config=qm.VectorParams(size=self.models.dimension,distance=qm.Distance.COSINE))
        for field,schema in (("authority",qm.PayloadSchemaType.KEYWORD),
            ("documentId",qm.PayloadSchemaType.KEYWORD),
            ("campuses",qm.PayloadSchemaType.KEYWORD),
            ("educationLevels",qm.PayloadSchemaType.KEYWORD),
            ("effectiveFromDay",qm.PayloadSchemaType.INTEGER),
            ("effectiveToDay",qm.PayloadSchemaType.INTEGER)):
            self.qdrant.create_payload_index(version,field_name=field,field_schema=schema)
        for start in range(0,len(rows),32):
            batch=rows[start:start+32]
            vectors=self.models.encode([row["searchText"] for row in batch])
            points=[qm.PointStruct(id=str(uuid.uuid5(uuid.NAMESPACE_URL,row["id"])),vector=vector,
                payload=point_payload(row))
                for row,vector in zip(batch,vectors)]
            self.qdrant.upsert(version,points=points,wait=True)
            if start%320==0:
                print(f"index {version}: {min(start+32,len(rows))}/{len(rows)}",flush=True)
        count=self.qdrant.count(version,exact=True).count
        if count!=len(rows):
            raise RuntimeError(f"向量数量不符：{count}/{len(rows)}")
        manifest={"collection":version,"chunkCount":count,"createdAt":utcnow(),
            "embeddingModel":self.models.embedding_name,"dimension":self.models.dimension,
            "corpusHash":content_hash("\n".join(sorted(row["id"] for row in rows)))}
        with self.lock:
            self.store.set_setting("activeIndex",manifest)
            self._load_lexical()
        return manifest

    def publish_document(self, doc, chunks):
        with self.index_write_lock:
            active = self.store.setting("activeIndex")
            old_chunk_ids={row["id"] for row in self.store.chunks_for_document(doc["id"])}
            if active:
                vectors = self.models.encode([row["searchText"] for row in chunks])
                self.qdrant.upsert(active["collection"], points=[
                    qm.PointStruct(id=str(uuid.uuid5(uuid.NAMESPACE_URL, row["id"])), vector=vector,
                        payload=point_payload(row))
                    for row,vector in zip(chunks,vectors)
                ], wait=True)
            with self.lock:
                self.store.put_document(doc, chunks)
                self._load_lexical()
            if active:
                obsolete_ids=old_chunk_ids-{row["id"] for row in chunks}
                try:
                    self._delete_chunk_vectors(active["collection"],obsolete_ids)
                    if doc.get("supersedesId"):
                        self._delete_document_vectors(active["collection"],doc["supersedesId"])
                finally:
                    with self.lock:
                        self._record_corpus_update(active)
            return active

    def _delete_chunk_vectors(self, collection, chunk_ids):
        if not chunk_ids:
            return
        point_ids=[str(uuid.uuid5(uuid.NAMESPACE_URL,chunk_id)) for chunk_id in chunk_ids]
        self.qdrant.delete(collection,points_selector=qm.PointIdsList(points=point_ids),wait=True)

    def _delete_document_vectors(self, collection, document_id):
        self.qdrant.delete(collection,points_selector=qm.FilterSelector(filter=qm.Filter(must=[
            qm.FieldCondition(key="documentId",match=qm.MatchValue(value=document_id))
        ])),wait=True)

    def _record_corpus_update(self, active):
        active["updatedAt"] = utcnow()
        active["chunkCount"] = len(self.lexical.rows)
        active["corpusHash"] = content_hash("\n".join(sorted(self.lexical.rows)))
        self.store.set_setting("activeIndex", active)

    def set_document_status(self, doc_id, status):
        with self.index_write_lock:
            doc=self.store.get_document(doc_id)
            if doc is None:
                raise ValueError("知识文档不存在")
            active=self.store.setting('activeIndex')
            if active and status=="published" and doc.get("status")!="published":
                chunks=self.store.chunks_for_document(doc_id)
                vectors=self.models.encode([row["searchText"] for row in chunks])
                self.qdrant.upsert(active["collection"],points=[
                    qm.PointStruct(id=str(uuid.uuid5(uuid.NAMESPACE_URL,row["id"])),vector=vector,
                        payload=point_payload(row))
                    for row,vector in zip(chunks,vectors)
                ],wait=True)
            elif active and status!="published":
                self._delete_document_vectors(active["collection"],doc_id)
            with self.lock:
                self.store.set_status(doc_id,status)
                self._load_lexical()
                if active:
                    self._record_corpus_update(active)

    def status(self):
        active=self.store.setting("activeIndex")
        return {"ready":active is not None,"index":active,
            "documentCount":len(self.store.documents(published_only=True)),
            "knowledgeCount":sum(r.get("type")!="post" for r in self.lexical.rows.values()),
            "postCount":sum(r.get("type")=="post" for r in self.lexical.rows.values()),
            "embeddingModel":self.models.embedding_name,"rerankModel":self.models.reranker_name}

    def search(self,query:str,*,queries=None,limit=8,include_community=False,filters=None,trace_id=None):
        started=time.perf_counter()
        trace_id=trace_id or uuid.uuid4().hex
        queries=list(dict.fromkeys([query,*(queries or [])]))[:3]
        filters=filters or {}
        with self.lock:
            active=self.store.setting("activeIndex")
            lexical=self.lexical
        if active is None:
            raise RuntimeError("知识库尚未建立混合索引")
        if active["embeddingModel"]!=self.models.embedding_name or active["dimension"]!=self.models.dimension:
            raise RuntimeError("向量模型与已发布索引不一致，需要重建索引")
        authorities=["official","verified","curated"]
        if include_community:
            authorities.append("community")
        today=datetime.now(timezone(timedelta(hours=8))).date().isoformat()
        campus=filters.get("campus")
        level=filters.get("educationLevel")
        allowed={key for key,row in lexical.rows.items()
            if row["authority"] in authorities and matches_scope(row,today=today,campus=campus,level=level)}
        vector_filter=scope_qdrant_filter(authorities,campus=campus,level=level,today=today)
        encode_started=time.perf_counter()
        vector_queries=self.models.encode(queries)
        encode_ms=round((time.perf_counter()-encode_started)*1000)
        rankings=[]
        stages=[]
        for text,vector in zip(queries,vector_queries):
            dense=self.qdrant.query_points(active["collection"],query=vector,limit=60,
                query_filter=vector_filter,
                with_payload=True).points
            dense_rows=dedupe_ranking(
                [(p.payload["chunkId"],float(p.score)) for p in dense
                    if p.payload.get("chunkId") in allowed],lexical,limit=30)
            sparse_rows=dedupe_ranking(lexical.search(text,limit=60,allowed=allowed),lexical,limit=30)
            rankings.extend([dense_rows,sparse_rows])
            stages.append({"query":text,"dense":dense_rows,"bm25":sparse_rows})
        fused=reciprocal_rank_fusion(rankings,limit=60,rows_by_key=lexical.rows)
        # The current relational state decides visibility, even if old vectors remain.
        # get_chunks returns rows in the order of the ids it is given, so the RRF
        # ranking survives into narrow_candidates, which relies on it.
        fetched=self.store.get_chunks([key for key,_ in fused])
        filtered,candidates=narrow_candidates(fetched,
            today=today,campus=campus,level=level,
            limit=int(os.environ.get("KNOWLEDGE_RERANK_CANDIDATES","12")))
        filtered_count=len(filtered)
        rerank_stats={}
        rerank_started=time.perf_counter()
        ranked=self.models.rerank(query,candidates,stats=rerank_stats)
        threshold=self.rerank_threshold
        selected=[]
        counts=Counter()
        for row in ranked:
            if row["rerankScore"]<threshold:
                continue
            if counts[row["documentId"]]>=3:
                continue
            selected.append(row)
            counts[row["documentId"]]+=1
            if len(selected)>=limit:
                break
        results=[]
        seen=set()
        chars=0
        context_budget=int(os.environ.get("KNOWLEDGE_CONTEXT_CHAR_BUDGET","16000"))
        # Each matched passage stays intact; neighbors supply missing adjacent clauses.
        for row in selected:
            for part in [row,*self.store.neighbors(row["documentId"],row["ordinal"])]:
                if part["id"] in seen or chars+len(part["content"])>context_budget:
                    continue
                seen.add(part["id"])
                chars+=len(part["content"])
                results.append({**part,"score":row["rerankScore"],
                    "retrievalRole":"match" if part["id"]==row["id"] else "neighbor",
                    "summary":part["content"][:260]})
        trace={"traceId":trace_id,"indexVersion":active["collection"],"retrievalMode":"dense_bm25_rrf_rerank",
            "corpusHash":active['corpusHash'],
            "query":query,"queries":queries,"filters":filters,"stages":stages,"fused":fused,
            "reranked":[{"id":r["id"],"score":r["rerankScore"]} for r in ranked],
            "contextIds":[r["id"] for r in results],
            # Counts at every narrowing step: a drop from fused to filtered points at
            # visibility or scope, a drop from filtered to reranked is this host's
            # latency budget, and truncatedPairs says whether the budget cost evidence.
            "queryCount":len(queries),"fusedCount":len(fused),"filteredCount":filtered_count,
            "scopeEligibleCount":len(allowed),
            "rerankedCount":len(ranked),"selectedCount":len(selected),
            **rerank_stats,
            "rerankThreshold":threshold,
            "encodeMs":encode_ms,
            "rerankMs":round((time.perf_counter()-rerank_started)*1000),
            "retrievalMs":round((time.perf_counter()-started)*1000)}
        self.store.trace(trace_id,trace)
        return {"items":results,"trace":trace}
