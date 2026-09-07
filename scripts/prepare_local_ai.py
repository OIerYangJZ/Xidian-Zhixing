"""Prepare an isolated local acceptance DB and one explicit test session.

Never used by the backend or included in a production login flow.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import sqlite3


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source-db',required=True)
    parser.add_argument('--student-id',required=True)
    parser.add_argument('--output-dir',required=True)
    args=parser.parse_args()
    root=Path(args.output_dir).resolve();root.mkdir(parents=True,exist_ok=True)
    target=root/'app-local.db'
    if target.exists():
        raise ValueError('Local database already exists; reuse it or choose a new output directory')
    with sqlite3.connect(Path(args.source_db).resolve().as_uri()+'?mode=ro',uri=True) as source:
        with sqlite3.connect(target) as dest:
            source.backup(dest)
            user=dest.execute('SELECT id FROM users WHERE student_id=?',(args.student_id,)).fetchone()
            if user is None:
                raise ValueError('Authorized test account is not present in local database')
            token=secrets.token_urlsafe(32)
            dest.execute('DELETE FROM sessions')
            dest.execute('INSERT INTO sessions VALUES(?,?,?)',(token,user[0],datetime.now(timezone.utc).isoformat()))
    config={'BACKEND_DB_FILE':str(target),'BACKEND_HOST':'127.0.0.1','BACKEND_PORT':'18080',
        'BACKEND_CORS_ALLOWED_ORIGINS':'http://127.0.0.1:18080','BACKEND_STORAGE_DIR':str(root/'storage'),
        'BACKEND_WEB_ROOT':str(root/'web'),'BACKEND_AI_BASE_URL':'http://127.0.0.1:11434/v1',
        'BACKEND_AI_API_KEY':'local-ollama','BACKEND_AI_MODEL':'xiaodian-local-instruct',
        'BACKEND_AI_QUERY_TIMEOUT':'40','BACKEND_AI_CONTEXT_ITEMS':'4',
        'BACKEND_ADMIN_USERNAME':'local_ai_admin','BACKEND_ADMIN_PASSWORD':secrets.token_urlsafe(24),
        'BACKEND_RAG_URL':'http://127.0.0.1:8091','BACKEND_RAG_API_KEY':secrets.token_urlsafe(32)}
    (root/'backend-env.json').write_text(json.dumps(config,indent=2),encoding='utf8')
    (root/'test-session.json').write_text(json.dumps({'token':token}),encoding='utf8')
    web=root/'web';web.mkdir(exist_ok=True)
    (web/'local-test-login.html').write_text('''<!doctype html><meta charset="utf-8"><title>小电本地验收</title>
<h1>小电本地验收</h1><p>仅连接此电脑的隔离数据库。此入口不属于正式登录功能。</p>
<button onclick='localStorage.setItem("flutter.xdu_treehole_auth_token", JSON.stringify('''+json.dumps(token)+'''));location.href="/"'>进入本地电台</button>''',encoding='utf8')
    print('Local database, configuration and test entry created; session not printed.')


if __name__=='__main__':
    main()
