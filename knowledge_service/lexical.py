"""Chinese BM25 with real term frequencies; RRF joins independent rank lists."""
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
import math
import re

import jieba


STOP_WORDS = set("的 了 是 在 我 你 他 她 它 吗 呢 吧 啊 和 与 及 或 怎么 如何 什么 哪些 哪里 请 请问 帮 帮我 一下 这个 那个 可以 需要 有 没有 进行 相关 以及 为 对 将 还 就 都 很 想 要 能 该 今天 现在 目前 当前 西电 西安电子科技大学".split())
ALIASES = {"南校区": "长安校区", "北校区": "雁塔校区", "寝室": "宿舍",
    "来访人员": "访客", "来校访客": "访客", "来访者": "访客",
    "连不上": "无法连接", "断网": "网络故障"}
GENERIC_QUERY_TERMS = set("申请 办理 补办 流程 条件 要求 开放 时间 联系 联系方式 电话 方法 方式 怎么 如何 查询 需要 怎样 哪里 地址".split())
FACILITY_REPAIR_CONTEXT = ("宿舍", "寝室", "公寓", "热水", "浴室", "澡堂", "水龙头", "淋浴")
REPAIR_INDICATORS = ("报修", "维修", "故障", "坏", "漏水", "漏电", "失灵", "不出水")
TIME_QUERY_CUES = ("什么时候", "何时", "时间", "开始", "截止", "哪天", "几号", "几点", "日期", "起止", "周末", "周六", "周日", "周几", "星期")
for word in ["长安校区", "雁塔校区", "南校区", "北校区", "国家励志奖学金", "国家奖学金", "国家助学金", "奖励标准", "资助标准", "系统开放时间", "补退选", "转专业", "校园网", "一网通办", "无线网", "无线网络", "校园卡", "一卡通", "挂失", "来校访客", "因公网络账号申请", "受访单位", "预付费电表", "免费电额度", "上半年", "下半年", "网报时间", "工作时间", "就诊时间", "门诊时间", "周六", "周日"]:
    jieba.add_word(word)


def tokens(text: str) -> list[str]:
    text = re.sub(r"校园卡(?:丢失|丢了|遗失)", "一卡通 挂失", text, flags=re.I)
    text = re.sub(r"wi[\s-]*fi|无线网(?!络)", "无线网络", text, flags=re.I)
    for original, canonical in ALIASES.items():
        text = text.replace(original, canonical)
    return [w for w in jieba.lcut(text.lower()) if w not in STOP_WORDS and re.search(r"[\w\u4e00-\u9fff]", w)]


