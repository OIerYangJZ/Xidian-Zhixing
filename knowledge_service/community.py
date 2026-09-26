"""Periodic export of approved public posts; business visibility is checked again at use."""
import argparse
import json
from pathlib import Path
import sqlite3
import requests
import os
from .store import content_hash


def snapshot(path):
    with sqlite3.connect(Path(path).resolve().as_uri()+'?mode=ro',uri=True) as db:
        db.row_factory=sqlite3.Row
        return [dict(row) for row in db.execute('SELECT id,title,content,visibility,deleted,review_status,created_at,updated_at,channel FROM posts')]


def sync(path, request):
    previous = {d['id']:d for d in request('/documents')['items'] if d.get('authority')=='community'}
    active=set()
    count=0
    for row in snapshot(path):
        if row['deleted'] or row['visibility']=='private' or row['review_status'] not in {'approved','resolved'}:
            continue
        doc_id='post-'+row['id'];active.add(doc_id)
        old=previous.get(doc_id)
        if old and old['status']=='published' and old['contentHash']==content_hash(row['content']) and old['title']==row['title']:
            continue
        request('/documents',{'id':doc_id,'postId':row['id'],'title':row['title'], 'content':row['content'],
            'sourceId':'public-forum','sourceUrl':'','authority':'community',
            'publishedAt':row['created_at'],'postUpdatedAt':row['updated_at'],'channel':row['channel']})
        count+=1
    for doc_id,doc in previous.items():
        if doc_id not in active and doc['status']=='published':
            request('/documents/status',{'id':doc_id,'status':'disabled'});count+=1
    return {'changed':count,'publicPosts':len(active)}


def main():
    p=argparse.ArgumentParser();p.add_argument('--app-db',required=True);args=p.parse_args()
    def request(path,body=None):
        response=requests.request('POST' if body is not None else 'GET',os.environ['KNOWLEDGE_URL']+path,
            headers={'Authorization':'Bearer '+os.environ['KNOWLEDGE_API_KEY']},json=body,timeout=180)
        response.raise_for_status();return response.json()
    print(json.dumps(sync(args.app_db,request)))


if __name__=='__main__':
    main()
