"""Actual HTTP/model acceptance runner. Records failures; never substitutes mocked answers."""
import argparse
import json
from pathlib import Path
import time
import re
import requests


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--cases',required=True)
    parser.add_argument('--config-dir',default='artifacts/ai/local');parser.add_argument('--output',required=True)
    args=parser.parse_args();root=Path(args.config_dir)
    config=json.loads((root/'backend-env.json').read_text())
    session=json.loads((root/'test-session.json').read_text())
    headers={'Authorization':'Bearer '+session['token']}
    knowledge_headers={'Authorization':'Bearer '+config['BACKEND_RAG_API_KEY']}
    requests.get('http://127.0.0.1:18080/api/health',timeout=15).raise_for_status()
    ready=requests.get(config['BACKEND_RAG_URL']+'/status',headers=knowledge_headers,timeout=15)
    ready.raise_for_status()
    if ready.json()['ready'] is not True:
        raise RuntimeError('Knowledge index is not ready for acceptance')
    cases=json.loads(Path(args.cases).read_text(encoding='utf8'));results=[]
    for case in cases:
        started=time.perf_counter()
        row={'id':case['id'],'question':case.get('question'),'status':'failed'}
        try:
            body=case.get('body') or {'content':case['question'],'messages':case.get('messages',[])}
            response=requests.post('http://127.0.0.1:18080/api/'+case.get('endpoint','ai/chat'),
                headers=headers,json=body,timeout=165)
            row['httpStatus']=response.status_code
            if not response.ok:
                row['errorResponse']=response.json()
            response.raise_for_status();data=response.json()['data'];row['response']=data
            answer=data['answer']
            trace=requests.get(config['BACKEND_RAG_URL']+'/traces/'+data['traceId'],headers=knowledge_headers,timeout=15)
            trace.raise_for_status();row['trace']=trace.json()
            checks={
                'answerFields':all(value in answer for value in case.get('contains',[])),
                'answerAlternatives':all(any(value in answer for value in group) for group in case.get('containsAny',[])),
                'noForbiddenValues':not any(value in answer for value in case.get('excludes',[])),
                'promptInjected':bool(row['trace'].get('systemPayloadHash')) and data['promptVersion'].startswith('xiaodian-'),
                'intent':row['trace']['queryPlan']['intent'] in case.get('allowedIntents',[case['intent']]),
            }
            if case.get('noPhone'):
                checks['noInventedPhone']=not re.search(r'\d[\d\s-]{6,}\d',answer)
            if row['trace']['queryPlan']['intent'] in {'campus_qa','personal_data'}:
                checks['hybridRetrieval']=row['trace']['retrievalMode']=='dense_bm25_rrf_rerank'
                if 'expectedCampus' in case:
                    checks['campusScope']=row['trace']['filters'].get('campus')==case['expectedCampus']
                expected=case.get('expectedDocuments') or ([case['expectedDocument']] if case.get('expectedDocument') else [])
                if expected:
                    checks['expectedEvidence']=any(doc in value for doc in expected for value in row['trace']['usedSourceIds'])
            row['checks']=checks;row['status']='passed' if all(checks.values()) else 'failed'
        except Exception as error:
            row['error']=str(error)
        row['elapsedMs']=round((time.perf_counter()-started)*1000);results.append(row)
        Path(args.output).write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
        print(json.dumps({'id':row['id'],'status':row['status'],'elapsedMs':row['elapsedMs'],'checks':row.get('checks'),'error':row.get('error')},ensure_ascii=False),flush=True)
    if any(row['status']!='passed' for row in results):
        raise SystemExit(1)


if __name__=='__main__':
    main()
