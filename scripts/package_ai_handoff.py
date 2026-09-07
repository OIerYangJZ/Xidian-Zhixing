"""Build a portable manual-deployment handoff from explicit inputs, without local sessions."""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import zipfile


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle,'sha256').hexdigest()


def archive(path, files, *, compressed=True):
    manifest=[]
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED) as output:
        for source,target in files:
            output.write(source,target)
            manifest.append({'path':target,'bytes':source.stat().st_size,'sha256':digest(source)})
        output.writestr('MANIFEST.json',json.dumps(manifest,ensure_ascii=False,indent=2))
    return {'file':path.name,'bytes':path.stat().st_size,'sha256':digest(path),'files':len(manifest)}


def tree(root,prefix):
    return [(p,prefix+'/'+p.relative_to(root).as_posix()) for p in sorted(root.rglob('*'))
        if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc']


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--db',required=True);parser.add_argument('--web',required=True)
    parser.add_argument('--output',required=True);parser.add_argument('--models')
    args=parser.parse_args();root=Path(__file__).resolve().parents[1]
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
    code=[]
    for name in ['server.py','_globals.py','object_storage.py','rag_service.py','sql_repository.py',
                 'requirements-storage.txt','requirements-auth.txt']:
        code.append((root/'backend'/name,'backend/'+name))
    for name in ['handlers','helpers','services']:
        code.extend(tree(root/'backend'/name,'backend/'+name))
    for name in ['knowledge_service','deploy/knowledge','docs/ai']:
        code.extend(tree(root/name,name))
    for name in ['evaluate_local_ai.py','verify_local_knowledge.py','verify_local_rag_grounding.py','knowledge_request.py','package_ai_handoff.py']:
        code.append((root/'scripts'/name,'scripts/'+name))
    for name in ['flutter_app/lib/core/l10n/campus_text.dart','flutter_app/lib/features/ai/ai_page.dart',
                 'flutter_app/lib/repositories/ai_repository.dart','miniprogram/api/ai.js',
                 'miniprogram/pages/ai/chat/index.js']:
        code.append((root/name,'client-source-changes/'+name))
    code.extend((p,n) for p,n in tree(Path(args.web),'web') if p.name!='local-test-login.html')
    manifest={'scope':'manual deployment; local test credentials and community corpus excluded','archives':[]}
    manifest['archives'].append(archive(out/'xiaodian-code-web.zip',code))
    with tempfile.TemporaryDirectory(prefix='xiaodian-handoff-') as temporary:
        snapshot=Path(temporary)/'knowledge.db'
        with sqlite3.connect(args.db) as source,sqlite3.connect(snapshot) as target:
            source.backup(target)
            target.execute('PRAGMA foreign_keys=ON')
            target.execute("DELETE FROM documents WHERE json_extract(data,'$.authority')='community'")
            target.execute("DELETE FROM documents WHERE id LIKE 'acceptance-%'")
            target.execute('DELETE FROM traces');target.execute('DELETE FROM jobs');target.execute('DELETE FROM settings')
            raws={}
            for key,raw in target.execute('SELECT id,data FROM documents').fetchall():
                doc=json.loads(raw)
                if doc.get('rawObjectKey'):
                    original=Path(doc['rawObjectKey'])
                    doc['rawObjectKey']='data/raw/'+original.name
                    raws[doc['rawObjectKey']]=original
                target.execute('UPDATE documents SET data=? WHERE id=?',(json.dumps(doc,ensure_ascii=False),key))
            target.commit();target.execute('VACUUM')
            manifest['publishedDocuments']=target.execute("SELECT count(*) FROM documents WHERE status='published'").fetchone()[0]
            target.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        source.close();target.close()
        manifest['archives'].append(archive(out/'xiaodian-official-data.zip',[(snapshot,'data/knowledge.db'),
            *((p,n) for n,p in sorted(raws.items()))]))
    if args.models:
        model_files=[]
        for name in ['bge-m3','bge-reranker-v2-m3']:
            model_files.extend(tree(Path(args.models)/name,'models/'+name))
        manifest['archives'].append(archive(out/'xiaodian-bge-models.zip',model_files,compressed=False))
    (out/'HANDOFF.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(manifest,ensure_ascii=False))


if __name__=='__main__':
    main()