class BM25:
    def __init__(self, rows: list[dict]):
        self.rows = {r["id"]: r for r in rows}
        self.postings = defaultdict(dict)
        self.lengths = {}
        self.title_terms = {}
        self.content_terms = {}
        for row in rows:
            title_terms = tokens(row["title"])
            content_terms = tokens(row["content"])
            self.title_terms[row["id"]] = set(title_terms)
            self.content_terms[row["id"]] = set(content_terms)
            terms = title_terms + title_terms + content_terms
            self.lengths[row["id"]] = len(terms)
            for term, count in Counter(terms).items():
                self.postings[term][row["id"]] = count
        self.average_length = sum(self.lengths.values()) / max(1,len(rows))

    def search(self, query: str, limit=30, allowed=None):
        scores = defaultdict(float)
        n = len(self.rows)
        query_terms=set(tokens(query))
        normalized_query=query.lower()
        if (any(term in normalized_query for term in FACILITY_REPAIR_CONTEXT)
                and any(term in normalized_query for term in REPAIR_INDICATORS)):
            # The campus hotline is a generic intake path; expand the query while
            # leaving specialized repair documents indexed with their own wording.
            query_terms.add("热线")
        if (any(term in normalized_query for term in ("奖学金", "助学金", "资助"))
                and any(term in normalized_query for term in ("金额", "多少钱", "多少元", "标准", "额度", "固定发放"))):
            query_terms.update(("奖励标准", "资助标准"))
        if (any(term in normalized_query for term in ("选课", "培养计划", "选班"))
                and any(term in normalized_query for term in TIME_QUERY_CUES)):
            query_terms.add("系统开放时间")
        if (any(term in normalized_query for term in ("医保报销", "门诊报销"))
                and not re.search(r"(?:19|20)\d{2}", normalized_query)):
            current_year=datetime.now(timezone(timedelta(hours=8))).year
            query_terms.update(tokens(str(current_year)))
        cet_time_query=(any(term in normalized_query for term in ("四六级", "英语四级", "英语六级", "cet"))
            and any(term in normalized_query for term in TIME_QUERY_CUES))
        if cet_time_query and "报名" in normalized_query:
            query_terms.add("网报时间")
        if (cet_time_query
                and not any(term in normalized_query for term in ("上半年", "下半年"))
                and not re.search(r"(?:19|20)\d{2}", normalized_query)):
            current_date=datetime.now(timezone(timedelta(hours=8)))
            half="上半年" if current_date.month<=6 else "下半年"
            query_terms.update(tokens(f"{current_date.year} {half}"))
        if any(term in normalized_query for term in ("登录失败", "无法登录", "登录不上", "登不上")):
            query_terms.update(tokens("账号激活 忘记密码"))
        if (any(term in normalized_query for term in ("校园网", "无线网", "无线网络", "wifi", "wi-fi"))
                and any(term in normalized_query for term in ("访客", "来访", "外来人员", "校外人员"))):
            query_terms.update(tokens("来校访客 网络接入认证 因公网络账号申请 受访单位"))
        if (any(term in normalized_query for term in ("宿舍", "寝室", "公寓", "住宿"))
                and any(term in normalized_query for term in ("电费", "电表", "充值", "用电"))):
            query_terms.update(("电表", "预付费电表", "免费电额度"))
        if "周末" in normalized_query:
            query_terms.update(tokens("周六 周日"))
        if (any(term in normalized_query for term in ("校医院", "医院", "门诊", "就诊", "急诊"))
                and any(term in normalized_query for term in TIME_QUERY_CUES)):
            query_terms.update(("工作时间", "就诊时间", "门诊时间"))
        for term in sorted(query_terms):
            posting = self.postings.get(term, {})
            idf = math.log(1 + (n-len(posting)+0.5)/(len(posting)+0.5))
            for key, tf in posting.items():
                if allowed is not None and key not in allowed:
                    continue
                scores[key] += idf * tf * 2.2 / (tf+1.2*(0.25+0.75*self.lengths[key]/max(1,self.average_length)))
                if (len(term) > 1 and term not in GENERIC_QUERY_TERMS and idf >= 1.2
                        and term in self.title_terms[key] and term in self.content_terms[key]):
                    scores[key] += idf * 4
        return sorted(scores.items(), key=lambda item:(-item[1],item[0]))[:limit]


def reciprocal_rank_fusion(rankings: list[list[tuple[str,float]]], limit=60, rows_by_key=None):
    scores = defaultdict(float)
    representative_scores = defaultdict(float)
    representative_keys = defaultdict(set)
    for rows in rankings:
        seen = set()
        for rank, (key, _) in enumerate(rows, 1):
            row = (rows_by_key or {}).get(key, {})
            identity = row.get("contentHash") or key
            if identity in seen:
                continue
            seen.add(identity)
            contribution = 1 / (60+rank)
            scores[identity] += contribution
            representative_scores[(identity,key)] += contribution
            representative_keys[identity].add(key)
    authority_priority = {"official":3,"verified":2,"curated":1,"community":0}
    fused=[]
    for identity, score in scores.items():
        key=max(representative_keys[identity],key=lambda candidate:(
            authority_priority.get((rows_by_key or {}).get(candidate,{}).get("authority"),-1),
            (rows_by_key or {}).get(candidate,{}).get("publishedAt") or "",
            representative_scores[(identity,candidate)],candidate))
        fused.append((key,score))
    return sorted(fused, key=lambda item:(-item[1],item[0]))[:limit]
