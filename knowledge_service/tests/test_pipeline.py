import hashlib
from pathlib import Path
import sys
import pytest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from knowledge_service.html_body import parse_html
from knowledge_service.ingest import make_document
from knowledge_service.store import KnowledgeStore


def test_cms_body_preserves_table_and_real_date_without_footer():
    body='请申请人核对下列材料与适用范围。'*8
    page=f'<html><title>2024级学生2026年申请通知</title><span>发布时间：2026年09月04日</span><div id="vsb_content"><p>{body}</p><table><tr><td>对象</td><td>截止</td></tr><tr><td>本科生</td><td>9月18日17:00</td></tr></table><a href="/apply">申请入口</a></div><footer>页脚联系电话999</footer></html>'
    _,text,date,_=parse_html(page.encode(),'https://jwc.xidian.edu.cn/info/test.htm')
    assert date=='2026-09-04'
    assert '本科生 | 9月18日17:00' in text
    assert 'https://jwc.xidian.edu.cn/apply' in text
    assert '999' not in text


def test_missing_date_is_not_guessed_from_title():
    _,_,date,_=parse_html(('<title>2024级申请通知</title><div id="vsb_content">'+ '申请材料须完整提交。'*15+'</div>').encode(),'https://xidian.edu.cn/2024/info.htm')
    assert date is None


def test_empty_article_does_not_publish_navigation():
    with pytest.raises(ValueError,match='正文不足'):
        parse_html(('<title>研究生申请通知</title><div id="vsb_content"></div><footer>'+'学校联系电话 导航链接 '*20+'</footer>').encode(),'https://gr.xidian.edu.cn/info/test.htm')


def test_revisions_and_disabling_remove_old_evidence(tmp_path):
    store=KnowledgeStore(str(tmp_path/'knowledge.db'))
    doc,chunks=make_document('办理说明','申请表和成绩单。'*100,'https://xidian.edu.cn/notice.htm')
    store.put_document(doc,chunks)
    old_ids=[c['id'] for c in chunks]
    updated,new_chunks=make_document('办理说明','只需申请表。'*100,doc['sourceUrl'])
    store.put_document(updated,new_chunks)
    assert store.get_chunks(old_ids)==[]
    assert store.get_chunks([new_chunks[0]['id']])
    store.set_status(doc['id'],'disabled')
    assert store.get_chunks([new_chunks[0]['id']])==[]
    assert store.neighbors(doc['id'],0)==[]


def test_policy_replacement_archives_previous_in_same_transaction(tmp_path):
    store=KnowledgeStore(str(tmp_path/'knowledge.db'))
    old,old_chunks=make_document('旧通知','9月10日前申请。','https://xidian.edu.cn/old.htm')
    store.put_document(old,old_chunks)
    new,new_chunks=make_document('新通知','9月20日前申请，本通知替代旧通知。','https://xidian.edu.cn/new.htm')
    new['supersedesId']=old['id'];store.put_document(new,new_chunks)
    assert store.get_document(old['id'])['status']=='archived'
    assert store.get_chunks([old_chunks[0]['id']])==[]
    assert store.get_chunks([new_chunks[0]['id']])
