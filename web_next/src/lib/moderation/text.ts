const prohibitedTerms: Record<string, string[]> = {
  血腥: [
    '血腥',
    '血肉模糊',
    '肢解',
    '碎尸',
    '斩首',
    '开膛',
    '割喉',
    '断肢',
    '虐杀',
    'gore',
    'dismemberment',
    'beheading',
  ],
  暴力: ['暴力', '殴打', '群殴', '砍人', '捅人', '枪杀', '虐待', '家暴', '恐怖袭击', '校园霸凌', 'violent assault'],
  色情: [
    '色情',
    '淫秽',
    '成人影片',
    '成人视频',
    '黄色内容',
    '黄色图片',
    '黄色视频',
    '黄色网站',
    '裸聊',
    '约炮',
    '卖淫',
    '嫖娼',
    '强奸',
    '乱伦',
    'porn',
    'pornography',
    'sexual content',
  ],
  违法犯罪: [
    '违法犯罪',
    '诈骗',
    '毒品',
    '贩毒',
    '制毒',
    '赌博网站',
    '赌博平台',
    '洗钱',
    '枪支交易',
    '炸弹制作',
    '买卖身份证',
    '伪造证件',
    '入室盗窃',
    '抢劫',
    '绑架',
    '勒索',
    '黑客攻击',
    '盗号',
    'criminal activity',
    'drug trafficking',
    'money laundering',
  ],
};

const defaultSensitiveTerms = ['引流', '广告', '辱骂', '诈骗'];

const reviewPatterns: Array<[string, RegExp]> = [
  ['联系方式', /(?:加我|联系我|私聊|扫码|加v|加vx|加微|微信|威信|微[信芯]|qq|扣扣)/i],
  ['外部链接', /(?:https?:\/\/|www\.|短链|链接[:：])/i],
  ['手机号', /(?<!\d)1[3-9]\d{9}(?!\d)/],
  ['邮箱', /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i],
  ['营销话术', /(?:代理|加盟|兼职|刷单|返利|优惠券|折扣|促销|推广|引流|代购|赚钱|日赚|低价)/i],
];

function normalize(value: string) {
  return value
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\p{Cf}\p{Cc}]/gu, '');
}

function matchesTerm(text: string, term: string) {
  const normalizedTerm = normalize(term).trim();
  if (/^[a-z0-9 ]+$/.test(normalizedTerm)) {
    const pattern = new RegExp(
      `(?<![a-z0-9])${normalizedTerm
        .split(/\s+/)
        .map((word) => word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        .join('\\s+')}(?![a-z0-9])`,
      'i',
    );
    return pattern.test(text);
  }
  const compactText = text.replace(/[^\p{L}\p{N}]/gu, '');
  const compactTerm = normalizedTerm.replace(/[^\p{L}\p{N}]/gu, '');
  return compactTerm.length > 0 && compactText.includes(compactTerm);
}

export type TextModerationResult = {
  decision: 'approve' | 'review' | 'reject';
  reasons: string[];
};

export function assessPostText(value: string): TextModerationResult {
  const text = normalize(value).trim();
  if (!text) return { decision: 'approve', reasons: [] };

  const categories = Object.entries(prohibitedTerms)
    .filter(([, terms]) => terms.some((term) => matchesTerm(text, term)))
    .map(([category]) => category);
  if (categories.length) {
    return { decision: 'reject', reasons: categories.map((category) => `禁止内容类别：${category}`) };
  }

  const sensitiveTerms = [...defaultSensitiveTerms, ...(process.env.BACKEND_SENSITIVE_WORDS || '').split(/[,，\n]/)]
    .map((term) => term.trim())
    .filter(Boolean);
  const sensitiveHits = sensitiveTerms.filter((term) => matchesTerm(text, term));
  if (sensitiveHits.length) {
    return { decision: 'reject', reasons: [`命中敏感词：${sensitiveHits.slice(0, 3).join('、')}`] };
  }

  const reasons = reviewPatterns
    .filter(([, pattern]) => pattern.test(text))
    .map(([label]) => `疑似营销或导流：${label}`);
  if (/(.)\1{8,}/su.test(text)) reasons.push('疑似重复刷屏文本');
  if ([...text].length > 5000) reasons.push('文本长度异常');

  return { decision: reasons.length ? 'review' : 'approve', reasons };
}
