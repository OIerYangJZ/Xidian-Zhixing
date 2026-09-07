"""Exercise actual incremental retrieval and application visibility in the isolated local DB."""
import json
from pathlib import Path
import sqlite3
import uuid
import requests


def main():
    root=Path('artifacts/ai/local')
    config=json.loads((root/'backend-env.json').read_text())
    token=json.loads((root/'test-session.json').read_text())['token']
    headers={'Authorization':'Bearer '+config['BACKEND_RAG_API_KEY']}
    def request(path,body=None):
        response=requests.request('POST' if body is not None else 'GET',config['BACKEND_RAG_URL']+path,
            headers=headers,json=body,timeout=180)
        response.raise_for_status();return response.json()
    def search(question):
        return request('/search',{'query':question,'limit':4,'includeCommunity':True})
    suffix=uuid.uuid4().hex[:8];doc_id='acceptance-'+suffix;post_id='acceptance-post-'+suffix
    title='紫杉工坊本地验收 '+suffix
    body={'id':doc_id,'title':title,'content':'紫杉工坊临时办理码为 XD-7319。本条仅为本地验收数据。',
        'sourceUrl':'','authority':'curated'}
    result={'scope':'isolated local DB; real BGE/BM25/RRF/rerank and real application search','checks':{}}
    created=[]
    def app_search():
        response=requests.post('http://127.0.0.1:18080/api/ai/search',
            headers={'Authorization':'Bearer '+token},json={'query':title},timeout=120)
        response.raise_for_status();return response.json()
    try:
        request('/documents',body)
        created.append(doc_id)
        first=search(title+'临时办理码');result['firstTrace']=first['trace']['traceId']
        result['checks']['publishedRetrieved']=any(r['documentId']==doc_id and 'XD-7319' in r['content'] for r in first['items'])
        body['content']='紫杉工坊临时办理码现为 XD-8420，之前的办理码作废。本条仅为本地验收数据。'
        request('/documents',body)
        changed=search(title+'临时办理码');result['updatedTrace']=changed['trace']['traceId']
        result['checks']['revisionReplaced']=any(r['documentId']==doc_id and 'XD-8420' in r['content'] for r in changed['items']) and not any('XD-7319' in r['content'] for r in changed['items'])
        replacement_id=doc_id+'-replacement'
        request('/documents',{**body,'id':replacement_id,'supersedesId':doc_id,
            'content':'紫杉工坊临时办理码为 XD-9662。本通知明确替代旧通知，仅为本地验收数据。'})
        created.append(replacement_id)
        replaced=search(title+'临时办理码')
        result['checks']['supersededAbsent']=any(r['documentId']==replacement_id for r in replaced['items']) and all(r['documentId']!=doc_id for r in replaced['items'])
        request('/documents/status',{'id':replacement_id,'status':'disabled'})
        request('/documents/status',{'id':doc_id,'status':'disabled'})
        disabled=search(title+'临时办理码');result['disabledTrace']=disabled['trace']['traceId']
        result['checks']['disabledAbsent']=all(r['documentId']!=doc_id for r in disabled['items'])
        with sqlite3.connect(root/'app-local.db') as db:
            user_id=db.execute('SELECT user_id FROM sessions WHERE token=?',(token,)).fetchone()[0]
            db.execute('INSERT INTO posts(id,title,content,channel,status,author_alias,author_id,created_at,updated_at,review_status) VALUES(?,?,?,?,?,?,?,?,?,?)',
                (post_id,title,'紫杉工坊公开讨论的临时办理码是 XD-9551。','校园生活','active','本地验收',user_id,'2026-09-07','2026-09-07','approved'))
        request('/documents',{'id':'post-'+post_id,'postId':post_id,'title':title,
            'content':'紫杉工坊公开讨论的临时办理码是 XD-9551。','sourceUrl':'','authority':'community','channel':'校园生活'})
        created.append('post-'+post_id)
        public=app_search()
        result['checks']['publicPostVisible']=any(r['targetId']==post_id for r in public['data']['items'])
        # Leave the indexed copy public to verify live application filtering before periodic sync.
        with sqlite3.connect(root/'app-local.db') as db:
            db.execute("UPDATE posts SET visibility='private' WHERE id=?",(post_id,))
        private=app_search()
        result['checks']['privatePostHidden']=all(r['targetId']!=post_id for r in private['data']['items'])
        with sqlite3.connect(root/'app-local.db') as db:
            db.execute("UPDATE posts SET visibility='public',deleted=1 WHERE id=?",(post_id,))
        deleted=app_search()
        result['checks']['deletedPostHidden']=all(r['targetId']!=post_id for r in deleted['data']['items'])
    finally:
        with sqlite3.connect(root/'app-local.db') as db:
            db.execute('DELETE FROM posts WHERE id=?',(post_id,))
        for key in created:
            request('/documents/status',{'id':key,'status':'archived'})
        status=request('/status')
        result['checks']['manifestCountMatchesPublished']=status['index']['chunkCount']==status['knowledgeCount']+status['postCount']
        (root/'knowledge-lifecycle.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(result,ensure_ascii=False))
    if not all(result['checks'].values()):
        raise SystemExit(1)


if __name__=='__main__':
    main()
